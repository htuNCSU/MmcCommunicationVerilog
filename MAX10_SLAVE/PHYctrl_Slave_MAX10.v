

module PHYctrl_Slave_MAX10 (
   input         CLOCK_50_MAX10,
   input         CLOCK_25_MAX10,
   input  [3: 0] USER_PB,
   
   output [4: 0] USER_LED,
   output  [1:0] PMODA_IO,
   output        ENET_MDC,
   inout         ENET_MDIO,
   
   // Ethernet A
   output        ENET0_RESET_N,
   
   output        ENET0_GTX_CLK,
   input         ENET0_TX_CLK,
   input         ENET0_RX_CLK,
   input  [3: 0] ENET0_RX_DATA,
   input         ENET0_RX_DV,
   input         ENET0_LED_LINK100,

   output [3: 0] ENET0_TX_DATA,
   output        ENET0_TX_EN,
   output        ENET0_TX_ER,
   // Ethernet 1
   output        ENET1_GTX_CLK,
   output        ENET1_RESET_N,
   
   input         ENET1_TX_CLK,
   input         ENET1_RX_CLK,
   input  [3: 0] ENET1_RX_DATA,
   input         ENET1_RX_DV,
   input         ENET1_LED_LINK100,
      
   output [3: 0] ENET1_TX_DATA,
   output        ENET1_TX_EN
);
   
   
   wire rst;
   
   assign rst = ~USER_PB[3];
   
   assign ENET0_RESET_N = USER_PB[3];
   assign ENET1_RESET_N = USER_PB[3];
   
   wire clk_tx0_25;
   wire clk_tx1_25;
   wire clk_rx0_25;
   wire clk_rx1_25;
   assign clk_tx0_25 = ENET0_TX_CLK;
   assign clk_tx1_25 = ENET1_TX_CLK;
   assign clk_rx0_25 = ENET0_RX_CLK;
   assign clk_rx1_25 = ENET1_RX_CLK;
   
 
///////////////////////////////////////   transmitter mac  /////////////////////////////
 
   wire [7:0] TxRamAddr;
   wire [7:0] TxData;
   
   //dual port ram for tx, a port for write from higher level, b port for read from txmac
   tx_dual_port_ram_8bit tx_dual_port_ram_8bit_ins( 
    //.data_a, 
      .data_b(TxData),
    //.addr_a, 
      .addr_b(TxRamAddr),
    //.we_a, 
      .we_b(1'b0), 
      .clk(clk_rx1_25),
    //.q_a, 
      .q_b(TxData)
     );
     
////////////////////////////////////       receiver mac              /////////////////////////////
   wire [7:0]RxRamAddr;
   wire [7:0]RxData;
   wire RxValid;


   wire [7:0]readFromRxRam8bit;
   //dual port ram for rx, a port for write from rxmac, b port for read from higher level
   rx_dual_port_ram_8bit rx_dual_port_ram_8bit_ins(
   
      .data_a(RxData), 
      //.data_b,
      .addr_a(RxRamAddr),
    //.addr_b(SW[7:2]),
      .we_a(RxValid), 
      .we_b(1'b0),
      .clk(clk_rx1_25),
      //.q_a, 
      .q_b(readFromRxRam8bit)
   );
   
     
   reg [5:0]rx_ram_addr1;
   always @ (posedge clk_rx1_25 )
   begin
         if (rst) begin
               rx_ram_addr1 <= 6'b0;
         end else if (ENET1_RX_DV)begin
               if (rx_ram_addr1 < 6'b111110 )
                   rx_ram_addr1 <= rx_ram_addr1 + 1'b1; 
         end
   end
   
   wire [3:0]readFromRxRam;
   rx_data_ram rx_data_ram_ins(
   
      .data_a(ENET1_RX_DATA), 
      //.data_b,
      .addr_a(rx_ram_addr1),
     // .addr_b(SW[7:2]),
      .we_a(ENET1_RX_DV), 
      .we_b(1'b0),
      .clk(clk_rx1_25),
      //.q_a, 
      .q_b(readFromRxRam)
   );
   
   
// generatioon of 100MHz clock
   wire Clk_100MHz;
   pll_25to100MHz delay_measure_clock
(
   .inclk0(CLOCK_25_MAX10),
   .areset(rst),
   .c0(Clk_100MHz)
);

   wire [7:0]LastSlaveIDPlus1;
   wire [7:0]SlaveID;
   wire [3:0]readSlaveID;
   wire [7:0]LogicDelay;
   wire [7:0]AveSlaveDelay;
   
   fb_slave_mac fb_slave_mac_ins
 (
      .MRxClk(clk_rx1_25), 
      .MTxClk(clk_tx0_25), 
      .Clk_100MHz(Clk_100MHz),
      .MRxDV(ENET1_RX_DV), 
      .MRxD(ENET1_RX_DATA), 
      .Reset(rst), 
      .TxData(TxData),
      .inSlaveID(8'd1), 
      .inLastSlaveIDPlus1(8'd2), 
      
      .MTxD_sync2(ENET0_TX_DATA), 
      .MTxEn_sync2(ENET0_TX_EN), 
      .RxData(RxData), 
      .RxValid(RxValid),
      .RxRamAddr(RxRamAddr),
      .TxRamAddr(TxRamAddr),
      .SynchSignal(PMODA_IO[0]),
      .SlaveID(SlaveID),
      .LastSlaveIDPlus1(LastSlaveIDPlus1),
      .LogicDelay(LogicDelay),
      .AveSlaveDelay(AveSlaveDelay)
    /*.FrmCrcError
      .CrcError, 
      .StateIdle, 
      .StateFFS,
      .StatePreamble,
      .StateNumb,
      .StateSlaveID,
      .StateDist,
      .StateDelay,
      .StateDelayMeas,
      .StateDelayDist,
      .StateData, 
      .StateSlaveData, 
      .StateSlaveCrc, 
      .StateFrmCrc*/
);
   assign readSlaveID = USER_PB[1]?LastSlaveIDPlus1[1:0]:SlaveID[1:0];
   assign USER_LED[1:0] = readSlaveID[1:0];
   
//////////////////////////////////         MI INTERFACE FOR PORT 0 ///////////////////////////////
   wire [31:0] command0;
   wire [15:0] command_and0;
   wire [3: 0] comm_addr0;
   wire [15:0] readData0;
   wire [15:0] readDataRam0;
   phyInital phyInital_ins0 (
   
      .clk(CLOCK_50_MAX10),
      .reset(~USER_PB[0]),
      .mdc(ENET_MDC),
      .md_inout(ENET_MDIO),
      .command(command0),
      .command_and(command_and0),
      
      .comm_addr(comm_addr0),
    //.ram_read_addr(USER_PB[3:0]),
      .iniStart(1'b1),
    //.iniEnd(USER_LED[0]),
    //.stateout(LEDR[12:0]),
      .readDataoutRam(readDataRam0)
    //.busy(USER_LED[1]),
    //.WCtrlDataStartout(USER_LED[2])
      );
   
   phyIniCommand0 pyhIniCommands (
      .clk(CLOCK_50_MAX10),
      .q(command0),
      .addr(comm_addr0)
      );
   phyIniCommand0_and pyhIniCommands_and (
      .clk(CLOCK_50_MAX10),
      .q(command_and0),
      .addr(comm_addr0)
      );
      
      assign USER_LED[3] =   ENET0_LED_LINK100;
      assign USER_LED[4] =   ENET1_LED_LINK100;
      

///////////////////////////////////////////////////end of MI INTERFACE FOR PORT 1 ///////////////////////////////
      
      
endmodule 



  
  
  