`include "freedm_bus/fb_defines.v"


module pyhctrl (
   input         CLOCK_50,
   
   // KEY
   input  [0: 0] KEY,
   input  [17: 0] SW,
   
   output [17: 0] LEDR,
   output [10: 0] GPIO,
   output [8: 0] LEDG,
   output [6:0]HEX7,HEX6,HEX5,HEX4,HEX3,HEX2,HEX1,HEX0,
   // Ethernet 0
   output        ENET0_MDC,
   inout         ENET0_MDIO,
   output        ENET0_RESET_N,
   
   output        ENET0_GTX_CLK,
   input         ENET0_TX_CLK,
   input         ENET0_RX_CLK,
   input  [3: 0] ENET0_RX_DATA,
   input         ENET0_RX_DV,
   
   output [3: 0] ENET0_TX_DATA,
   output        ENET0_TX_EN,
   output        ENET0_TX_ER,
   // Ethernet 1
   output        ENET1_GTX_CLK,
   output        ENET1_MDC,
   inout         ENET1_MDIO,
   output        ENET1_RESET_N,
   
   input         ENET1_TX_CLK,
   input         ENET1_RX_CLK,
   input  [3: 0] ENET1_RX_DATA,
   input         ENET1_RX_DV,
   
   output [3: 0] ENET1_TX_DATA,
   output        ENET1_TX_EN
);
   
   wire rst;
   assign rst = SW[17];
   
   wire mdc;
   assign ENET1_MDC = mdc;
   assign ENET0_MDC = mdc;

   assign ENET0_RESET_N = 1'b1;
   assign ENET1_RESET_N = 1'b1;


   assign GPIO[0] = ENET0_TX_DATA[0];
   assign GPIO[1] = ENET0_TX_DATA[1];
   assign GPIO[2] = ENET0_TX_DATA[2];
   assign GPIO[3] = ENET0_TX_DATA[3];
   assign GPIO[4] = ENET1_RX_DATA[0];
   assign GPIO[5] = ENET1_RX_DATA[1];
   assign GPIO[6] = ENET1_RX_DATA[2];
   assign GPIO[7] = ENET1_RX_DATA[3];
   
   wire clk_tx0_25;
   wire clk_tx1_25;
   wire clk_rx0_25;
   wire clk_rx1_25;
   assign clk_tx0_25 = ENET0_TX_CLK;
   assign clk_tx1_25 = ENET1_TX_CLK;
   assign clk_rx0_25 = ENET0_RX_CLK;
   assign clk_rx1_25 = ENET1_RX_CLK;
   
   wire TxStateSoC;
   wire [1:0]RxStateDelay;
   
//   generation of start transmitting signal  
   reg [31:0]TxCnt;
   wire TxStartFrm;
   assign TxStartFrm = & TxCnt[24:0];
   
   always @ (posedge  clk_tx0_25)
   begin 
      if (rst) begin
               TxCnt <= 31'b0;
         end else if (TxStartFrm )begin
               TxCnt <= 31'b0;
         end
         else
               TxCnt <= TxCnt + 1'b1;
   end

   

wire  PHYInitEnd;
wire  FrameStart;
wire  ConfigOK;

wire  NumbFrameReceived;
wire  DistFrameReceived;
wire  DelayFrameReceived;
wire  DelayDistFrameReceived;

reg   NumbFrameReceived_TXsyn1;
reg   DistFrameReceived_TXsyn1;
reg   DelayFrameReceived_TXsyn1;
reg   DelayDistFrameReceived_TXsyn1;
reg   NumbFrameReturned;
reg   DistFrameReturned;
reg   DelayFrameReturned;
reg   DelayDistFrameReturned;

wire  TopStateIdle;
wire  TopStateNumb;
wire  TopStateDist;
wire  TopStateDelay;
wire  TopStateDelayDist;
wire  TopStateData;
wire  TopStateWait;

assign  LEDR[11] = TopStateIdle;
assign  LEDR[12] = TopStateNumb;
assign  LEDR[13] = TopStateDist;
assign  LEDR[14] = TopStateDelay;
assign  LEDR[15] = TopStateDelayDist;
assign  LEDR[16] = TopStateData;
assign  LEDR[17] = TopStateWait;

/////////////////////////////////////// fb_top state machine  /////////////////
   
fb_topstatem fb_topstatem_INS
(
   .clk_top(clk_tx0_25), 
   .rst(rst), 
   .SystemEnd(1'b0), 
   .SystemStart(SW[8]), 
   .PHYInitEnd(PHYInitEnd), 
   .NumbFrameReturned(NumbFrameReturned), 
   .DistFrameReturned(DistFrameReturned), 
   .DelayFrameReturned(DelayFrameReturned),
   .DelayDistFrameReturned(DelayDistFrameReturned),
   .ConfigEnd(ConfigOK), 
   .DataFrameGo(TxStartFrm), 
   .StateIdle(TopStateIdle), 
   .StateNumb(TopStateNumb), 
   .StateDist(TopStateDist), 
   .StateDelay(TopStateDelay), 
   .StateDelayDist(TopStateDelayDist), 
   .StateData(TopStateData), 
   .StateWait(TopStateWait)
);

//generator FrameStart signal
assign FrameStart = TopStateNumb | TopStateDist | TopStateDelay | TopStateDelayDist | TopStateData;

//synchronizing RX signals to TX clock
always @ (posedge clk_tx0_25 or posedge rst)
begin
  if(rst)
  begin
    NumbFrameReceived_TXsyn1       <= 1'b0;
    DistFrameReceived_TXsyn1       <= 1'b0;
    DelayFrameReceived_TXsyn1      <= 1'b0;
    DelayDistFrameReceived_TXsyn1  <= 1'b0;
    NumbFrameReturned              <= 1'b0;
    DistFrameReturned              <= 1'b0;
    DelayFrameReturned             <= 1'b0;
    DelayDistFrameReturned         <= 1'b0;
  end
  else
  begin
    NumbFrameReceived_TXsyn1       <= NumbFrameReceived;
    DistFrameReceived_TXsyn1       <= DistFrameReceived;
    DelayFrameReceived_TXsyn1      <= DelayFrameReceived;
    DelayDistFrameReceived_TXsyn1  <= DelayDistFrameReceived;
    NumbFrameReturned              <= NumbFrameReceived_TXsyn1;
    DistFrameReturned              <= DistFrameReceived_TXsyn1;
    DelayFrameReturned             <= DelayFrameReceived_TXsyn1;
    DelayDistFrameReturned         <= DelayDistFrameReceived_TXsyn1;
  end
end

 
///////////////////////////////////////   transmitter mac  /////////////////////////////
 
   wire [7:0] TxRamAddr;
   wire [7:0] TxData;

   fb_txmac fb_txmac_ins(
   
      .MTxClk(clk_tx0_25), 
      .Reset(rst), 
      .TxUnderRun(1'b0), 
      .TxData(TxData), 
      
      .TxStartFrm(FrameStart),
      .NumbSoC(TopStateNumb),
      .DistSoC(TopStateDist),
      .DelaySoC(TopStateDelay),
      .DelayDistSoC(TopStateDelayDist),
      .DataSoC(TopStateData),
      /*
      .TxStartFrm(TxStartFrm),
      .NumbSoC(1'b0),
      .DistSoC(1'b0),
      .DelaySoC(1'b1),
      .DelayDistSoC(1'b0),
      .DataSoC(1'b0),
      */
      .LastSlaveIDPlus1(8'd2),
      .AveSlaveDelay(8'h3e),
      
      .MTxD(ENET0_TX_DATA),
      .MTxEn(ENET0_TX_EN), 
      .MTxErr(ENET0_TX_ER), 
   // .TxDone(LEDR[1]), 
   // .TxUsedData(LEDR[2]), 
   // .WillTransmit(LEDR[3]),
   // .StartTxDone(LEDR[4]), 
      .StateIdle(LEDR[1]),
      .StatePreamble(LEDR[2]),
      .StateSoC(TxStateSoC),
      .StateNumb(LEDR[3]), 
      .StateDist(LEDR[5:4]), 
      .StateDelay(LEDR[6]),
      .StateDelayDist(LEDR[7]), 
      .StateData(LEDR[9:8]),
      .StateCrc(LEDR[10]),
      .TxRamAddr(TxRamAddr)
     );
   
   //dual port ram for tx, a port for write from higher level, b port for read from txmac
   tx_dual_port_ram_8bit tx_dual_port_ram_8bit_ins( 
    //.data_a, 
      .data_b(TxData),
    //.addr_a, 
      .addr_b(TxRamAddr),
    //.we_a, 
      .we_b(1'b0), 
      .clk(clk_tx0_25),
    //.q_a, 
      .q_b(TxData)
     );
     
////////////////////////////////////       receiver mac              /////////////////////////////
   wire RxStateIdle;
   wire [7:0]RxData;
   wire RxValid;
   wire [7:0]RxRamAddr;
   wire [15:0]DelaySum;
   wire [7:0]LastSlaveIDPlus1;
   fb_rxmac  fb_rxmac_ins
(
      .MRxClk(clk_rx1_25), 
      .MRxDV(ENET1_RX_DV), 
      .MRxD(ENET1_RX_DATA), 
      .Reset(rst), 
      .inLastSlaveIDPlus1(8'd2),
      
      .RxData(RxData), 
      .RxValid(RxValid),
      .RxRamAddr(RxRamAddr),
      .LastSlaveIDPlus1(LastSlaveIDPlus1),
      .DelaySum(DelaySum),
      .NumbFrameReceived(NumbFrameReceived), 
      .DistFrameReceived(DistFrameReceived), 
      .DelayFrameReceived(DelayFrameReceived),
      .DelayDistFrameReceived(DelayDistFrameReceived),
      //.DataFrameReceived(DataFrameReceived),
      
      .StateIdle(RxStateIdle), 
      //.StateFFS(LEDG[1]), 
      .StatePreamble(LEDG[1]), 
      .StateNumb(LEDG[3:2]),
      .StateDist(LEDG[5:4]),
      .StateDelay(RxStateDelay),
      .StateData(LEDG[7:6]),
     // .StateFrmCrc(LEDG[8])
      //.debug(LEDG[8])
     );
     
   LEDnumb LED5(HEX5, LastSlaveIDPlus1[3:0]);
   
   wire [7:0]readFromRxRam8bit;
   //dual port ram for rx, a port for write from rxmac, b port for read from higher level
   rx_dual_port_ram_8bit rx_dual_port_ram_8bit_ins(
   
      .data_a(RxData), 
      //.data_b,
      .addr_a(RxRamAddr),
      .addr_b(SW[7:2]),
      .we_a(RxValid), 
      .we_b(1'b0),
      .clk(clk_rx1_25),
      //.q_a, 
      .q_b(readFromRxRam8bit)
   );
   
     
     
   reg [5:0]rx_ram_addr1;
   always @ (posedge clk_rx1_25 )
   begin
         if (rst) 
         begin
               rx_ram_addr1 <= 6'b0;
         end
         else 
         if (RxStateIdle)
            rx_ram_addr1 <= 6'b0;
         else 
         if (ENET1_RX_DV)
         begin
               if (rx_ram_addr1 < 6'b111110 )
                   rx_ram_addr1 <= rx_ram_addr1 + 1'b1; 
         end
   end
   
   wire [3:0]readFromRxRam;
   rx_data_ram rx_data_ram_ins(
   
      .data_a(ENET1_RX_DATA), 
      //.data_b,
      .addr_a(rx_ram_addr1),
      .addr_b(SW[7:2]),
      .we_a(ENET1_RX_DV), 
      .we_b(1'b0),
      .clk(clk_rx1_25),
      //.q_a, 
      .q_b(readFromRxRam)
   );
   

   LEDnumb LED4(HEX4, readFromRxRam[3:0]);


////////////////////////////           Configration check         ////////////////
   
ConfigCheck ConfigCheck_ins(
.Reset(rst),
.LastSlaveIDPlus1(LastSlaveIDPlus1), 
.AveSlaveDelay(AveSlaveDelay), 
.ConfigOK(ConfigOK)
);
assign LEDG[8] = ConfigOK;
/////////////////////////////////        DELAY CALCULATION    //////////////////////
   
wire clk_100MHz;
wire [15:0] RegLoopDelay;
wire [7:0]  AveTransDelay ;
wire [7:0]  AveLogicDelay ;
wire [7:0]  AveSlaveDelay ;
pll_25to100MHz delay_measure_clock_master
(
   .inclk0(clk_rx1_25),
   .areset(rst),
   .c0(clk_100MHz)
);

DelayCalculator DelayCalculator_ins
(
   .Clk_100MHz(clk_100MHz), 
   .rst(rst), 
   .StartCounting(ENET0_TX_EN), 
   .StopCounting(ENET1_RX_DV), 
   .DelaySum(DelaySum),
   .LastSlaveIDPlus1(LastSlaveIDPlus1),
   //.LastSlaveIDPlus1(SW[13:11]),
   .RegLoopDelay(RegLoopDelay), 
   .AveTransDelay(AveTransDelay), 
   .AveLogicDelay(AveLogicDelay), 
   .AveSlaveDelay(AveSlaveDelay)
);

////  Display all kinds of delay calculation result 
reg   [7:0]readRxRamOrDelay;

always@ (*)
begin
   if(SW[16:14]==3'b001)
      readRxRamOrDelay = DelaySum[7:0];
   else
   if(SW[16:14]==3'b010)
      readRxRamOrDelay = RegLoopDelay[7:0];
   else
   if(SW[16:14]==3'b011)
      readRxRamOrDelay = AveTransDelay;
   else
   if(SW[16:14]==3'b100)
      readRxRamOrDelay = AveLogicDelay;
   else
   if(SW[16:14]==3'b101)
      readRxRamOrDelay = AveSlaveDelay;
   else
      readRxRamOrDelay = readFromRxRam8bit;
end

LEDnumb LED6(HEX6, readRxRamOrDelay[3:0]);
LEDnumb LED7(HEX7, readRxRamOrDelay[7:4]);


//// /////////////////////////////     End of delay calculation   /////////////////////////
   
//////////////////////////////////         MI INTERFACE        ///////////////////////////////
   wire [31:0] command0;
   wire [15:0] command_and0;
   wire [3: 0] comm_addr0;
   wire [15:0] readData0;
   wire [15:0] readDataRam0;
   phyInital phyInital_ins0 (
   
      .clk(CLOCK_50),
      .reset(SW[0]),
      .mdc(mdc),
      .md_inout0(ENET0_MDIO),
      .md_inout1(ENET1_MDIO),
      .command(command0),
      .command_and(command_and0),
      
      .comm_addr(comm_addr0),
      .ram_read_addr(SW[5:2]),
      .iniStart(1'b1),
      .iniEnd(PHYInitEnd),
    //.stateout(LEDR[12:0]),
      .readDataoutRam(readDataRam0)
    //.busy(LEDG[8]),
    //.WCtrlDataStartout(LEDG[7])
      );
   
   phyIniCommand0 pyhIniCommands (
      .clk(CLOCK_50),
      .q(command0),
      .addr(comm_addr0)
      );
   phyIniCommand0_and pyhIniCommands_and (
      .clk(CLOCK_50),
      .q(command_and0),
      .addr(comm_addr0)
      );
      
      wire [15:0]readDataRamOrDelay;
      assign readDataRamOrDelay = SW[1] ? readDataRam0 : RegLoopDelay;
      LEDnumb LED0(HEX0, readDataRamOrDelay[3:0]);
      LEDnumb LED1(HEX1, readDataRamOrDelay[7:4]);
      LEDnumb LED2(HEX2, readDataRamOrDelay[11:8]);
      LEDnumb LED3(HEX3, readDataRamOrDelay[15:12]);
     
//////////////////////////////////         MI INTERFACE  END    ///////////////////////////////
      

endmodule 



  
  
  