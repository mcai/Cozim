`timescale 1ps/1ps

`include "config.sv"

module testbench_n
#(
  parameter CLK_PERIOD = 5,
  parameter integer PACKET_RATE = 20, // Offered traffic as percent of capacity
  
  //parameter integer WARMUP_PACKETS = 1000, // Number of packets to warm-up the network
  //parameter integer MEASURE_PACKETS = 5000, // Number of packets to be measured
  //parameter integer DRAIN_PACKETS = 3000, // Number of packets to drain the network
  
  //parameter integer DOWNSTREAM_EN_RATE = 100, // Percent of time simulated nodes able to receive data
  parameter integer NODE_QUEUE_DEPTH = `INPUT_QUEUE_DEPTH * 8
);

  logic clk;
  logic reset_n;
 
  packet_t [0:`NODES-1] l_data_FFtoN; // fifo.o_data -> network.i_data 
  logic [0:`NODES-1] n_i_data_val; // f_o_data_val && o_en -> network.i_data_val
  logic [0:`NODES-1] n_o_en; // network.o_en -> fifo.i_en and i_data_val:1
  
  //logic [0:`NODES-1] i_en; // 1 -> none
  packet_t [0:`NODES-1] n_o_data; // network.o_data -> none
  logic [0:`NODES-1] n_o_data_val; // network.o_data_val -> none
  
  // ------------------------------------------------------------------------------------------------------------------
  packet_t [0:`NODES-1] f_i_data;  // (f_x_dest, f_y_dest) -> f_i_data -> fifo.i_data
  logic [0:`NODES-1] f_i_data_val;
  logic [0:`NODES-1] f_o_data_val; // fifo.o_data_val -> f_o_data_val -> l_data_val:2
  logic [0:`NODES-1] f_o_full_n;  // fifo.o_en -> fo_full_n -> none
  
  // ------------------------------------------------------------------------------------------------------------------   
  logic [0:`NODES-1] f_data_val;
  logic [0:`NODES-1][$clog2(`X_NODES)-1:0] f_x_dest;  // f_i_data[i].x_dest=f_x_dest[i]=$urandom_range(`X_NODES-1, 0);
  logic [0:`NODES-1][$clog2(`Y_NODES)-1:0] f_y_dest;  //f_i_data[i].y_dest=f_y_dest[i]=$urandom_range(`Y_NODES-1, 0);
  
  // FLAGS:  Control
  // ------------------------------------------------------------------------------------------------------------------
  // Pseudo time value/clock counter
  longint f_time;
  
  integer f_port_f_data_count [0:`NODES-1]; // Count number of packets simulated and added to the node queues
  integer f_port_i_data_count [0:`NODES-1];   // Count number of packets that left the node, transmitted on each port
  integer f_port_o_data_count [0:`NODES-1];   // Count number of received packets on each port
  integer f_total_f_data_count;            // Count total number of simulated packets
  integer f_total_i_data_count;              // Count total number of transmitted packets
  integer f_total_o_data_count;              // Count total number of received packets
  
  
  logic [0:`NODES-1][0:`N-1] test_en_SCtoFF;
  
  packet_t [0:`NODES-1][0:`N-1] test_data_FFtoAA;
  logic [0:`NODES-1][0:`N-1] test_data_val_FFtoAA;
  
  packet_t [0:`NODES-1][0:`N-1] test_data_AAtoSW;
  
  logic [0:`NODES-1][0:`N-1] test_data_val_AAtoRC;
  logic [0:`NODES-1][0:`N-1][0:`M-1] test_output_req_AAtoRC;
  
  logic [0:`NODES-1][0:`N-1][0:`M-1] test_output_req_RCtoSC;
  
  logic [0:`NODES-1][0:`N-1][0:`M-1] test_l_req_matrix_SC;
  
  logic [0:`NODES-1][0:`N-1] test_update;
  logic [0:`NODES-1][0:`N-1] test_calculate_neighbor;
  //logic [$clog2(`N):0] test_parent; //=i
  logic [0:`NODES-1][0:`N-1][0:`M-1] test_r_o_output_req;
  
  logic [0:`NODES-1][0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones;
  logic [0:`NODES-1][0:`PH_TABLE_DEPTH-1] test_max_pheromone_value;
  logic [0:`NODES-1][0:`PH_TABLE_DEPTH-1] test_min_pheromone_value;
  
  network network(
						.clk(clk), 
						.reset_n(reset_n), 
						.i_data(l_data_FFtoN), 
						.i_data_val(n_i_data_val),  //[i] = f_o_data_val[i] && o_en[i];
						.o_en(n_o_en),
						.o_data(n_o_data),
						.o_data_val(n_o_data_val),
						
    .test_en_SCtoFF(test_en_SCtoFF),
  
    .test_data_FFtoAA(test_data_FFtoAA),
    .test_data_val_FFtoAA(test_data_val_FFtoAA), 
  
    .test_data_AAtoSW(test_data_AAtoSW),
  
    .test_data_val_AAtoRC(test_data_val_AAtoRC),
    .test_output_req_AAtoRC(test_output_req_AAtoRC),
  
    .test_output_req_RCtoSC(test_output_req_RCtoSC),
  
    .test_l_req_matrix_SC(test_l_req_matrix_SC),//SC
	  
				  
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

  // SIMULATION:  Node TX
  // ------------------------------------------------------------------------------------------------------------------
  genvar i;
  generate
    for (i=0; i<`NODES; i++) begin : GENERATE_INPUT_QUEUES
      fifo_packet #(.DEPTH(NODE_QUEUE_DEPTH))
        gen_fifo_packet (.clk,
                               .ce(1'b1),
                               .reset_n,
                               .i_data(f_i_data[i]),      
                               .i_data_val(f_i_data_val[i]),                //f_data_val[i]
                               .i_en(n_o_en[i]),
                               .o_data(l_data_FFtoN[i]),         //i_data
                               .o_data_val(f_o_data_val[i]), //f_o_data_val
                               .o_en(f_o_full_n[i]));            
    end
  endgenerate
  
  // Check for an output enable before raising valid
  always_comb begin
    //n_i_data_val = '0;
    for(int i=0; i<`NODES; i++) begin
      n_i_data_val[i] = f_o_data_val[i] && n_o_en[i];  //to network
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
			   f_i_data_val[y*`X_NODES + x] <= 0;
			   
            f_i_data[y*`X_NODES + x].x_source <= x; 
            f_i_data[y*`X_NODES + x].y_source <= y; 
            f_i_data[y*`X_NODES + x].x_dest <= 0; 
            f_i_data[y*`X_NODES + x].y_dest <= 0; 
				
			   f_i_data[y*`X_NODES + x].ant <= 0;
				f_i_data[y*`X_NODES + x].backward <= 0;
				
            f_i_data[y*`X_NODES + x].x_memory <= 0;
            f_i_data[y*`X_NODES + x].y_memory <= 0;
            f_i_data[y*`X_NODES + x].num_memories <= 0;
          end
        end
      end else begin
        for(int i=0; i<`NODES; i++) begin
          f_i_data[i].x_dest <= f_x_dest[i];
          f_i_data[i].y_dest <= f_y_dest[i];
	 
          /*if (f_time % `CREATE_ANT_PERIOD == 0)begin
				f_i_data_val[i] <= 1;
				f_i_data[i].ant <= 1;
          end else begin*/
				f_i_data_val[i] <= f_data_val[i];
				f_i_data[i].ant <= 0;
			 //end
        end
      end
  end
  
  // TEST FUNCTION:  TX and RX Packet Counters
  // ------------------------------------------------------------------------------------------------------------------ 
  always_ff@(negedge clk) begin
    if(~reset_n) begin
      for(int i=0; i<`NODES; i++) begin
        f_port_f_data_count[i] <= 0;
        f_port_i_data_count[i] <= 0;
        f_port_o_data_count[i] <= 0;
      end          
    end else begin
      for(int i=0; i<`NODES; i++) begin
        f_port_f_data_count[i] <= f_port_f_data_count[i] + 1 ;
        f_port_i_data_count[i] <= n_i_data_val[i] /*&& n_o_en[i]*/ ? f_port_i_data_count[i] + 1 : f_port_i_data_count[i];
        f_port_o_data_count[i] <= n_o_data_val[i] ? f_port_o_data_count[i] + 1 : f_port_o_data_count[i];
     end
    end
  end
  
  always_comb begin
    f_total_f_data_count = 0;   
    f_total_i_data_count = 0;
    f_total_o_data_count = 0;
    for (int i=0; i<`NODES; i++) begin
      f_total_f_data_count = f_port_f_data_count[i] + f_total_f_data_count;
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
            $display("f_time %g:  Transmitted %g packets,  Received %g packets   0:%g  1:%g  2:%g  3:%g  %g:%g",
  				          f_time,     f_total_i_data_count,    f_total_o_data_count,
				  f_port_o_data_count[0],f_port_o_data_count[1],f_port_o_data_count[2],f_port_o_data_count[3],`NODES,f_port_o_data_count[`NODES-1]);
        end
    end
  end

endmodule
