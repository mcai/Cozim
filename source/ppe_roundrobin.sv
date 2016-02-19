// M-bit Programmable Priority Encoder including round robin priority generation.
module ppe_roundrobin
#(
  parameter N // Number of requesters
)
(
  input logic clk,
  input logic ce,
  input logic reset_n,

  input logic [0:N-1] i_request, // Active high Request vector

  output logic [0:N-1] o_grant // One-hot Grant vector
);

  logic [0:N-1] l_priority; // One-hot Priority selection vector
  logic [0:N-1] l_carry; // Carry-bit between arbiter slices
  logic [0:N-1] l_intermediate; // Intermediate wire inside arbiter slice

  // Variable priority iterative arbiter slice generation. Final slice carry loops round.
  // ------------------------------------------------------------------------------------------------------------------
  generate
	genvar i;
    for (i=0; i<N; i++) begin : requesters
		assign l_intermediate[i] = l_carry[i] | l_priority[i];
		assign o_grant[i] = l_intermediate[i] & i_request[i];
		assign l_carry[i==N-1?0:i+1] = l_intermediate[i] & ~i_request[i];
    end
  endgenerate

  // Round-Robin priority generation.
  // ------------------------------------------------------------------------------------------------------------------
  always_ff@(posedge clk) begin
    if(~reset_n) begin
      l_priority[0] <= 1'b1;
      l_priority[1:N-1] <= 0;
    end else begin
      if(ce) begin
        l_priority <= |o_grant ? {o_grant[N-1], o_grant[0:N-2]} : l_priority;
      end
    end
  end

endmodule
