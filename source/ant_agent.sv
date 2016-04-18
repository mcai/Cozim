`include "config.sv"

module ant_agent
#(
  parameter integer X_LOC, // Current location on the X axis
  parameter integer Y_LOC // Current location on the Y axis
)
(
  input logic reset_n,  
  input packet_t [0:`N-1] i_data, // Data in
  input logic [0:`N-1] i_data_val, // Data in valid
  output packet_t [0:`M-1] o_data, // Data out
  output logic [0:`N-1] o_data_val, // Data out valid
  output logic [0:`N-1][0:`M-1] o_output_req, //output request
  
  output logic [0:`N-1] test_update,
  output logic [0:`N-1] test_calculate_neighbor,
  //output logic [0:`N-1][$clog2(`N):0] test_parent, //=i
  output logic [0:`N-1][0:`M-1] test_r_o_output_req,
  
  output logic [0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones,
  output logic [0:`PH_TABLE_DEPTH-1] test_max_pheromone_value,
  output logic [0:`PH_TABLE_DEPTH-1] test_min_pheromone_value 
);

  logic [0:`N-1]l_update;
  logic [0:`N-1]l_calculate_neighbor;
  
  logic [0:`N-1]l_is_ant;
  logic [0:`N-1][$clog2(`X_NODES)-1:0] l_x_temp;
  logic [0:`N-1][$clog2(`Y_NODES)-1:0] l_y_temp;

  //logic [0:`N-1][$clog2(`N)-1:0] l_parent; //=i
  //logic [$clog2(`N):0] l_parent; //=i
  
  logic [0:`N-1][0:`M-1] l_output_req;
  logic [0:`N-1][0:`M-1] r_o_output_req;
  
  assign test_update = l_update;
  assign test_calculate_neighbor = l_calculate_neighbor;
  //assign test_parent = l_parent;
  assign test_r_o_output_req = r_o_output_req;
  
  ant_routing_table #(.X_LOC(X_LOC), .Y_LOC(Y_LOC))
       routing_table(
		    .reset_n(reset_n),
          .i_update(l_update),// whether update or not
          .i_calculate_neighbor(l_calculate_neighbor), //whether calculate neighbor or not
			 
			 .i_is_ant(l_is_ant),
			 .i_x_dest(l_x_temp),
			 .i_y_dest(l_y_temp),
			 
          //.i_parent(l_parent), // = i;
			 
          .o_output_req(r_o_output_req),
			 
  .test_pheromones(test_pheromones),
  .test_max_pheromone_value(test_max_pheromone_value),
  .test_min_pheromone_value(test_min_pheromone_value)
       );

   always_comb begin

      for(int i=0; i<`N; i++) begin
         o_data[i] = '0;
         o_data_val[i] = '0;

         l_update[i] = '0;
         l_calculate_neighbor[i] = '0;
	 
         l_is_ant[i] = 0;
         l_x_temp[i] = '0;
         l_y_temp[i] = '0;
	 
         //l_parent = i;
	 
         l_output_req[i] = '0;
	 
         // data valid
         if(i_data_val[i]) begin
            o_data[i] = i_data[i];
		      
            l_x_temp[i] = o_data[i].x_dest;
            l_y_temp[i] = o_data[i].y_dest;
		  
            // handle normal packet
            if(~o_data[i].ant) begin
               // LOC != dest
               if(X_LOC != o_data[i].x_dest || Y_LOC != o_data[i].y_dest) begin 
                  // send normal packet				
                  // 1.calculate_neighbor
				      l_is_ant[i] = 0;
                  l_calculate_neighbor[i] = 1'b1;
				      
				      // delay !!!!!!!!!!!!!!!!
				
                  // 2.o_output_req[i] = r_o_output_req
                  //o_output_req[i] = r_o_output_req;
                  
			         // LOC == dest
               end else begin
                  l_output_req[i] = 5'b10000;
               end
               
            // handle ant packet
            end else begin
	            // handle forward ant packet
               if(~o_data[i].backward) begin
                  // LOC != dest: memorize & send forward
                  if(X_LOC != o_data[i].x_dest || Y_LOC != o_data[i].y_dest) begin
                     // memorize
	                  o_data[i].x_memory[o_data[i].num_memories] = X_LOC;
                     o_data[i].y_memory[o_data[i].num_memories] = Y_LOC;
                     o_data[i].num_memories++;
                     
                     // send forward ant packet				  
				         // 1.calculate_neighbor
				         l_is_ant[i] = 1;
                     l_calculate_neighbor[i] = 1'b1; 
				         
				         // delay !!!!!!!!!!!!!!!!
				         
				         //2.o_output_req[i] = r_o_output_req
                     //o_output_req[i] = r_o_output_req;
                     
                  /// LOC == dest: create and send backward ant packet
                  end else begin
                     // create backward ant packet
                     o_data[i].backward = 1'b1;
				       
                     l_x_temp[i] = o_data[i].x_source;
                     l_y_temp[i] = o_data[i].y_source;
				        
                     o_data[i].x_source = o_data[i].x_dest;
                     o_data[i].y_source = o_data[i].y_dest;
				        
                     o_data[i].x_dest = l_x_temp[i];
                     o_data[i].y_dest = l_y_temp[i];
	                  
	                  // send backward ant packet (give next_output to route calculator):
                     if(o_data[i].x_memory[o_data[i].num_memories-1] != X_LOC)
                        l_output_req[i] = (o_data[i].x_memory[o_data[i].num_memories] > X_LOC) ? 5'b00100 : 5'b00001;
                     else if(o_data[i].y_memory[o_data[i].num_memories-1] != Y_LOC)
                        l_output_req[i] = (o_data[i].y_memory[o_data[i].num_memories] > Y_LOC) ? 5'b01000 : 5'b00010;
				         else
				            l_output_req[i] = 5'b10000;
                  end
              
	            // handle backward ant packet	  
               end else begin                         
                  // update pheromones(pheromones[dest][next_output]++, pheromones[dest][other]--)
				      l_is_ant[i] = 1;
                  l_update[i] = 1'b1;
                
                  // LOC != dest: update routing table & send backward
                  if(X_LOC != o_data[i].x_dest || Y_LOC != o_data[i].y_dest) begin
                     // send backward ant packet (give next_output to RC) and calculate next_output            
                     if (o_data[i].x_memory[0] == X_LOC && o_data[i].y_memory[0] == Y_LOC) begin
                        //o_output_req = dest
                        if(o_data[i].x_dest != X_LOC) 
                           l_output_req[i] = (o_data[i].x_dest > X_LOC) ? 5'b00100 : 5'b00001;
                        else //if (i_ant_y_dest != Y_LOC)
                           l_output_req[i] = (o_data[i].y_dest > Y_LOC) ? 5'b01000 : 5'b00010;
                     end else begin
                        //o_output_req is in memory
                        for(int m = 1;m < o_data[i].num_memories; m++) begin
                           if(o_data[i].x_memory[m] == X_LOC && o_data[i].y_memory[m] == Y_LOC) begin
                              if(o_data[i].x_memory[m-1] != X_LOC) 
                                 l_output_req[i] = (o_data[i].x_memory[m-1] > X_LOC) ? 5'b00100 : 5'b00001;//2 : 4;
                              else
                                 l_output_req[i] = (o_data[i].y_memory[m-1] > Y_LOC) ? 5'b01000 : 5'b00010;//1 : 3;
                           end
                        end
                     end // else raise exception
                  /// LOC == dest:
                  end else begin
                     l_output_req[i] = 5'b10000;// ?? need to destroy
                  end
                 
               end // backward ant packet
               
            end // ant data packet
            o_data_val[i] = 1'b1;
         end // if(i_data_val[i])
      end // for
   end // always_comb  
  
   always_comb begin
      for(int i=0;i<`N;i++)begin
	      o_output_req[i]= l_calculate_neighbor ? r_o_output_req[i] : l_output_req[i];
	   end
   end

endmodule
