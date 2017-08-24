

module PHYctrl_Slave (
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
   assign ENET0_MDC = mdc;
   assign ENET1_MDC = mdc;
   
   assign ENET0_RESET_N = 1'b1;
   assign ENET1_RESET_N = 1'b1;

   
   assign GPIO[0] = ENET0_TX_CLK;
   assign GPIO[1] = ENET0_TX_DATA[1];
   assign GPIO[2] = ENET0_TX_EN;
   assign GPIO[3] = ENET1_RX_DV;
   
   assign ENET1_TX_EN = SW[9];
   
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
         if(StateIdle)
               rx_ram_addr1 <= 6'b0;
         else
         if (ENET1_RX_DV)begin
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
   
wire Clk_100MHz;
pll_25to100MHz delay_measure_clock
(
   .inclk0(clk_rx1_25),
   .areset(rst),
   .c0(Clk_100MHz)
);
   
   LEDnumb LED4(HEX4, readFromRxRam[3:0]);


   wire [7:0]LastSlaveIDPlus1;
   wire [7:0]SlaveID;
   wire [7:0]LogicDelay;
   wire [7:0]AveSlaveDelay;
   wire [3:0]readSlaveID;
   
   wire StateIdle;
   
   fb_slave_mac fb_slave_mac_ins
 (
      .MRxClk(clk_rx1_25), 
      .MTxClk(clk_tx0_25), 
      .Clk_100MHz(Clk_100MHz),
      .MRxDV(ENET1_RX_DV), 
      .MRxD(ENET1_RX_DATA), 
      .Reset(rst), 
      .TxData(TxData),
      .inSlaveID(8'd0), 
      .inLastSlaveIDPlus1(8'd2), 
      
      .MTxD_sync2(ENET0_TX_DATA), 
      .MTxEn_sync2(ENET0_TX_EN), 
      .RxData(RxData), 
      .RxValid(RxValid),
      .RxRamAddr(RxRamAddr),
      .TxRamAddr(TxRamAddr),
      .SynchSignal(GPIO[9]),
      .SlaveID(SlaveID),
      .LastSlaveIDPlus1(LastSlaveIDPlus1),
      .LogicDelay(LogicDelay),
      .AveSlaveDelay(AveSlaveDelay),
    //.FrmCrcError
    //.CrcError, 
      .StateIdle(StateIdle), 
      .StateFFS(LEDR[1]), 
      .StatePreamble(LEDR[2]),
      .StateNumb(LEDR[3]),
      .StateSlaveID(LEDR[5:4]),
      .StateDist(LEDR[6]),
      .StateDelay(LEDR[7]),
      .StateDelayMeas(LEDR[9:8]),
      .StateDelayDist(LEDR[11]), 
      .StateData(LEDR[12]), 
      .StateSlaveData(LEDR[14:13]), 
      .StateSlaveCrc(LEDR[15]), 
      .StateFrmCrc(LEDR[16])
);
   assign readSlaveID = SW[1]?LastSlaveIDPlus1[3:0]:SlaveID[3:0];
   
reg   [7:0]readRxRamOrDelay;

always@ (*)
begin
   if(SW[16:14]==3'b001)
      readRxRamOrDelay = LogicDelay;
   else
   if(SW[16:14]==3'b010)
      readRxRamOrDelay = 8'b0;
   else
   if(SW[16:14]==3'b011)
      readRxRamOrDelay = 8'b0;
   else
   if(SW[16:14]==3'b100)
      readRxRamOrDelay = 8'b0;
   else
   if(SW[16:14]==3'b101)
      readRxRamOrDelay = AveSlaveDelay;
   else
      readRxRamOrDelay = readFromRxRam8bit;
end

   LEDnumb LED5(HEX5, readSlaveID);
   LEDnumb LED6(HEX6, readRxRamOrDelay[3:0]);
   LEDnumb LED7(HEX7, readRxRamOrDelay[7:4]);
   
//////////////////////////////////         MI INTERFACE FOR PORT 0 ///////////////////////////////
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
      .iniEnd(LEDG[0]),
    //.stateout(LEDR[12:0]),
      .readDataoutRam(readDataRam0),
      .busy(LEDG[8]),
      .WCtrlDataStartout(LEDG[7])
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

      LEDnumb LED0(HEX0, readDataRam0[3:0]);
      LEDnumb LED1(HEX1, readDataRam0[7:4]);
      LEDnumb LED2(HEX2, readDataRam0[11:8]);
      LEDnumb LED3(HEX3, readDataRam0[15:12]);
     


      
      
endmodule 



  
  
  