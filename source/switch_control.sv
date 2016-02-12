`include "config.sv"

module switch_control
#(
  parameter integer N, // Number of inputs
  parameter integer M
)
(
  input  logic clk,
  input  logic ce,
  input  logic reset_n,
  
  input  logic        [0:M-1] i_en,            // signal from downstream router that indicates if it is available
  input  logic [0:N-1][0:M-1] i_output_req,    // N local input units requests up to M output ports
  
  output logic [0:M-1][0:N-1] o_output_grant,  // Each of the M outputs are granted to the N inputs
  
  output logic        [0:N-1] o_input_grant  // Each of the N inputs has a single input queue that can be granted
);

  logic [0:N-1][0:M-1] l_req_matrix;    // N Packed requests for M available output ports

  // No virtual Output Queues, each input can only request a single output, only need to arbitrate for the output 
  // port. The input 'output_req' is N, M-bit words.  Each word corresponds to an input port, each bit corresponds to 
  // the requested output port.  This is transposed so that each word corresponds to an output port, and each bit 
  // corresponds to an input that requested it.  This also ensures that output port requests will not be made if the 
  // corresponding output enable is low.  This is then fed into M round robin arbiters.
  // ----------------------------------------------------------------------------------------------------------------
  always_comb begin
    l_req_matrix = '0;
    for (int i=0; i<M; i++) begin
      for (int j=0; j<N; j++) begin
        l_req_matrix[i][j] = i_output_req[j][i] && i_en[i];
      end
    end
  end
  
  genvar i;
  generate
    for (i=0; i<M; i++) begin : OUTPUT_ARBITRATION
        ppe_roundrobin #(.N(N)) gen_ppe_roundrobin (.clk,
                                                            .ce,
                                                            .reset_n,
                                                            .i_request(l_req_matrix[i]),
                                                            .o_grant(o_output_grant[i]));
    end
  endgenerate
    
  // indicate to input FIFOs, according to arbitration results, that data will be read. Enable is high if any of the 
  // output_grants indicate they have accepted an input.  This creates one N bit word, which is the logical 'or' of
  // all the output_grants, as each output_grant is an N-bit onehot vector representing a granted input.
  // ----------------------------------------------------------------------------------------------------------------
  always_comb begin
    o_input_grant = '0;
    for(int i=0; i<N; i++) begin
      o_input_grant |= o_output_grant[i];
      // if this fails to synthesize, this is equivalent to: l_en[0:N-1] = l_en[0:N-1] | l_output_grant[i][0:N-1];
    end
  end 

endmodule
