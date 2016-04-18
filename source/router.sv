`include "config.sv"

module router #(
  parameter integer X_LOC, // Current node location on the X axis of the Mesh
  parameter integer Y_LOC // Current node location on the Y axis of the Mesh
)
(
  input logic clk, reset_n,
  
  // Upstream Bus.
  // ------------------------------------------------------------------------------------------------------------------
  input  packet_t [0:`N-1] i_data, // Input data from upstream [local, north, east, south, west]
  input  logic [0:`N-1] i_data_val, // Validates data from upstream [local, north, east, south, west]
  output logic [0:`M-1] o_en, // Enables data from upstream [local, north, east, south, west]
  
  // Downstream Bus
  // ------------------------------------------------------------------------------------------------------------------
  output packet_t [0:`M-1] o_data, // Outputs data to downstream [local, north, east, south, west]
  output logic [0:`M-1] o_data_val, // Validates output data to downstream [local, north, east, south, west]
  input  logic [0:`N-1] i_en, // Enables output to downstream [local, north, east, south, west]
  
  output logic [0:`N-1] test_en_SCtoFF,
  
  output  packet_t [0:`N-1] test_data_FFtoAA,
  output  logic [0:`N-1] test_data_val_FFtoAA, 
  
  output packet_t [0:`N-1] test_data_AAtoSW,
  
  output logic [0:`N-1] test_data_val_AAtoRC,
  output logic [0:`N-1][0:`M-1] test_output_req_AAtoRC,
  
  output logic [0:`N-1][0:`M-1] test_output_req_RCtoSC,
  
  output logic [0:`N-1][0:`M-1] test_l_req_matrix_SC,
  
  output logic [0:`N-1]test_update,
  output logic [0:`N-1]test_calculate_neighbor,
  //output logic [$clog2(`N):0] test_parent, //=i
  output logic [0:`N-1][0:`M-1] test_r_o_output_req,
  
  output logic [0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones,
  output logic [0:`PH_TABLE_DEPTH-1] test_max_pheromone_value,
  output logic [0:`PH_TABLE_DEPTH-1] test_min_pheromone_value 
);
  
  // Clock Enable.  For those modules that require it.
  logic ce=1'b1;

  // Local Signals

  //logic [0:`N-1] l_o_en; // Enable of the input crossbar

  logic [0:`N-1][0:`M-1] l_output_req_AAtoRC;
  logic [0:`N-1][0:`M-1] l_output_req_RCtoSC; // Request sent from RC to SC
  logic [0:`M-1][0:`N-1] l_output_grant; // Grant from SC, used to control switch and FIFOs

  // Five input FIFOs, with a Route Calculator attached to the packet waiting at the 
  // output of each FIFO.  The result of the route calculation is used by the switch control for arbitration.
  // ----------------------------------------------------------------------------------------------------------------

  logic [0:`N-1] l_en_SCtoFF; // Connects switch control enable output to FIFO

  packet_t [0:`N-1] l_data_FFtoAA;
  logic [0:`N-1] l_data_val_FFtoAA;

  packet_t [0:`N-1] l_data_AAtoSW;
  logic [0:`N-1] l_data_val_AAtoRC;

  generate
    genvar i;
    for (i=0; i<`N; i++) begin : input_ports
      fifo_packet #(.DEPTH(`INPUT_QUEUE_DEPTH))
        input_queue (.clk(clk), .ce(ce), .reset_n(reset_n),
                          .i_data(i_data[i]),
                          .i_data_val(i_data_val[i]),
                          .i_en(l_en_SCtoFF[i]),
                          
                          .o_data(l_data_FFtoAA[i]),
                          .o_data_val(l_data_val_FFtoAA[i]),

                          .o_en(o_en[i])
      );
									
      // Route calculator will output 5 packed words, each word corresponds to an input, each bit corresponds to the output requested.
      route_calculator_aco
        route_calculator (
                          //.i_x_dest(l_data[i].x_dest),
                          //.i_y_dest(l_data[i].y_dest),
                          .i_output_req(l_output_req_AAtoRC[i]),
                          .i_val(l_data_val_AAtoRC[i]),
                          .o_output_req(l_output_req_RCtoSC[i])
      );
    end
  endgenerate
  
  ant_agent #(.X_LOC(X_LOC), .Y_LOC(Y_LOC))
    ant_agent(.reset_n(reset_n),
              .i_data(l_data_FFtoAA), 
              .i_data_val(l_data_val_FFtoAA),
              .o_data(l_data_AAtoSW),
              .o_data_val(l_data_val_AAtoRC),
              .o_output_req(l_output_req_AAtoRC),
				  
  .test_update(test_update),
  .test_calculate_neighbor(test_calculate_neighbor),
  //.test_parent(test_parent), //=i
  .test_r_o_output_req(test_r_o_output_req),
  
  .test_pheromones(test_pheromones),
  .test_max_pheromone_value(test_max_pheromone_value),
  .test_min_pheromone_value(test_min_pheromone_value)
  );
/*(  
  input packet_t [0:`N-1] i_data, // Data in
  input logic [0:`N-1] i_data_val, // Data in valid
  output packet_t [0:`M-1] o_data, // Data out
  output logic [0:`N-1] o_data_val, // Data out valid
  output logic [0:`N-1][`M-1:0] o_data_output //[i]=l_next_output
);*/
 
  // Switch Control receives N, M-bit words, each word corresponds to an input, each bit corresponds to the requested
  // output.  This is combined with the enable signal from the downstream router, then arbitrated.  The result is
  // M, N-bit words each word corresponding to an output, each bit corresponding to an input (note the transposition).
  // ------------------------------------------------------------------------------------------------------------------  
  switch_control
    switch_control (.clk(clk), .ce(ce), .reset_n(reset_n),
                    .i_en(i_en),
                    .i_output_req(l_output_req_RCtoSC), // From the local VCs or Route Calculator
                    .o_output_grant(l_output_grant), // To the switch, and to the downstream router
                    .o_input_grant(l_en_SCtoFF), // To the local VCs or FIFOs
                             .test_l_req_matrix_SC(test_l_req_matrix_SC)
  );
 
  // Switch.  Switch uses onehot input from switch control.
  // ------------------------------------------------------------------------------------------------------------------
  
  switch_onehot_packet
    switch (
            .i_sel(l_output_grant), // From the Switch Control
            .i_data(l_data_AAtoSW),
            .o_data(o_data)
  );
  
  assign test_en_SCtoFF=l_en_SCtoFF;
  
  assign test_data_FFtoAA=l_data_FFtoAA; // Input data from upstream [local, north, east, south, west]
  assign test_data_val_FFtoAA=l_data_val_FFtoAA; // Validates data from upstream [local, north, east, south, west]
  
  assign test_data_AAtoSW=l_data_AAtoSW;
  
  assign test_data_val_AAtoRC=l_data_val_AAtoRC;
  assign test_output_req_AAtoRC=l_output_req_AAtoRC;
  
  assign test_output_req_RCtoSC=l_output_req_RCtoSC;
  
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
