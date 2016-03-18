`define X_NODES 8 // k(x,y)-ary.  Number of node columns  (must be > 0)
`define Y_NODES 8 // k(x,y)-ary.  Number of node rows (must be > 0)
`define NODES `X_NODES * `Y_NODES // Total number of nodes

`define INPUT_QUEUE_DEPTH 4 // Globally set packet depth for input queues

`define N 5
`define M `N

 // Network packet type for simple addressed designs
typedef struct packed {
    logic [$clog2(`X_NODES)-1:0] x_source;
    logic [$clog2(`Y_NODES)-1:0] y_source;   
    logic [$clog2(`X_NODES)-1:0] x_dest;
    logic [$clog2(`Y_NODES)-1:0] y_dest;
	 
	 logic ant;
	 logic forward;
    logic [0:`NODES-1][$clog2(`X_NODES+1)-1:0] x_memory;
    logic [0:`NODES-1][$clog2(`Y_NODES+1)-1:0] y_memory;
} packet_t;

 // Network packet type for simple addressed designs
typedef struct packed {
    logic [$clog2(`X_NODES)-1:0] x_neighbor;
    logic [$clog2(`Y_NODES)-1:0] y_neighbor;
	 real value;
} pheromone_t;
