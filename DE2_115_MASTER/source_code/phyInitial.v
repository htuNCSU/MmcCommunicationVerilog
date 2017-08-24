module phyInital (
      
      input clk,reset,
      input iniStart,
      input [3:0]ram_read_addr,
      input [31:0] command,
      input [15:0]command_and,
      inout md_inout0,
      inout md_inout1,
     
      output mdc,
      output reg [3: 0] comm_addr,
      output reg iniEnd,
      output reg [12:0]stateout,
      output [15:0]readDataoutRam,
      output busy,
      output WCtrlDataStartout
      );
      
      wire Busy;
      wire WCtrlDataStart, RStatStart, UpdateMIIRX_DATAReg, Nvalid;
      wire [15:0] writeData;
      wire [15:0] readData;
      wire [15:0] writeData_and;
      
      assign busy = Busy;
      assign WCtrlDataStartout = WCtrlDataStart;
      //assign readDataout = readData;
      
      reg save ;
      reg [3:0]mi_addr;
      always @ (posedge clk)
      begin
      
            if (reset) begin 
                  mi_addr<= 4'b0;
            end
            
            else begin 
                  if (save) begin
                     if (mi_addr < 4'b1110)
                        mi_addr <= mi_addr + 1'b1;
                  end
            end
      end
      
      mi_data_ram mi_data_ram_ins(
      
         .data_a(readData), 
         //.data_b,
         .addr_a(mi_addr), 
         .addr_b(ram_read_addr),
         .we_a(save), 
         .we_b(1'b0), 
         .clk(clk),
         //.q_a, 
         .q_b(readDataoutRam)
      );
     

      wire [4:0] pyhAddr;
      wire [4:0] regAddr;
      wire writeOp;
      
      assign writeOp = command[31];
      assign pyhAddr = command[30:26];
      assign regAddr = command[25:21];
      assign writeData = command[15:0];
      assign writeData_and = command_and;
      
      wire [15: 0] ctrlData;
      assign ctrlData =  (readData | writeData) & writeData_and;
      
      
      reg WCtrlData,RStat;
      
     
      
      wire md_we, md_out,md_in, md_inout;
      
      assign md_inout0 = md_inout ;
      assign md_inout1 = md_inout ;
      assign md_inout = md_we? md_out:1'bz;
      assign md_in = (pyhAddr==5'b10000)? md_inout0 : md_inout1;
      
      reg comm_addr_rst, comm_addr_en;
      
       
   eth_miim eth_miim_ins (

      .Clk(clk),
      .Reset(reset),
      .Divider(8'd50),
      .NoPre(1'b0),
      .CtrlData(ctrlData),
      .Rgad(regAddr),
      .Fiad(pyhAddr),
      .WCtrlData(WCtrlData),
      .RStat(RStat),
      .ScanStat(1'b0),
   
      .Mdi(md_in),
      .Mdo(md_out),
      .MdoEn(md_we),
      .Mdc(mdc),
   
      .Busy(Busy),
      .Prsd(readData),
      //.LinkFail(LEDG[1]),
      .Nvalid(Nvalid),
      .WCtrlDataStart(WCtrlDataStart),
      .RStatStart(RStatStart),
      .UpdateMIIRX_DATAReg(UpdateMIIRX_DATAReg)
   
       );
  
      always @ (posedge clk)
      begin
      
            if (comm_addr_rst) begin 
                  comm_addr <= 4'b0;
            end
            
            else begin 
                  if (comm_addr_en ) comm_addr <= comm_addr + 4'b1;
            end
      end
  

   reg      [3:0]state, next_state;

   // Declare states
   parameter s_rst = 0, s_ini = 1, s_read1 = 2, s_read2 = 3, s_wait= 4, s_write1 = 5 , s_write2 = 6, s_delay1=7, s_delay2=8, s_delay3=9 ;

   // Determine the next state synchronously, based on the
   // current state and the input
   always @ (posedge clk ) begin
      if (reset)
         state <= s_rst;
      else
         state <= next_state;
   end

   // Determine the output based only on the current state
   // and the input (do not wait for a clock edge).
   always @ (state or iniStart or UpdateMIIRX_DATAReg or command or Busy or RStatStart or WCtrlDataStart) 
   begin
         next_state = state;
         WCtrlData = 1'b0;
         RStat     = 1'b0;
         comm_addr_en = 0;
         comm_addr_rst = 0; 
         stateout=0;
         save = 0;
         iniEnd = 0 ;
         case (state)
            s_rst:
               
               begin
                  comm_addr_rst =  1; 
                  if (iniStart) begin
                  
                     next_state = s_ini;
                  end
                  
                  else begin
                        next_state = s_rst;
                  end
               end

            s_ini:
               begin
                     if ( |command & ~Busy) begin
                           next_state = s_read1; stateout=1;
                     end
                     
                     else if ( ~(|command) & ~Busy) begin
                           next_state = s_ini; 
                           iniEnd = 1;
                     end
                     
                     else begin 
                           next_state = s_ini; stateout=2;
                     end
               end
               
            s_read1:
               begin
                     WCtrlData = 1'b0;
                     RStat = 1'b1;
                        
                     if ( RStatStart ) begin
                           next_state = s_read2;stateout=4;
                     end
                     
                     else begin 
                           next_state = s_read1;stateout=8;
                     end
               end
               
            s_read2:
               begin
                     WCtrlData = 1'b0;
                     RStat     = 1'b1;
                        
                     if (UpdateMIIRX_DATAReg) begin
                           next_state = s_wait;stateout=16;
                           save = 1;
                     end
                     
                     else begin 
                           next_state = s_read2;stateout=32;
                     end
               end
              
             s_wait:
               begin
                     WCtrlData = 1'b0;
                     RStat     = 1'b0;
                     if (~Busy) begin
                           next_state = s_write1;
                     end
                     
                     else begin 
                           next_state = s_wait;stateout=1024;
                           
                     end
               end
               
            s_write1:
               begin
                     WCtrlData = 1'b1;
                     RStat     = 1'b0;
                        
                     if ( WCtrlDataStart  ) begin
                           next_state = s_write2; stateout=64;
                     end
                     
                     else begin 
                           next_state = s_write1;stateout=128;
                     end
               end
             
             s_write2:
               begin
                     WCtrlData = 1'b0;
                     RStat     = 1'b0;
                        
                     if ( ~Busy ) begin
                           next_state = s_delay1;stateout=256;
                           comm_addr_en =  1;
                     end
                     
                     else begin 
                           next_state = s_write2;stateout=512;
                     end
               end
               
             s_delay1: 
               begin
                     next_state = s_delay2;
               end
             
             s_delay2:
               begin
                     next_state = s_delay3;
               end
               
             s_delay3:
               begin
                     next_state = s_ini;
               end
             
               
         endcase
   end

endmodule


      
      
      

      
      
      
      
      