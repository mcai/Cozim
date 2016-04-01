`include "config.sv"

module route_calculator_aco
(
  input logic [0:`M-1] i_output_req, // ant agent to route calculator
  input logic i_val, // Valid destination
  output logic [0:`M-1] o_output_req // route calculator to switch control. One-hot request for the [local, north, east, south, west] output port
);

  always_comb begin
    o_output_req = '0;
    if(i_val) begin
      o_output_req = i_output_req;
    end
  end

endmodule
