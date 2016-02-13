`include "config.sv"

module alinx_top(input logic clk, reset_n,
			output logic [3:0] led);

  // Network Read from Nodes.  Valid/Enable protocol.
  // ------------------------------------------------------------------------------------------------------------------
  packet_t [0:`NODES-1] i_data; // Input data from the nodes to the network
  logic [0:`NODES-1] i_data_val; // Validates the input data from the nodes.
  logic [0:`NODES-1] o_en; // Enables the node to send data to the network.
  
  // Network Write to Nodes.  Valid/Enable protocol.
  // ------------------------------------------------------------------------------------------------------------------
  packet_t [0:`NODES-1] o_data; // Output data from the network to the nodes
  logic [0:`NODES-1] o_data_val; // Validates the output data to the nodes
  
  network network(
						.clk(clk), 
						.reset_n(reset_n), 
						.i_data(i_data), 
						.i_data_val(i_data_val),
						.o_en(o_en),
						.o_data(o_data),
						.o_data_val(o_data_val)
                );
			
endmodule
