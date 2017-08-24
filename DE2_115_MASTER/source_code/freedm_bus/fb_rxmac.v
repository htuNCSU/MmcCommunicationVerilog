
`include "timescale.v"


module fb_rxmac     (MRxClk, MRxDV, MRxD, Reset, inLastSlaveIDPlus1,
                     RxData, RxValid, RxRamAddr, LastSlaveIDPlus1, DelaySum,
                     NumbFrameReceived, DistFrameReceived, DelayFrameReceived, DataFrameReceived, DelayDistFrameReceived,
                     StateIdle, StateFFS, StatePreamble, StateNumb, StateDist, StateDelay, StateData, StateFrmCrc,debug
                    );

input         MRxClk;
input         MRxDV;
input   [3:0] MRxD;
input         Reset;
input   [7:0] inLastSlaveIDPlus1;

output  [7:0] RxData;
output        RxValid;
output  [7:0] RxRamAddr;

output  [7:0] LastSlaveIDPlus1;
output [15:0] DelaySum;
output        NumbFrameReceived;      //finishing receiving numbering frame 
output        DistFrameReceived;      //finishing receiving distribute frame
output        DelayFrameReceived;     //finishing receiving delay frame
output        DataFrameReceived;      //finishing receiving data frame
output        DelayDistFrameReceived; //finishing receiving data frame

output        StateIdle;
output        StateFFS;
output        StatePreamble;
output  [1:0] StateNumb;
output  [1:0] StateDist;
output  [1:0] StateDelay;
output  [1:0] StateData;
output        StateFrmCrc;

output        debug;
reg           debug;
reg     [7:0] RxData;
reg           RxValid;


reg           RegNumbSoC;             //denote this is a numbering frame
reg           RegDistSoC;             //denote this is a distribute frame
reg           RegDelaySoC;            //denote this is a delay frame
reg           RegDelayDistSoC;             //denote this is a delay dist frame
reg           RegDataSoC;             //denote this is a data frame
reg           NumbFrameReceived;      //finishing receiving numbering frame 
reg           DistFrameReceived;      //finishing receiving distribute frame
reg           DelayFrameReceived;     //finishing receiving delay frame
reg           DataFrameReceived;      //finishing receiving data frame
reg           DelayDistFrameReceived; //finishing receiving data frame

reg     [7:0] LatchedByte;
reg     [7:0] LastSlaveIDPlus1;
reg    [15:0] DelaySum;
reg    [15:0] DelaySumCnt;
reg           RegFrmCrcError;
reg   [15:0]  RegTotalFrmNibbleCnt;

wire  [7:0]   FrmCrc;
wire          TotalRecvNibCntEq0;
wire  [15:0]  TotalRecvNibCnt;
wire  [7: 0]  RxRamAddr;
wire          DelayFrameEnd;
wire          DataFrameEnd;
wire          FrmCrcStateEnd;
wire  [3:0]   FrmCrcNibCnt;
wire  [7: 0]  SlaveDataNibbleCnt;

wire          MRxDEq5;
wire          MRxDEqNumbSoC;
wire          MRxDEqDataSoC;
wire          MRxDEqDistSoC;
wire          MRxDEqDelaySoC;
wire          MRxDEqDelayDistSoC;
wire          GreatEq5thNibble;
wire          BeforeFrameCrc;
wire          BeforeFrmCrcAtDelayFrm;
wire    [7:0] Crc;
wire          Enable_Crc;
wire          Initialize_Crc;
wire    [3:0] Data_Crc;

wire          GenerateRxValid;

assign SlaveDataNibbleCnt = 8'd4;

assign MRxDEq5 = MRxD == 4'd5;
assign MRxDEqDelayDistSoC  = MRxD == 4'd2;
assign MRxDEqDelaySoC = MRxD == 4'd3;
assign MRxDEqDistSoC  = MRxD == 4'd4;
assign MRxDEqNumbSoC  = MRxD == 4'd6;
assign MRxDEqDataSoC  = MRxD == 4'd7;
assign DelayFrameEnd  = TotalRecvNibCnt == 15'd4 + 15'd2*inLastSlaveIDPlus1 - 16'd1;
assign DataFrameEnd   = TotalRecvNibCnt == RegTotalFrmNibbleCnt - 16'd1;
assign GreatEq5thNibble = TotalRecvNibCnt > 16'd4;
assign BeforeFrameCrc = TotalRecvNibCnt <= RegTotalFrmNibbleCnt;
assign BeforeFrmCrcAtDelayFrm = TotalRecvNibCnt <= 15'd4 + 15'd2*inLastSlaveIDPlus1;


fb_rxcounters fb_rxcounters_ins(
   .MRxClk(MRxClk),
   .Reset(Reset),
   .MRxDV(MRxDV), 
   .RxValid(RxValid),
   .StateIdle(StateIdle), 
   .StateFFS(StateFFS), 
   .StatePreamble(StatePreamble), 
   .StateData(StateData),
   .StateFrmCrc(StateFrmCrc),
   .MRxDEqDataSoC(MRxDEqDataSoC),
   .TotalRecvNibCntEq0(TotalRecvNibCntEq0),
   .TotalRecvNibCnt(TotalRecvNibCnt),
   .RxRamAddr(RxRamAddr),
   .FrmCrcNibCnt(FrmCrcNibCnt),
   .FrmCrcStateEnd(FrmCrcStateEnd)
   );
   
// Rx State Machine module
fb_rxstatem rxstatem_ins
  (.MRxClk(MRxClk),
   .Reset(Reset),
   .MRxDV(MRxDV),
   .MRxDEqDataSoC(MRxDEqDataSoC),
   .MRxDEqNumbSoC(MRxDEqNumbSoC),
   .MRxDEqDistSoC(MRxDEqDistSoC),
   .MRxDEqDelaySoC(MRxDEqDelaySoC),
   .MRxDEqDelayDistSoC(MRxDEqDelayDistSoC),
   .MRxDEq5(MRxDEq5),
   .DelayFrameEnd(DelayFrameEnd),
   .DataFrameEnd(DataFrameEnd),
   .FrmCrcStateEnd(FrmCrcStateEnd),
   
   .StateIdle(StateIdle),
   .StateFFS(StateFFS),
   .StatePreamble(StatePreamble),
   .StateNumb(StateNumb),
   .StateDist(StateDist),
   .StateDelay(StateDelay),
   .StateData(StateData),
   .StateFrmCrc(StateFrmCrc)
   );

always @ (LastSlaveIDPlus1 or SlaveDataNibbleCnt or Reset)
begin
   if(Reset)
     RegTotalFrmNibbleCnt = 0 ;
   else 
     RegTotalFrmNibbleCnt = ((SlaveDataNibbleCnt + 8'd2 ) * 8'd2) + 8'd4;//LastSlaveIDPlus1
end

always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
  begin
      NumbFrameReceived      <= 1'b0 ;
      DistFrameReceived      <= 1'b0 ;
      DelayFrameReceived     <= 1'b0 ;
      DataFrameReceived      <= 1'b0 ;
      DelayDistFrameReceived <= 1'b0 ;
  end
  else
  if (StateFrmCrc & FrmCrcStateEnd) 
  begin 
     
     if (RegNumbSoC)
      NumbFrameReceived <=  1'b1;
     else
     if (RegDistSoC)
      DistFrameReceived <=  1'b1;
     else 
     if (RegDelaySoC)
      DelayFrameReceived<=  1'b1;
     else
     if (RegDataSoC)
      DataFrameReceived <=  1'b1;
     else
     if (RegDelayDistSoC)
      DelayDistFrameReceived <= 1'b1;
     
  end
  else
  if (StateIdle)
  begin
   NumbFrameReceived      <=  1'b0;
   DistFrameReceived      <=  1'b0;
   DelayFrameReceived     <=  1'b0;
   DataFrameReceived      <=  1'b0;
   DelayDistFrameReceived <=  1'b0 ;
  end
end



always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
  begin
   RegDataSoC  <=  1'b0;
   RegNumbSoC  <=  1'b0;
   RegDistSoC  <=  1'b0;
   RegDelaySoC <=  1'b0;
   RegDelayDistSoC <= 1'b0;
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
      RegDelaySoC<=  1'b1;
     else
     if (MRxDEqDelayDistSoC)
      RegDelayDistSoC <= 1'b1;
  end
  else
  if (StateIdle)
  begin
   RegDataSoC   <=  1'b0;
   RegNumbSoC   <=  1'b0;
   RegDistSoC   <=  1'b0;
   RegDelaySoC  <=  1'b0;
   RegDelayDistSoC <= 1'b0;
  end
end


assign GenerateRxValid = (RegDataSoC & ~TotalRecvNibCnt[0] & GreatEq5thNibble & BeforeFrameCrc )| ( RegNumbSoC & (TotalRecvNibCnt == 16'd6)) | ( RegDelaySoC & ~TotalRecvNibCnt[0] & GreatEq5thNibble & BeforeFrmCrcAtDelayFrm);
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    begin
      LatchedByte[7:0]   <=   8'h0;
      RxData[7:0]        <=   8'h0;
      LastSlaveIDPlus1   <=   8'h0;
      DelaySumCnt        <=  16'h0;
    end
  else
    begin
      // Latched byte
      LatchedByte[7:0]         <=  {MRxD[3:0], LatchedByte[7:4]};

      if(GenerateRxValid)
      begin
         if (RegNumbSoC)
           begin
              LastSlaveIDPlus1 <=  LatchedByte[7:0];          // receiving the number of slaves 
           end
         else
         if (RegDelaySoC)
           begin
              DelaySumCnt      <=  DelaySumCnt + LatchedByte[7:0];          // receiving the number of slaves 
           end
         else
           RxData[7:0]         <=  LatchedByte[7:0]; // Data goes through only in data state  
      end    
      else
      begin
        // Delaying data to be valid for two cycles.
        // Zero when not active.
        if (~RegDelaySoC)
         DelaySumCnt <= 16'd0;
         
        RxData[7:0] <=  8'h0;         // Output data byte
        
      end
    end
end


//

always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    begin
      DelaySum   <=  16'b0;
    end
  else
    begin
     if ( RegDelaySoC & FrmCrcStateEnd)
      DelaySum   <=  DelaySumCnt ;
    end
end

always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    begin
      debug   <=  1'b0;
    end
  else
    begin
     if ( DelaySumCnt != 16'b0)
      debug   <=  1'b1 ;
    end
end


// Output byte stream

always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    begin
      RxValid   <=  1'b0;
    end
  else
    begin
     if ( ~RegNumbSoC & ~RegDistSoC & ~RegDelaySoC)
      RxValid   <=  GenerateRxValid ;
    end
end

           
wire Enable_FrmCrc;
wire [3:0] Data_FrmCrc;
wire Initialize_FrmCrc;
assign Enable_FrmCrc = ~StateFrmCrc;
assign Data_FrmCrc = MRxD;
assign Initialize_FrmCrc = StateIdle & ~MRxDV;


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

//frame crc check
always @ (posedge MRxClk or posedge Reset)
begin
  if(Reset)
    RegFrmCrcError   <=  1'b0;
  else
  if (StateFrmCrc)
    begin
     if ( {~FrmCrc[4], ~FrmCrc[5], ~FrmCrc[6], ~FrmCrc[7]} != MRxD)
        RegFrmCrcError   <=  1'b1 ;
    end
  else
  if (StateIdle)
    RegFrmCrcError    <= 1'b0;
end           
           
endmodule
