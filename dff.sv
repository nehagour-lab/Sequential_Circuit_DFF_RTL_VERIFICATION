// Code your design here
module dff(dff_if dif);
  
  always @(posedge dif.clk) begin
    if (dif.rst == 1'b1)
        dif.dout <= 1'b0;
    else 
      	dif.dout <=dif.din;
     end
    
endmodule

interface dff_if ;
  logic clk,rst,din,dout;
endinterface
