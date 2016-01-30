module top(input logic clk, reset_n,
			output logic [3:0] led);
	
	parameter MAX_CYCLE_WIDTH = 32;
   
	logic [MAX_CYCLE_WIDTH-1:0] current_cycle;

	simulator #(MAX_CYCLE_WIDTH) simulator(clk, reset_n, led[1:0], current_cycle);
	assign led[3:2] = 2'b0;
			
endmodule

module simulator  #(parameter MAX_CYCLE_WIDTH = 32)
			(input logic clk, reset_n,
			output logic [1:0] state,
			output logic [MAX_CYCLE_WIDTH-1:0] current_cycle);
	
	parameter MAX_CYCLE = {MAX_CYCLE_WIDTH{1'b1}};
	
	logic [1:0] next_state;
	
	always_ff @(posedge clk or negedge reset_n)
		if (!reset_n) begin
			state <= 2'b00;
			current_cycle <= {MAX_CYCLE_WIDTH{1'b0}};
		end
		else begin
			state <= next_state;
			
			if(current_cycle < MAX_CYCLE)		
				current_cycle <= current_cycle + 1;
		end
	
	always_comb
		case (state)
			2'b00: //INVALID
				next_state <= 2'b01;
			2'b01: //INITIALIZED
				next_state <= 2'b10;
			2'b10: begin //RUNNING
				next_state <= 2'b10;
				
				if (current_cycle == MAX_CYCLE)
					next_state <= 2'b11;
			end
			2'b11://COMPLETED
				next_state <= 2'b11;
			default:
				next_state <= 2'bx;
		endcase
	
endmodule
