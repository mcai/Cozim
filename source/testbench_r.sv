`timescale 1ps/1ps

`include "config.sv"

module testbench_r
#(
  parameter integer X = 2,
  parameter integer Y = 1,
  parameter CLK_PERIOD = 5,
  parameter integer PACKET_RATE = 30 // Offered traffic as percent of capacity
  
//  parameter integer WARMUP_PACKETS = 1000, // Number of packets to warm-up the network
//  parameter integer MEASURE_PACKETS = 5000, // Number of packets to be measured
//  parameter integer DRAIN_PACKETS = 3000, // Number of packets to drain the network
  
//  parameter integer DOWNSTREAM_EN_RATE = 100, // Percent of time simulated nodes able to receive data
//  parameter integer NODE_QUEUE_DEPTH = `INPUT_QUEUE_DEPTH * 8
);

  logic clk;
  logic reset_n;

  // FLAGS:  Random
  // ------------------------------------------------------------------------------------------------------------------   
  logic [0:`N-1] f_data_val;

  logic [0:`N-1][$clog2(`X_NODES+1)-1:0] f_x_src;
  logic [0:`N-1][$clog2(`Y_NODES+1)-1:0] f_y_src;

  logic [0:`N-1][$clog2(`X_NODES+1)-1:0] f_x_dest;  // l_i_data[i].x_dest=f_x_dest[i]=$urandom_range(`X_NODES-1, 0);
  logic [0:`N-1][$clog2(`Y_NODES+1)-1:0] f_y_dest;  //l_i_data[i].y_dest=f_y_dest[i]=$urandom_range(`Y_NODES-1, 0);
  
  // FLAGS:  Control
  // ------------------------------------------------------------------------------------------------------------------
  // Pseudo time value/clock counter
  longint f_time;
  
  integer f_port_t_data_count [0:`N-1];   // Count number of packets simulated and added to the node queues
  integer f_port_i_data_count [0:`N-1];   // Count number of packets that left the node, transmitted on each port
  integer f_port_o_data_count [0:`M-1];   // Count number of received packets on each port
  
  integer f_total_t_data_count;            // Count total number of simulated packets
  integer f_total_i_data_count;              // Count total number of transmitted packets
  integer f_total_o_data_count;              // Count total number of received packets
  
  // ------------------------------------------------------------------------------------------------------------------

  packet_t [0:`N-1] l_i_data;
  logic [0:`N-1] l_i_data_val;
  logic [0:`N-1] l_o_en;

  packet_t [0:`M-1] l_o_data;
  logic [0:`M-1] l_o_data_val;
  //logic [0:`M-1] l_i_en;
  
  // SCtoFF------------------------------------------------------------------------------------------------------------------
  logic [0:`N-1] test_en_SCtoFF; 
  // FFtoAA------------------------------------------------------------------------------------------------------------------
  packet_t [0:`N-1] test_data_FFtoAA; 
  logic [0:`N-1] test_data_val_FFtoAA; 
  // AAtoSW------------------------------------------------------------------------------------------------------------------
  packet_t [0:`N-1] test_data_AAtoSW;
  // AAtoRC------------------------------------------------------------------------------------------------------------------
  logic [0:`N-1] test_data_val_AAtoRC;
  logic [0:`N-1][0:`M-1] test_output_req_AAtoRC;
  // RCtoSC------------------------------------------------------------------------------------------------------------------
  logic [0:`N-1][0:`M-1] test_output_req_RCtoSC;
  // SC------------------------------------------------------------------------------------------------------------------
  logic [0:`N-1][0:`M-1] test_l_req_matrix_SC;
  
  
  logic [0:`N-1] test_update;
  logic [0:`N-1] test_calculate_neighbor;
  //logic [$clog2(`N):0] test_parent; //=i
  logic [0:`N-1][0:`M-1] test_r_o_output_req;
  
  logic [0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones;
  logic [0:`PH_TABLE_DEPTH-1] test_max_pheromone_value;
  logic [0:`PH_TABLE_DEPTH-1] test_min_pheromone_value;
  
    router #(.X_LOC(X), .Y_LOC(Y))
      gen_router (
                   .clk(clk),
                   .reset_n(reset_n),
                   .i_data(l_i_data),          // From the upstream routers and nodes
                   .i_data_val(l_i_data_val),  // From the upstream routers and nodes
                   .o_en(l_o_en),              // To the upstream routers
                   .o_data(l_o_data),         // To the downstream routers
                   .o_data_val(l_o_data_val), // To the downstream routers
                   .i_en(5'b11111),             // From the downstream routers
                   
                   .test_en_SCtoFF(test_en_SCtoFF), // Inputs an enable, if high on a clock edge, o_data was read from memory
                   
                   .test_data_FFtoAA(test_data_FFtoAA), // Input data from upstream [local, north, east, south, west]
                   .test_data_val_FFtoAA(test_data_val_FFtoAA), // Validates data from upstream [local, north, east, south, west]
                   
                   .test_data_AAtoSW(test_data_AAtoSW),
                   
                   .test_data_val_AAtoRC(test_data_val_AAtoRC),
                   .test_output_req_AAtoRC(test_output_req_AAtoRC),
						 
                   .test_output_req_RCtoSC(test_output_req_RCtoSC),
						 
                   .test_l_req_matrix_SC(test_l_req_matrix_SC),
				  
  .test_update(test_update),
  .test_calculate_neighbor(test_calculate_neighbor),
  //.test_parent(test_parent), //=i
  .test_r_o_output_req(test_r_o_output_req),
  
  .test_pheromones(test_pheromones),
  .test_max_pheromone_value(test_max_pheromone_value),
  .test_min_pheromone_value(test_min_pheromone_value)
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
      for(int i=0; i<`N; i++) begin
          f_x_src[i] <= 0;
          f_y_src[i] <= 0;
          f_x_dest[i] <= 0;
          f_y_dest[i] <= 0;
      end
    end else begin
          f_x_src[0] <= X;
          f_y_src[0] <= Y;
          f_x_dest[0] <= $urandom_range(`X_NODES-1, 0);
          f_y_dest[0] <= $urandom_range(`Y_NODES-1, 0);

          f_x_src[1] <= $urandom_range(`X_NODES-1, 0);
          f_y_src[1] <= $urandom_range(`Y_NODES-1, Y+1);
          f_x_dest[1] <= X;
          f_y_dest[1] <= $urandom_range(Y, 0);

          f_x_src[2] <= $urandom_range(`X_NODES-1, X+1);
          f_y_src[2] <= Y;
          f_x_dest[2] <= $urandom_range(X, 0);
          f_y_dest[2] <= $urandom_range(`Y_NODES-1, 0);

          f_x_src[3] <= $urandom_range(`X_NODES-1, 0);
          f_y_src[3] <= $urandom_range(Y-1, 0);
          f_x_dest[3] <= X;
          f_y_dest[3] <= $urandom_range(`Y_NODES-1, Y);

          f_x_src[4] <= $urandom_range(X-1, 0);
          f_y_src[4] <= Y;
          f_x_dest[4] <= $urandom_range(`X_NODES-1, X);
          f_y_dest[4] <= $urandom_range(`Y_NODES-1, 0);
    end
  end
  
  // RANDOM FLAG:  Valid (Bernoulli) and bursty (fixed burst size)
  // ------------------------------------------------------------------------------------------------------------------ 
  always_ff@(posedge clk) begin
    if(~reset_n) begin
      for(int i=0; i<`N; i++) begin
        f_data_val[i] <= 0;
      end
    end else begin
      for(int i=0; i<`N; i++) begin
        f_data_val[i] <= ($urandom_range(100,1) <= PACKET_RATE) ? 1'b1 : 1'b0;
      end
    end
  end
  
  // RANDOM DATA GENERATION:  Populate input data
  // ------------------------------------------------------------------------------------------------------------------  
  always_ff@(posedge clk) begin
      if(~reset_n) begin
         for (int i = 0; i < `N; i++) begin
            l_i_data_val[i] <= 0;
				
            l_i_data[i].x_source <= '0; // Source field used to declare which input port packet was presented to
            l_i_data[i].y_source <= '0; // Source field used to declare which input port packet was presented to
            l_i_data[i].x_dest <= '0; // Destination field indicates where packet is to be routed to
            l_i_data[i].y_dest <= '0; // Destination field indicates where packet is to be routed to 
				
				l_i_data[i].ant <= 0;
	         l_i_data[i].backward <= 0;
				
            l_i_data[i].x_memory <= '0;
            l_i_data[i].y_memory <= '0;
            l_i_data[i].num_memories <= '0;
         end
      end else begin
        for(int i=0; i<`N; i++) begin
          l_i_data_val[i] <= f_data_val[i];
			 
          l_i_data[i].x_source <= f_x_src[i];
          l_i_data[i].y_source <= f_y_src[i];
          l_i_data[i].x_dest <= f_x_dest[i];
          l_i_data[i].y_dest <= f_y_dest[i];
          			 
          if (f_time % `CREATE_ANT_PERIOD == 0)begin
	         l_i_data[i].ant <= 1;
          end else begin
	         l_i_data[i].ant <= 0;
			 end
        end
      end
    end
  
  // TEST FUNCTION:  TX and RX Packet Counters
  // ------------------------------------------------------------------------------------------------------------------ 
  always_ff@(negedge clk) begin
    if(~reset_n) begin
      for(int i=0; i<`N; i++) begin
        f_port_t_data_count[i] <= 0;
        f_port_i_data_count[i] <= 0;
        f_port_o_data_count[i] <= 0;
      end          
    end else begin
      for(int i=0; i<`N; i++) begin
        f_port_t_data_count[i] <= f_port_t_data_count[i] + 1 ;
        f_port_i_data_count[i] <= l_i_data_val[i] ? f_port_i_data_count[i] + 1 : f_port_i_data_count[i];
        f_port_o_data_count[i] <= l_o_data_val[i] ? f_port_o_data_count[i] + 1 : f_port_o_data_count[i];
     end
    end
  end
  
  always_comb begin
    f_total_t_data_count = 0;   
    f_total_i_data_count = 0;
    f_total_o_data_count = 0;

    for (int i=0; i<`N; i++) begin
      f_total_t_data_count = f_port_t_data_count[i] + f_total_t_data_count;
      f_total_i_data_count = f_port_i_data_count[i] + f_total_i_data_count;
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
            $display("f_time %g:  Transmitted %g packets, Received %g packets   0:%g  1:%g  2:%g  3:%g  4:%g",
				                                               f_time, f_total_i_data_count, f_total_o_data_count,
				f_port_o_data_count[0],f_port_o_data_count[1],f_port_o_data_count[2],f_port_o_data_count[3],f_port_o_data_count[4]);
        end
    end
  end

endmodule

