#!/usr/bin/env node
/**
 * Test script to verify write operations and monitor register changes
 */

const ModbusRTU = require("modbus-serial");
const fs = require("fs");
const path = require("path");

const CONFIG_PATH = path.join(__dirname, "modbus.config.json");
const config = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));

const client = new ModbusRTU();
client.setTimeout(config.timeoutMs || 3000);
client.setID(config.unitId);

console.log("╔════════════════════════════════════════════════════════════╗");
console.log("║        Modbus TCP Write Test & Monitor                    ║");
console.log("╚════════════════════════════════════════════════════════════╝");
console.log("");
console.log(`Target Device: ${config.slaveHost}:${config.slavePort}`);
console.log(`Unit ID: ${config.unitId}`);
console.log("");

async function readBothRegisters() {
  // Read the "read" registers (40001, 40003, 40005)
  const readRegs = await client.readHoldingRegisters(0, 5);
  const target_read = readRegs.data[0];
  const lbcap_read = readRegs.data[2];
  const highlim_read = readRegs.data[4];

  // Read the "write" registers (40007, 40009, 40011)
  const writeRegs = await client.readHoldingRegisters(6, 5);
  const target_write = writeRegs.data[0];
  const lbcap_write = writeRegs.data[2];
  const highlim_write = writeRegs.data[4];

  return {
    read: { target: target_read, lbcap: lbcap_read, highlim: highlim_read },
    write: { target: target_write, lbcap: lbcap_write, highlim: highlim_write }
  };
}

function displayValues(label, values) {
  console.log(`${label}:`);
  console.log(`  READ  → Target: ${values.read.target} kW, LB Cap: ${values.read.lbcap} kW, High Limit: ${values.read.highlim} kW`);
  console.log(`  WRITE → Target: ${values.write.target} kW, LB Cap: ${values.write.lbcap} kW, High Limit: ${values.write.highlim} kW`);
  console.log("");
}

async function test() {
  try {
    // Step 1: Connect
    console.log("⏳ Connecting to Modbus slave...");
    await client.connectTCP(config.slaveHost, { port: config.slavePort });
    console.log("✅ Connected!");
    console.log("");

    // Step 2: Read initial values
    console.log("═══════════════════════════════════════════════════════════");
    console.log("Step 1: Reading initial values");
    console.log("═══════════════════════════════════════════════════════════");
    const initial = await readBothRegisters();
    displayValues("INITIAL VALUES", initial);

    // Step 3: Write a test value to Target Gen kW (40007 / register 6)
    const testValue = 1234;
    console.log("═══════════════════════════════════════════════════════════");
    console.log(`Step 2: Writing ${testValue} to Target Gen kW (40007)`);
    console.log("═══════════════════════════════════════════════════════════");
    await client.writeRegister(6, testValue);
    console.log(`✅ Write command sent: ${testValue} → Register 40007`);
    console.log("");

    // Step 4: Immediately read back both sets
    console.log("═══════════════════════════════════════════════════════════");
    console.log("Step 3: Reading immediately after write");
    console.log("═══════════════════════════════════════════════════════════");
    const afterWrite = await readBothRegisters();
    displayValues("IMMEDIATELY AFTER WRITE", afterWrite);

    if (afterWrite.write.target === testValue) {
      console.log("✅ Write register (40007) shows correct value: " + testValue);
    } else {
      console.log("❌ Write register (40007) does NOT show written value!");
      console.log(`   Expected: ${testValue}, Got: ${afterWrite.write.target}`);
    }
    console.log("");

    if (afterWrite.read.target !== initial.read.target) {
      console.log("✅ Read register (40001) CHANGED from " + initial.read.target + " to " + afterWrite.read.target);
    } else {
      console.log("⚠️  Read register (40001) has NOT changed (still " + afterWrite.read.target + ")");
      console.log("   This suggests PLC is not copying 40007 → 40001");
    }
    console.log("");

    // Step 5: Monitor for changes over 10 seconds
    console.log("═══════════════════════════════════════════════════════════");
    console.log("Step 4: Monitoring for 10 seconds...");
    console.log("═══════════════════════════════════════════════════════════");
    
    for (let i = 1; i <= 10; i++) {
      await new Promise(resolve => setTimeout(resolve, 1000));
      const current = await readBothRegisters();
      
      const readChanged = current.read.target !== initial.read.target;
      const writeChanged = current.write.target !== afterWrite.write.target;
      
      let status = "";
      if (readChanged) status += "📊 READ changed! ";
      if (writeChanged) status += "✍️  WRITE changed! ";
      if (!readChanged && !writeChanged) status = "⏸️  No change";
      
      console.log(`[${i}s] ${status} Read: ${current.read.target}, Write: ${current.write.target}`);
    }
    console.log("");

    // Step 6: Final comparison
    console.log("═══════════════════════════════════════════════════════════");
    console.log("Step 5: Final values after 10 seconds");
    console.log("═══════════════════════════════════════════════════════════");
    const final = await readBothRegisters();
    displayValues("FINAL VALUES", final);

    // Analysis
    console.log("═══════════════════════════════════════════════════════════");
    console.log("ANALYSIS");
    console.log("═══════════════════════════════════════════════════════════");
    
    if (final.write.target === testValue) {
      console.log("✅ Write register (40007) retained the value: " + testValue);
      console.log("   → The write was successful and persisted");
    } else {
      console.log("⚠️  Write register (40007) changed back to: " + final.write.target);
      console.log("   → PLC may be overwriting this register");
    }
    console.log("");

    if (final.read.target !== initial.read.target) {
      console.log("✅ Read register (40001) changed from " + initial.read.target + " to " + final.read.target);
      console.log("   → PLC is updating the read register");
    } else {
      console.log("❌ Read register (40001) DID NOT change (still " + final.read.target + ")");
      console.log("   → PLC is NOT copying write register → read register");
      console.log("");
      console.log("POSSIBLE CAUSES:");
      console.log("  1. PLC logic is not reading from register 40007");
      console.log("  2. PLC scan cycle hasn't processed the write yet");
      console.log("  3. PLC may be writing its own values to 40001");
      console.log("  4. Register mapping in PLC may be incorrect");
      console.log("  5. PLC may require a trigger/enable bit to process writes");
    }
    console.log("");

    client.close();
    process.exit(0);

  } catch (err) {
    console.log("");
    console.log("╔════════════════════════════════════════════════════════════╗");
    console.log("║  ❌ TEST FAILED                                            ║");
    console.log("╚════════════════════════════════════════════════════════════╝");
    console.log("");
    console.log(`Error: ${err.message}`);
    console.log("");

    if (client.isOpen) client.close();
    process.exit(1);
  }
}

test();

