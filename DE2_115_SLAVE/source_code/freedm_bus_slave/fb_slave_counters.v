

`include "timescale.v"


module fb_slave_counters (MRxClk, Clk_100MHz, Reset, MRxDV, RxValid, MRxDEqDataSoC, MTxEn_TxSync2,
                          StateIdle, StatePreamble, StateNumb, StateSlaveID, StateDist, StateDelay, StateDelayMeas,
                          StateDelayDist, StateData, StateSlaveData, StateSlaveCrc, StateFrmCrc,
                          TotalRecvNibCnt, TotalSentNibCnt, LogicDelay, SlaveCrcEnd, FrmCrcStateEnd, TxRamAddr, RxRamAddr
                      );

input        MRxClk;                  // Tx clock
input        Clk_100MHz;
input        Reset;                   // Reset
input        MRxDV;
input        RxValid;
input        MRxDEqDataSoC;
input        MTxEn_TxSync2;
input        StateIdle;               // Idle state
input        StatePreamble;           // Preamble state
input        StateNumb;
input [1:0]  StateSlaveID;
input        StateDist;
input        StateDelay;
input        StateDelayMeas;
input        StateDelayDist;
input        StateData;               // Data state
input [1:0]  StateSlaveData;          // StateSlaveData state
input        StateSlaveCrc;           // slave CRC state
input        StateFrmCrc;

output [15:0] TotalSentNibCnt;
output [15:0] TotalRecvNibCnt;        // total Nibble counter
output [7:0]  LogicDelay;              // Nibble counter
output [7: 0] TxRamAddr;
output [7: 0] RxRamAddr;
output        SlaveCrcEnd;
output        FrmCrcStateEnd;

reg [15:0]    TotalSentNibCnt;
reg [15:0]    TotalRecvNibCnt;
reg [7:0]     LogicDelay;
reg [7:0]     LogicDelayCnt;
reg [3: 0]    CrcNibCnt;
reg [3: 0]    PreambleNibCnt;
reg [3: 0]    FrmCrcNibCnt;
reg [7: 0]    TxRamAddr;
reg [7: 0]    RxRamAddr;

reg ResetLogicDelayCnt_100MHzSync1     ;
reg ResetLogicDelayCnt_100MHzSync2     ;
        
reg IncrementLogicDelayCnt_100MHzSync1 ; 
reg IncrementLogicDelayCnt_100MHzSync2 ;
    
reg MTxEn_TxSync2_100MHzSync1          ;
reg MTxEn_TxSync2_100MHzSync2          ;
reg MTxEn_TxSync2_100MHzSync3          ;

wire  ResetLogicDelayCnt;
wire IncrementLogicDelayCnt;
assign IncrementLogicDelayCnt =  MRxDV & ~MTxEn_TxSync2; //start counting when receiving any signal but yet not transmitting anything
assign ResetLogicDelayCnt = StateIdle &  ~MRxDV ;


//////////////////////////////   100 MHz clock domain   /////////////////////

 
always @ (posedge Clk_100MHz or posedge Reset)
begin
  if(Reset)
  begin
    ResetLogicDelayCnt_100MHzSync1     <=  1'b0;
    ResetLogicDelayCnt_100MHzSync2     <=  1'b0;
        
    IncrementLogicDelayCnt_100MHzSync1 <=  1'b0; 
    IncrementLogicDelayCnt_100MHzSync2 <=  1'b0;
    
    MTxEn_TxSync2_100MHzSync1          <=  1'b0;
    MTxEn_TxSync2_100MHzSync2          <=  1'b0;
    MTxEn_TxSync2_100MHzSync3          <=  1'b0;
  end
  else
    begin
    ResetLogicDelayCnt_100MHzSync1     <= ResetLogicDelayCnt;
    ResetLogicDelayCnt_100MHzSync2     <= ResetLogicDelayCnt_100MHzSync1;
    
    IncrementLogicDelayCnt_100MHzSync1 <= IncrementLogicDelayCnt;
    IncrementLogicDelayCnt_100MHzSync2 <= IncrementLogicDelayCnt_100MHzSync1;
    
    MTxEn_TxSync2_100MHzSync1          <=  MTxEn_TxSync2;
    MTxEn_TxSync2_100MHzSync2          <=  MTxEn_TxSync2_100MHzSync1;
    MTxEn_TxSync2_100MHzSync3          <=  MTxEn_TxSync2_100MHzSync2;
    end
end

// register logic delay 

always @ (posedge Clk_100MHz or posedge Reset)
begin
  if(Reset)
    LogicDelay <=  8'b0; 
  else 
  if ((MTxEn_TxSync2_100MHzSync3==0) & (MTxEn_TxSync2_100MHzSync2 ==1)) // stop counting when TX start to transmitting any signal
    LogicDelay <= LogicDelayCnt;
end

 
// delay counter count from receiving to starting sending signal
always @ (posedge Clk_100MHz or posedge Reset)
begin
  if(Reset)
    LogicDelayCnt <=  8'd0;
  else
    begin
      if(ResetLogicDelayCnt_100MHzSync2)
        LogicDelayCnt <=  8'd0;
      else
      if(IncrementLogicDelayCnt_100MHzSync2)
        LogicDelayCnt <=  LogicDelayCnt + 8'd1;
    end
end



//////////////////////////////   100 MHz clock domain end/////////////////////

// Total Nibble Counter received for the whole frame incl.( Preamble, SoC, SlaveDate, SlaveCRC, NO FrameCRC)
wire ResetTotalRecvNibCnt;
wire IncrementTotalRecvNibCnt;
assign IncrementTotalRecvNibCnt = MRxDV;
assign ResetTotalRecvNibCnt =  StateIdle;

always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    TotalRecvNibCnt <=  16'h0;
  else
    begin
      if(ResetTotalRecvNibCnt)
        TotalRecvNibCnt <=  16'h0;
      else
      if(IncrementTotalRecvNibCnt)
        TotalRecvNibCnt <=  TotalRecvNibCnt + 16'd1;
     end
end


// Total Nibble Counter already sent( Preamble,SoC, SlaveDate, SlaveCRC, NO FrameCRC)
wire ResetTotalSentNibCnt;
wire IncrementTotalSentNibCnt;
assign IncrementTotalSentNibCnt = StateNumb | (|StateSlaveID) | StateDist | StateDelay | StateDelayMeas | StateDelayDist |StateData | (|StateSlaveData) | StateSlaveCrc ;
assign ResetTotalSentNibCnt =  StateIdle;

always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    TotalSentNibCnt <=  16'h0;
  else
    begin
      if(ResetTotalSentNibCnt)
        TotalSentNibCnt <=  16'h0;
      else
      if(IncrementTotalSentNibCnt)
        TotalSentNibCnt <=  TotalSentNibCnt + 16'd1;
     end
end


wire IncrementCrcNibCnt;
wire ResetCrcNibCnt;
assign IncrementCrcNibCnt = StateSlaveCrc ;
assign ResetCrcNibCnt =  |StateSlaveData ;  
assign SlaveCrcEnd = CrcNibCnt[0] ;

always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    CrcNibCnt <=  4'b0;
  else
    begin
      if(ResetCrcNibCnt)
        CrcNibCnt <=  4'b0;
      else
      if(IncrementCrcNibCnt)
        CrcNibCnt <=  CrcNibCnt + 4'b0001;
     end
end


wire IncrementFrmCrcNibCnt;
wire ResetFrmCrcNibCnt;

assign IncrementFrmCrcNibCnt = StateFrmCrc ;
assign ResetFrmCrcNibCnt =  StateIdle | StatePreamble | StateData | (|StateSlaveData) | StateSlaveCrc;
assign FrmCrcStateEnd    =  FrmCrcNibCnt[0] ;

always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    FrmCrcNibCnt <=  4'b0;
  else
    begin
      if(ResetFrmCrcNibCnt)
        FrmCrcNibCnt <=  4'b0;
      else
      if(IncrementFrmCrcNibCnt)
        FrmCrcNibCnt <=  FrmCrcNibCnt + 4'b0001;
     end
end


wire IncrementTxRamAddr;
wire ResetTxRamAddr;

assign ResetTxRamAddr =  StateIdle | StatePreamble | StateData;
assign IncrementTxRamAddr = StateSlaveData[0];

always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    TxRamAddr <=  8'b0;
  else
    begin
      if(ResetTxRamAddr)
        TxRamAddr <=  8'b0;
      else
      if(IncrementTxRamAddr)
        TxRamAddr <=  TxRamAddr + 8'b0001;
     end
end


wire ResetRxRamAddr;
wire IncrementRxRamAddr;
assign ResetRxRamAddr =  StateIdle | StatePreamble;
assign IncrementRxRamAddr = RxValid ;

always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    RxRamAddr[7:0] <=  8'd0;
  else
    begin
      if(ResetRxRamAddr)
        RxRamAddr[7:0] <=  8'd0;
      else
      if(IncrementRxRamAddr)
        RxRamAddr[7:0] <=  RxRamAddr[7:0] + 8'd1;
     end
end




endmodule
