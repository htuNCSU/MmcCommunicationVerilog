
`include "timescale.v"


module fb_slave_statem (MRxClk, Reset, MRxDV, MRxDEq5, MRxDEqDataSoC, MRxDEqNumbSoC, MRxDEqDistSoC, MRxDEqDelaySoC, MRxDEqDelayDistSoC, SlaveIDStart, DelayMeasStart,
                        DistStateEnd, DelayDistStateEnd, SlaveDataStart, SlaveDataEnd, SlaveCrcEnd, IsLastSlave, DataFrameEnd, FrmCrcStateEnd,
                        StateIdle, StatePreamble, StateFFS, StateNumb, StateSlaveID, StateDist, StateDelay, StateDelayMeas, StateDelayDist, StateData, StateSlaveData,
                        StateSlaveCrc, StateFrmCrc
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
input         SlaveIDStart;
input         DelayMeasStart;
input         DistStateEnd;
input         DelayDistStateEnd;
input         SlaveDataStart;    //SlaveDataStart = TotalNibCnt == SlaveDataStartCnt; 
input         SlaveDataEnd;      // SlaveDataEnd = TotalNibCnt == SlaveDataEndCnt;
input         SlaveCrcEnd;
input         IsLastSlave; 
input         DataFrameEnd;     //DataFrameEnd = (TotalNibCnt ==(TotalNibFrameCnt - 1'b1));
input         FrmCrcStateEnd;

output        StateIdle;
output        StateFFS;
output        StatePreamble;
output        StateNumb;
output  [1:0] StateSlaveID;
output        StateDist;
output        StateDelay;
output  [1:0] StateDelayMeas;
output        StateDelayDist;
output        StateData;
output  [1:0] StateSlaveData;
output        StateSlaveCrc;
output        StateFrmCrc;

reg           StateIdle;
reg           StateFFS;
reg           StatePreamble;
reg           StateNumb;
reg    [1:0]  StateSlaveID;
reg           StateDist;
reg           StateDelay;
reg    [1:0]  StateDelayMeas;
reg           StateDelayDist;
reg           StateData;
reg    [1:0]  StateSlaveData;
reg           StateSlaveCrc;
reg           StateFrmCrc;

wire          StartIdle;
wire          StartFFS;
wire          StartPreamble;
wire          StartNumb;
wire   [1:0]  StartSlaveID;
wire          StartDist;
wire          StartDelay;
wire   [1:0]  StartDelayMeas;
wire          StartDelayDist;
wire          StartData;
wire   [1:0]  StartSlaveData;
wire          StartSlaveCrc;
wire          StartFrmCrc;

// Defining the next state
assign StartIdle         = ~MRxDV & ( StatePreamble | StateFFS ) | (StateFrmCrc & FrmCrcStateEnd) ;

assign StartFFS          = MRxDV & ~MRxDEq5 & StateIdle;

assign StartPreamble     = MRxDV & MRxDEq5 & (StateIdle | StateFFS);

assign StartData         = (MRxDV & StatePreamble & MRxDEqDataSoC)|(StateSlaveCrc & SlaveCrcEnd & ~IsLastSlave);

assign StartNumb         =  MRxDV & StatePreamble & MRxDEqNumbSoC ;

assign StartSlaveID[0]   = StateNumb & SlaveIDStart ;

assign StartSlaveID[1]   = StateSlaveID[0];

assign StartDist         =  MRxDV & StatePreamble & MRxDEqDistSoC ;

assign StartDelay        =  MRxDV & StatePreamble & MRxDEqDelaySoC ;

assign StartDelayMeas[0] = StateDelay & DelayMeasStart ;

assign StartDelayMeas[1] = StateDelayMeas[0];

assign StartDelayDist    =  MRxDV & StatePreamble & MRxDEqDelayDistSoC ;

assign StartSlaveData[0] = StateData & SlaveDataStart | StateSlaveData[1] & ~SlaveDataEnd;
 
assign StartSlaveData[1] =  StateSlaveData[0]; 

assign StartSlaveCrc     = StateSlaveData[1] & SlaveDataEnd;
 
assign StartFrmCrc       = StateSlaveCrc & SlaveCrcEnd & IsLastSlave | StateData & DataFrameEnd | StateSlaveID[1] | StateDelayMeas[1] | (StateDist & DistStateEnd)| (StateDelayDist & DelayDistStateEnd);  

// Rx State Machine
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    begin
      StateIdle       <=  1'b1;
      StateFFS        <=  1'b0;
      StatePreamble   <=  1'b0;
      StateNumb       <=  1'b0;
      StateSlaveID    <=  2'b0;
      StateDelay      <=  1'b0;
      StateDelayMeas  <=  2'b0;
      StateDelayDist  <=  1'b0;
      StateDist       <=  1'b0;
      StateData       <=  1'b0;
      StateSlaveData  <=  2'b0;
      StateSlaveCrc   <=  1'b0;
      StateFrmCrc     <=  1'b0;
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
      
      if(  StartIdle | StartNumb | StartDist | StartDelay | StartDelayDist | StartData )
        StatePreamble <=  1'b0;
      else
      if(StartPreamble)
        StatePreamble <=  1'b1;
     
      if(StartSlaveID[0])
        StateNumb <=  1'b0;
      else
      if(StartNumb)
        StateNumb <=  1'b1;
      
      if(StartSlaveID[1])
        StateSlaveID[0] <=  1'b0;
      else
      if(StartSlaveID[0])
        StateSlaveID[0] <=  1'b1;
      
      if(StartFrmCrc)
        StateSlaveID[1] <=  1'b0;
      else
      if(StartSlaveID[1])
        StateSlaveID[1] <=  1'b1;
     
      if(StartFrmCrc)
        StateDist <=  1'b0;
      else
      if(StartDist)
        StateDist <=  1'b1;
        
      if(StartDelayMeas[0])
        StateDelay <=  1'b0;
      else
      if(StartDelay)
        StateDelay <=  1'b1;
        
      if(StartDelayMeas[1])
        StateDelayMeas[0] <=  1'b0;
      else
      if(StartDelayMeas[0])
        StateDelayMeas[0] <=  1'b1;
      
     if(StartFrmCrc)
        StateDelayMeas[1] <=  1'b0;
      else
      if(StartDelayMeas[1])
        StateDelayMeas[1] <=  1'b1;
        
     if(StartFrmCrc)
        StateDelayDist    <=  1'b0;
      else
      if(StartDelayDist)
        StateDelayDist    <=  1'b1;
        
     if(StartSlaveData[0] | StartFrmCrc)
        StateData <=  1'b0;
      else
      if(StartData)
        StateData <=  1'b1;
      
      if(StartSlaveData[1] )
        StateSlaveData[0] <=  1'b0;
      else
      if(StartSlaveData[0])
        StateSlaveData[0] <=  1'b1;
        
     if(StartSlaveData[0] | StartSlaveCrc)
        StateSlaveData[1]  <=  1'b0;
      else
      if(StartSlaveData[1])
        StateSlaveData[1] <=  1'b1;
      
      if(StartData | StartFrmCrc)
        StateSlaveCrc    <=  1'b0;
      else
      if(StartSlaveCrc)
        StateSlaveCrc <=  1'b1;
      
      if(StartIdle)
        StateFrmCrc <=  1'b0;
      else
      if(StartFrmCrc)
        StateFrmCrc   <=  1'b1;
      
    end
end

endmodule
