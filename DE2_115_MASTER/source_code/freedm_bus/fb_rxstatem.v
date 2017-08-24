
`include "timescale.v"


module fb_rxstatem (MRxClk, Reset, MRxDV, MRxDEq5, MRxDEqDataSoC, MRxDEqNumbSoC, MRxDEqDistSoC, MRxDEqDelaySoC,MRxDEqDelayDistSoC,
                    DelayFrameEnd, DataFrameEnd, FrmCrcStateEnd, StateIdle, StateFFS, StatePreamble, 
                    StateNumb, StateDist, StateDelay, StateData, StateFrmCrc
                    );

input         MRxClk;
input         Reset;
input         MRxDV;

input         MRxDEq5;
input         MRxDEqDataSoC;
input         MRxDEqNumbSoC;
input         MRxDEqDistSoC;
input         MRxDEqDelaySoC;
input         MRxDEqDelayDistSoC;
input         DelayFrameEnd;
input         DataFrameEnd;
input         FrmCrcStateEnd;


output        StateIdle;
output        StateFFS;
output        StatePreamble;
output [1:0]  StateNumb;
output [1:0]  StateDist;
output [1:0]  StateDelay;
output [1:0]  StateData;
output        StateFrmCrc;

reg           StateIdle;
reg           StateFFS;
reg           StatePreamble;
reg   [1:0]   StateNumb;
reg   [1:0]   StateDist;
reg   [1:0]   StateDelay;
reg   [1:0]   StateData;
reg           StateFrmCrc;

wire          StartIdle;
wire          StartFFS;
wire          StartPreamble;
wire  [1:0]   StartNumb;
wire  [1:0]   StartDist;
wire  [1:0]   StartDelay;
wire  [1:0]   StartData;
wire          StartFrmCrc;


// Defining the next state
assign StartIdle = ~MRxDV & ( StatePreamble | StateFFS | (|StateData) ) | StateFrmCrc & FrmCrcStateEnd;

assign StartFFS = MRxDV & ~MRxDEq5 & StateIdle;

assign StartPreamble = MRxDV & MRxDEq5 & (StateIdle | StateFFS);

assign StartNumb[0]    = MRxDV & (StatePreamble & MRxDEqNumbSoC);

assign StartNumb[1]    = MRxDV & StateNumb[0];

assign StartDist[0]    = MRxDV & (StatePreamble & (MRxDEqDistSoC | MRxDEqDelayDistSoC ));

assign StartDist[1]    = MRxDV & StateDist[0];

assign StartDelay[0]   = MRxDV & (StatePreamble & MRxDEqDelaySoC | StateDelay[1] & ~DelayFrameEnd);

assign StartDelay[1]   = MRxDV & StateDelay[0];

assign StartData[0]    = MRxDV & (StatePreamble & MRxDEqDataSoC | (StateData[1] & ~DataFrameEnd));

assign StartData[1]    = MRxDV & StateData[0] ;

assign StartFrmCrc     = MRxDV & (StateNumb[1] | StateData[1] & DataFrameEnd | StateDist[1] | StateDelay[1] & DelayFrameEnd);
/*assign StartDrop = MRxDV & (StateIdle & Transmitting | StateSFD & ~IFGCounterEq24 &
                   MRxDEqD |  StateData0 &  ByteCntMaxFrame);*/

// Rx State Machine
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    begin
      StateIdle     <=  1'b1;
      StatePreamble <=  1'b0;
      StateFFS      <=  1'b0;
      StateNumb     <=  2'b0;
      StateDist     <=  2'b0;
      StateDelay    <=  2'b0;
      StateData     <=  2'b0;
      StateFrmCrc   <=  1'b0;
    end
  else
    begin
      if(StartPreamble | StartFFS)
        StateIdle <=  1'b0;
      else
      if(StartIdle)
        StateIdle <=  1'b1;
      
     if(StartPreamble | StartIdle)
        StateFFS <=  1'b0;
      else
      if(StartFFS)
        StateFFS <=  1'b1;
      
      if(StartDelay[0] | StartDist[0] |StartNumb[0] | StartData[0] | StartIdle )
        StatePreamble <=  1'b0;
      else
      if(StartPreamble)
        StatePreamble <=  1'b1;
      
      if(StartNumb[1])
        StateNumb[0] <=  1'b0;
      else
      if(StartNumb[0])
        StateNumb[0] <=  1'b1;
      
     if(StartFrmCrc)
        StateNumb[1] <=  1'b0;
      else
      if(StartNumb[1])
        StateNumb[1] <=  1'b1;
//
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
        
      if(StartDelay[1])
        StateDelay[0] <=  1'b0;
      else
      if(StartDelay[0])
        StateDelay[0] <=  1'b1;
      
      if(StartFrmCrc | StartDelay[0])
        StateDelay[1] <=  1'b0;
      else
      if(StartDelay[1])
        StateDelay[1] <=  1'b1;

      if(StartIdle | StartData[1])
        StateData[0] <=  1'b0;
      else
      if(StartData[0])
        StateData[0] <=  1'b1;
      
     if(StartIdle | StartData[0] | StartFrmCrc)
        StateData[1] <=  1'b0;
      else
      if(StartData[1])
        StateData[1] <=  1'b1;
      
     if(StartIdle)
        StateFrmCrc  <=  1'b0;
      else
      if(StartFrmCrc)
        StateFrmCrc  <=  1'b1;
    end
end

endmodule
