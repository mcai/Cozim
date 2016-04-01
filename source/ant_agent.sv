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
  output logic [0:`N-1] o_data_val, // Data out valid
  output logic [0:`N-1][`M-1:0] o_output_req //output request
);

  ant_routing_table
       routing_table(
          .i_update(l_update),// whether update or not
          .i_calculate_neighbor(l_calculate_neighbor), //whether calculate neighbor or not
          .i_dest(l_dest), // = l_data[i].y_dest*8+l_data[i].x_dest
          .i_parent(l_parent), // = i;
          .o_next_output(l_next_output) // l_next_output
       );

  logic l_update;
  logic l_calculate_neighbor;
  
  logic [$clog2(`NODES)-1:0] l_dest;
  logic [0:`N-1] l_parent; //=i
  
  logic [0:`N-1] l_next_output;
  
  logic [$clog2(`X_NODES)-1:0] l_x_temp;
  logic [$clog2(`Y_NODES)-1:0] l_y_temp;
  
  always_comb begin
    o_output_req = '0;
	 
    o_data = '0;
    o_data_val = '0;

    l_update = '0;
    l_calculate_neighbor = '0;
	 
    l_dest = Y_LOC * 8 + X_LOC;
	 
    l_parent = '0;
    l_next_output = '0;
	 l_x_temp = '0;
	 l_y_temp = '0;

    for(int i=0; i<`N; i++) begin
      // data valid
      if(i_data_val[i]) begin
        o_data[i] = o_data[i];
		  
        // handle normal packet
        if(~o_data[i].ant) begin
          // LOC != dest
          if(X_LOC != o_data[i].x_dest || Y_LOC != o_data[i].y_dest) begin 
            // send normal packet				
            // 1.calculate_neighbor(l_dest,l_parent)
            l_dest = o_data[i].y_dest * 8 + o_data[i].x_dest;
            l_parent = i;
            l_calculate_neighbor = 1'b1;
				
            // 2.o_output_req[i] = l_next_output
            o_output_req[i] = l_next_output;
          
			 // LOC == dest
          end else begin
            o_output_req[i] = 5'b10000;
          end

        // handle ant packet
        end else begin
	       // handle forward ant packet
          if(~o_data[i].backward) begin
            // LOC != dest: memorize & send forward
            if(X_LOC != o_data[i].x_dest || Y_LOC != o_data[i].y_dest) begin
              // memorize
	           o_data[i].x_memory[o_data[i].num_memory] = X_LOC;
              o_data[i].y_memory[o_data[i].num_memory] = Y_LOC;
              o_data[i].num_memory++;

              // send forward ant packet				  
				  // 1.calculate_neighbor
              l_dest = o_data[i].y_dest * 8 + o_data[i].x_dest;
              l_parent = i;
              l_calculate_neighbor = 1'b1; 
				  
				  //2.o_output_req[i] = l_next_output
              o_output_req[i] = l_next_output;

            /// LOC == dest: create and send backward ant packet
            end else begin
              // create backward ant packet
              o_data[i].backward = 1'b1;
				  
              l_x_temp = o_data[i].x_source;
              l_y_temp = o_data[i].y_source;
				  
              o_data[i].x_source = o_data[i].x_dest;
              o_data[i].y_source = o_data[i].y_dest;
				  
              o_data[i].x_dest = l_x_temp;
              o_data[i].y_dest = l_y_temp;
	
	           // send backward ant packet (give next_output to route calculator):
              if(o_data[i].x_memory[o_data[i].num_memory] != X_LOC) 
                o_output_req[i] = o_data[i].x_memory[o_data[i].num_memory] > X_LOC ? 5'b00100 : 5'b00001;
              else 
                o_output_req[i] = o_data[i].y_memory[o_data[i].num_memory] > Y_LOC ? 5'b01000 : 5'b00010;
            end

	       // handle backward ant packet	  
          end else begin                         
            // update pheromones(pheromones[dest][next_output]++, pheromones[dest][other]--)
            l_dest = o_data[i].y_dest * 8 + o_data[i].x_dest;
            l_parent = i;
            l_update = 1'b1;

            // LOC != dest: update routing table & send backward
            if(X_LOC != o_data[i].x_dest || Y_LOC != o_data[i].y_dest) begin
              // send backward ant packet (give next_output to RC) and calculate next_output            
              if (o_data[i].x_memory[0] == X_LOC && o_data[i].y_memory[0] == Y_LOC) begin
                //o_output_req = dest
                if(o_data[i].x_dest != X_LOC) 
                  o_output_req[i] = (o_data[i].x_dest > X_LOC) ? 5'b00100 : 5'b00001;
                else //if (i_ant_y_dest != Y_LOC)
                  o_output_req[i] = (o_data[i].y_dest > Y_LOC) ? 5'b01000 : 5'b00010;
              end else begin
                //o_output_req is in memory
                for(int m = 1;m < o_data[i].num_memory; m++) begin
                  if(o_data[i].x_memory[m] == X_LOC && o_data[i].y_memory[m] == Y_LOC) begin
                    if(o_data[i].x_memory[m-1] != X_LOC) 
                      o_output_req[i] = o_data[i].x_memory[m-1] > X_LOC ? 5'b00100 : 5'b00001;//2 : 4;
                    else
                      o_output_req[i] = o_data[i].y_memory[m-1] > Y_LOC ? 5'b01000 : 5'b00010;//1 : 3;
                  end
                end
              end // else raise exception
            /// LOC == dest:
            end else begin
              o_output_req[i] = 5'b10000;// ?? need to destroy
            end

          end // backward ant packet

        end // ant data packet
        o_data_val[i] = 1'b1;
      end // if(i_data_val[i])
    end // for
  end // always_comb

endmodule
