// Quartus Prime Verilog Template
// Single port RAM with single read/write address and initial contents 
// specified with an initial block

module phyIniCommand1_and
#(parameter DATA_WIDTH=16, parameter ADDR_WIDTH=4)
(
   input [(DATA_WIDTH-1):0] data,
   input [(ADDR_WIDTH-1):0] addr,
   input we, clk,
   output [(DATA_WIDTH-1):0] q
);

   // Declare the RAM variable
   reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

   // Variable to hold the registered read address
   reg [ADDR_WIDTH-1:0] addr_reg;

   // Specify the initial contents.  You can also use the $readmemb
   // system task to initialize the RAM variable from a text file.
   // See the $readmemb template page for details.
   initial 
   begin : INIT
      $readmemb("C:/altera/16.0/myProjects/PHYctrl_100Mbps_Slave/ram_init1_and.txt", ram);
   end 

   always @ (posedge clk)
   begin
      // Write
      if (we)
         ram[addr] <= data;

      addr_reg <= addr;
   end

   // Continuous assignment implies read returns NEW data.
   // This is the natural behavior of the TriMatrix memory
   // blocks in Single Port mode.  
   assign q = ram[addr_reg];

endmodule
