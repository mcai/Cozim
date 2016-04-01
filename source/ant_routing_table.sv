`include "config.sv"

module ant_routing_table(
  input logic i_update_signal,
  input logic i_calculate_neighbor,
  input logic [0:`N-1] i_dest,
  input logic [0:`N-1] i_parent,//=i
  output logic [0:`N-1] o_next_output
);

  logic [0:`N-1] l_next_output;

  logic [0:`NODES-1][0:`N-2] pheromones;//='0;
  //pheromones [0:`NODES-1][0:`N-2] pheromones;
  int max_ph;
  logic [0:`N-1] d;

  always_comb begin

    pheromones=pheromones;//l_ph_table_mem=l_ph_table_mem;
    max_ph='0;
	 d='0; 
    l_next_output='0;
	 o_next_output='0;
    
    if(i_calculate_neighbor) begin
      //use pheromones[i_dest][i_parent],output next_output
      for(int neighbor=1; neighbor<5; neighbor++)begin
        if ( (neighbor!=i_parent) && ( max_ph < pheromones[i_dest][neighbor-1] ) ) begin
          max_ph = pheromones[i_dest][neighbor-1];
          d=neighbor;
        end //else max_ph=max_ph;d=d;
      end
      for(int neighbor=0;neighbor<5;neighbor++)begin
        if(neighbor==d) begin
          l_next_output[neighbor]=1;
        end else begin
          l_next_output[neighbor]=0;
        end
      end
      o_next_output=l_next_output;

    end else if (i_update_signal) begin
      //update pheromones[i_dest][i_parent]
      for(int neighbor=1; neighbor<5; neighbor++)begin
        if ( neighbor==i_parent ) begin
          pheromones[i_dest][neighbor-1]=(pheromones[i_dest][neighbor-1]==`PH_MIN_VALUE) ? 0: pheromones[i_dest][neighbor-1]+1;
        end else begin
          pheromones[i_dest][neighbor-1]=(pheromones[i_dest][neighbor-1]==`PH_MAX_VALUE) ? 0: pheromones[i_dest][neighbor-1]-1;
        end
      end
    end

  end//always_comb

endmodule