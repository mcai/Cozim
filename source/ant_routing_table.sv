`include "config.sv"

module ant_routing_table#(
  parameter integer X_LOC, // Current location on the X axis
  parameter integer Y_LOC // Current location on the Y axis
)(
  input logic reset_n,
  input logic [0:`N-1] i_update,
  input logic [0:`N-1] i_calculate_neighbor,
  input logic [0:`N-1] i_is_ant,
  input logic [0:`N-1][$clog2(`X_NODES)-1:0] i_x_dest,
  input logic [0:`N-1][$clog2(`Y_NODES)-1:0] i_y_dest,
  //input logic [0:`N-1][$clog2(`N)-1:0] i_parent,
  output logic [0:`N-1][0:`M-1] o_output_req,
  
  output logic [0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones,
  output logic [0:`PH_TABLE_DEPTH-1] test_max_pheromone_value,
  output logic [0:`PH_TABLE_DEPTH-1] test_min_pheromone_value
);

   logic [0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] pheromones;
   //logic [0:`PH_TABLE_DEPTH+1] temp;
   logic [0:`PH_TABLE_DEPTH-1] max_pheromone_value;
   logic [0:`PH_TABLE_DEPTH-1] min_pheromone_value;
   logic [$clog2(`N)-1:0] max_pheromone_neighbor;
   logic [$clog2(`N)-1:0] min_pheromone_neighbor;
  
   logic [0:`N-1][$clog2(`NODES)-1:0] l_dest;//i_dest
  
   assign test_pheromones=pheromones;
   assign test_max_pheromone_value=max_pheromone_value;
   assign test_min_pheromone_value=min_pheromone_value;

   always_comb begin
    
      if(~reset_n)begin
	      /*
         for(int i=0;i<`NODES;i++)begin
	         for(int j=0;j<`N-1;j++)begin
	   	      pheromones[i][j]='0;
	   	   end
	      end
	      for(int i=0;i<`N;i++)begin
 	         o_output_req[i] = '0;
	      end
		   */
	      //temp='0;
		   pheromones='0;
		   o_output_req='0;
		   l_dest='0;
         max_pheromone_value = '0;
         min_pheromone_value = '0;
         max_pheromone_neighbor = '0;
         min_pheromone_neighbor = '0;
      end else begin
         for(int i=0;i<`N;i++)begin
	         o_output_req[i]= o_output_req[i];
    	      l_dest[i] = i_y_dest[i] * `X_NODES + i_x_dest[i];
	         //temp='0;
	         max_pheromone_value = `PH_MIN_VALUE;
	         min_pheromone_value = `PH_MAX_VALUE; 
	         max_pheromone_neighbor = '0;
	         min_pheromone_neighbor = '0;
        
	         if(i_calculate_neighbor[i]) begin
               /*for(int j = 0; j < `N-1; j++) begin
                  if(j+1 != i) begin
	    	            if(max_pheromone_value < pheromones[l_dest[i]][j]) begin
                        max_pheromone_value = pheromones[l_dest[i]][j];
                        max_pheromone_neighbor = j+1;
		               end
		               if(min_pheromone_value > pheromones[l_dest[i]][j]) begin
                        min_pheromone_value = pheromones[l_dest[i]][j];
                        min_pheromone_neighbor = j+1;
		               end
                  end
               end*/
	            //if((max_pheromone_value - min_pheromone_value) > 2) begin//:calculate by using table 
	               //may make error choice(choose output with less pheromone)
	 	            //prevent deadlock
		            /*
                     rule
	 	            */
	 	         //   for(int j = 0; j < `N; j++) begin
               //      o_output_req[i][j] = (j == max_pheromone_neighbor) ? 1 : 0;
	 	         //   end
 	 	         //end else begin//(is not ant packet and table.d is not avail) begin:calculate by XY-random router
	               //XY-random router
		            //temp = pheromones[l_dest[i]][0] + pheromones[l_dest[i]][1] + pheromones[l_dest[i]][2] + pheromones[l_dest[i]][3];
	 	            if(i_x_dest[i] > i_y_dest[i]) begin    //if(temp[0] == 0) begin //temp[7] == 0
		               if(i_x_dest[i] != X_LOC) 
                        o_output_req[i] = (i_x_dest[i] > X_LOC) ? 5'b00100 : 5'b00001;
                     else if (i_y_dest[i] != Y_LOC)
                        o_output_req[i] = (i_y_dest[i] > Y_LOC) ? 5'b01000 : 5'b00010;
                     else
                        o_output_req[i] = 5'b10000;
		            end else begin
		               if(i_y_dest[i] != Y_LOC)
                        o_output_req[i] = (i_y_dest[i] > Y_LOC) ? 5'b01000 : 5'b00010;
                     else if (i_x_dest[i] != X_LOC) 
                        o_output_req[i] = (i_x_dest[i] > X_LOC) ? 5'b00100 : 5'b00001;
                     else
                        o_output_req[i] = 5'b10000;
		            end
	            //end
            end else if(i_update[i]) begin
               for(int j = 0; j < `N-1; j++) begin
                  if(j+1 == i) begin			 
			            //if(pheromones[l_dest[i]][j] < `PH_MAX_VALUE) begin
			 	         pheromones[l_dest[i]][j] = (pheromones[l_dest[i]][j] < `PH_MAX_VALUE) ? pheromones[l_dest[i]][j]+1:pheromones[l_dest[i]][j];
			            //end
                  end else begin
			            //if(pheromones[l_dest[i]][j] > `PH_MIN_VALUE) begin
				         pheromones[l_dest[i]][j] = (pheromones[l_dest[i]][j] > `PH_MIN_VALUE) ? pheromones[l_dest[i]][j]-1:pheromones[l_dest[i]][j];
			            //end
                  end
               end
            end
	      end
	   end
   end
endmodule
