module ConfigCheck (Reset, LastSlaveIDPlus1, AveSlaveDelay, ConfigOK
);
input       Reset;
input [7:0] LastSlaveIDPlus1;
input [7:0] AveSlaveDelay;

output ConfigOK;

reg    ConfigOK;

always @ *
begin
   if(Reset)
      ConfigOK = 1'd0;
   else
   if ( (LastSlaveIDPlus1 >= 8'd1 & LastSlaveIDPlus1 <= 8'd30) & (AveSlaveDelay >= 8'd50 & AveSlaveDelay <= 8'd70) )
      ConfigOK = 1'd1;
   else
      ConfigOK = 1'd0;
end

endmodule

