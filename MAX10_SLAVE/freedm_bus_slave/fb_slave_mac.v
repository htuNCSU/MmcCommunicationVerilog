
`include "timescale.v"


module fb_slave_mac (MRxClk, MTxClk, Clk_100MHz, MRxDV, MRxD, Reset, TxData, inSlaveID, inLastSlaveIDPlus1,
                     MTxD_sync2, MTxEn_sync2, RxData, RxValid, RxRamAddr, TxRamAddr, SynchSignal,
                     SlaveID, LastSlaveIDPlus1, LogicDelay, AveSlaveDelay,
                     StateIdle, StatePreamble, StateFFS, StateNumb, StateDist, StateDelay, StateDelayMeas, StateDelayDist, StateSlaveID,
                     StateData, StateSlaveData, StateSlaveCrc, StateFrmCrc
                    );

input         MRxClk;
input         MTxClk;
input         Clk_100MHz;
input         MRxDV;               // from PHY
input   [3:0] MRxD;                // from PHY
input         Reset;
input   [7:0] TxData;              // from memory
input   [7:0] inSlaveID;
input   [7:0] inLastSlaveIDPlus1;
             
output  [3:0] MTxD_sync2;          // to PHY
output        MTxEn_sync2;         // to PHY

output  [7:0] RxData;              // to rx memory
output        RxValid;
output  [7:0] RxRamAddr;           // rx memory address
output  [7:0] TxRamAddr;
output        SynchSignal;
output  [7:0] SlaveID;
output  [7:0] LastSlaveIDPlus1;
output  [7:0] LogicDelay;
output  [7:0] AveSlaveDelay;

output        StateIdle;
output        StatePreamble;
output        StateFFS;
output        StateNumb;
output  [1:0] StateSlaveID;
output        StateDist;
output        StateDelay;
output  [1:0] StateDelayMeas;
output        StateDelayDist;
output        StateData;
output  [1:0] StateSlaveData;
output        StateSlaveCrc;
output        StateFrmCrc;

reg     [3:0] MTxD;                
reg     [3:0] MTxD_sync1;                
reg     [3:0] MTxD_sync2;          // to PHY
reg           MTxEn;                     
reg           MTxEn_sync1;         // synchronized with TX clock 
reg           MTxEn_sync2;         // to PHY


reg     [7:0] RxData;              // to rx memory 
reg           RxValid;
reg     [3:0] MRxD_q1;              // delayed data, at least 4 nibbles are needed for SoC check
reg     [3:0] MRxD_q2;
reg     [3:0] MRxD_q3;
reg     [3:0] MRxD_q4;
reg           RegDataSoC;
reg           RegNumbSoC;
reg           RegDistSoC;
reg           RegDelaySoC;
reg           RegDelayDistSoC;
reg     [7:0] LatchedByte;
reg     [3:0] MTxD_d;
reg     [7:0] SlaveID;
reg     [7:0] NextSlaveID;
reg     [7:0] LastSlaveIDPlus1;
reg    [15:0] SlaveDataStartCnt;    // to register
reg    [15:0] SlaveDataEndCnt;      // to register
reg    [15:0] TotalFrmNibbleCnt;  
reg     [7:0] DelayAhead;
//reg     [7:0] DelaySum;
reg     [7:0] AveSlaveDelay;

reg           RegSlaveCrcError;

wire          Busy;
wire          MRxDEqDataSoC;
wire          MRxDEqNumbSoC;
wire          MRxDEqDistSoC;
wire          MRxDEqDelaySoC;
wire          MRxDEqDelayDistSoC;
wire          MRxDEq5;
wire          SlaveIDStart;
wire          DelayMeasStart;
wire          DistStateEnd;
wire          DelayDistStateEnd;
wire          SlaveDataStart;
wire          SlaveDataEnd;
wire          SlaveCrcEnd; 
wire          IsLastSlave;
wire          DataFrameEnd;
wire          FrmCrcStateEnd;
wire    [7:0] TxRamAddr;
wire    [7:0] RxRamAddr;
wire    [7:0] LogicDelay;

wire    [7:0] SlaveCrc;
wire    [7:0] FrmCrc;
wire   [15:0] TotalRecvNibCnt;
wire   [15:0] TotalSentNibCnt;
wire          GenerateRxValid;
wire          ReceivingSlaveData;
wire          AfterPreamble;

assign Busy               = ~ StateIdle;
assign MRxDEq5            = MRxD == 4'd5;
assign MRxDEqDataSoC      = MRxD == 4'd7;
assign MRxDEqNumbSoC      = MRxD == 4'd6;
assign MRxDEqDistSoC      = MRxD == 4'd4;
assign MRxDEqDelaySoC     = MRxD == 4'd3;
assign MRxDEqDelayDistSoC = MRxD == 4'd2;

assign IsLastSlave        = inSlaveID == inLastSlaveIDPlus1 - 8'h1;
assign SlaveIDStart       = TotalSentNibCnt == 16'd4 - 16'd1;  //numbering frame only has 4pre-2ID-2CRC nibbles
assign DistStateEnd       = TotalSentNibCnt == 16'd6 - 16'd1;  //distribute frame only has 4pre-2ID-2CRC nibbles
assign DelayDistStateEnd  = TotalSentNibCnt == 16'd6 - 16'd1;
assign DelayMeasStart     = TotalSentNibCnt == inSlaveID*16'd2 + 16'd3;  //delay measuring frame has 4pre-2*n DL-2CRC nibbles
assign SlaveDataStart     = TotalSentNibCnt == SlaveDataStartCnt - 16'd1; 
assign SlaveDataEnd       = TotalSentNibCnt == SlaveDataEndCnt   - 16'd1; 
assign DataFrameEnd       = TotalSentNibCnt == TotalFrmNibbleCnt - 16'd1; 
assign ReceivingSlaveData = (TotalRecvNibCnt > SlaveDataStartCnt) & (TotalRecvNibCnt < (SlaveDataEndCnt));
assign AfterPreamble      = TotalRecvNibCnt > 16'd3;

// latch the received data and delay them
// synchronized with MTxClk
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    begin
     MRxD_q1   <=  4'b0;
     MRxD_q2   <=  4'b0;
     MRxD_q3   <=  4'b0;
     MRxD_q4   <=  4'b0;
    end
  else
    begin
     MRxD_q1   <=  MRxD;
     MRxD_q2   <=  MRxD_q1;
     MRxD_q3   <=  MRxD_q2;
     MRxD_q4   <=  MRxD_q3;
    end
end

//latch this frame type
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
  begin
   RegDataSoC      <=  1'b0;
   RegNumbSoC      <=  1'b0;
   RegDistSoC      <=  1'b0;
   RegDelaySoC     <=  1'b0;
   RegDelayDistSoC <=  1'b0;
  end
  else
  if (StatePreamble) 
  begin 
     if (MRxDEqDataSoC)
      RegDataSoC <=  1'b1;
     else
     if (MRxDEqNumbSoC)
      RegNumbSoC <=  1'b1;
     else
     if (MRxDEqDistSoC)
      RegDistSoC <=  1'b1;
     else
     if (MRxDEqDelaySoC)
      RegDelaySoC <=  1'b1;
     else
     if (MRxDEqDelayDistSoC)
      RegDelayDistSoC <= 1'b1;
  end
  else
  if (StateIdle)
  begin
   RegDataSoC      <=  1'b0;
   RegNumbSoC      <=  1'b0;
   RegDistSoC      <=  1'b0;
   RegDelaySoC     <=  1'b0;
   RegDelayDistSoC <=  1'b0;
  end
end


/////////////////////////      Rx State Machine module   /////////////////
fb_slave_statem fb_slave_statem_ins
(
   .MRxClk(MRxClk),
   .Reset(Reset),
   .MRxDV(MRxDV),
   .MRxDEq5(MRxDEq5),
   .MRxDEqDataSoC(MRxDEqDataSoC),
   .MRxDEqNumbSoC(MRxDEqNumbSoC),
   .MRxDEqDistSoC(MRxDEqDistSoC),
   .MRxDEqDelaySoC(MRxDEqDelaySoC),
   .MRxDEqDelayDistSoC(MRxDEqDelayDistSoC),
   .DistStateEnd(DistStateEnd),
   .DelayDistStateEnd(DelayDistStateEnd),
   .SlaveIDStart(SlaveIDStart),
   .DelayMeasStart(DelayMeasStart),
   .SlaveDataStart(SlaveDataStart),
   .SlaveDataEnd(SlaveDataEnd),
   .SlaveCrcEnd(SlaveCrcEnd), 
   .IsLastSlave(IsLastSlave), 
   .DataFrameEnd(DataFrameEnd), 
   .FrmCrcStateEnd(FrmCrcStateEnd),
   
   .StateIdle(StateIdle),
   .StateFFS(StateFFS),
   .StatePreamble(StatePreamble),
   .StateNumb(StateNumb),
   .StateSlaveID(StateSlaveID),
   .StateDist(StateDist),
   .StateDelay(StateDelay),
   .StateDelayMeas(StateDelayMeas),
   .StateDelayDist(StateDelayDist),
   .StateData(StateData),
   .StateSlaveData(StateSlaveData),
   .StateSlaveCrc(StateSlaveCrc), 
   .StateFrmCrc(StateFrmCrc)
 );

///////////////////////      Rx counter module  ///////////////////////
fb_slave_counters fb_slave_counters_ins
(
   .MRxClk(MRxClk),
   .Clk_100MHz(Clk_100MHz),
   .Reset(Reset), 
   .MRxDV(MRxDV), 
   .RxValid(RxValid),
   .MTxEn_TxSync2(MTxEn_sync2),
   .StateIdle(StateIdle), 
   .StatePreamble(StatePreamble), 
   .StateNumb(StateNumb),
   .StateSlaveID(StateSlaveID),
   .StateDist(StateDist),
   .StateDelay(StateDelay),
   .StateDelayMeas(StateDelayMeas),
   .StateDelayDist(StateDelayDist),
   .StateData(StateData), 
   .StateSlaveData(StateSlaveData), 
   .StateSlaveCrc(StateSlaveCrc), 
   .StateFrmCrc(StateFrmCrc),
   
   .TotalSentNibCnt(TotalSentNibCnt),
   .TotalRecvNibCnt(TotalRecvNibCnt), 
   .LogicDelay(LogicDelay), 
   .SlaveCrcEnd(SlaveCrcEnd), 
   .FrmCrcStateEnd(FrmCrcStateEnd), 
   .TxRamAddr(TxRamAddr), 
   .RxRamAddr(RxRamAddr)
);

///////////////////////////////       transmitting part         //////////////////
always @ (*) 
begin
  if(StateData | StateNumb | StateDist | StateDelay | StateDelayDist)
      MTxD_d[3:0] = MRxD_q4;                                           // Lower nibbles
  else
  if(StateSlaveID[0])
      MTxD_d[3:0] = NextSlaveID[3:0];                                  // Lower nibbles
  else
  if(StateSlaveID[1])
      MTxD_d[3:0] = NextSlaveID[7:4];                                  // Lower nibbles
  else
  if(StateDelayMeas[0])
      MTxD_d[3:0] = LogicDelay[3:0];                                  // Lower nibbles
  else
  if(StateDelayMeas[1])
      MTxD_d[3:0] = LogicDelay[7:4];                                  // Lower nibbles
  else
  if(StateSlaveData[0])
      MTxD_d[3:0] = TxData[3:0];                                  // Lower nibbles
  else
  if(StateSlaveData[1])
      MTxD_d[3:0] = TxData[7:4];                                  // Higher nibble
  else
  if(StateSlaveCrc)
      MTxD_d[3:0] = {~SlaveCrc[4], ~SlaveCrc[5], ~SlaveCrc[6], ~SlaveCrc[7]};         // SlaveCrc
  else
  if (StateFrmCrc)
      MTxD_d[3:0] = {~FrmCrc[4], ~FrmCrc[5], ~FrmCrc[6], ~FrmCrc[7]};     
  else
    MTxD_d[3:0] = 4'h0;
end


// Transmit Enable
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    MTxEn <=  1'b0;
  else
    MTxEn <= StateNumb| (|StateSlaveID) | StateDist |StateDelay | (|StateDelayMeas) | StateDelayDist|  StateData | (|StateSlaveData) | StateSlaveCrc | StateFrmCrc ;
end


// Transmit nibble
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    MTxD[3:0] <=  4'h0;
  else
    MTxD[3:0] <=  MTxD_d[3:0];
end

// Transmit enable synchronized with TX clock
always @ (posedge MTxClk or posedge Reset)
begin
  if(Reset)
  begin
   MTxEn_sync1    <=  1'b0; 
   MTxEn_sync2    <=  1'b0;
  end
  else
  begin
    MTxEn_sync1    <= MTxEn;
    MTxEn_sync2    <= MTxEn_sync1;
  end
end

// Transmit nibble synchronized with TX clock
always @ (posedge MTxClk or posedge Reset)
begin
  if(Reset)
  begin
    MTxD_sync1 <=  4'h0;
    MTxD_sync2 <=  4'h0;
  end
  else
  begin
    MTxD_sync1 <=  MTxD;
    MTxD_sync2 <=  MTxD_sync1;
  end
end



// Receive information based on different frame types
assign GenerateRxValid = (ReceivingSlaveData & TotalRecvNibCnt[0] & (StateData | (|StateSlaveData))) | (RegNumbSoC & (TotalRecvNibCnt == 16'd5)) | (RegDistSoC & (TotalRecvNibCnt == 16'd5)) |  (RegDelaySoC & (TotalRecvNibCnt == 16'd5)) | (RegDelayDistSoC & (TotalRecvNibCnt == 16'd5))  ;
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    begin
      LatchedByte[7:0]   <=  8'd0;
      RxData[7:0]        <=  8'd0;
      SlaveID            <=  8'd0;
      NextSlaveID        <=  8'd0;
      LastSlaveIDPlus1   <=  8'd0;
      DelayAhead         <=  8'd0;
      AveSlaveDelay      <=  8'd0;
    end
  else
    begin
      // Latched byte
      LatchedByte[7:0]   <=  {MRxD[3:0], LatchedByte[7:4]};

      if(GenerateRxValid)  // process the received data based different frame type
        begin
         if (RegNumbSoC)
           begin
            SlaveID           <=  LatchedByte[7:0];          // receiving slave ID
            NextSlaveID       <=  LatchedByte[7:0] + 8'b1;   // preparing next slave ID
           end
         else
         if (RegDistSoC)
            LastSlaveIDPlus1  <=  LatchedByte[7:0];          //receiving the last slave ID
         else
         if (RegDelaySoC)
            DelayAhead        <=  LatchedByte[7:0];          //receiving the accumulated delay
         else
         if (RegDelayDistSoC)
            AveSlaveDelay     <=  LatchedByte[7:0];          //receiving the average delay of one slave
         else
            RxData[7:0]       <=  LatchedByte[7:0];          // Data goes through only in data state  
        end
      else
        // Delaying data to be valid for two cycles.
        // Zero when not active.
        RxData[7:0] <=  8'h0;         // Output data byte
  end
end

//// calculate the data position based on the slave ID received   (change inSlaveID to SlaveID in the final implementation)
always @ (inSlaveID or Reset)
begin
  if(Reset)
    begin
      SlaveDataStartCnt   =  16'b0;
      SlaveDataEndCnt     =  16'b0;
    end
  else
    begin
      SlaveDataStartCnt   =  16'd4 + (4'd6 * inSlaveID);
      SlaveDataEndCnt     =  SlaveDataStartCnt + 16'd4;
    end
end

//// calculate the total frame length based on the slave numbers  (change inLastSlaveIDPlus1 to LastSlaveIDPlus1 in the final implementation)
always @ (inLastSlaveIDPlus1 or Reset)
begin
  if(Reset)
    begin
      TotalFrmNibbleCnt   =  16'b0;
    end
  else
    begin
      TotalFrmNibbleCnt   =  16'd4 + (4'd6 * inLastSlaveIDPlus1);
    end
end
/*
//  calculate the sum of delay 
always @ (DelayAhead or LogicDelay or Reset)
begin
  if(Reset)
    begin
      DelaySum   =  8'b0;
    end
  else
    begin
      DelaySum   =  DelayAhead + LogicDelay;
    end
end
*/
//delay the rxvalid signal to fit the data receiving
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    begin
      RxValid   <=  1'b0;
    end
  else
    begin
     if (~RegNumbSoC & ~RegDistSoC & ~RegDelaySoC & ~RegDelayDistSoC)
        RxValid   <=  GenerateRxValid ;
    end
end

wire EnableSlaveCrc;
wire [3:0] DataSlaveCrc;
wire InitializeSlaveCrc;

assign EnableSlaveCrc = ~StateSlaveCrc;
assign DataSlaveCrc = MRxD_q4;
assign InitializeSlaveCrc = StateIdle | StateData | SlaveCrcEnd;

// Connecting slave data Crc
fb_crc slavecrc 
(
   .Clk(MRxClk), 
   .Reset(Reset), 
   .Data(DataSlaveCrc), 
   .Enable(EnableSlaveCrc), 
   .Initialize(InitializeSlaveCrc), 
   .Crc(SlaveCrc)
);

// slave data crc check
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    RegSlaveCrcError   <=  1'b0;
  else
  if (StateSlaveCrc)
    begin
     if ( {~SlaveCrc[4], ~SlaveCrc[5], ~SlaveCrc[6], ~SlaveCrc[7]} != MRxD_q4)
        RegSlaveCrcError   <=  1'b1 ;
    end
  else
  if (StateIdle)
    RegSlaveCrcError    <= 1'b0;
end           
           
// Connecting frame data Crc
wire Enable_FrmCrc;
wire [3:0] Data_FrmCrc;
wire Initialize_FrmCrc;

assign Enable_FrmCrc = ~StateFrmCrc;
assign Data_FrmCrc = MTxD_d;
assign Initialize_FrmCrc = StateIdle | StatePreamble;

// Connecting module Crc
fb_crc framecrc 
(
   .Clk(MRxClk), 
   .Reset(Reset), 
   .Data(Data_FrmCrc), 
   .Enable(Enable_FrmCrc), 
   .Initialize(Initialize_FrmCrc), 
   .Crc(FrmCrc)
);


SynchModule SynchModule_ins
(
 .Clk_100MHz(Clk_100MHz), 
 .Reset(Reset), 
 .Busy(Busy), 
 .LastSlaveIDPlus1(LastSlaveIDPlus1), 
 .SlaveID(SlaveID), 
 .AveSlaveDelay(AveSlaveDelay), 
 .SynchSignal(SynchSignal)
);



endmodule
