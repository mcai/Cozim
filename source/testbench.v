`timescale 1ps/1ps

module testbench();
	
	parameter MAX_CYCLE_WIDTH = 5;

	reg clk;
	reg reset_n;
	  
	wire [1:0] state;
	wire [MAX_CYCLE_WIDTH-1:0] current_cycle;

	// instantiate device to be tested  
	simulator #(MAX_CYCLE_WIDTH) dut(clk, reset_n, state, current_cycle);

	// generate clock to sequence tests
	always #10 clk <= ! clk;
	  
	// initialize test
	initial begin
		#0;
		clk = 0;		
		reset_n = 0;
		
		#10;		
		reset_n = 1;
		
		#10000;
		$finish;
	end

	// output waveforms
	initial begin
		$dumpfile("test.vcd");
		$dumpvars(0, dut);
	end

endmodule