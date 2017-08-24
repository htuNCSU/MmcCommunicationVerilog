
`include "timescale.v"

module fb_rxcounters 
  (
   MRxClk, Reset, MRxDV, RxValid,
   StateIdle, StateFFS, StatePreamble, StateData, StateFrmCrc,
   MRxDEqDataSoC, TotalRecvNibCntEq0, TotalRecvNibCnt, RxRamAddr, FrmCrcNibCnt, FrmCrcStateEnd
   );

input         MRxClk;
input         Reset;
input         MRxDV;
input         RxValid;
input         StateIdle;
input         StateFFS;
input         StatePreamble;
input  [1:0]  StateData;
input         StateFrmCrc;

input         MRxDEqDataSoC;

output        TotalRecvNibCntEq0;            // Received Nibble counter = 0
output [15:0] TotalRecvNibCnt;               // Received Nibble counter
output [7: 0] RxRamAddr;
output [3: 0] FrmCrcNibCnt;
output        FrmCrcStateEnd;


reg   [15:0]  TotalRecvNibCnt;
reg   [7:0]   RxRamAddr;
reg   [3: 0]  FrmCrcNibCnt;

wire          ResetTotalRecvNibCnt;
wire          IncrementTotalRecvNibCnt;
assign        ResetTotalRecvNibCnt =  StateIdle & ~MRxDV;
assign        IncrementTotalRecvNibCnt =  MRxDV  ;

always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    TotalRecvNibCnt[15:0] <=  16'd0;
  else
    begin
      if(ResetTotalRecvNibCnt)
        TotalRecvNibCnt[15:0] <=  16'd0;
      else
      if(IncrementTotalRecvNibCnt)
        TotalRecvNibCnt[15:0] <=  TotalRecvNibCnt[15:0] + 16'd1;
     end
end

assign TotalRecvNibCntEq0       = TotalRecvNibCnt == 16'd0;


wire          ResetRxRamAddr;
wire          IncrementRxRamAddr;
assign ResetRxRamAddr =  StateIdle | StateFFS | StatePreamble;
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


wire IncrementFrmCrcNibCnt;
wire ResetFrmCrcNibCnt;

assign IncrementFrmCrcNibCnt = StateFrmCrc ;
assign ResetFrmCrcNibCnt =  StateIdle ;
assign FrmCrcStateEnd    = FrmCrcNibCnt[0] ; // CRC always has two nibbles

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


endmodule
