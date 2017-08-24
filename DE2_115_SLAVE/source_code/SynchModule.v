module SynchModule( Clk_100MHz, Reset, Busy, LastSlaveIDPlus1, SlaveID, AveSlaveDelay, SynchSignal);

input          Clk_100MHz;
input          Reset;
input          Busy;
input   [7:0]  LastSlaveIDPlus1;
input   [7:0]  SlaveID;
input   [7:0]  AveSlaveDelay;

output         SynchSignal;

wire   [31:0]  SynchDelay;

wire           SynchSignal;
reg    [31:0]  SynchDelayCnt;


assign SynchDelay = (LastSlaveIDPlus1 - SlaveID - 8'd1) * AveSlaveDelay + 32'd1;

always @ (posedge Clk_100MHz)
begin
   if ( Reset )
      SynchDelayCnt <= 32'd0;
   else
   if (Busy)
      SynchDelayCnt <= 32'd0; 
   else
      SynchDelayCnt <= SynchDelayCnt + 32'd1;
end

assign SynchSignal = SynchDelayCnt >= SynchDelay;


endmodule 