module simulator  #(parameter MAX_CYCLE_WIDTH = 32)
			(input wire clk, reset_n,
			output reg [1:0] state,
			output reg [MAX_CYCLE_WIDTH-1:0] current_cycle);

	parameter MAX_CYCLE = {MAX_CYCLE_WIDTH{1'b1}};

	reg [1:0] next_state;

	always @(posedge clk or negedge reset_n)
		if (!reset_n) begin
			state <= 2'b00;
			current_cycle <= {MAX_CYCLE_WIDTH{1'b0}};
		end
		else begin
			state <= next_state;

			if(current_cycle < MAX_CYCLE)
				current_cycle <= current_cycle + 1;
		end

	always @(*)
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