`timescale 1ps/1ps

`include "config.sv"

module testbench
#(
  parameter CLK_PERIOD = 5,
  parameter integer PACKET_RATE = 100, // Offered traffic as percent of capacity
  
  parameter integer WARMUP_PACKETS = 1000, // Number of packets to warm-up the network
  parameter integer MEASURE_PACKETS = 5000, // Number of packets to be measured
  parameter integer DRAIN_PACKETS = 3000, // Number of packets to drain the network
  
  parameter integer DOWNSTREAM_EN_RATE = 100, // Percent of time simulated nodes able to receive data
  parameter integer NODE_QUEUE_DEPTH = `INPUT_QUEUE_DEPTH * 8
);

  logic clk;
  logic reset_n;

  // SIGNALS:  Node Input Bus.
  // ------------------------------------------------------------------------------------------------------------------
  // fifo.o_data -> network.i_data 
  packet_t [0:`NODES-1] i_data; // Input data from the nodes to the network 
  
  // l_i_data_val && o_en -> network.i_data_val
  logic [0:`NODES-1] i_data_val; // Validates the input data from the nodes.
  
  // from network.o_en -> fifo.i_en and i_data_val:1
  logic [0:`NODES-1] o_en; // Enables the node to send data to the network.
  
  // SIGNALS:  Node Output Bus
  // ------------------------------------------------------------------------------------------------------------------
  // 1 -> none
  logic [0:`NODES-1] i_en; // Enables output data from network to downstream nodes  
  // network.o_data -> none
  packet_t [0:`NODES-1] o_data; // Output data from the network to the nodes  
  // network.o_data_val -> none
  logic [0:`NODES-1] o_data_val; // Validates the output data to the nodes
  
  // SIGNALS:  Input Queue FIFO signals
  // ------------------------------------------------------------------------------------------------------------------
  // (f_x_dest, f_y_dest) -> s_i_data -> (fifo.i_data.Xdest, fifo.i_data.Ydest)
  packet_t [0:`NODES-1] s_i_data; // Input data from upstream [core, north, east, south, west]
  // fifo.o_data_val -> l_i_data_val -> i_data_val:2
  logic [0:`NODES-1] l_i_data_val; // Used to create i_data_val depending on the value of o_en  
  // fifo.o_en -> f_full -> none
  logic [0:`NODES-1] f_full; // Indicates that the node queue is saturated
  
  // FLAGS:  Random
  // ------------------------------------------------------------------------------------------------------------------   
  logic [0:`NODES-1] f_data_val;
  // s_i_data[i].x_dest=f_x_dest[i]=$urandom_range(`X_NODES-1, 0);
  logic [0:`NODES-1][$clog2(`X_NODES+1)-1:0] f_x_dest;
  //s_i_data[i].y_dest=f_y_dest[i]=$urandom_range(`Y_NODES-1, 0);
  logic [0:`NODES-1][$clog2(`Y_NODES+1)-1:0] f_y_dest;
  
  // FLAGS:  Control
  // ------------------------------------------------------------------------------------------------------------------
  // Pseudo time value/clock counter
  longint f_time;
  
  integer f_port_s_i_data_count [0:`NODES-1]; // Count number of packets simulated and added to the node queues
  integer f_total_s_i_data_count;            // Count total number of simulated packets
  integer f_port_i_data_count [0:`NODES-1];   // Count number of packets that left the node, transmitted on each port
  integer f_total_i_data_count;              // Count total number of transmitted packets
  integer f_port_o_data_count [0:`NODES-1];   // Count number of received packets on each port
  integer f_total_o_data_count;              // Count total number of received packets
  
  network network(
						.clk(clk), 
						.reset_n(reset_n), 
						.i_data(i_data), 
						.i_data_val(i_data_val),  //[i] = l_i_data_val[i] && o_en[i];
						.o_en(o_en),
						.o_data(o_data),
						.o_data_val(o_data_val)
                );

  // SIMULATION:  System Clock
  // ------------------------------------------------------------------------------------------------------------------
  initial begin
    clk = 1;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // SIMULATION:  System Time
  // ------------------------------------------------------------------------------------------------------------------  
  initial begin
    f_time = 0;
    forever #(CLK_PERIOD) f_time = f_time + 1;
  end  
  
  // SIMULATION:  System Reset
  // ------------------------------------------------------------------------------------------------------------------
  initial begin
    reset_n = 0;
    #(CLK_PERIOD + 3 * CLK_PERIOD / 4)
    reset_n = 1;
  end

  // SIMULATION:  Node RX
  // ------------------------------------------------------------------------------------------------------------------
  always_ff@(posedge clk) begin
    if(~reset_n) begin
      for(int i=0; i<`NODES; i++) begin
        i_en[i] <= 0;
      end
    end else begin
      for(int i=0; i<`NODES; i++) begin
        i_en[i] <= ($urandom_range(100,1) <= DOWNSTREAM_EN_RATE) ? 1 : 0;
      end
    end
  end
  
  // SIMULATION:  Node TX
  // ------------------------------------------------------------------------------------------------------------------
  genvar i;
  generate
    for (i=0; i<`NODES; i++) begin : GENERATE_INPUT_QUEUES
      fifo_packet #(.DEPTH(NODE_QUEUE_DEPTH))
        gen_fifo_packet (.clk,
                               .ce(1'b1),
                               .reset_n,
										// [i]=f_x_dest[i]=$urandom_range(`X_NODES-1, 0);
                               .i_data(s_i_data[i]),         // From the simulated input data
                               .i_data_val(1'b1), // From the simulated input data
                               .i_en(o_en[i]),               // From the Router
                               .o_data(i_data[i]),           // To the Router
                               .o_data_val(l_i_data_val[i]), // To the Router
                               .o_en(f_full[i]));            // Used to indicate router saturation
    end
  endgenerate
  
  // Check for an output enable before raising valid
  always_comb begin
    i_data_val = '0;
    for(int i=0; i<`NODES; i++) begin
      i_data_val[i] = l_i_data_val[i] && o_en[i];  //to network
    end
  end
    
  // --------------------------------------------------------------------------------------------------------------------
  // RANDOM DATA GENERATION
  // --------------------------------------------------------------------------------------------------------------------
  // The random data generation consists of two parts, random flag generation, and the population of the data.  A valid
  // bit and random node address are generated each cycle as flags.  When populating input data, these flags can be
  // sampled as and when required.  The data generation has been split this way to enable easier editing of the composite
  // parts.  For example, creating a new random traffic pattern would require only the valid bit to be worked on, and the
  // rest can remain the same.
  // --------------------------------------------------------------------------------------------------------------------
  
  // RANDOM FLAG:  Destination
  // ------------------------------------------------------------------------------------------------------------------
  always_ff@(posedge clk) begin
    if(~reset_n) begin
      for(int i=0; i<`NODES; i++) begin
          f_x_dest[i] <= 0;
          f_y_dest[i] <= 0;
      end
    end else begin
      for(int i=0; i<`NODES; i++) begin
          f_x_dest[i] <= $urandom_range(`X_NODES-1, 0);
          f_y_dest[i] <= $urandom_range(`Y_NODES-1, 0);
      end
    end
  end
  
  // RANDOM FLAG:  Valid (Bernoulli) and bursty (fixed burst size)
  // ------------------------------------------------------------------------------------------------------------------ 
  always_ff@(posedge clk) begin
    if(~reset_n) begin
      for(int i=0; i<`NODES; i++) begin
        f_data_val[i] <= 0;
      end
    end else begin
      for(int i=0; i<`NODES; i++) begin
        f_data_val[i] <= ($urandom_range(100,1) <= PACKET_RATE) ? 1'b1 : 1'b0;
      end
    end
  end
  
  // RANDOM DATA GENERATION:  Populate input data
  // ------------------------------------------------------------------------------------------------------------------  
  always_ff@(posedge clk) begin
      if(~reset_n) begin
          for (int y = 0; y < `Y_NODES; y++) begin
            for (int x = 0; x < `X_NODES; x++) begin
              s_i_data[y *`X_NODES + x].x_source <= x; // Source field used to declare which input port packet was presented to
              s_i_data[y*`X_NODES + x].y_source <= y; // Source field used to declare which input port packet was presented to
              s_i_data[y*`X_NODES + x].x_dest <= 0; // Destination field indicates where packet is to be routed to
              s_i_data[y*`X_NODES + x].y_dest <= 0; // Destination field indicates where packet is to be routed to 
            end
          end
      end else begin
        for(int i=0; i<`NODES; i++) begin
          s_i_data[i].x_dest <= f_x_dest[i];
          s_i_data[i].y_dest <= f_y_dest[i];

          s_i_data[i].backward <= 0;
          s_i_data[i].x_memory <= 0;
          s_i_data[i].y_memory <= 0;
          s_i_data[i].num_memories <= 0;
			 
          if (f_time % `CREATE_ANT_PERIOD == 0)
				s_i_data[i].ant <= 1;
          else
				s_i_data[i].ant <= 0;
        end
      end
    end
  
  // TEST FUNCTION:  TX and RX Packet Counters
  // ------------------------------------------------------------------------------------------------------------------ 
  always_ff@(negedge clk) begin
    if(~reset_n) begin
      for(int i=0; i<`NODES; i++) begin
        f_port_s_i_data_count[i] <= 0;
        f_port_i_data_count[i] <= 0;
        f_port_o_data_count[i] <= 0;
      end          
    end else begin
      for(int i=0; i<`NODES; i++) begin
        f_port_s_i_data_count[i] <= f_port_s_i_data_count[i] + 1 ;
        f_port_i_data_count[i] <= i_data_val[i] && o_en[i] ? f_port_i_data_count[i] + 1 : f_port_i_data_count[i];
        f_port_o_data_count[i] <= o_data_val[i] ? f_port_o_data_count[i] + 1 : f_port_o_data_count[i];
     end
    end
  end
  
  always_comb begin
    f_total_s_i_data_count = 0;   
    f_total_i_data_count = 0;
    f_total_o_data_count = 0;
    for (int i=0; i<`NODES; i++) begin
      f_total_s_i_data_count = f_port_s_i_data_count[i] + f_total_s_i_data_count;
      f_total_i_data_count = f_port_i_data_count[i]   + f_total_i_data_count;
      f_total_o_data_count = f_port_o_data_count[i] + f_total_o_data_count;    
    end
  end

  initial begin
	 #100000 $finish;
  end

  initial begin
    $display("");

    forever@(posedge clk) begin
        if(f_time % 100 == 0) begin
            $display("f_time %g:  Transmitted %g packets, Received %g packets", f_time, f_total_i_data_count, f_total_o_data_count);
        end
    end
  end

endmodule
