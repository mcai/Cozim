`include "config.sv"

module route_calculator_xy
#(
  parameter integer X_LOC, // Current location on the X axis
  parameter integer Y_LOC // Current location on the Y axis
)
(
  input logic [$clog2(`X_NODES)-1:0] i_x_dest, // Packet destination on the x axis
  input logic [$clog2(`Y_NODES)-1:0] i_y_dest, // Packet destination on the Y axis
  
  input logic i_val, // Valid destination
  
  output logic [0:`M-1] o_output_req // One-hot request for the [local, north, east, south, west] output port
);

  always_comb begin
    o_output_req = '0;
    if(i_val) begin
      if(i_x_dest != X_LOC) 
        o_output_req = (i_x_dest > X_LOC) ? 5'b00100 : 5'b00001;
      else if (i_y_dest != Y_LOC)
        o_output_req = (i_y_dest > Y_LOC) ? 5'b01000 : 5'b00010;
      else
        o_output_req = 5'b10000;
    end
  end

endmodule
