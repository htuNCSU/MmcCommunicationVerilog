
`include "timescale.v"


module fb_slave_mac (MRxClk, MRxDV, MRxD, Reset, TxData,
					 SlaveDataStartCnt, SlaveDataEndCnt, LastSlave, TotalFrmNibbleCnt,
					 MTxD, MTxEn, RxData, RxValid, RxRamAddr, TxRamAddr
                     CrcError, 
					 StateIdle, StatePreamble, StateFFS, StateData, StateSlaveData, StateSlaveCrc, StateFrmCrc
                    );

input         MRxClk;
input         MRxDV;               // from PHY
input   [3:0] MRxD;                // from PHY
input         Reset;
input   [7:0] TxData;              // from memory
input         SlaveDataStartCnt;   // from register
input         SlaveDataEndCnt;     // from register
input         LastSlave;           // from register
input         TotalFrmNibbleCnt;   // from register(from Preamble to CRCn, no frame CRC)

output  [3:0] MTxD;                // to PHY
output        MTxEn;               // to PHY
output  [7:0] RxData;              // to rx memory
output        RxValid;

output        CrcError;
output  [7:0] TxRamAddr;           // tx memory address
output  [7:0] RxRamAddr;           // rx memory address

output        StateIdle;
output        StatePreamble;
output        StateFFS;
output        StateData;
output        StateSlaveData;
output        StateSlaveCrc;
output        StateFrmCrc;

reg     [7:0] RxData;               // to rx memory
reg           RxValid;
reg     [3:0] MRxD_q1;              // delayed data, at least 4 nibbles are needed for SoC check
reg     [3:0] MRxD_q2;
reg     [3:0] MRxD_q3;
reg     [3:0] MRxD_q4;

wire          MRxDEqDataSoC;
wire          MRxDEq5;
wire 		  SlaveDataStart;
wire          SlaveDataEnd;
wire          SlaveCrcEnd; 
wire          LastSlave;
wire          DataFrameEnd;
wire          FrmCrcStateEnd;
wire    [7:0] TxRamAddr;
wire    [7:0] RxRamAddr;
wire          SlaveByteCntEq0;

wire          StartIdle;
wire    [7:0] Crc;
wire          Enable_Crc;
wire          Initialize_Crc;
wire    [3:0] Data_Crc;
wire   [15:0] TotalNibCnt;
wire          GenerateRxValid;
wire          IncrementTotalNibCnt;

assign MRxDEq5 = MRxD == 4'h5;
assign MRxDEqDataSoC = MRxD == 4'h7;
assign SlaveDataStart = TotalNibCnt == SlaveDataStartCnt; 
assign SlaveDataEnd   = TotalNibCnt == SlaveDataEndCnt; 
assign DataFrameEnd   = TotalNibCnt == TotalFrmNibbleCnt; 


// latch the received data and delay them
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    begin
      MRxD_q1   <=  1'b0;
	  MRxD_q2   <=  1'b0;
	  MRxD_q3   <=  1'b0;
	  MRxD_q4   <=  1'b0;
    end
  else
    begin
      MRxD_q1   <=  MRxD;
	  MRxD_q2   <=  MRxD_q1;
	  MRxD_q3   <=  MRxD_q2;
	  MRxD_q4   <=  MRxD_q3;
    end
end



/////////////////////////      Rx State Machine module   /////////////////
fb_slave_statem fb_slave_statem_ins
(
   .MRxClk(MRxClk),
   .Reset(Reset),
   .MRxDV(MRxDV),
   .MRxDEqDataSoC(MRxDEqDataSoC),
   .MRxDEq5(MRxDEq5),
   .SlaveDataStart(SlaveDataStart)
   .SlaveDataEndSlaveDataEnd
   .SlaveCrcEnd(SlaveCrcEnd), 
   .LastSlave(LastSlave), 
   .DataFrameEnd(DataFrameEnd), 
   .FrmCrcStateEnd(FrmCrcStateEnd),
   
   .StateIdle(StateIdle),
   .StateFFS(StateFFS),
   .StatePreamble(StatePreamble),
   .StateData(StateData),
   .StateSlaveData(StateSlaveData),
   .StateSlaveCrc(StateSlaveCrc), 
   .StateFrmCrc(StateFrmCrc),
   .StartIdle(StartIdle)
 );

///////////////////////      Rx counter module  ///////////////////////
fb_slave_counters fb_slave_counters_ins
(
   .MRxClk(MRxClk), 
   .Reset(Reset), 
   .MRxDEqDataSoC(MRxDEqDataSoC),
   .StateIdle(StateIdle), 
   .StatePreamble(StatePreamble), 
   .StateData(StateData), 
   .StateSlaveData(StateSlaveData), 
   .StateSlaveCrc(StateSlaveCrc), 
   .StateFrmCrc(StateFrmCrc),

   .TotalNibCnt(TotalNibCnt), 
   //.NibCnt(), 
   .SlaveCrcEnd(SlaveCrcEnd), 
   .FrmCrcStateEnd(FrmCrcStateEnd), 
   .TxRamAddr(TxRamAddr), 
   .RxRamAddr(RxRamAddr),
   .SlaveByteCntEq0(SlaveByteCntEq0)
   .IncrementTotalNibCnt(IncrementTotalNibCnt)
);

///////////////////////////////       transmitting part         //////////////////
always @ (StateData or StateSlaveData or StateSlaveCrc or StateFrmCrc or MRxD_q4 or TxData or Crc or FrmCrc) 
begin
  if(StateData)
      MTxD_d[3:0] = MRxD_q4;                                      // Lower nibbles
  else
  if(StateSlaveData[0])
      MTxD_d[3:0] = TxData[3:0];                                  // Lower nibbles
  else
  if(StateSlaveData[1])
      MTxD_d[3:0] = TxData[7:4];                                  // Higher nibble
  else
  if(StateSlaveCrc)
      MTxD_d[3:0] = {~Crc[4], ~Crc[5], ~Crc[6], ~Crc[7]};         // Crc
  else
  if (StateFrmCrc)
      MTxD_d[3:0] = {~FrmCrc[4], ~FrmCrc[5], ~FrmCrc[6], ~FrmCrc[7]};     
  else
    MTxD_d[3:0] = 4'h0;
end


// Transmit Enable
always @ (posedge MTxClk or posedge Reset)
begin
  if(Reset)
    MTxEn <=  1'b0;
  else
    MTxEn <= StateData | (|StateSlaveData) | StateSlaveCrc | StateFrmCrc ;
end


// Transmit nibble
always @ (posedge MTxClk or posedge Reset)
begin
  if(Reset)
    MTxD[3:0] <=  4'h0;
  else
    MTxD[3:0] <=  MTxD_d[3:0];
end

///////////////////////////////  end of transmitting part         //////////////////

   
// 
/*
assign Enable_Crc = MRxDV & (|StateData & ~ByteCntMaxFrame);
assign Initialize_Crc = StateSFD | DlyCrcEn & (|DlyCrcCnt[3:0]) &
                        DlyCrcCnt[3:0] < 4'h9;

assign Data_Crc[0] = MRxD[3];
assign Data_Crc[1] = MRxD[2];
assign Data_Crc[2] = MRxD[1];
assign Data_Crc[3] = MRxD[0];


// Connecting module Crc
eth_crc crcrx
  (.Clk(MRxClk),
   .Reset(Reset),
   .Data(Data_Crc),
   .Enable(Enable_Crc),
   .Initialize(Initialize_Crc), 
   .Crc(Crc),
   .CrcError(CrcError)
   );
*/

// Output byte stream
assign GenerateRxValid = StateSlaveData[0] & ~SlaveByteCntEq0;
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    begin
      LatchedByte[7:0]   <=  8'h0;
      RxData[7:0]        <=  8'h0;
    end
  else
    begin
      // Latched byte
      LatchedByte[7:0]   <=  {MRxD[3:0], LatchedByte[7:4]};

      if(GenerateRxValid)
        // Data goes through only in data state 
        RxData[7:0]    <=  LatchedByte[7:0] & {8{|StateData}};
      else
        // Delaying data to be valid for two cycles.
        // Zero when not active.
        RxData[7:0] <=  8'h0;         // Output data byte
    end
end

always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    begin
      RxValid   <=  1'b0;
    end
  else
    begin
      RxValid   <=  GenerateRxValid ;
    end
end


wire Enable_Crc;
wire [3:0] Data_Crc;
wire Initialize_Crc;

assign Enable_Crc = ~StateSlaveCrc;
assign Data_Crc = MTxD_d;
assign Initialize_Crc = StateIdle | StateData | EndCrcState;

// Connecting module Crc
fb_crc slavecrc (.Clk(MTxClk), .Reset(Reset), .Data(Data_Crc), .Enable(Enable_Crc), .Initialize(Initialize_Crc), 
               .Crc(Crc), .CrcError(CrcError)
              );
			  
			  
wire Enable_FrmCrc;
wire [3:0] Data_FrmCrc;
wire Initialize_FrmCrc;

assign Enable_FrmCrc = ~StateFrmCrc;
assign Data_FrmCrc = MTxD_d;
assign Initialize_FrmCrc = StateIdle;

// Connecting module Crc
fb_crc framecrc (.Clk(MTxClk), .Reset(Reset), .Data(Data_FrmCrc), .Enable(Enable_FrmCrc), .Initialize(Initialize_FrmCrc), 
               .Crc(FrmCrc), .CrcError(FrmCrcError)
              );

endmodule
