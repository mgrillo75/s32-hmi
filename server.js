const fs = require("fs");
const path = require("path");
const express = require("express");
const cors = require("cors");
const morgan = require("morgan");
const ModbusRTU = require("modbus-serial");

const CONFIG_PATH = path.join(__dirname, "modbus.config.json");
if (!fs.existsSync(CONFIG_PATH)) {
  console.error(`Missing configuration file at ${CONFIG_PATH}`);
  process.exit(1);
}
const config = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
const TAGS = config.tags || {};
const COMMANDS = config.commands || {};

const defaultState = {
  mode: "AUTO",
  commsOK: false,
  burnIn_s: 30,
  burnET: 0,
  burnActive: true,
  alarms: [],
  controlMode: 1,  // 1 = AUTO, 0 = MANUAL
  controlModeInput: 1,
  manualSetpoint_kW: 0,
  manualSetpointInput_kW: 0,
  testMode: 1,     // 1 = TEST (outputs disabled), 0 = LIVE (outputs enabled)
  testModeInput: 1,
  cfg: {
    targetPerGenKW: 2050,
    maxLB_kW: 2000,
    step_kW: 50,
    devCap_scaled: 10000,
    genHighLimit_kW: 2150,
    ramp_kW_per_min: 600,
    minHWStep_kW: 50,
    targetGenKW_read: 0,
    loadBankCap_read: 0,
    genHighLimit_read: 0
  },
  gen: { g1_kW: 0, g2_kW: 0, g3_kW: 0, g1_52A: false, g2_52A: false, g3_52A: false },
  lb: { measured_kW: 0, applied_kW: 0, available_kW: 0, setpoint_kW: 0 },
  wr: { busy: false, ok: false, err: null, last: null },
  meta: { lastPoll: null }
};

const state = JSON.parse(JSON.stringify(defaultState));
const tagCache = {};

const client = new ModbusRTU();
client.setTimeout(config.timeoutMs || 2000);

const app = express();
app.use(cors());
app.use(express.json());
app.use(morgan("dev"));

const HTTP_PORT = config.httpPort || 4000;
const POLL_INTERVAL = config.pollIntervalMs || 1000;

let modbusQueue = Promise.resolve();
function enqueue(work) {
  const job = modbusQueue.then(() => work());
  modbusQueue = job.catch(() => {});
  return job;
}

async function ensureConnection() {
  if (client.isOpen) return;
  await client.connectTCP(config.slaveHost, { port: config.slavePort });
  client.setID(config.unitId || 1);
}

function safeClose() {
  if (client.isOpen) {
    try { client.close(); } catch (_) {}
  }
}

function toSigned16(value) {
  return value > 0x7fff ? value - 0x10000 : value;
}

function toSigned32(buffer) {
  const signed = buffer.readInt32BE(0);
  return signed;
}

function decodeValue(raw, cfg) {
  const scale = cfg.scale ?? 1;
  const datatype = (cfg.datatype || "uint16").toLowerCase();
  if (datatype === "bool") {
    if (Array.isArray(raw)) return !!raw[0];
    return !!raw;
  }
  let value;
  switch (datatype) {
    case "int16":
      value = toSigned16(raw[0]);
      break;
    case "uint32":
      value = (raw[0] << 16) + raw[1];
      break;
    case "int32": {
      const buffer = Buffer.allocUnsafe(4);
      buffer.writeUInt16BE(raw[0], 0);
      buffer.writeUInt16BE(raw[1], 2);
      value = toSigned32(buffer);
      break;
    }
    case "float32": {
      const buffer = Buffer.allocUnsafe(4);
      buffer.writeUInt16BE(raw[0], 0);
      buffer.writeUInt16BE(raw[1], 2);
      value = buffer.readFloatBE(0);
      break;
    }
    default:
      value = raw[0];
  }
  return value * scale;
}

function encodeValue(value, cfg) {
  const datatype = (cfg.datatype || "uint16").toLowerCase();
  const scale = cfg.scale ?? 1;
  if (datatype === "bool") return [value ? 1 : 0];

  let working = value;
  if (datatype !== "float32" && scale !== 1) {
    working = Math.round(value / scale);
  }

  switch (datatype) {
    case "int16": {
      const val = working < 0 ? 0x10000 + working : working;
      return [val & 0xffff];
    }
    case "uint32": {
      const high = (working >>> 16) & 0xffff;
      const low = working & 0xffff;
      return [high, low];
    }
    case "int32": {
      const buffer = Buffer.allocUnsafe(4);
      buffer.writeInt32BE(working, 0);
      return [buffer.readUInt16BE(0), buffer.readUInt16BE(2)];
    }
    case "float32": {
      const buffer = Buffer.allocUnsafe(4);
      buffer.writeFloatBE(value, 0);
      return [buffer.readUInt16BE(0), buffer.readUInt16BE(2)];
    }
    default:
      return [Math.round(working) & 0xffff];
  }
}

function setByPath(obj, pathStr, value) {
  if (!pathStr) return;
  const parts = pathStr.split(".");
  let cursor = obj;
  parts.slice(0, -1).forEach((key) => {
    if (cursor[key] === undefined || typeof cursor[key] !== "object") cursor[key] = {};
    cursor = cursor[key];
  });
  cursor[parts[parts.length - 1]] = value;
}

function updateWriteStatus(ok, err) {
  state.wr = {
    busy: false,
    ok,
    err: err || null,
    last: new Date().toISOString()
  };
}

async function readRegisters(cfg) {
  return enqueue(async () => {
    await ensureConnection();
    const fn = (cfg.function || "holding").toLowerCase();
    const length = cfg.length || 1;
    switch (fn) {
      case "holding":
        return (await client.readHoldingRegisters(cfg.address, length)).data;
      case "input":
        return (await client.readInputRegisters(cfg.address, length)).data;
      case "coil":
        return (await client.readCoils(cfg.address, length)).data;
      case "discrete":
        return (await client.readDiscreteInputs(cfg.address, length)).data;
      default:
        throw new Error(`Unsupported function ${cfg.function}`);
    }
  });
}

async function writeTagInternal(tagName, value, meta = {}) {
  const cfg = TAGS[tagName];
  if (!cfg) throw new Error(`Unknown tag ${tagName}`);
  if (cfg.writable === false) throw new Error(`Tag ${tagName} is read-only`);
  const registers = encodeValue(value, cfg);
  
  console.log(`📝 WRITE REQUEST: ${tagName}`);
  console.log(`   Value: ${value}, Register: ${cfg.address}, Encoded: [${registers.join(", ")}]`);
  
  state.wr = { busy: true, ok: false, err: null, last: null };
  await enqueue(async () => {
    await ensureConnection();
    const fn = (cfg.writeFunction || cfg.function || "holding").toLowerCase();
    if (fn === "holding") {
      if ((cfg.length || registers.length) > 1) {
        console.log(`   → Writing multiple registers at address ${cfg.address}`);
        await client.writeRegisters(cfg.address, registers);
      } else {
        console.log(`   → Writing single register at address ${cfg.address} = ${registers[0]}`);
        await client.writeRegister(cfg.address, registers[0]);
      }
    } else if (fn === "coil") {
      console.log(`   → Writing coil at address ${cfg.address} = ${!!value}`);
      await client.writeCoil(cfg.address, !!value);
    } else {
      throw new Error(`Unsupported write function ${fn}`);
    }
  });
  if (cfg.path) setByPath(state, cfg.path, value);
  tagCache[tagName] = { value, meta, ts: new Date().toISOString() };
  updateWriteStatus(true);
  console.log(`   ✅ Write completed successfully`);
  return value;
}

async function executeConfiguredCommand(name, payload = {}) {
  const cfg = COMMANDS[name];
  if (!cfg) throw new Error(`Unknown command ${name}`);
  if (cfg.tag) {
    const value = payload.value ?? cfg.value;
    if (value === undefined) throw new Error(`Command ${name} requires a value`);
    return writeTagInternal(cfg.tag, value, payload.meta);
  }
  const fn = (cfg.function || "coil").toLowerCase();
  const value = payload.value ?? cfg.value ?? true;
  return enqueue(async () => {
    await ensureConnection();
    if (fn === "coil") {
      await client.writeCoil(cfg.address, !!value);
    } else if (fn === "holding") {
      const registers = encodeValue(value, cfg);
      if ((cfg.length || registers.length) > 1) {
        await client.writeRegisters(cfg.address, registers);
      } else {
        await client.writeRegister(cfg.address, registers[0]);
      }
    } else {
      throw new Error(`Unsupported command function ${fn}`);
    }
    if (cfg.path) {
      const nextValue = payload.pathValue ?? cfg.pathValue ?? value;
      setByPath(state, cfg.path, nextValue);
    }
  });
}

let polling = false;
let pollCount = 0;
async function pollAllTags() {
  if (polling) return;
  polling = true;
  pollCount++;
  const logDetail = pollCount % 10 === 1; // Log details every 10 polls
  
  try {
    if (logDetail) console.log(`\n📊 POLL #${pollCount} - Reading all tags...`);
    
    for (const [tagName, cfg] of Object.entries(TAGS)) {
      if (cfg.read === false) continue;
      const raw = await readRegisters(cfg);
      const decoded = decodeValue(raw, cfg);
      tagCache[tagName] = { value: decoded, ts: new Date().toISOString() };
      if (cfg.path) setByPath(state, cfg.path, decoded);
      
      // Log config read values to see if they change
      if (logDetail && (tagName.includes("Target_kW") || tagName.includes("Load_Bank_Cap") || tagName.includes("High_Limit") || tagName.includes("Control_Mode") || tagName.includes("Manual_Load_Bank") || tagName.includes("Test_Mode"))) {
        console.log(`   ${tagName}: ${decoded}`);
      }
    }
    state.commsOK = true;
    state.meta.lastPoll = new Date().toISOString();
  } catch (err) {
    console.error("Poll error:", err.message);
    state.commsOK = false;
    if (!state.alarms.includes("Modbus poll failure")) state.alarms.push("Modbus poll failure");
    safeClose();
  } finally {
    polling = false;
  }
}

setInterval(() => {
  pollAllTags().catch((err) => console.error("Poll loop error:", err.message));
}, POLL_INTERVAL);
pollAllTags();

app.get("/healthz", (req, res) => {
  res.json({ ok: true, connected: client.isOpen, lastPoll: state.meta.lastPoll });
});

app.get("/api/state", (req, res) => {
  res.json({
    state,
    meta: {
      lastPoll: state.meta.lastPoll,
      tags: Object.keys(tagCache).length
    }
  });
});

app.get("/api/tags", (req, res) => {
  res.json(tagCache);
});

app.get("/api/tags/:tagName", (req, res) => {
  const tagName = req.params.tagName;
  if (!tagCache[tagName]) {
    return res.status(404).json({ error: `Tag ${tagName} not found` });
  }
  res.json(tagCache[tagName]);
});

app.post("/api/write", async (req, res) => {
  const { tag, value, meta } = req.body || {};
  if (!tag) return res.status(400).json({ error: "tag is required" });
  if (value === undefined) return res.status(400).json({ error: "value is required" });
  try {
    const written = await writeTagInternal(tag, value, meta);
    res.json({ ok: true, tag, value: written });
  } catch (err) {
    console.error("Write error:", err.message);
    updateWriteStatus(false, err.message);
    res.status(500).json({ error: err.message });
  }
});

app.post("/api/command", async (req, res) => {
  const { command, payload } = req.body || {};
  if (!command) return res.status(400).json({ error: "command is required" });
  try {
    const result = await executeConfiguredCommand(command, payload);
    res.json({ ok: true, command, result });
  } catch (err) {
    console.error("Command error:", err.message);
    res.status(500).json({ error: err.message });
  }
});

if (config.staticDir) {
  const staticPath = path.resolve(__dirname, config.staticDir);
  if (fs.existsSync(staticPath)) {
    app.use(express.static(staticPath));
    console.log(`Serving static assets from ${staticPath}`);
  }
}

app.listen(HTTP_PORT, () => {
  console.log(`Modbus master server listening on port ${HTTP_PORT}`);
  console.log(`Target slave ${config.slaveHost}:${config.slavePort} (unit ${config.unitId || 1})`);
});

process.on("SIGINT", () => {
  console.log("Shutting down...");
  safeClose();
  process.exit(0);
});

