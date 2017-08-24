

`include "timescale.v"


module fb_txstatem  (MTxClk, Reset, 
                     TxStartFrm, NumbStateEnd, DistStateEnd, DelayStateEnd, SlaveEndFrm, TxEndFrm, 
                      RegNumbSoC, RegDataSoC, RegDistSoC, RegDelaySoC, RegDelayDistSoC,
                      
                      TxUnderRun, UnderRun, StartTxDone, CrcStateEnd, PreambleStateEnd,
                      
                      StateIdle, StatePreamble, StateSoC, StateNumb, StateDist, 
                      StateDelay, StateDelayDist, StateData, StateCrc, StateFrmCrc,
                      
                      StartData
                     );

input MTxClk;
input Reset;


input        TxStartFrm;
input        NumbStateEnd;
input        DistStateEnd;
input        DelayStateEnd;
input        SlaveEndFrm;
input        TxEndFrm;
input        RegNumbSoC;
input        RegDataSoC;
input        RegDistSoC;
input        RegDelaySoC;
input        RegDelayDistSoC;
input        TxUnderRun;
input        UnderRun;
input        StartTxDone; 
input        CrcStateEnd;
input        PreambleStateEnd;

output       StateIdle;         // Idle state
output       StatePreamble;     // Preamble state
output       StateSoC;          // SoC state
output       StateNumb;         // Numbering state
output [1:0] StateDist;         // Distribute state
output       StateDelay;        // Delay state
output [1:0] StateDelayDist;    // Delay Distribute state
output [1:0] StateData;         // Data state
output       StateCrc;          // Crc state
output       StateFrmCrc;       // Frame Crc state

output [1:0] StartData;         // Data state will be activated in next clock


reg          StateIdle;
reg          StatePreamble;
reg          StateSoC;
reg          StateNumb;
reg    [1:0] StateDist;
reg          StateDelay;
reg    [1:0] StateDelayDist;
reg    [1:0] StateData;
reg          StateCrc;
reg          StateFrmCrc;

wire         StartIdle;          // Idle state will be activated in next clock
wire         StartPreamble;     // Preamble state will be activated in next clock
wire         StartSoC;          // SoC state will be activated in next clock
wire         StartNumb;
wire [1:0]   StartDist;
wire         StartDelay;
wire [1:0]   StartDelayDist;
wire [1:0]   StartData;
wire         StartCrc;          // Crc state will be activated in next clock
wire         StartFrmCrc;       // Frm Crc state will be activated in next clock


// Defining the next state

assign StartIdle = StartTxDone;

assign StartPreamble = StateIdle & TxStartFrm;

assign StartSoC = StatePreamble & PreambleStateEnd;

assign StartNumb = StateSoC & RegNumbSoC;

assign StartDist[0] = StateSoC & RegDistSoC;

assign StartDist[1] = StateDist[0];

assign StartDelay = StateSoC & RegDelaySoC;

assign StartDelayDist[0] = StateSoC & RegDelayDistSoC;

assign StartDelayDist[1] = StateDelayDist[0];

assign StartData[0] = ( StateSoC & RegDataSoC ) | ( StateData[1] & ~SlaveEndFrm ) | ( StateCrc & ~TxEndFrm & CrcStateEnd);

assign StartData[1] =  StateData[0] & ~TxUnderRun ;

assign StartCrc =  StateData[1] & SlaveEndFrm ;

assign StartFrmCrc = StateCrc & TxEndFrm  | StateNumb & NumbStateEnd | StateDist[1] & DistStateEnd | StateDelay & DelayStateEnd | StateDelayDist[1];

// Tx State Machine
always @ (posedge MTxClk or posedge Reset)
begin
  if(Reset)
    begin
      StateIdle            <=  1'b1;
      StatePreamble        <=  1'b0;
      StateSoC             <=  1'b0;
      StateNumb            <=  1'b0;
      StateDist[1:0]       <=  2'b0;
      StateDelay           <=  1'b0;
      StateDelayDist[1:0]  <=  2'b0;
      StateData[1:0]       <=  2'b0;
      StateCrc             <=  1'b0;
      StateFrmCrc          <=  1'b0;
    end
  else
    begin
      StateData[1:0] <=  StartData[1:0];
     
      if(StartPreamble)
        StateIdle <=  1'b0;
      else
      if(StartIdle)
        StateIdle <=  1'b1;
   
     if(StartSoC)
        StatePreamble <=  1'b0;
      else
      if(StartPreamble)
        StatePreamble <=  1'b1;
      
     if(StartData[0] | StartNumb | StartDist[0] | StartDelay | StartDelayDist[0])
        StateSoC  <=  1'b0;
      else
      if(StartSoC)
        StateSoC  <=  1'b1;
      
      if(StartFrmCrc)
        StateNumb <=  1'b0;
      else
      if(StartNumb)
        StateNumb <=  1'b1;
        
      if(StartFrmCrc)
        StateDelay <=  1'b0;
      else
      if(StartDelay)
        StateDelay <=  1'b1;
        
     if(StartDist[1])
        StateDist[0] <=  1'b0;
      else
      if(StartDist[0])
        StateDist[0] <=  1'b1;
      
     if(StartFrmCrc)
        StateDist[1] <=  1'b0;
      else
      if(StartDist[1])
        StateDist[1] <=  1'b1;
        
     if(StartDelayDist[1])
        StateDelayDist[0] <=  1'b0;
      else
      if(StartDelayDist[0])
        StateDelayDist[0] <=  1'b1;
      
     if(StartFrmCrc)
        StateDelayDist[1] <=  1'b0;
      else
      if(StartDelayDist[1])
        StateDelayDist[1] <=  1'b1;
        
      if(StartData[0] | StartFrmCrc)
        StateCrc <=  1'b0;
      else
      if(StartCrc)
        StateCrc <=  1'b1;
        
      if(StartIdle)
        StateFrmCrc <=  1'b0;
      else
      if(StartFrmCrc)
        StateFrmCrc <=  1'b1;

    end
end

endmodule
