module alinx_top(input logic clk, reset_n,
			output logic [3:0] led);

  assign led[3:2] = 2'b0;

  // instantiate the simulator
  
  parameter MAX_CYCLE_WIDTH = 32;
  
  logic [MAX_CYCLE_WIDTH-1:0] current_cycle;
  
  simulator #(MAX_CYCLE_WIDTH) simulator(clk, reset_n, led[1:0], current_cycle);
			
endmodule
