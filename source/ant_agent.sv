`include "config.sv"

module ant_agent
#(
  parameter integer X_LOC, // Current location on the X axis
  parameter integer Y_LOC // Current location on the Y axis
)
(  
  input packet_t [0:`N-1] i_data, // Data in
  input logic [0:`N-1] i_data_val, // Data in valid
  output packet_t [0:`M-1] o_data, // Data out
  output logic [0:`N-1] o_data_val // Data out valid
);

//  packet_t [0:`N-1] l_data; // Data in

  ant_routing_table #(.X_LOC(X_LOC), .Y_LOC(Y_LOC))
       routing_table();
  
  var logic [$clog2(`X_NODES)-1:0] l_x_temp;
  var logic [$clog2(`Y_NODES)-1:0] l_y_temp;
  
  always_comb begin
//    l_data = i_data;
	 
    for(int i=0; i<`N; i++) begin
      if(i_data_val[i]) begin
		  if(~i_data[i].ant) begin
		    // normal packet
		  end else begin
		    // ant packet
			 if(~i_data[i].backward) begin
			  // forward ant packet
			  // memorize
			  i_data[i].x_memory[i_data[i].num_memory] = X_LOC;
			  i_data[i].y_memory[i_data[i].num_memory] = Y_LOC;
			  i_data[i].num_memory++;
			  
			  if(X_LOC != i_data[i].x_dest || Y_LOC != i_data[i].y_dest) begin
			    // send forward ant packet
			  end else begin
			    i_data[i].backward = 1'b1;
				 
			    l_x_temp = i_data[i].x_source;
			    l_y_temp = i_data[i].y_source;
			    
				 i_data[i].x_source = i_data[i].x_dest;
			    i_data[i].y_source = i_data[i].y_dest;
			    
				 i_data[i].x_dest = l_x_temp;
			    i_data[i].y_dest = l_y_temp;
				 
				 // send backward ant packet
			  end
			  
			 end else begin
			  // backward ant packet
		    end
		  end
	   end
    end
  end
 
  function memorize
  (
    input a, b, c, d,
	 output myfunction
  );
    begin
      myfunction = ((a+b) + (c-d));
    end
  endfunction

  // Pipeline control.
  assign o_data = i_data;

endmodule
