
`include "timescale.v"

module fb_txmac (MTxClk, Reset, TxStartFrm, TxUnderRun, DataSoC, NumbSoC, DistSoC, DelaySoC, DelayDistSoC, TxData,
                 LastSlaveIDPlus1, AveSlaveDelay,
                 MTxD, MTxEn, MTxErr, TxDone, TxUsedData, WillTransmit, 
                 StartTxDone, StateIdle, StatePreamble, StateSoC, StateNumb, StateDist, StateDelay, StateDelayDist, StateData, StateCrc, StateFrmCrc,
                 TxRamAddr
                 );

input MTxClk;                   // Transmit clock (from PHY)

input Reset;                    // Reset

input TxStartFrm;               // Transmit packet start frame
input TxUnderRun;               // Transmit packet under-run
input DataSoC;
input NumbSoC;
input DistSoC;
input DelaySoC;
input DelayDistSoC;
input [7:0] LastSlaveIDPlus1;
input [7:0] AveSlaveDelay;
input [7:0] TxData;             // Transmit packet data byte

output [3:0] MTxD;              // Transmit nibble (to PHY)
output MTxEn;                   // Transmit enable (to PHY)
output MTxErr;                  // Transmit error  (to PHY)
output TxDone;                  // Transmit packet done (to RISC)

output TxUsedData;              // Transmit packet used data (to RISC)
output WillTransmit;            // Will transmit (to RxEthMAC)

output StartTxDone;

output StateIdle;
output StatePreamble;
output StateSoC;
output StateNumb;
output [1:0] StateDist;
output StateDelay;
output [1:0] StateDelayDist;
output [1:0] StateData;
output StateCrc;
output StateFrmCrc;
output [7:0]TxRamAddr;

reg [3:0] MTxD;
reg MTxEn;
reg MTxErr;
reg TxDone;
reg TxUsedData;
reg WillTransmit;

reg [3:0] MTxD_d;
reg PacketFinished_q;
reg PacketFinished;
reg RegDataSoC;
reg RegNumbSoC;
reg RegDistSoC;
reg RegDelaySoC;
reg RegDelayDistSoC;

reg [15:0] RegTotalFrmNibbleCnt;

wire MTxClk_n;
wire SlaveEndFrm;
wire TxEndFrm;
wire NumbStateEnd;
wire DistStateEnd;
wire DelayStateEnd;
wire DelayDistStateEnd;

wire [1: 0] StartData;

wire UnderRun;
wire [7:0] Crc;
wire [7:0] FrmCrc;
wire CrcError;
wire FrmCrcError;
wire [15:0] TotalNibCnt;
wire [15:0] NibCnt;
wire PacketFinished_d;
wire CrcStateEnd;
wire PreambleStateEnd;
wire FrmCrcStateEnd;
wire [7:0]TxRamAddr;
wire [3:0]CrcNibCnt;

wire [7:0] SlaveDataNibbleCnt; 
assign SlaveDataNibbleCnt = 8'd4; // assume each slave has 4 nibbles(2bytes) data 

assign StartTxDone        = (StateFrmCrc & FrmCrcStateEnd);
assign UnderRun           = StateData[0] & TxUnderRun ;
assign SlaveEndFrm        = (NibCnt == (SlaveDataNibbleCnt - 1'b1 ) & ( NibCnt != 32'b0 ));
assign TxEndFrm           = (TotalNibCnt  == (RegTotalFrmNibbleCnt - 1'b1)) ;
assign NumbStateEnd       = (TotalNibCnt  == 16'd6 - 16'd1 );
assign DistStateEnd       = (TotalNibCnt  == 16'd6 - 16'd1 );
assign DelayStateEnd      = (TotalNibCnt  == 16'd6 - 16'd1 );
assign DelayDistStateEnd  = (TotalNibCnt  == 16'd6 - 16'd1 );

 
always @ (LastSlaveIDPlus1 or SlaveDataNibbleCnt or Reset)
begin
   if(Reset)
     RegTotalFrmNibbleCnt = 0 ;
   else 
     RegTotalFrmNibbleCnt = ((SlaveDataNibbleCnt + 8'd2 ) * LastSlaveIDPlus1) + 8'd4;
end

// register SoC when receiving the start command
always @ (posedge MTxClk or posedge Reset)
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
  if (TxStartFrm) 
  begin 
     if (DataSoC)
      RegDataSoC  <=  1'b1;
     else
     if (NumbSoC)
      RegNumbSoC  <=  1'b1;
     else
     if (DistSoC)
      RegDistSoC  <=  1'b1;
     else
     if (DelaySoC)
      RegDelaySoC <=  1'b1;
     else
     if (DelayDistSoC)
      RegDelayDistSoC <=  1'b1;
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

// Transmit packet used data
always @ (posedge MTxClk or posedge Reset)
begin
  if(Reset)
    TxUsedData <=  1'b0;
  else
    TxUsedData <=  |StartData;
end


// Transmit packet done
always @ (posedge MTxClk or posedge Reset)
begin
  if(Reset)
    TxDone <=  1'b0;
  else
    begin
      if(TxStartFrm)
        TxDone <=  1'b0;
      else
      if(StartTxDone)
        TxDone <=  1'b1;
    end
end

// Transmit nibble
always @ (*) 
begin
  if(StateNumb | StateDelay)
      MTxD_d[3:0] = 4'b0000;
  else
  if(StateData[0])
      MTxD_d[3:0] = TxData[3:0];                                  // Lower nibbles
  else
  if(StateData[1])
      MTxD_d[3:0] = TxData[7:4];                                  // Higher nibble
  else
  if(StateCrc)
      MTxD_d[3:0] = {~Crc[4], ~Crc[5], ~Crc[6], ~Crc[7]};         // Crc
  else 
  if(StatePreamble)
      MTxD_d[3:0] = 4'b0101;                                    // Preamble 6
  else 
  if (StateFrmCrc)
      MTxD_d[3:0] = {~FrmCrc[4], ~FrmCrc[5], ~FrmCrc[6], ~FrmCrc[7]};
  else
  if(StateSoC)
    begin
       if(RegDataSoC)
         MTxD_d[3:0] = 4'b0111;                                    // DataSoC 7
       else
       if(RegNumbSoC)
         MTxD_d[3:0] = 4'b0110;                                    // NumbSoC 6
       else
       if(RegDistSoC)   
         MTxD_d[3:0] = 4'b0100;                                    // DistSoC 4
       else
       if(RegDelaySoC)   
         MTxD_d[3:0] = 4'b0011;                                    // DelaySoC 3
       else
       if(RegDelayDistSoC)   
         MTxD_d[3:0] = 4'b0010;                                    // DelayDistSoC 2
       else
         MTxD_d[3:0] = 4'b0000; 
    end      
  else
  if(StateDist[0])
      MTxD_d[3:0] = LastSlaveIDPlus1[3:0];
  else
  if(StateDist[1])
      MTxD_d[3:0] = LastSlaveIDPlus1[7:4];
  else
  if(StateDelayDist[0])
      MTxD_d[3:0] = AveSlaveDelay[3:0];
  else
  if(StateDelayDist[1])
      MTxD_d[3:0] = AveSlaveDelay[7:4];
  else
    MTxD_d[3:0] = 4'h0;
end


// Transmit Enable
always @ (posedge MTxClk or posedge Reset)
begin
  if(Reset)
    MTxEn <=  1'b0;
  else
    MTxEn <=  StatePreamble | StateSoC | StateNumb | (|StateDist) |  StateDelay | (|StateDelayDist) |(|StateData) | StateCrc | StateFrmCrc ;
end


// Transmit nibble
always @ (posedge MTxClk or posedge Reset)
begin
  if(Reset)
    MTxD[3:0] <=  4'h0;
  else
    MTxD[3:0] <=  MTxD_d[3:0];
end


// Transmit error
always @ (posedge MTxClk or posedge Reset)
begin
  if(Reset)
    MTxErr <=  1'b0;
  else
    MTxErr <=  UnderRun;
end


// WillTransmit
always @ (posedge MTxClk or posedge Reset)
begin
  if(Reset)
    WillTransmit <=   1'b0;
  else
    WillTransmit <=  StatePreamble | StateSoC | StateNumb | (|StateDist) |  StateDelay | (|StateDelayDist)  | (|StateData) | StateCrc | StateFrmCrc;
end


assign PacketFinished_d = StartTxDone ;


// Packet finished
always @ (posedge MTxClk or posedge Reset)
begin
  if(Reset)
    begin
      PacketFinished <=  1'b0;
      PacketFinished_q  <=  1'b0;
    end
  else
    begin
      PacketFinished <=  PacketFinished_d;
      PacketFinished_q  <=  PacketFinished;
    end
end


// Connecting module Counters
fb_txcounters txcounters1 (.MTxClk(MTxClk), .Reset(Reset),
                            .StateIdle(StateIdle),.StatePreamble(StatePreamble), .StateSoC(StateSoC), 
                            .StateNumb(StateNumb), .StateDist(StateDist), .StateDelay(StateDelay), 
                            .StateDelayDist(StateDelayDist),
                            .StateData(StateData), .StateCrc(StateCrc), .StateFrmCrc(StateFrmCrc),
                            .StartData(StartData),
                            
                            .TotalNibCnt(TotalNibCnt), .NibCnt(NibCnt), .CrcNibCnt(CrcNibCnt),
                            .CrcStateEnd(CrcStateEnd), .PreambleStateEnd(PreambleStateEnd),
                            .FrmCrcStateEnd(FrmCrcStateEnd), .TxRamAddr(TxRamAddr)
                           );


// Connecting module StateM
fb_txstatem txstatem1 (.MTxClk(MTxClk), .Reset(Reset), .NumbStateEnd(NumbStateEnd),.DistStateEnd(DistStateEnd),.DelayStateEnd(DelayStateEnd),
                        .TxStartFrm(TxStartFrm), .SlaveEndFrm(SlaveEndFrm), .TxEndFrm(TxEndFrm), 
                        .RegNumbSoC(RegNumbSoC), .RegDataSoC(RegDataSoC), .RegDistSoC(RegDistSoC), 
                        .RegDelaySoC(RegDelaySoC), .RegDelayDistSoC(RegDelayDistSoC),
                        .CrcStateEnd(CrcStateEnd),.PreambleStateEnd(PreambleStateEnd),
                        .TxUnderRun(TxUnderRun), .UnderRun(UnderRun), .StartTxDone(StartTxDone),
                        
                        .StateIdle(StateIdle), .StatePreamble(StatePreamble),.StateSoC(StateSoC), 
                        .StateNumb(StateNumb), .StateDist(StateDist), .StateDelayDist(StateDelayDist),
                        .StateDelay(StateDelay), .StateData(StateData), .StateCrc(StateCrc), 
                        .StateFrmCrc(StateFrmCrc),
                        
                        .StartData(StartData)
                       );


wire Enable_Crc;
wire [3:0] Data_Crc;
wire Initialize_Crc;

assign Enable_Crc = ~StateCrc;

assign Data_Crc = MTxD_d;

assign Initialize_Crc = StateIdle | StateSoC | CrcStateEnd;


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
