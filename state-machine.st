(*
===============================================================================
VOLTAGRID / SEL RTAC MASTER CONTROLLER
STATE-MACHINE SKELETON
Single Master Controller Version
-------------------------------------------------------------------------------
Intent:
- Supervisory coordination only
- Local genset controllers, SEL relays, SEL-2240, OEM controllers retain
  machine/protection ownership
- Master issues permissives, start/stop requests, breaker open/close requests,
  AGC/VCS biases, and orchestrates major sequences
===============================================================================
*)

(*
===============================================================================
TYPE DECLARATIONS
===============================================================================
*)
TYPE E_SYS_STATE :
(
    SYS_INIT := 0,
    SYS_IDLE := 1,
    SYS_NORMAL := 2,
    SYS_PARTY_MODE := 3,
    SYS_BLACKOUT_DETECTED := 4,
    SYS_BLACKOUT_RECOVERY := 5,
    SYS_BLACKSTART_READY := 6,
    SYS_BLACKSTART_ACTIVE := 7,
    SYS_FAULT := 8,
    SYS_ABORTED := 9
);
END_TYPE

TYPE E_SEQ_STATE :
(
    SEQ_IDLE := 0,
    SEQ_START := 1,
    SEQ_CHECK_PERMISSIVES := 2,
    SEQ_ISSUE_COMMAND := 3,
    SEQ_WAIT_FEEDBACK := 4,
    SEQ_VERIFY := 5,
    SEQ_COMPLETE := 6,
    SEQ_FAIL := 7,
    SEQ_ABORT := 8
);
END_TYPE

TYPE E_GEN_MODE :
(
    GEN_BLOCK := 0,
    GEN_STOP := 1,
    GEN_AUTO := 2,
    GEN_MANUAL := 3
);
END_TYPE

TYPE E_GEN_RUN_STATE :
(
    GEN_OFFLINE := 0,
    GEN_STARTING := 1,
    GEN_RUNNING_UNSYNC := 2,
    GEN_SYNCED := 3,
    GEN_STOPPING := 4,
    GEN_TRIPPED := 5,
    GEN_UNAVAILABLE := 6
);
END_TYPE

TYPE E_BREAKER_STATE :
(
    BRK_OPEN := 0,
    BRK_CLOSED := 1,
    BRK_TRANSITION := 2,
    BRK_FAIL := 3,
    BRK_UNKNOWN := 4
);
END_TYPE

TYPE ST_Genset :
STRUCT
    Id                      : INT;
    Enabled                 : BOOL;
    ModeCmd                 : E_GEN_MODE;     (* from HMI *)
    Priority                : INT;            (* 1..100 *)
    EngineHours             : REAL;

    (* permissives / feedback *)
    LocalReadyForDemand     : BOOL;           (* DIA.NE / OEM / Modbus *)
    InAutoAtLocal           : BOOL;
    NoStartBlockAlarms      : BOOL;
    RunningFb               : BOOL;
    SyncCompleteFb          : BOOL;
    GCB_ClosedFb            : BOOL;
    TripFb                  : BOOL;
    DelayedShutdownReqFb    : BOOL;

    (* measured *)
    kW                      : REAL;
    kVAR                    : REAL;
    AvailablekW             : REAL;

    (* supervisory outputs *)
    StartReq                : BOOL;
    StopReq                 : BOOL;
    RemoteBlockCmd          : BOOL;
    PlantEmergencyModeCmd   : BOOL;
    FastDisconnectCmd       : BOOL;
    FullThrottleModeCmd     : BOOL;

    AGC_Enable              : BOOL;
    AGC_Manual              : BOOL;
    AGC_kW_Setpoint         : REAL;
    AGC_kW_Min              : REAL;
    AGC_kW_Max              : REAL;
    AGC_BiasOut             : REAL;           (* abstract bias output *)

    VCS_Enable              : BOOL;
    VCS_Manual              : BOOL;
    VCS_kVAR_Setpoint       : REAL;
    VCS_kVAR_Min            : REAL;
    VCS_kVAR_Max            : REAL;
    VCS_BiasOut             : REAL;           (* abstract bias output *)

    RunState                : E_GEN_RUN_STATE;
    StartPermissive         : BOOL;
    StopPermissive          : BOOL;
    SelectedForStart        : BOOL;
    SelectedForStop         : BOOL;
END_STRUCT
END_TYPE

TYPE ST_Breaker :
STRUCT
    Id                      : INT;
    Name                    : STRING[40];
    ControlEnabled          : BOOL;
    RatedAmps               : INT;

    OpenFb                  : BOOL;
    ClosedFb                : BOOL;
    TripAlarmFb             : BOOL;
    BusVoltage              : REAL;

    OpenCmd                 : BOOL;
    CloseCmd                : BOOL;
    BlockClose              : BOOL;

    State                   : E_BREAKER_STATE;
    SeqState                : E_SEQ_STATE;
END_STRUCT
END_TYPE

TYPE ST_System :
STRUCT
    State                   : E_SYS_STATE;
    PrevState               : E_SYS_STATE;

    HealthyMaster           : BOOL;
    HealthyComms            : BOOL;
    HMI_HeartbeatOk         : BOOL;
    OT_Healthy              : BOOL;

    PartyModeReq            : BOOL;
    PartyModeActive         : BOOL;
    BlackStartEnable        : BOOL;
    BlackStartReq           : BOOL;
    BlackStartActive        : BOOL;

    BlackoutDetected        : BOOL;
    DeadBus34k5             : BOOL;
    DeadBus480              : BOOL;

    IRM_TargetPct           : REAL;
    MinimumSynchronized     : INT;
    MinGensetLoadPct        : REAL;

    Plant_kW_Load           : REAL;
    Plant_kVAR              : REAL;
    MainBus_kV              : REAL;
    MainBus_Hz              : REAL;

    AlarmActive             : BOOL;
    FaultLatched            : BOOL;
    AbortReq                : BOOL;
    ResetReq                : BOOL;
END_STRUCT
END_TYPE

(*
===============================================================================
GLOBAL VARIABLES
===============================================================================
*)
VAR_GLOBAL
    gSys            : ST_System;
    gGensets        : ARRAY[1..46] OF ST_Genset;      (* size adapt per site *)
    gMVBreakers     : ARRAY[1..200] OF ST_Breaker;    (* site-specific *)
    gLVBreakers     : ARRAY[1..200] OF ST_Breaker;    (* site-specific *)
END_VAR

(*
===============================================================================
UTILITY FUNCTIONS
===============================================================================
*)
FUNCTION F_IsDeadBus : BOOL
VAR_INPUT
    Bus_kV          : REAL;
    Nominal_kV      : REAL;
    ThresholdPU     : REAL;       (* e.g. 0.3 *)
END_VAR
F_IsDeadBus := (Bus_kV < (Nominal_kV * ThresholdPU));

FUNCTION F_GensetStartPermissive : BOOL
VAR_INPUT
    Gen             : ST_Genset;
END_VAR
F_GensetStartPermissive :=
    Gen.Enabled
    AND (Gen.ModeCmd = GEN_AUTO)
    AND Gen.LocalReadyForDemand
    AND Gen.InAutoAtLocal
    AND Gen.NoStartBlockAlarms
    AND NOT Gen.TripFb;

FUNCTION F_GensetStopPermissive : BOOL
VAR_INPUT
    Gen             : ST_Genset;
END_VAR
F_GensetStopPermissive :=
    Gen.Enabled
    AND (Gen.RunState = GEN_SYNCED OR Gen.RunState = GEN_RUNNING_UNSYNC)
    AND NOT Gen.TripFb;

FUNCTION F_AverageOnlineLoadPct : REAL
VAR
    i               : INT;
    n               : INT;
    totalPct        : REAL;
    pct             : REAL;
END_VAR
n := 0;
totalPct := 0.0;

FOR i := 1 TO 46 DO
    IF gGensets[i].RunState = GEN_SYNCED THEN
        IF gGensets[i].AvailablekW > 0.0 THEN
            pct := (gGensets[i].kW / gGensets[i].AvailablekW) * 100.0;
            totalPct := totalPct + pct;
            n := n + 1;
        END_IF;
    END_IF;
END_FOR;

IF n > 0 THEN
    F_AverageOnlineLoadPct := totalPct / INT_TO_REAL(n);
ELSE
    F_AverageOnlineLoadPct := 0.0;
END_IF;

FUNCTION F_OnlineGenCount : INT
VAR
    i               : INT;
    n               : INT;
END_VAR
n := 0;
FOR i := 1 TO 46 DO
    IF gGensets[i].RunState = GEN_SYNCED THEN
        n := n + 1;
    END_IF;
END_FOR;
F_OnlineGenCount := n;

FUNCTION F_RequiredGenCountIRM : INT
VAR_INPUT
    PlantLoadkW         : REAL;
    IRM_TargetPct       : REAL;
END_VAR
VAR
    RequiredCapacity    : REAL;
    i                   : INT;
    sortedCap           : ARRAY[1..46] OF REAL;
    sumCap              : REAL;
    cnt                 : INT;
END_VAR

(* Skeleton only:
   Required online count = enough online available kW so that
   reserve margin >= IRM_TargetPct.
*)
RequiredCapacity := PlantLoadkW * (1.0 + (IRM_TargetPct / 100.0));
sumCap := 0.0;
cnt := 0;

FOR i := 1 TO 46 DO
    IF gGensets[i].Enabled THEN
        cnt := cnt + 1;
        sortedCap[cnt] := gGensets[i].AvailablekW;
    END_IF;
END_FOR;

(* TODO: sort by commitment preference / priority class *)
sumCap := 0.0;
F_RequiredGenCountIRM := 0;
FOR i := 1 TO cnt DO
    sumCap := sumCap + sortedCap[i];
    F_RequiredGenCountIRM := F_RequiredGenCountIRM + 1;
    IF sumCap >= RequiredCapacity THEN
        EXIT;
    END_IF;
END_FOR;

(*
===============================================================================
FUNCTION BLOCKS
===============================================================================
*)
FUNCTION_BLOCK FB_GensetState
VAR_INPUT
    Id              : INT;
END_VAR
VAR
    StartPerm       : BOOL;
    StopPerm        : BOOL;
END_VAR

StartPerm := F_GensetStartPermissive(Gen := gGensets[Id]);
StopPerm  := F_GensetStopPermissive(Gen := gGensets[Id]);

gGensets[Id].StartPermissive := StartPerm;
gGensets[Id].StopPermissive  := StopPerm;

IF gGensets[Id].TripFb THEN
    gGensets[Id].RunState := GEN_TRIPPED;

ELSIF gGensets[Id].RunningFb AND gGensets[Id].GCB_ClosedFb AND gGensets[Id].SyncCompleteFb THEN
    gGensets[Id].RunState := GEN_SYNCED;

ELSIF gGensets[Id].RunningFb AND NOT gGensets[Id].GCB_ClosedFb THEN
    gGensets[Id].RunState := GEN_RUNNING_UNSYNC;

ELSIF gGensets[Id].StartReq AND NOT gGensets[Id].RunningFb THEN
    gGensets[Id].RunState := GEN_STARTING;

ELSIF gGensets[Id].StopReq AND gGensets[Id].RunningFb THEN
    gGensets[Id].RunState := GEN_STOPPING;

ELSIF NOT gGensets[Id].RunningFb THEN
    gGensets[Id].RunState := GEN_OFFLINE;

ELSE
    (* hold last *)
END_IF;

FUNCTION_BLOCK FB_AGC_VCS
VAR
    i               : INT;
    OnlineCount     : INT;
    HzError         : REAL;
    kVError         : REAL;
    SharedkWBias    : REAL;
    SharedkVARBias  : REAL;
END_VAR

OnlineCount := F_OnlineGenCount();

(* Skeleton only *)
HzError := 60.0 - gSys.MainBus_Hz;
kVError := 34.5 - gSys.MainBus_kV;

SharedkWBias := HzError * 100.0;
SharedkVARBias := kVError * 100.0;

FOR i := 1 TO 46 DO
    IF gGensets[i].RunState = GEN_SYNCED THEN

        IF gGensets[i].AGC_Enable THEN
            IF gGensets[i].AGC_Manual THEN
                gGensets[i].AGC_BiasOut := gGensets[i].AGC_kW_Setpoint;
            ELSE
                gGensets[i].AGC_BiasOut := SharedkWBias / INT_TO_REAL(MAX(OnlineCount,1));
            END_IF;
        ELSE
            gGensets[i].AGC_BiasOut := 0.0;
        END_IF;

        IF gGensets[i].VCS_Enable THEN
            IF gGensets[i].VCS_Manual THEN
                gGensets[i].VCS_BiasOut := gGensets[i].VCS_kVAR_Setpoint;
            ELSE
                gGensets[i].VCS_BiasOut := SharedkVARBias / INT_TO_REAL(MAX(OnlineCount,1));
            END_IF;
        ELSE
            gGensets[i].VCS_BiasOut := 0.0;
        END_IF;

        (* clamp *)
        IF gGensets[i].AGC_BiasOut < gGensets[i].AGC_kW_Min THEN
            gGensets[i].AGC_BiasOut := gGensets[i].AGC_kW_Min;
        END_IF;
        IF gGensets[i].AGC_BiasOut > gGensets[i].AGC_kW_Max THEN
            gGensets[i].AGC_BiasOut := gGensets[i].AGC_kW_Max;
        END_IF;

        IF gGensets[i].VCS_BiasOut < gGensets[i].VCS_kVAR_Min THEN
            gGensets[i].VCS_BiasOut := gGensets[i].VCS_kVAR_Min;
        END_IF;
        IF gGensets[i].VCS_BiasOut > gGensets[i].VCS_kVAR_Max THEN
            gGensets[i].VCS_BiasOut := gGensets[i].VCS_kVAR_Max;
        END_IF;
    ELSE
        gGensets[i].AGC_BiasOut := 0.0;
        gGensets[i].VCS_BiasOut := 0.0;
    END_IF;
END_FOR;

FUNCTION_BLOCK FB_GMS
VAR
    i                   : INT;
    OnlineCount         : INT;
    RequiredCount       : INT;
    AvgLoadPct          : REAL;
    StartIssued         : INT;
    StopCandidate       : INT;
END_VAR

OnlineCount := F_OnlineGenCount();
RequiredCount := F_RequiredGenCountIRM(
                    PlantLoadkW := gSys.Plant_kW_Load,
                    IRM_TargetPct := gSys.IRM_TargetPct);
IF RequiredCount < gSys.MinimumSynchronized THEN
    RequiredCount := gSys.MinimumSynchronized;
END_IF;

AvgLoadPct := F_AverageOnlineLoadPct();

(* clear selections *)
FOR i := 1 TO 46 DO
    gGensets[i].SelectedForStart := FALSE;
    gGensets[i].SelectedForStop := FALSE;
END_FOR;

(* Party Mode bypasses automatic GMS *)
IF gSys.PartyModeActive THEN
    RETURN;
END_IF;

(* Start logic: IRM has priority *)
IF OnlineCount < RequiredCount THEN
    StartIssued := 0;

    (* Skeleton selection:
       Choose two startable gensets by best priority / least hours tie-break
    *)
    FOR i := 1 TO 46 DO
        IF F_GensetStartPermissive(Gen := gGensets[i]) AND (gGensets[i].RunState = GEN_OFFLINE) THEN
            gGensets[i].SelectedForStart := TRUE;
            gGensets[i].StartReq := TRUE;
            StartIssued := StartIssued + 1;
        END_IF;

        IF StartIssued >= 2 THEN
            EXIT;
        END_IF;
    END_FOR;
END_IF;

(* Stop logic: only if above IRM need and minimum load violated *)
IF (OnlineCount > RequiredCount) AND (AvgLoadPct < gSys.MinGensetLoadPct) THEN
    StopCandidate := 0;

    (* Skeleton selection:
       Highest engine hours among equal priorities, lowest commitment value first
    *)
    FOR i := 1 TO 46 DO
        IF F_GensetStopPermissive(Gen := gGensets[i]) THEN
            StopCandidate := i;
            EXIT;
        END_IF;
    END_FOR;

    IF StopCandidate > 0 THEN
        gGensets[StopCandidate].SelectedForStop := TRUE;
        gGensets[StopCandidate].StopReq := TRUE;
    END_IF;
END_IF;

(* delayed shutdown override *)
FOR i := 1 TO 46 DO
    IF gGensets[i].DelayedShutdownReqFb THEN
        (* maintain IRM by demanding extra gensets *)
        (* skeleton: flag handled naturally by RequiredCount/start logic *)
    END_IF;
END_FOR;

FUNCTION_BLOCK FB_PartyMode
VAR
    i               : INT;
END_VAR

gSys.PartyModeActive := gSys.PartyModeReq;

IF gSys.PartyModeActive THEN
    FOR i := 1 TO 46 DO
        IF F_GensetStartPermissive(Gen := gGensets[i]) THEN
            gGensets[i].StartReq := TRUE;
        END_IF;
    END_FOR;
END_IF;

FUNCTION_BLOCK FB_BlackoutRecovery
VAR
    Seq             : E_SEQ_STATE := SEQ_IDLE;
    TimerExpired    : BOOL;
    i               : INT;
END_VAR

CASE Seq OF

SEQ_IDLE:
    IF gSys.BlackoutDetected THEN
        Seq := SEQ_START;
    END_IF;

SEQ_START:
    (* Verify master and comms healthy *)
    IF gSys.HealthyMaster AND gSys.HealthyComms THEN
        Seq := SEQ_CHECK_PERMISSIVES;
    ELSE
        Seq := SEQ_FAIL;
    END_IF;

SEQ_CHECK_PERMISSIVES:
    gSys.DeadBus34k5 := F_IsDeadBus(Bus_kV := gSys.MainBus_kV, Nominal_kV := 34.5, ThresholdPU := 0.3);
    (* gSys.DeadBus480 to come from LV E-house measurement *)
    IF gSys.DeadBus34k5 AND gSys.DeadBus480 THEN
        Seq := SEQ_ISSUE_COMMAND;
    END_IF;

SEQ_ISSUE_COMMAND:
    (* Open all ICBs + LV feeders required by site logic *)
    FOR i := 1 TO 200 DO
        IF gMVBreakers[i].ControlEnabled THEN
            gMVBreakers[i].OpenCmd := TRUE;
        END_IF;
        IF gLVBreakers[i].ControlEnabled THEN
            gLVBreakers[i].OpenCmd := TRUE;
        END_IF;
    END_FOR;

    (* Start backup diesel through OEM controller / EMCP interface *)
    (* BackupDiesel.StartReq := TRUE; *)
    Seq := SEQ_WAIT_FEEDBACK;

SEQ_WAIT_FEEDBACK:
    (* wait for breaker feedback and backup diesel online *)
    (* skeleton: replace with timers and feedback checks *)
    TimerExpired := FALSE;
    IF NOT TimerExpired THEN
        Seq := SEQ_VERIFY;
    ELSE
        Seq := SEQ_FAIL;
    END_IF;

SEQ_VERIFY:
    (* close critical LV feeders only *)
    (* issue site-specific close list *)
    Seq := SEQ_COMPLETE;

SEQ_COMPLETE:
    gSys.State := SYS_BLACKSTART_READY;
    (* hold complete *)

SEQ_FAIL:
    gSys.AlarmActive := TRUE;
    gSys.FaultLatched := TRUE;
    IF gSys.AbortReq THEN
        Seq := SEQ_ABORT;
    ELSIF gSys.ResetReq THEN
        Seq := SEQ_IDLE;
    END_IF;

SEQ_ABORT:
    gSys.State := SYS_ABORTED;

END_CASE;

FUNCTION_BLOCK FB_BlackStart
VAR
    Seq             : E_SEQ_STATE := SEQ_IDLE;
    i               : INT;
    StartedPrimary  : INT;
END_VAR

CASE Seq OF

SEQ_IDLE:
    IF gSys.BlackStartReq AND gSys.BlackStartEnable AND (gSys.State = SYS_BLACKSTART_READY) THEN
        Seq := SEQ_START;
    END_IF;

SEQ_START:
    gSys.BlackStartActive := TRUE;
    Seq := SEQ_CHECK_PERMISSIVES;

SEQ_CHECK_PERMISSIVES:
    IF gSys.HealthyMaster AND gSys.HealthyComms AND gSys.DeadBus34k5 THEN
        Seq := SEQ_ISSUE_COMMAND;
    ELSE
        Seq := SEQ_FAIL;
    END_IF;

SEQ_ISSUE_COMMAND:
    (* example sequence:
       1) verify all ICBs open
       2) close SYNCON path if required
       3) energize main bus
       4) start/stage gensets
       5) transfer off backup diesel
    *)

    (* step: start two primary gensets *)
    StartedPrimary := 0;
    FOR i := 1 TO 46 DO
        IF F_GensetStartPermissive(Gen := gGensets[i]) THEN
            gGensets[i].StartReq := TRUE;
            StartedPrimary := StartedPrimary + 1;
        END_IF;

        IF StartedPrimary >= 2 THEN
            EXIT;
        END_IF;
    END_FOR;

    Seq := SEQ_WAIT_FEEDBACK;

SEQ_WAIT_FEEDBACK:
    (* wait for running/sync feedback *)
    Seq := SEQ_VERIFY;

SEQ_VERIFY:
    (* if enough primary gensets synced, isolate backup diesel *)
    IF F_OnlineGenCount() >= gSys.MinimumSynchronized THEN
        (* BackupDiesel.StopReq := TRUE; *)
        gSys.BlackStartActive := FALSE;
        Seq := SEQ_COMPLETE;
    ELSE
        Seq := SEQ_FAIL;
    END_IF;

SEQ_COMPLETE:
    gSys.State := SYS_NORMAL;

SEQ_FAIL:
    gSys.AlarmActive := TRUE;
    gSys.FaultLatched := TRUE;
    IF gSys.AbortReq THEN
        Seq := SEQ_ABORT;
    ELSIF gSys.ResetReq THEN
        Seq := SEQ_IDLE;
    END_IF;

SEQ_ABORT:
    gSys.BlackStartActive := FALSE;
    gSys.State := SYS_ABORTED;

END_CASE;

FUNCTION_BLOCK FB_BreakerState
VAR_INPUT
    IsLV            : BOOL;
    Id              : INT;
END_VAR

IF IsLV THEN
    IF gLVBreakers[Id].OpenFb AND NOT gLVBreakers[Id].ClosedFb THEN
        gLVBreakers[Id].State := BRK_OPEN;
    ELSIF gLVBreakers[Id].ClosedFb AND NOT gLVBreakers[Id].OpenFb THEN
        gLVBreakers[Id].State := BRK_CLOSED;
    ELSIF gLVBreakers[Id].TripAlarmFb THEN
        gLVBreakers[Id].State := BRK_FAIL;
    ELSE
        gLVBreakers[Id].State := BRK_UNKNOWN;
    END_IF;
ELSE
    IF gMVBreakers[Id].OpenFb AND NOT gMVBreakers[Id].ClosedFb THEN
        gMVBreakers[Id].State := BRK_OPEN;
    ELSIF gMVBreakers[Id].ClosedFb AND NOT gMVBreakers[Id].OpenFb THEN
        gMVBreakers[Id].State := BRK_CLOSED;
    ELSIF gMVBreakers[Id].TripAlarmFb THEN
        gMVBreakers[Id].State := BRK_FAIL;
    ELSE
        gMVBreakers[Id].State := BRK_UNKNOWN;
    END_IF;
END_IF;

(*
===============================================================================
PROGRAMS
===============================================================================
*)
PROGRAM PRG_InputMapping
VAR
    i               : INT;
END_VAR

(* Map site I/O, FEP tags, relay bits, SEL-2411 data, Modbus data here *)

FOR i := 1 TO 46 DO
    (* Example abstractions only:
       gGensets[i].LocalReadyForDemand := <from SEL-2411 hardwire or Modbus>;
       gGensets[i].RunningFb := <from SEL-2411 or OEM>;
       gGensets[i].GCB_ClosedFb := <from SEL-700G>;
       gGensets[i].SyncCompleteFb := <from OEM / relay>;
       gGensets[i].TripFb := <from OEM/relay>;
       gGensets[i].kW := <analog>;
       gGensets[i].kVAR := <analog>;
       gGensets[i].AvailablekW := <analog>;
       gGensets[i].EngineHours := <Modbus>;
    *)
END_FOR;

(* example Holt-style mapping candidate *)
(*
   Engine Start/Stop write reg: 0x006C
   Engine operating mode read: 0x0000 / 0x00A2
   Starter mode read: 0x021A
   Start-stop state read: 0x009A
   Shutdown active alarm: 0x0281
*)

PROGRAM PRG_SupervisoryState
VAR
    blackoutFB      : FB_BlackoutRecovery;
    blackstartFB    : FB_BlackStart;
END_VAR

gSys.DeadBus34k5 := F_IsDeadBus(Bus_kV := gSys.MainBus_kV, Nominal_kV := 34.5, ThresholdPU := 0.3);

CASE gSys.State OF

SYS_INIT:
    IF gSys.HealthyMaster THEN
        gSys.State := SYS_IDLE;
    END_IF;

SYS_IDLE:
    IF gSys.BlackoutDetected THEN
        gSys.State := SYS_BLACKOUT_DETECTED;
    ELSE
        gSys.State := SYS_NORMAL;
    END_IF;

SYS_NORMAL:
    IF gSys.PartyModeReq THEN
        gSys.State := SYS_PARTY_MODE;
    ELSIF gSys.BlackoutDetected THEN
        gSys.State := SYS_BLACKOUT_DETECTED;
    ELSIF gSys.FaultLatched THEN
        gSys.State := SYS_FAULT;
    END_IF;

SYS_PARTY_MODE:
    IF NOT gSys.PartyModeReq THEN
        gSys.State := SYS_NORMAL;
    END_IF;

SYS_BLACKOUT_DETECTED:
    gSys.State := SYS_BLACKOUT_RECOVERY;

SYS_BLACKOUT_RECOVERY:
    blackoutFB();
    IF gSys.State = SYS_BLACKSTART_READY THEN
        (* transition done in FB *)
    END_IF;

SYS_BLACKSTART_READY:
    IF gSys.BlackStartReq THEN
        gSys.State := SYS_BLACKSTART_ACTIVE;
    END_IF;

SYS_BLACKSTART_ACTIVE:
    blackstartFB();

SYS_FAULT:
    IF gSys.ResetReq THEN
        gSys.FaultLatched := FALSE;
        gSys.State := SYS_IDLE;
    END_IF;

SYS_ABORTED:
    IF gSys.ResetReq THEN
        gSys.State := SYS_IDLE;
    END_IF;

END_CASE;

PROGRAM PRG_GeneratorSupervisor
VAR
    i               : INT;
    genFB           : ARRAY[1..46] OF FB_GensetState;
    agcFB           : FB_AGC_VCS;
    gmsFB           : FB_GMS;
    partyFB         : FB_PartyMode;
END_VAR

FOR i := 1 TO 46 DO
    genFB[i](Id := i);
END_FOR;

partyFB();

IF (gSys.State = SYS_NORMAL) OR (gSys.State = SYS_PARTY_MODE) THEN
    gmsFB();
    agcFB();
END_IF;

PROGRAM PRG_BreakerSupervisor
VAR
    i               : INT;
    mvFB            : ARRAY[1..200] OF FB_BreakerState;
    lvFB            : ARRAY[1..200] OF FB_BreakerState;
END_VAR

FOR i := 1 TO 200 DO
    mvFB[i](IsLV := FALSE, Id := i);
    lvFB[i](IsLV := TRUE, Id := i);
END_FOR;

PROGRAM PRG_OutputMapping
VAR
    i               : INT;
END_VAR

FOR i := 1 TO 46 DO
    (* map supervisory requests to real outputs / comm writes *)

    (* hardwire style *)
    (*
    SEL2411_OUT_Start[i] := PulseFromBool(gGensets[i].StartReq);
    SEL2411_OUT_Stop[i] := PulseFromBool(gGensets[i].StopReq);
    SEL2411_OUT_RemoteBlock[i] := gGensets[i].RemoteBlockCmd;
    SEL2411_AO_kWSetpoint[i] := gGensets[i].AGC_BiasOut;
    SEL2411_AO_kVARSetpoint[i] := gGensets[i].VCS_BiasOut;
    *)

    (* Modbus style alternative *)
    (*
    IF gGensets[i].StartReq THEN
        ModbusWrite(Reg := 16#006C, Value := 2);   (* RUN *)
    ELSIF gGensets[i].StopReq THEN
        ModbusWrite(Reg := 16#006C, Value := 0);   (* STOP *)
    END_IF;
    *)
END_FOR;

FOR i := 1 TO 200 DO
    (* map MV and LV breaker commands to FEP/relay/2240 interface *)
    (* NGVL -> FEP -> GOOSE/MMS/Modbus *)
END_FOR;

PROGRAM PLC_PRG
PRG_InputMapping();
PRG_SupervisoryState();
PRG_GeneratorSupervisor();
PRG_BreakerSupervisor();
PRG_OutputMapping();