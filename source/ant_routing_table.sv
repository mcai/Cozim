`include "config.sv"

module ant_routing_table(
  input logic i_update,
  input logic i_calculate_neighbor,
  input logic [0:`N-1] i_dest,
  input logic [0:`N-1] i_parent,
  output logic [0:`N-1] o_next_output
);

  logic [0:`NODES-1][0:`N-2] pheromones;
  int max_pheromone_value;
  logic [0:`N-1] max_pheromone_neighbor;

  always_comb begin
    max_pheromone_value = '0;
	 max_pheromone_neighbor = '0;
	 o_next_output ='0;
    
    if(i_calculate_neighbor) begin
      for(int neighbor = 1; neighbor < `N; neighbor++) begin
        if(neighbor != i_parent && max_pheromone_value < pheromones[i_dest][neighbor-1]) begin
          max_pheromone_value = pheromones[i_dest][neighbor-1];
          max_pheromone_neighbor = neighbor;
        end
      end
		
      for(int neighbor = 0; neighbor < `N; neighbor++) begin
        o_next_output[neighbor] = neighbor == max_pheromone_neighbor ? 1 : 0;
      end
			 
    end else if(i_update) begin
      for(int neighbor = 1; neighbor < `N; neighbor++) begin
        if(neighbor==i_parent) begin			 
			 if(pheromones[i_dest][neighbor-1] < `PH_MAX_VALUE) begin
				pheromones[i_dest][neighbor-1] += 1;
			 end
        end else begin
			 if(pheromones[i_dest][neighbor-1] > `PH_MIN_VALUE) begin
				pheromones[i_dest][neighbor-1] -= 1;
			 end
        end
      end
    end
  end
endmodule
