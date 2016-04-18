`define X_NODES 4 // k(x,y)-ary.  Number of node columns  (must be > 0)
`define Y_NODES 4 // k(x,y)-ary.  Number of node rows (must be > 0)
`define NODES `X_NODES * `Y_NODES // Total number of nodes

`define INPUT_QUEUE_DEPTH 4 // Globally set packet depth for input queues
`define N 5 // input ports
`define M `N // output ports

`define PH_TABLE_DEPTH 4
`define PH_MIN_VALUE `PH_TABLE_DEPTH'b0
`define PH_MAX_VALUE `PH_TABLE_DEPTH'b1111
`define CREATE_ANT_PERIOD 100

 // Network packet type for simple addressed designs
typedef struct packed {
    logic [$clog2(`X_NODES)-1:0] x_source;
    logic [$clog2(`Y_NODES)-1:0] y_source;   
    logic [$clog2(`X_NODES)-1:0] x_dest;
    logic [$clog2(`Y_NODES)-1:0] y_dest;
	 
	 logic ant;
	 logic backward;
    logic [0:`NODES-1][$clog2(`X_NODES)-1:0] x_memory;
    logic [0:`NODES-1][$clog2(`Y_NODES)-1:0] y_memory;
	 logic [$clog2(`NODES)-1:0] num_memories;
} packet_t;
