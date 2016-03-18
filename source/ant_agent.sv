`include "config.sv"

module ant_agent
#(
  parameter integer X_LOC, // Current location on the X axis
  parameter integer Y_LOC // Current location on the Y axis
)
(
  input  packet_t [0:`N-1] i_data,
  input  logic [0:`N-1] i_data_val
);

  ant_routing_table #(.X_LOC(X_LOC), .Y_LOC(Y_LOC))
       routing_table();
  
  always_comb begin
    for (int i=0; i<`M; i++) begin
      if(i_data_val[i]) begin
		  if(~i_data[i].ant) begin
		    // normal packet
		  end else begin
		    // ant packet
			 if(i_data[i].forward) begin
			  // forward ant packet
			 end else begin
			  // backward ant packet
		    end
		  end
	   end
    end
  end
 
  function myfunction;
    input a, b, c, d;
    begin
      myfunction = ((a+b) + (c-d));
    end
endfunction 

endmodule
