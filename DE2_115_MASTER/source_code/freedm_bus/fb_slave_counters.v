

`include "timescale.v"


module fb_slave_counters (MRxClk, Reset, MRxDEqDataSoC,
                          StateIdle, StatePreamble, StateData, StateSlaveData, StateSlaveCrc, StateFrmCrc,
                          TotalNibCnt, NibCnt, SlaveCrcEnd, FrmCrcStateEnd, TxRamAddr, RxRamAddr, SlaveByteCntEq0, IncrementTotalNibCnt
                      );

input MRxClk;                  // Tx clock
input Reset;                   // Reset
input StateIdle;               // Idle state
input StatePreamble;           // Preamble state
input StateData;               // Data state
input [1:0] StateSlaveData;    // StateSlaveData state
input StateSlaveCrc;           // slave CRC state
input StateFrmCrc;
input MRxDEqDataSoC;

output [15:0] TotalNibCnt;    // total Nibble counter
output [15:0] NibCnt;     // Nibble counter

output SlaveCrcEnd;
output FrmCrcStateEnd;
output [7: 0] TxRamAddr;
output [7: 0] RxRamAddr;
output        SlaveByteCntEq0;
output IncrementTotalNibCnt;

wire       SlaveByteCntEq0;
wire [3:0] CrcNibbleCnt;

reg [15:0] TotalNibCnt;
reg [15:0] NibCnt;
reg [3: 0] CrcNibCnt;
reg [3: 0] PreambleNibCnt;
reg [3: 0] FrmCrcNibCnt;
reg [7: 0] TxRamAddr;
reg [7: 0] RxRamAddr;

assign CrcNibbleCnt = 4'd2;


wire ResetNibCnt;
wire IncrementNibCnt;
assign IncrementNibCnt =  (|StateSlaveData)  ;
assign ResetNibCnt = StateIdle | StateData ;

// Nibble Counter started from each slave data( only for data, no SoC no CRC)
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    NibCnt <=  16'h0;
  else
    begin
      if(ResetNibCnt)
        NibCnt <=  16'h0;
      else
      if(IncrementNibCnt)
        NibCnt <=  NibCnt + 16'd1;
     end
end

wire ResetTotalNibCnt;
wire IncrementTotalNibCnt;
assign IncrementTotalNibCnt =   StatePreamble | StateData | (|StateSlaveData) | StateSlaveCrc ;
assign ResetTotalNibCnt     =   StateIdle;

// Total Nibble Counter for the whole frame incl.( Preamble, SlaveDate, SlaveCRC, NO FrameCRC)
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    TotalNibCnt <=  16'h0;
  else
    begin
      if(ResetTotalNibCnt)
        TotalNibCnt <=  16'h0;
      else
      if(IncrementTotalNibCnt)
        TotalNibCnt <=  TotalNibCnt + 16'd1;
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
assign FrmCrcStateEnd    = FrmCrcNibCnt[0] ;

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
assign IncrementTxRamAddr = StartSlaveData[0];

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
assign ResetRxRamAddr =  StateIdle | StateFFS | StatePreamble | StateData;
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


wire          ResetByteCounter;
wire          IncrementByteCounter;
wire          ByteCntMax;
assign ResetByteCounter =  MRxDV & StatePreamble & MRxDEqDataSoC | StateData;
assign IncrementByteCounter = ~ResetByteCounter & MRxDV &( StateSlaveData[1] & ~ByteCntMax ) ;
assign SlaveByteCntEq0       = ByteCnt == 16'd0;
assign ByteCntMax       = ByteCnt == 16'hffff;

always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    ByteCnt[15:0] <=  16'd0;
  else
    begin
      if(ResetByteCounter)
        ByteCnt[15:0] <=  16'd0;
      else
      if(IncrementByteCounter)
        ByteCnt[15:0] <=  ByteCnt[15:0] + 16'd1;
     end
end



endmodule
