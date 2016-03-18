`include "config.sv"

module ant_routing_table
#(
  parameter integer X_LOC, // Current location on the X axis
  parameter integer Y_LOC // Current location on the Y axis
)
();

logic [0:`NODES-1][0:`N-2] pheromones;

endmodule
