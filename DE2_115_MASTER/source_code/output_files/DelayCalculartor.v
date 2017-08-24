module DelayCalculator(Clk_100MHz, rst, StartCounting, StopCounting, DelaySum, LastSlaveIDPlus1,
                       RegLoopDelay, AveTransDelay, AveLogicDelay, AveSlaveDelay);


input         Clk_100MHz;
input         rst;
input         StartCounting;
input         StopCounting;
input  [15:0]  DelaySum;
input  [7:0]  LastSlaveIDPlus1;

output [15:0] RegLoopDelay;
output [7:0]  AveTransDelay;
output [7:0]  AveLogicDelay;
output [7:0]  AveSlaveDelay;

reg    [31:0] Trans_mul;
reg    [31:0] Logic_mul;
reg    [15:0] LoopDelayCnt;
reg    [15:0] RegLoopDelay;
reg    [7:0]  AveTransDelay;
reg    [7:0]  AveLogicDelay;
reg    [7:0]  AveSlaveDelay;
reg           ResetLoopDelay_100MHzSync1;
reg           ResetLoopDelay_100MHzSync2;
reg           ResetLoopDelay_100MHzSync3;
reg           StopLoopDelay_100MHzSync1;
reg           StopLoopDelay_100MHzSync2;
reg           StopLoopDelay_100MHzSync3;

wire   [16:0] mul;
wire   [8:0]  shift;
wire   [16:0] mul1;
wire   [8:0]  shift1;
wire          ResetLoopDelay;
wire          StopLoopDelay;

assign ResetLoopDelay = StartCounting;  //.StartCounting(TxStateSoC), start counting after SoC, exclude SoC
assign StopLoopDelay  = StopCounting;   //.StopCounting(RxStateDelay[0]), stop counting after SoC, include SoC


//synchronized with 100 MHz clock
always @ (posedge Clk_100MHz or posedge rst)
begin
  if(rst)
  begin
    ResetLoopDelay_100MHzSync1 <=  1'b0;
    ResetLoopDelay_100MHzSync2 <=  1'b0;
    ResetLoopDelay_100MHzSync3 <=  1'b0;
    StopLoopDelay_100MHzSync1  <=  1'b0;
    StopLoopDelay_100MHzSync2  <=  1'b0;
    StopLoopDelay_100MHzSync3  <=  1'b0;
  end
  else
  begin
    ResetLoopDelay_100MHzSync1 <=  ResetLoopDelay;
    ResetLoopDelay_100MHzSync2 <=  ResetLoopDelay_100MHzSync1;
    ResetLoopDelay_100MHzSync3 <=  ResetLoopDelay_100MHzSync2;
    StopLoopDelay_100MHzSync1  <=  StopLoopDelay;
    StopLoopDelay_100MHzSync2  <=  StopLoopDelay_100MHzSync1;
    StopLoopDelay_100MHzSync3  <=  StopLoopDelay_100MHzSync2;
  end
end

// counting the loop delay
always @ (posedge Clk_100MHz or posedge rst)
begin
  if(rst)
    LoopDelayCnt <=  16'd0;
  else
    begin
      if((~ResetLoopDelay_100MHzSync3) & ResetLoopDelay_100MHzSync2)
        LoopDelayCnt <=  16'd0;
      else
        LoopDelayCnt <=  LoopDelayCnt + 16'd1;
    end
end
   
// register the loop delay
always @ (posedge Clk_100MHz or posedge rst)
begin
  if(rst)
    RegLoopDelay <=  16'd0;
  else
    begin
      if((~StopLoopDelay_100MHzSync3) & (StopLoopDelay_100MHzSync2))
        RegLoopDelay <= LoopDelayCnt ;
    end
end
   
// calculate transmission delay/logic delay/Slave delay based on loop delay and logic delay sum
always @ (*)
begin
   if( rst )
   begin
      AveTransDelay =  8'd0;
      AveLogicDelay =  8'd0;
      AveSlaveDelay =  8'd0;
      Trans_mul     = 32'd0;
      Logic_mul     = 32'd0;
   end
   else
   begin
      Trans_mul     = (RegLoopDelay - DelaySum) * mul1;
      
      AveTransDelay = Trans_mul >> shift1;
      
      Logic_mul     = DelaySum * mul;
      
      AveLogicDelay = Logic_mul >> shift;
      
      AveSlaveDelay = AveTransDelay + AveLogicDelay;
    end
end

division_factor division_factor_ins
(
.div(LastSlaveIDPlus1),
.mul(mul),
.shift(shift)
);

division_factor division_factor_ins1
(
.div((LastSlaveIDPlus1 + 1'b1)),
.mul(mul1),
.shift(shift1)
);
endmodule 