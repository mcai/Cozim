`define PORTS 64
`define NODES   64          // Total number of nodes
`define X_NODES 8           // k(x,y,z)-ary.  Number of node columns  (must be > 0)
`define Y_NODES 8           // k(x,y,z)-ary.  Number of node rows (must be > 0)
`define PAYLOAD 512         // Size of the data packet
`define INPUT_QUEUE_DEPTH 4 // Globally set packet depth for input queues
`define TIME_STAMP_SIZE 32

`define DEGREE 5
`define N 5
`define M 5

`define DECOUPLE_EN     // Decouples the o_en of the FIFO from its i_en to prevent combinational loops

 // Network packet type for simple addressed designs
typedef struct packed {
	 logic [`PAYLOAD-1:0] data;
    logic [$clog2(`X_NODES)-1:0] x_source;
    logic [$clog2(`Y_NODES)-1:0] y_source;   
    logic [$clog2(`X_NODES)-1:0] x_dest;
    logic [$clog2(`Y_NODES)-1:0] y_dest; 
	 logic valid;
	 logic [`TIME_STAMP_SIZE-1:0] timestamp;
	 logic measure;
} packet_t;
