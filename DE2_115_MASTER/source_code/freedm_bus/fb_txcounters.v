

`include "timescale.v"


module fb_txcounters (MTxClk, Reset, 
                       StateIdle, StatePreamble, StateSoC, StateNumb, StateDist, StateDelay, StateDelayDist,
                       StateData, StateCrc, StateFrmCrc,
                       StartData, CrcNibCnt,
                       TotalNibCnt, NibCnt, CrcStateEnd, PreambleStateEnd, FrmCrcStateEnd, TxRamAddr
                      );

input         MTxClk;             // Tx clock
input         Reset;              // Reset
input         StateIdle;          // Idle state
input         StatePreamble;      // Preamble state
input         StateSoC;           // SoC state
input         StateNumb;
input  [1:0]  StateDist;
input         StateDelay;
input  [1:0]  StateDelayDist;
input  [1:0]  StateData;    // Data state
input  [1:0]  StartData;    // Start Data state
input         StateCrc;           // CRC state
input         StateFrmCrc;

 
output [3: 0] CrcNibCnt;    // total Nibble counter
output [15:0] TotalNibCnt;    // total Nibble counter
output [15:0] NibCnt;     // Nibble counter
output        CrcStateEnd;
output        PreambleStateEnd;
output        FrmCrcStateEnd;
output [7: 0] TxRamAddr;


wire ResetNibCnt;
wire IncrementNibCnt;
wire ResetTotalNibCnt;
wire IncrementTotalNibCnt;
 
reg [15:0] TotalNibCnt;
reg [15:0] NibCnt;
reg [3: 0] CrcNibCnt;
reg [3: 0] PreambleNibCnt;
reg [3: 0] FrmCrcNibCnt;
reg [7: 0] TxRamAddr;

assign IncrementNibCnt =  (|StateData)  ;
assign ResetNibCnt = StateIdle | StateSoC & StartData[0] | StateCrc & StartData[0]| StateCrc;

// Nibble Counter started from each slave data( only for data, no SoC no CRC)
always @ (posedge MTxClk or posedge Reset)
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


assign IncrementTotalNibCnt =  StatePreamble | StateSoC | StateNumb | (|StateDist) | StateDelay | (|StateDelayDist)| (|StateData) | StateCrc ;
assign ResetTotalNibCnt = StateIdle;

// Total Nibble Counter for the whole frame incl.(Preamble, SoC, SlaveDate, SlaveCRC, NO FrameCRC)
always @ (posedge MTxClk or posedge Reset)
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

assign IncrementCrcNibCnt = StateCrc ;
assign ResetCrcNibCnt =  (|StateData);
assign CrcStateEnd = CrcNibCnt[0] ; // CRC always has two nibbles

always @ (posedge MTxClk or posedge Reset)
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
assign ResetFrmCrcNibCnt =  StateCrc ;
assign FrmCrcStateEnd    = FrmCrcNibCnt[0] ; // CRC always has two nibbles

always @ (posedge MTxClk or posedge Reset)
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


wire IncrementPreambleNibCnt;
wire ResetPreambleNibCnt;

assign IncrementPreambleNibCnt = StatePreamble ;
assign ResetPreambleNibCnt =  StateIdle;
assign PreambleStateEnd = (PreambleNibCnt == 4'b0010);

always @ (posedge MTxClk or posedge Reset)
begin
  if(Reset)
    PreambleNibCnt <=  4'b0;
  else
    begin
      if(ResetPreambleNibCnt)
        PreambleNibCnt <=  4'b0;
      else
      if(IncrementPreambleNibCnt)
        PreambleNibCnt <=  PreambleNibCnt + 4'b0001;
     end
end

wire IncrementTxRamAddr;
wire ResetTxRamAddr;

assign IncrementTxRamAddr = StateData[0];
assign ResetTxRamAddr =  StateIdle | StatePreamble | StateSoC;

always @ (posedge MTxClk or posedge Reset)
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


endmodule
