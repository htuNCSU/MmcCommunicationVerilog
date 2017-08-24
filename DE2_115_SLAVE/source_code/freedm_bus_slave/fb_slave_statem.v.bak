
`include "timescale.v"


module fb_slave_statem (MRxClk, Reset, MRxDV, MRxDEqDataSoC, MRxDEq5, SlaveDataStart
				SlaveDataEnd, SlaveCrcEnd, LastSlave, DataFrameEnd, FrmCrcStateEnd,
                StateIdle, StatePreamble, StateFFS, StateData, StateSlaveData,
				StateSlaveCrc, StateFrmCrc
                    );

input         MRxClk;
input         Reset;
input         MRxDV;

input         MRxDEq5;
input         MRxDEqDataSoC;
input         SlaveDataStart;    //SlaveDataStart = TotalNibCnt == SlaveDataStartCnt; 
input         SlaveDataEnd;      // SlaveDataEnd = TotalNibCnt == SlaveDataEndCnt;
input         SlaveCrcEnd;
input         LastSlave; 
input         DataFrameEnd;     //DataFrameEnd = (TotalNibCnt ==(TotalNibFrameCnt - 1'b1));
input         FrmCrcStateEnd;

output        StateIdle;
output        StateFFS;
output        StatePreamble;
output        StateData;
output        StateSlaveData;
output        StateSlaveCrc;
output        StateFrmCrc;

reg           StateIdle;
reg           StateFFS;
reg           StatePreamble;
reg           StateData;
reg           StateSlaveData;
reg           StateSlaveCrc;
reg           StateFrmCrc;

wire          StartIdle;
wire          StartFFS;
wire          StartPreamble;
wire          StartData;
wire          StartSlaveData;
wire          StartSlaveCrc;
wire          StartFrmCrc;

// Defining the next state
assign StartIdle = ~MRxDV & ( StatePreamble | StateFFS ) | (StateFrmCrc & FrmCrcStateEnd);

assign StartFFS = MRxDV & ~MRxDEq5 & StateIdle;

assign StartPreamble = MRxDV & MRxDEq5 & (StateIdle | StateFFS);

assign StartData = (MRxDV & StatePreamble & MRxDEqDataSoC)|(StateSlaveCrc & SlaveCrcEnd & ~LastSlave);

assign StartSlaveData[0] =  StateData & SlaveDataStart | StateSlaveData[1] & ~SlaveDataEnd;; 
 
assign StartSlaveData[1] =  StateSlaveData[0]; 

assign StartSlaveCrc = StateSlaveData[1] & SlaveDataEnd;
 
assign StartFrmCrc = StateSlaveCrc & SlaveCrcEnd & LastSlave | StateData & DataFrameEnd;  

// Rx State Machine
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    begin
      StateIdle     <=  1'b1;
      StateFFS      <=  1'b0;
	  StatePreamble <=  1'b0;
      StateData     <=  1'b0;
	  StateSlave    <=  1'b0;
	  StateSlaveCrc <=  1'b0;
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
		
      if(StartData)
        StatePreamble <=  1'b0;
      else
      if(StartPreamble)
        StatePreamble <=  1'b1;
	  
	  if(StartSlaveData | StartFrmCrc)
        StateData <=  1'b0;
      else
      if(StartData)
        StateData <=  1'b1;
		
	  if(StartSlaveCrc)
        StateSlaveData  <=  1'b0;
      else
      if(StartSlaveData)
        StateSlaveData <=  1'b1;
		
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
