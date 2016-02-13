`include "config.sv"

module router #(
  parameter integer X_LOC, // Current node location on the X axis of the Mesh
  parameter integer Y_LOC // Current node location on the Y axis of the Mesh
)
(
  input logic clk, reset_n,
  
  // Upstream Bus.
  // ------------------------------------------------------------------------------------------------------------------
  input  packet_t [0:`N-1] i_data, // Input data from upstream [core, north, east, south, west]
  input  logic [0:`N-1] i_data_val, // Validates data from upstream [core, north, east, south, west]
  output logic [0:`M-1] o_en, // Enables data from upstream [core, north, east, south, west]
  
  // Downstream Bus
  // ------------------------------------------------------------------------------------------------------------------
  output packet_t [0:`M-1] o_data, // Outputs data to downstream [core, north, east, south, west]
  output logic [0:`M-1] o_data_val, // Validates output data to downstream [core, north, east, south, west]
  input  logic [0:`N-1] i_en // Enables output to downstream [core, north, east, south, west]
);  
  
  // Local Signals common to all definitions
  // ------------------------------------------------------------------------------------------------------------------

  // Load balancing.  Shorted if LOAD_BALANCE is not defined
  packet_t [0:`N-1] l_i_data; // Output of the input crossbar
  logic [0:`N-1] l_i_data_val; // Output of the input crossbar
  logic [0:`N-1] l_o_en; // Enable of the input crossbar

  // Connections between input queues and switch etc.
  packet_t [0:`N-1] l_data; // Connects FIFO data outputs to switch
  logic [0:`N-1][0:`M-1] l_output_req; // Request sent to SwitchControl
  logic [0:`M-1][0:`N-1] l_output_grant; // Grant from SwitchControl, used to control switch and FIFOs

  // Clock Enable.  For those modules that require it.
  logic ce;
  
  assign l_i_data = i_data;
  assign l_i_data_val = i_data_val;
  assign o_en = l_o_en;
  
  // No virtual Output Queues.  Five input FIFOs, with a Route Calculator attached to the packet waiting at the 
  // output of each FIFO.  The result of the route calculation is used by the switch control for arbitration.
  // ----------------------------------------------------------------------------------------------------------------

  logic [0:`N-1] l_data_val; // Connects FIFO valid output to the route calculator    
  logic [0:`N-1] l_en; // Connects switch control enable output to FIFO
  genvar i;     

  generate
    for (i=0; i<`N; i++) begin : GENERATE_INPUT_QUEUES
      fifo_packet #(.DEPTH(`INPUT_QUEUE_DEPTH))
        gen_fifo_packet (.clk,
                                 .ce,
                                 .reset_n,
                                 .i_data(l_i_data[i]), // From the upstream routers
                                 .i_data_val(l_i_data_val[i]), // From the upstream routers
                                 .i_en(l_en[i]), // From the SwitchControl
                                 .o_data(l_data[i]), // To the Switch
                                 .o_data_val(l_data_val[i]), // To the route calculator
                                 .o_en(l_o_en[i]) // To the upstream router, possibly via load balance
                                 );
    end
  endgenerate
    
  // Route calculator will output 5 packed words, each word corresponds to an input, each bit corresponds to the
  // output requested.
  // ----------------------------------------------------------------------------------------------------------------
  generate
    for (i=0; i<`N; i++) begin : GENERATE_ROUTE_CALCULATORS  
      route_calculator #(.X_LOC(X_LOC), .Y_LOC(Y_LOC))
        gen_route_calculator (
                                    .i_x_dest(l_data[i].x_dest),
                                    .i_y_dest(l_data[i].y_dest),
                                    .i_val(l_data_val[i]),                                      // From local FIFO
                                    .o_output_req(l_output_req[i]));                            // To Switch Control
    end
  endgenerate 
 
  // Switch Control receives N, M-bit words, each word corresponds to an input, each bit corresponds to the requested
  // output.  This is combined with the enable signal from the downstream router, then arbitrated.  The result is
  // M, N-bit words each word corresponding to an output, each bit corresponding to an input (note the transposition).
  // ------------------------------------------------------------------------------------------------------------------  
  switch_control
    inst_switch_control (.clk,
                             .ce,
                             .reset_n,
                             .i_en(i_en),                      // From the downstream router
                             .i_output_req(l_output_req),      // From the local VCs or Route Calculator
                             .o_output_grant(l_output_grant),  // To the switch, and to the downstream router
                             .o_input_grant(l_en));            // To the local VCs or FIFOs
 
  // Switch.  Switch uses onehot input from switch control.
  // ------------------------------------------------------------------------------------------------------------------
  
  switch_onehot_packet
    inst_switch_oneHot_packet (.i_sel(l_output_grant), // From the Switch Control
                                     .i_data(l_data),        // From the local FIFOs
                                     .o_data(o_data));       // To the downstream routers
  
  // Output to downstream routers that the switch data is valid.  l_output_grant[output number] is a onehot vector, thus
  // if any of the bits are high the output referenced by [output number] has valid data.
  // ------------------------------------------------------------------------------------------------------------------                      
  always_comb begin
    o_data_val = '0;
    for (int i=0; i<`M; i++) begin  
      o_data_val[i]  = |l_output_grant[i];
    end
  end 

endmodule
