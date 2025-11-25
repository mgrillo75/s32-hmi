PROGRAM Main_Main_Man
VAR
	Test_Run : BOOL;
	
	Burn_In : TON;
	Current_Burn_In_Time : TIME;
	
	Load_Bank_Gateway_Software_Version : DINT;
	Load_Bank_Load_Accept_Sync : DINT;
	Load_Bank_Load_Accept_Reject : DINT;
	Load_Bank_Load_Bank_Count : DINT;
	Load_Bank_Nominal_Voltage : DINT;
	Load_Bank_Nominal_Frequency : DINT;
	Load_Bank_Connection_Mode : DINT;
	Load_Bank_Min_Resistive_Load_Step : UDINT;
	Load_Bank_Measured_Active_Power : DINT;
	Load_Bank_Applied_Resistive_Load : UDINT;
	Load_Bank_Requested_Resistive_Load : UDINT;
	Load_Bank_Requested_Resistive_Load_2 : UDINT;
	Load_Bank_Network_Rescan : DINT;
	Load_Bank_System_Status : DINT;
	Load_Bank_System_Alarms : DINT;
	Load_Bank_Available_Resistive_Load : UDINT;
	Test_Value : DINT;
	
	Gen_1_kW : UDINT;
	Gen_2_kW : UDINT;
	Gen_3_kW : UDINT;
	
	Gen_1_52A : BOOL;
	Gen_2_52A : BOOL;
	Gen_3_52A : BOOL;
	
	Number_of_Gens_Online : UDINT;
	Previous_Number_of_Gens_Online : UDINT;
	Number_of_Gens_Online_Change_Tracker : BOOL;
	Number_of_Gens_Online_Change_Timer : TON;
	New_Gen_Online : BOOL;
	Gen_Shutdown : BOOL;
	
	// Process variables with default values
    Target_Gen_kW 		: UDINT := 2050; 
	Load_Bank_Cap 		: UDINT := 2000; //user limit
	Gen_kW_High_Limit 	: UDINT := 2150;
    
    // Local variables to receive input from HMI via Modbus write command
    Target_Gen_kW_HMI_Input : UDINT; 
	Load_Bank_Cap_HMI_Input : UDINT;
	Gen_kW_High_Limit_HMI_Input : UDINT;
    
    // Internal flags
    User_SP_Initialized : BOOL := FALSE; // TRUE once user writes at least once
    Last_HMI_SP_Command : UDINT := 0; // Track last valid command
	
	LB_SP_Initialized : BOOL := FALSE;
	Last_HMI_LB_Command : UDINT := 0;

	kWLimit_SP_Initialized : BOOL := FALSE;
	Last_HMI_kWLimit_Command : UDINT := 0;
	
	
	Scaled_Set_Point_To_Measured_Deviation_Cap : DINT;
	Average_Gen_kW : UDINT;
	Gen_kW_Difference : DINT;
	Highest_Gen_kW : UDINT;
	Load_Bank_kW_Set_Point : UDINT;
	Load_Bank_kW_Set_Point_Scaled : UDINT;
	Load_Bank_kW_Set_Point_Byte_1 : UDINT;
	Load_Bank_kW_Set_Point_Byte_2 : UDINT;
	Load_Bank_Step_kW : UDINT;
	Action_Switch : BOOL;
	
	FirstScan : BOOL := TRUE;
	
	// Process variable limits
	Target_SP_Min : UDINT := 500;
	Target_SP_Max : UDINT := 2500;
	
	LB_Min        : UDINT := 500;
    LB_Max        : UDINT; //will be dynamic according to: Load_Bank_Available_Resistive_Load := DINT_TO_UDINT(Modbus_Load_Bank_Available_Resistive_Load.status.stVal); // load bank max capacity div 100 for kw

    kWLimit_Min   : UDINT := 1000;
    kWLimit_Max   : UDINT := 2500;
	
	// ========== ADDED: AUTO/MANUAL MODE CONTROL VARIABLES ==========
	// Control mode: TRUE = AUTO (automatic control), FALSE = MANUAL (operator-specified setpoint)
	Control_Mode : BOOL := TRUE; // Default to AUTO mode
	Control_Mode_HMI_Input : BOOL;
	Last_HMI_Mode_Command : BOOL := TRUE;
	Mode_Initialized : BOOL := FALSE;
	
	// Manual mode setpoint and tracking variables
	Manual_Load_Bank_Setpoint : UDINT := 0; // Manual mode setpoint in kW
	Manual_Load_Bank_Setpoint_HMI_Input : UDINT;
	Last_HMI_Manual_SP_Command : UDINT := 0;
	Manual_SP_Initialized : BOOL := FALSE;
	
	// Manual setpoint limits (dynamic max based on available load bank capacity)
	Manual_SP_Min : UDINT := 0;
	Manual_SP_Max : UDINT; // Will be set to LB_Max dynamically
	// ========== END ADDED VARIABLES ==========
	
	// ========== ADDED: TEST/LIVE MODE HMI CONTROL VARIABLES ==========
	// Test_Run already declared above: TRUE = Test Mode (no outputs), FALSE = Live Mode (outputs active)
	Test_Mode_HMI_Input : BOOL;
	Last_HMI_Test_Mode_Command : BOOL := TRUE; // Track last command (default TRUE = Test Mode)
	Test_Mode_Initialized : BOOL := FALSE;
	// ========== END ADDED TEST MODE VARIABLES ==========
	
END_VAR

IF FirstScan THEN
    // Force initial values reconfirmed
	IF NOT User_SP_Initialized AND (Last_HMI_SP_Command = 0) THEN
    	Target_Gen_kW := 2050;
	END_IF;
	
	IF NOT LB_SP_Initialized AND (Last_HMI_LB_Command = 0) THEN
    	Load_Bank_Cap := 2000;
	END_IF;

	(* Gen_kW_High_Limit default = 2150 *)
	IF NOT kWLimit_SP_Initialized AND (Last_HMI_kWLimit_Command = 0) THEN
    	Gen_kW_High_Limit := 2150;
	END_IF;
	
	// Clear any stale HMI input
    Target_Gen_kW_HMI_Input := 0;
	Load_Bank_Cap_HMI_Input := 0;
	Gen_kW_High_Limit_HMI_Input := 0;
	
	// ========== ADDED: Initialize AUTO/MANUAL mode on first scan ==========
	// Default to AUTO mode if not already initialized
	IF NOT Mode_Initialized AND (Last_HMI_Mode_Command = TRUE) THEN
		Control_Mode := TRUE; // Start in AUTO mode
	END_IF;
	
	// Clear any stale mode and manual setpoint inputs
	Control_Mode_HMI_Input := TRUE;
	Manual_Load_Bank_Setpoint_HMI_Input := 0;
	// ========== END ADDED INITIALIZATION ==========
	
	// ========== ADDED: Initialize TEST/LIVE mode on first scan ==========
	// Default to TEST mode (Test_Run = TRUE) for safety
	IF NOT Test_Mode_Initialized AND (Last_HMI_Test_Mode_Command = TRUE) THEN
		Test_Run := TRUE; // Start in TEST mode for safety
	END_IF;
	
	// Clear any stale test mode input
	Test_Mode_HMI_Input := TRUE; // Default to Test Mode
	// ========== END ADDED TEST MODE INITIALIZATION ==========

	Test_Run := 1;
	
	FirstScan := FALSE;
END_IF

//Initialize the burn in timer
Burn_In();

//Burn in timer used to prevent the 
IF NOT Burn_In.IN THEN
	
	//Test_Run := 0;
	Test_Run := 1;
	
	//This is the load level, in kW, that the RTAC will try to maintain on each genset
	//Target_Gen_kW := 2050;
	
	//determines the size of the incremental step changes in the load bank set point.
	//i.e. if the program is increasing the load by 500kW and Load_Bank_Step_kW is set to 50, then the Load Bank Set Point will increase by 50kW during each iteration of the main loop.
	//This incremental increase/decrease will occur roughly once per Cycle Time (as defined in the main controller settings, typically 100 to 500ms)
	//Cycle Time is 100ms as of 25 SEP 25
	Load_Bank_Step_kW := 50;
	
	//Load_Bank_Cap := 2000;
	//Gen_kW_High_Limit := 2150;
	Scaled_Set_Point_To_Measured_Deviation_Cap := 10000;

	Burn_In.PT := T#30S;
	Burn_In.IN := 1;
	Modbus_Load_Bank_Load_Accept_Sync.oper.ctlVal := 0;
	Modbus_Load_Bank_Load_Accept_Sync.oper.trigger := 1;
END_IF

//Just here to show the current burn in time after going online in the AcSELerator RTAC software
Current_Burn_In_Time := Burn_In.ET;

//Main IF Loop - data is loaded into variables for use by the main algorithm, the difference between the average genset load and the target genset load is calculated, then the load bank set point is updated.
IF TRUE THEN
	
	// User input modbus write commands (HMI -> RTAC)
	HMI_Modbus_Server_Tags_Target_kW_Input.oper.trigger := NOT HMI_Modbus_Server_Tags_Target_kW_Input.oper.trigger;
	Target_Gen_kW_HMI_Input := DINT_TO_UDINT(HMI_Modbus_Server_Tags_Target_kW_Input.oper.ctlVal);
	HMI_Modbus_Server_Tags_Load_Bank_Cap_Input.oper.trigger := NOT HMI_Modbus_Server_Tags_Load_Bank_Cap_Input.oper.trigger;
	Load_Bank_Cap_HMI_Input := DINT_TO_UDINT(HMI_Modbus_Server_Tags_Load_Bank_Cap_Input.oper.ctlVal);
	HMI_Modbus_Server_Tags_kW_High_Limit_Input.oper.trigger := NOT HMI_Modbus_Server_Tags_kW_High_Limit_Input.oper.trigger;
	Gen_kW_High_Limit_HMI_Input := DINT_TO_UDINT(HMI_Modbus_Server_Tags_kW_High_Limit_Input.oper.ctlVal);
	
	// Detect new HMI command
	IF Target_Gen_kW_HMI_Input <> Last_HMI_SP_Command THEN

		IF Target_Gen_kW_HMI_Input < Target_SP_Min THEN
			Target_Gen_kW := Target_SP_Min;
		ELSIF Target_Gen_kW_HMI_Input > Target_SP_Max THEN
			Target_Gen_kW := Target_SP_Max;
		ELSE
			Target_Gen_kW := Target_Gen_kW_HMI_Input;
		END_IF;
	
		User_SP_Initialized := TRUE;
		Last_HMI_SP_Command := Target_Gen_kW_HMI_Input;
	END_IF;
	
	// HMI feedback target load set point (RTAC → HMI)
	HMI_Modbus_Server_Tags_Target_kW.status.stVal := UDINT_TO_DINT(Target_Gen_kW);
	HMI_Modbus_Server_Tags_Target_kW.oper.trigger := NOT HMI_Modbus_Server_Tags_Target_kW.oper.trigger;
	
	// Detect new load bank cap command from HMI
	IF Load_Bank_Cap_HMI_Input <> Last_HMI_LB_Command THEN

		IF Load_Bank_Cap_HMI_Input < LB_Min THEN
			Load_Bank_Cap := LB_Min;
		ELSIF Load_Bank_Cap_HMI_Input > LB_Max THEN
			Load_Bank_Cap := LB_Max;
		ELSE
			Load_Bank_Cap := Load_Bank_Cap_HMI_Input;		
		END_IF;		

		LB_SP_Initialized := TRUE;
		Last_HMI_LB_Command := Load_Bank_Cap_HMI_Input;
	END_IF;

	// HMI load bank cap feedback (RTAC → HMI)
	HMI_Modbus_Server_Tags_Load_Bank_Cap.status.stVal := UDINT_TO_DINT(Load_Bank_Cap);
	HMI_Modbus_Server_Tags_Load_Bank_Cap.oper.trigger := NOT HMI_Modbus_Server_Tags_Load_Bank_Cap.oper.trigger;
	
	// Detect new kW high limit command from HMI
	IF Gen_kW_High_Limit_HMI_Input <> Last_HMI_kWLimit_Command THEN

		IF Gen_kW_High_Limit_HMI_Input < kWLimit_Min THEN
			Gen_kW_High_Limit := kWLimit_Min;
		ELSIF Gen_kW_High_Limit_HMI_Input > kWLimit_Max THEN
			Gen_kW_High_Limit := kWLimit_Max;
		ELSE
			Gen_kW_High_Limit := Gen_kW_High_Limit_HMI_Input;
		END_IF;
	
		kWLimit_SP_Initialized := TRUE;
		Last_HMI_kWLimit_Command := Gen_kW_High_Limit_HMI_Input;
	END_IF;
	
	// HMI kW high limit feedback (RTAC → HMI)
	HMI_Modbus_Server_Tags_kW_High_Limit.status.stVal := UDINT_TO_DINT(Gen_kW_High_Limit);
	HMI_Modbus_Server_Tags_kW_High_Limit.oper.trigger := NOT HMI_Modbus_Server_Tags_kW_High_Limit.oper.trigger;

	// ========== ADDED: AUTO/MANUAL MODE HMI INTERFACE ==========
	// Read control mode selection from HMI (TRUE = AUTO, FALSE = MANUAL)
	HMI_Modbus_Server_Tags_Control_Mode_Input.oper.trigger := NOT HMI_Modbus_Server_Tags_Control_Mode_Input.oper.trigger;
	Control_Mode_HMI_Input := HMI_Modbus_Server_Tags_Control_Mode_Input.oper.ctlVal <> 0; // Convert DINT to BOOL (0=FALSE/MANUAL, 1=TRUE/AUTO)
	
	// Detect mode change command from HMI
	IF Control_Mode_HMI_Input <> Last_HMI_Mode_Command THEN
		Control_Mode := Control_Mode_HMI_Input;
		Mode_Initialized := TRUE;
		Last_HMI_Mode_Command := Control_Mode_HMI_Input;
		
		// When switching to MANUAL mode, initialize manual setpoint with current auto setpoint (bumpless transfer)
		IF NOT Control_Mode THEN
			Manual_Load_Bank_Setpoint := Load_Bank_kW_Set_Point;
		END_IF;
	END_IF;
	
	// Send control mode feedback to HMI (RTAC → HMI)
	HMI_Modbus_Server_Tags_Control_Mode.status.stVal := BOOL_TO_DINT(Control_Mode); // Convert BOOL to DINT (TRUE=1/AUTO, FALSE=0/MANUAL)
	HMI_Modbus_Server_Tags_Control_Mode.oper.trigger := NOT HMI_Modbus_Server_Tags_Control_Mode.oper.trigger;
	
	// Read manual load bank setpoint from HMI
	HMI_Modbus_Server_Tags_Manual_Load_Bank_SP_Input.oper.trigger := NOT HMI_Modbus_Server_Tags_Manual_Load_Bank_SP_Input.oper.trigger;
	Manual_Load_Bank_Setpoint_HMI_Input := DINT_TO_UDINT(HMI_Modbus_Server_Tags_Manual_Load_Bank_SP_Input.oper.ctlVal);
	
	// Update dynamic maximum limit for manual setpoint (based on available load bank capacity)
	Manual_SP_Max := LB_Max;
	
	// Detect new manual setpoint command from HMI
	IF Manual_Load_Bank_Setpoint_HMI_Input <> Last_HMI_Manual_SP_Command THEN
		
		// Apply min/max limits to manual setpoint
		IF Manual_Load_Bank_Setpoint_HMI_Input < Manual_SP_Min THEN
			Manual_Load_Bank_Setpoint := Manual_SP_Min;
		ELSIF Manual_Load_Bank_Setpoint_HMI_Input > Manual_SP_Max THEN
			Manual_Load_Bank_Setpoint := Manual_SP_Max;
		ELSE
			Manual_Load_Bank_Setpoint := Manual_Load_Bank_Setpoint_HMI_Input;
		END_IF;
		
		Manual_SP_Initialized := TRUE;
		Last_HMI_Manual_SP_Command := Manual_Load_Bank_Setpoint_HMI_Input;
	END_IF;
	
	// Send manual setpoint feedback to HMI (RTAC → HMI)
	HMI_Modbus_Server_Tags_Manual_Load_Bank_SP.status.stVal := UDINT_TO_DINT(Manual_Load_Bank_Setpoint);
	HMI_Modbus_Server_Tags_Manual_Load_Bank_SP.oper.trigger := NOT HMI_Modbus_Server_Tags_Manual_Load_Bank_SP.oper.trigger;
	// ========== END ADDED AUTO/MANUAL MODE HMI INTERFACE ==========
	
	// ========== ADDED: TEST/LIVE MODE HMI INTERFACE ==========
	// Read test mode selection from HMI (TRUE = Test Mode, FALSE = Live Mode)
	// Register 17: Test_Mode_Input (HMI → RTAC)
	HMI_Modbus_Server_Tags_Test_Mode_Input.oper.trigger := NOT HMI_Modbus_Server_Tags_Test_Mode_Input.oper.trigger;
	Test_Mode_HMI_Input := HMI_Modbus_Server_Tags_Test_Mode_Input.oper.ctlVal <> 0; // Convert DINT to BOOL (0=FALSE/Live, 1=TRUE/Test)
	
	// Detect test mode change command from HMI
	IF Test_Mode_HMI_Input <> Last_HMI_Test_Mode_Command THEN
		Test_Run := Test_Mode_HMI_Input; // TRUE = Test Mode (outputs disabled), FALSE = Live Mode (outputs enabled)
		Test_Mode_Initialized := TRUE;
		Last_HMI_Test_Mode_Command := Test_Mode_HMI_Input;
	END_IF;
	
	// Send test mode feedback to HMI (RTAC → HMI)
	// Register 16: Test_Mode (RTAC → HMI)
	HMI_Modbus_Server_Tags_Test_Mode.status.stVal := BOOL_TO_DINT(Test_Run); // Convert BOOL to DINT (TRUE=1/Test, FALSE=0/Live)
	HMI_Modbus_Server_Tags_Test_Mode.oper.trigger := NOT HMI_Modbus_Server_Tags_Test_Mode.oper.trigger;
	// ========== END ADDED TEST/LIVE MODE HMI INTERFACE ==========
	
	//Real-Time Modbus data from the Load Bank Gateway is loaded into internal variables
	Load_Bank_Gateway_Software_Version := Modbus_Load_Bank_Gateway_Software_Version.status.stVal;
	Load_Bank_Load_Accept_Sync := Modbus_Load_Bank_Load_Accept_Sync.status.stVal;
	Load_Bank_Requested_Resistive_Load := DINT_TO_UDINT(Modbus_Load_Bank_Requested_Resistive_Load.status.stVal);
	Load_Bank_Load_Accept_Reject := Modbus_Load_Bank_Load_Accept_Reject.status.stVal;
	Load_Bank_Load_Bank_Count := Modbus_Load_Bank_Load_Bank_Count.status.stVal;
	Load_Bank_Nominal_Voltage := Modbus_Load_Bank_Nominal_Voltage.status.stVal;
	Load_Bank_Nominal_Frequency := Modbus_Load_Bank_Nominal_Frequency.status.stVal;
	Load_Bank_Connection_Mode := Modbus_Load_Bank_Connection_Mode.status.stVal;
	Load_Bank_Min_Resistive_Load_Step := DINT_TO_UDINT(Modbus_Load_Bank_Min_Resistive_Load_Step.status.stVal);
	Load_Bank_Measured_Active_Power := Modbus_Load_Bank_Measured_Active_Power.status.stVal;
	Load_Bank_Applied_Resistive_Load := DINT_TO_UDINT(Modbus_Load_Bank_Applied_Resistive_Load.status.stVal);
	Load_Bank_System_Status := Modbus_Load_Bank_System_Status.status.stVal;
	Load_Bank_System_Alarms := Modbus_Load_Bank_System_Alarms.status.stVal;
	Load_Bank_Available_Resistive_Load := DINT_TO_UDINT(Modbus_Load_Bank_Available_Resistive_Load.status.stVal); // load bank max capacity div 100 for kw
	
	// Calculate the Maximum kW limit by removing the scaling factor
	// Ensure we don't divide by zero if the load bank is offline (though 0/100 is just 0)
	LB_Max := Load_Bank_Available_Resistive_Load / 100;
	
	IF Load_Bank_Load_Accept_Sync = 1 AND Burn_in.Q THEN
		Modbus_Load_Bank_Load_Accept_Sync.oper.ctlVal := 0;
		Modbus_Load_Bank_Load_Accept_Sync.oper.trigger := NOT Modbus_Load_Bank_Load_Accept_Sync.oper.trigger;
	END_IF
	
	//Real-Time Three-phase power measurement from each generator is loaded into an internal variable
	Gen_1_kW := REAL_TO_UDINT(SEL_700G_1_SEL.FM_INST_P3X.mag / 1000);
	Gen_2_kW := REAL_TO_UDINT(SEL_700G_2_SEL.FM_INST_P3X.mag / 1000);
	Gen_3_kW := REAL_TO_UDINT(SEL_700G_3_SEL.FM_INST_P3X.mag / 1000);
	
	//Serve up genset KW to HMI via modbus tcp slave
	HMI_Modbus_Server_Tags_Kw_GenSet_1.stVal := UDINT_TO_DINT(Gen_1_kW);
	HMI_Modbus_Server_Tags_Kw_GenSet_2.stVal := UDINT_TO_DINT(Gen_2_kW);
	HMI_Modbus_Server_Tags_Kw_GenSet_3.stVal := UDINT_TO_DINT(Gen_3_kW);
	
	//Real-Time GCB breaker-closed status from each generator is loaded into an internal variable
	Gen_1_52A := SEL_700G_1_SEL.FM_INST_52AX.stVal;
	Gen_2_52A := SEL_700G_2_SEL.FM_INST_52AX.stVal;
	Gen_3_52A := SEL_700G_3_SEL.FM_INST_52AX.stVal;
	
	//Serve up circuit breaker status to HMI
	HMI_Modbus_Server_Tags_52A_Status_GenSet_1.status.stVal := Gen_1_52A;
	HMI_Modbus_Server_Tags_52A_Status_GenSet_2.status.stVal := Gen_2_52A;
	HMI_Modbus_Server_Tags_52A_Status_GenSet_3.status.stVal := Gen_3_52A;
	
	//Generator breaker statuses are used to determine how many generators are synchronized and closed into the bus
	Number_of_Gens_Online := BOOL_TO_UDINT(Gen_1_52A) + BOOL_TO_UDINT(Gen_2_52A) + BOOL_TO_UDINT(Gen_3_52A);
	
	//Average generator load is calculated by dividing the sum of all genset loads by the number of gensets online
	IF Number_of_Gens_Online > 0 THEN
			Average_Gen_kW := (Gen_1_kW + Gen_2_kW + Gen_3_kW) / Number_of_Gens_Online;
	ELSE
		Average_Gen_kW := 0;
	END_IF
	
	//The differnce between the 
	IF Average_Gen_kW > 0 THEN
		Gen_kW_Difference := UDINT_TO_DINT(Target_Gen_kW) - UDINT_TO_DINT(Average_Gen_kW);
	ELSE
		Gen_kW_Difference := 0;
	END_IF
	
	//The highest individual generator load is determined so that load bank load increases can be prevented if there is risk of overloading a unit
	Highest_Gen_kW := MAX(Gen_1_kW, Gen_2_kW, Gen_3_kW);
	
	// ========== MODIFIED: Wrapped control logic with AUTO/MANUAL mode selection ==========
	IF Control_Mode THEN
		// ===== AUTO MODE - Automatic control algorithm (original logic) =====
		IF ((Load_Bank_kW_Set_Point_Scaled) <= DINT_TO_UDINT(Load_Bank_Measured_Active_Power + Scaled_Set_Point_To_Measured_Deviation_Cap)) AND NOT Modbus_Load_Bank_Requested_Resistive_Load.oper.trigger THEN
			//The Load Bank Set Point is increased, decreased, or remains the same depending on the average generator load (in order to maintain the gensets at target load)
			IF Highest_Gen_kW >= Gen_kW_High_Limit AND Load_Bank_kW_Set_Point >= 200 THEN
				Load_Bank_kW_Set_Point := Load_Bank_kW_Set_Point - (Load_Bank_Step_kW * 2);
			ELSE	
				IF Gen_kW_Difference <= (-1 * UDINT_TO_DINT(Load_Bank_Step_kW)) AND Load_Bank_kW_Set_Point >= 100 THEN
					Load_Bank_kW_Set_Point := Load_Bank_kW_Set_Point - (Load_Bank_Step_kW);
				ELSE
					IF Gen_kW_Difference > UDINT_TO_DINT(Load_Bank_Step_kW) AND Highest_Gen_kW <= Gen_kW_High_Limit AND Load_Bank_kW_Set_Point <= Load_Bank_Cap THEN
						Load_Bank_kW_Set_Point := Load_Bank_kW_Set_Point + Load_Bank_Step_kW;
					ELSE
						IF Load_Bank_kW_Set_Point_Scaled > DINT_TO_UDINT(Load_Bank_Measured_Active_Power + Scaled_Set_Point_To_Measured_Deviation_Cap) THEN
							Load_Bank_kW_Set_Point := Load_Bank_kW_Set_Point - Load_Bank_Step_kW * 2;
						END_IF
					END_IF
				END_IF
			END_IF
		ELSE
			IF((Load_Bank_kW_Set_Point_Scaled) >= DINT_TO_UDINT(Load_Bank_Measured_Active_Power + Scaled_Set_Point_To_Measured_Deviation_Cap + 10000)) THEN
				Load_Bank_kW_Set_Point := Load_Bank_kW_Set_Point - Load_Bank_Step_kW * 2;
			END_IF
		END_IF
	ELSE
		// ===== MANUAL MODE - Operator-specified setpoint (no automatic control) =====
		// In manual mode, the load bank setpoint is directly set by the operator via HMI
		// The automatic control algorithm is bypassed
		Load_Bank_kW_Set_Point := Manual_Load_Bank_Setpoint;
	END_IF;
	// ========== END MODIFIED CONTROL LOGIC ==========

	// Scales the Load_Bank_kW_Set_Point value so it can be written to the load bank gateway modbus register
	Load_Bank_kW_Set_Point_Scaled := Load_Bank_kW_Set_Point * 100;
	
	//Modbus Holding Registers are loaded with the values required for the load bank(s) to increase/decrease to the new desired load level
	Modbus_Load_Bank_Requested_Resistive_Load.oper.ctlVal := UDINT_TO_DINT(Load_Bank_kW_Set_Point_Scaled);

END_IF	
	
	//If the code isn't in test mode, the new Modbus Holding Register values are sent to the Load Bank Gateway
	//This is the control action which should result in a change in load bank load levels if required
IF Test_Run = 0 AND Burn_In.Q THEN
	Modbus_Load_Bank_Requested_Resistive_Load.oper.trigger := NOT Modbus_Load_Bank_Requested_Resistive_Load.oper.trigger;
	//Modbus_Load_Bank_Requested_Resistive_Load_2.oper.trigger := NOT Modbus_Load_Bank_Requested_Resistive_Load_2.oper.trigger;
	//Modbus_Load_Bank_Load_Accept_Reject.oper.trigger := NOT Modbus_Load_Bank_Load_Accept_Reject.oper.trigger;
END_IF

