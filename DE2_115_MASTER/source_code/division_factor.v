module division_factor(div, mul, shift);

input  [7:0]  div;

output [15:0] mul;
output [8:0]  shift;

reg    [15:0] mul;
reg    [8:0]  shift;

always @(div)
begin

   case(div)
   
   8'd1: begin mul = 16'd1;      shift = 8'd0; end
   8'd2: begin mul = 16'd1;      shift = 8'd1; end
   8'd3: begin mul = 16'd21845;  shift = 8'd16; end
   8'd4: begin mul = 16'd1;      shift = 8'd2; end
   8'd5: begin mul = 16'd13107;  shift = 8'd16; end
   8'd6: begin mul = 16'd10923;  shift = 8'd16; end
   8'd7: begin mul = 16'd9362;   shift = 8'd16; end
   8'd8: begin mul = 16'd1;      shift = 8'd3; end
   8'd9: begin mul = 16'd7282;   shift = 8'd16; end
   8'd10:begin mul = 16'd6554;   shift = 8'd16; end
   8'd11:begin mul = 16'd5958;   shift = 8'd16; end
   8'd12:begin mul = 16'd5461;   shift = 8'd16; end
   8'd13:begin mul = 16'd5041;   shift = 8'd16; end
   8'd14:begin mul = 16'd4681;   shift = 8'd16; end
   8'd15:begin mul = 16'd4369;   shift = 8'd16; end
   8'd16:begin mul = 16'd1;      shift = 8'd4; end
   8'd17:begin mul = 16'd3855;   shift = 8'd16; end
   8'd18:begin mul = 16'd3641;   shift = 8'd16; end
   8'd19:begin mul = 16'd3449;   shift = 8'd16; end
   8'd20:begin mul = 16'd3277;   shift = 8'd16; end
   8'd21:begin mul = 16'd3121;   shift = 8'd16; end
   8'd22:begin mul = 16'd2979;   shift = 8'd16; end
   8'd23:begin mul = 16'd2849;   shift = 8'd16; end
   8'd24:begin mul = 16'd2731;   shift = 8'd16; end
   8'd25:begin mul = 16'd2621;   shift = 8'd16; end
   8'd26:begin mul = 16'd2521;   shift = 8'd16; end
   8'd27:begin mul = 16'd2427;   shift = 8'd16; end
   8'd28:begin mul = 16'd2341;   shift = 8'd16; end
   8'd29:begin mul = 16'd2260;   shift = 8'd16; end
   8'd30:begin mul = 16'd2185;   shift = 8'd16; end
  
   default: begin mul = 16'd1;      shift = 8'd0; end
   
   endcase
end

endmodule
