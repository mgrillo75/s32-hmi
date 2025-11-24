#!/usr/bin/env node
/**
 * Simple connection verification script for Modbus TCP slave
 * Run this to test connectivity before starting the full server
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
console.log("║        Modbus TCP Connection Verification                 ║");
console.log("╚════════════════════════════════════════════════════════════╝");
console.log("");
console.log(`Target Device: ${config.slaveHost}:${config.slavePort}`);
console.log(`Unit ID: ${config.unitId}`);
console.log(`Timeout: ${config.timeoutMs}ms`);
console.log("");

async function verify() {
  try {
    // Step 1: Connect
    console.log("⏳ Connecting to Modbus slave...");
    await client.connectTCP(config.slaveHost, { port: config.slavePort });
    console.log("✅ TCP connection established!");
    console.log("");

    // Step 2: Test read first 3 coils (circuit breaker status)
    console.log("═══════════════════════════════════════════════════════════");
    console.log("Testing COILS (Circuit Breaker Status)");
    console.log("═══════════════════════════════════════════════════════════");
    console.log("⏳ Reading coils 0-2 (Gen_1_52A, Gen_2_52A, Gen_3_52A)...");
    
    try {
      const coilResult = await client.readCoils(0, 3);
      console.log("✅ Coils read successful!");
      console.log(`   Raw values: [${coilResult.data.join(", ")}]`);
      console.log("");
      console.log("   Coil 0 (Gen_1_52A): " + (coilResult.data[0] ? "CLOSED ✓" : "OPEN ✗"));
      console.log("   Coil 1 (Gen_2_52A): " + (coilResult.data[1] ? "CLOSED ✓" : "OPEN ✗"));
      console.log("   Coil 2 (Gen_3_52A): " + (coilResult.data[2] ? "CLOSED ✓" : "OPEN ✗"));
      console.log("");
    } catch (err) {
      console.log("⚠️  Coil read failed: " + err.message);
      console.log("   (Coils may not be configured on device)");
      console.log("");
    }

    // Step 3: Test read input registers (generator power values)
    console.log("═══════════════════════════════════════════════════════════");
    console.log("Testing INPUT REGISTERS (Generator Power)");
    console.log("═══════════════════════════════════════════════════════════");
    console.log("⏳ Reading input registers 0, 2, 4 (GenSet_1, GenSet_2, GenSet_3)...");
    console.log("   Note: Registers at 30001, 30003, 30005");
    console.log("");
    
    try {
      const inputResult = await client.readInputRegisters(0, 5);
      console.log("✅ Input registers read successful!");
      console.log(`   Raw values (0-4): [${inputResult.data.join(", ")}]`);
      console.log("");
      
      // Each register is a single 16-bit value - extract every other register
      const gen1_kw = inputResult.data[0];  // Register 0 = 30001
      const gen2_kw = inputResult.data[2];  // Register 2 = 30003
      const gen3_kw = inputResult.data[4];  // Register 4 = 30005
      
      console.log("   Generator Power Values (16-bit):");
      console.log(`   Register 0 (30001) GenSet_1: ${gen1_kw} kW`);
      console.log(`   Register 2 (30003) GenSet_2: ${gen2_kw} kW`);
      console.log(`   Register 4 (30005) GenSet_3: ${gen3_kw} kW`);
      console.log("");
    } catch (err) {
      console.log("⚠️  Input register read failed: " + err.message);
      console.log("   Check register addresses in your device");
      console.log("");
    }

    // Step 4: Test read holding registers (configuration values - read-only)
    console.log("═══════════════════════════════════════════════════════════");
    console.log("Testing HOLDING REGISTERS (Configuration Read Values)");
    console.log("═══════════════════════════════════════════════════════════");
    console.log("⏳ Reading holding registers 0, 2, 4 (Target kW, LB Cap, High Limit)...");
    console.log("   Note: Registers at 40001, 40003, 40005");
    console.log("");
    
    try {
      const holdingReadResult = await client.readHoldingRegisters(0, 5);
      console.log("✅ Holding registers (read) successful!");
      console.log(`   Raw values (0-4): [${holdingReadResult.data.join(", ")}]`);
      console.log("");
      
      // Each register is a single 16-bit value - extract every other register
      const target_kw = holdingReadResult.data[0];     // Register 0 = 40001
      const lb_cap = holdingReadResult.data[2];        // Register 2 = 40003
      const high_limit = holdingReadResult.data[4];    // Register 4 = 40005
      
      console.log("   Configuration Values (16-bit):");
      console.log(`   Register 0 (40001) Target Gen kW: ${target_kw} kW`);
      console.log(`   Register 2 (40003) Load Bank Cap: ${lb_cap} kW`);
      console.log(`   Register 4 (40005) Gen High Limit: ${high_limit} kW`);
      console.log("");
    } catch (err) {
      console.log("⚠️  Holding register (read) failed: " + err.message);
      console.log("   Check register addresses in your device");
      console.log("");
    }

    // Step 5: Test read holding registers (configuration values - write registers)
    console.log("═══════════════════════════════════════════════════════════");
    console.log("Testing HOLDING REGISTERS (Configuration Write Values)");
    console.log("═══════════════════════════════════════════════════════════");
    console.log("⏳ Reading holding registers 6, 8, 10 (Target kW Input, LB Cap Input, High Limit Input)...");
    console.log("   Note: Registers at 40007, 40009, 40011");
    console.log("");
    
    try {
      const holdingWriteResult = await client.readHoldingRegisters(6, 5);
      console.log("✅ Holding registers (write) read successful!");
      console.log(`   Raw values (6-10): [${holdingWriteResult.data.join(", ")}]`);
      console.log("");
      
      // Each register is a single 16-bit value - extract every other register
      const target_kw_input = holdingWriteResult.data[0];     // Register 6 = 40007
      const lb_cap_input = holdingWriteResult.data[2];        // Register 8 = 40009
      const high_limit_input = holdingWriteResult.data[4];    // Register 10 = 40011
      
      console.log("   Write Configuration Values (16-bit):");
      console.log(`   Register 6 (40007) Target Gen kW Input: ${target_kw_input} kW`);
      console.log(`   Register 8 (40009) Load Bank Cap Input: ${lb_cap_input} kW`);
      console.log(`   Register 10 (40011) Gen High Limit Input: ${high_limit_input} kW`);
      console.log("");
      console.log("   ℹ️  These are the HMI write targets (PLC reads from these)");
      console.log("");
    } catch (err) {
      console.log("⚠️  Holding register (write) read failed: " + err.message);
      console.log("   Check register addresses in your device");
      console.log("");
    }

    // Step 6: Summary
    console.log("╔════════════════════════════════════════════════════════════╗");
    console.log("║  ✅ CONNECTION VERIFIED - Ready to start server!          ║");
    console.log("╚════════════════════════════════════════════════════════════╝");
    console.log("");
    console.log("Register Map Tested:");
    console.log("  • Coils 0-2: Circuit breaker status (Gen_1_52A, Gen_2_52A, Gen_3_52A)");
    console.log("  • Input 30001, 30003, 30005: Generator power values (GenSet_1, GenSet_2, GenSet_3)");
    console.log("  • Holding 40001, 40003, 40005: Config read values (Target, LB Cap, High Limit)");
    console.log("  • Holding 40007, 40009, 40011: Config write values (HMI → PLC)");
    console.log("  • Note: Values use alternating registers (every other address)");
    console.log("");
    console.log("Next steps:");
    console.log("  1. Run 'npm start' to start the Modbus master server");
    console.log("  2. Open http://localhost:4000/test.html in your browser");
    console.log("  3. Monitor the HMI for live data from your device");
    console.log("");

    client.close();
    process.exit(0);

  } catch (err) {
    console.log("");
    console.log("╔════════════════════════════════════════════════════════════╗");
    console.log("║  ❌ CONNECTION FAILED                                      ║");
    console.log("╚════════════════════════════════════════════════════════════╝");
    console.log("");
    console.log(`Error: ${err.message}`);
    console.log("");
    console.log("Troubleshooting:");
    console.log("  1. Verify slaveHost IP address is correct in modbus.config.json");
    console.log("  2. Verify slavePort (usually 502) is correct");
    console.log("  3. Check network connectivity: ping " + config.slaveHost);
    console.log("  4. Ensure Modbus slave device is powered on and accessible");
    console.log("  5. Verify unitId matches your device's slave ID");
    console.log("  6. Check firewall settings allow Modbus TCP (port " + config.slavePort + ")");
    console.log("  7. Verify register addresses in modbus.config.json match your device");
    console.log("");

    if (client.isOpen) client.close();
    process.exit(1);
  }
}

verify();

