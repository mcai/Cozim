`include "config.sv"

module ant_agent
#(
  parameter integer X_LOC, // Current location on the X axis
  parameter integer Y_LOC // Current location on the Y axis
)
(  
  input packet_t [0:`N-1] i_data, // Data in
  input logic [0:`N-1] i_data_val, // Data in valid
  output packet_t [0:`M-1] o_data, // Data out
  output logic [0:`N-1] o_data_val, // Data out valid
  output logic [0:`N-1][`M-1:0] o_output_req //[i]=l_next_output
);

  packet_t [0:`N-1] l_data; // Data in

  ant_routing_table
       routing_table(
          .i_update_signal(l_update_signal),//logic
          .i_calculate_neighbor(l_calculate_neighbor),//logic
          .i_dest(l_dest),//logic [0:`N-1]
                          //l_dest=l_data[i].y_dest*8+l_data[i].x_dest;
          .i_parent(l_parent),//logic [0:`N-1]
                                //l_parent=i;
          .o_next_output(l_next_output_temp)//logic [0:`N-1]
                                            //l_next_output=l_next_output_temp
       );
  logic l_update_signal;
  logic l_calculate_neighbor;
  logic [$clog2(`NODES)-1:0] l_dest;
  logic [0:`N-1] l_parent;//=i
  logic [0:`N-1] l_next_output;//=l_next_output_temp
  logic [0:`N-1] l_next_output_temp;
  logic [$clog2(`X_NODES)-1:0] l_x_temp;
  logic [$clog2(`Y_NODES)-1:0] l_y_temp;
  
  always_comb begin
    l_data = '0;
    o_output_req='0;
    o_data_val='0;

    l_update_signal='0;
    l_calculate_neighbor='0;
    l_dest=Y_LOC*8+X_LOC;
    l_parent='0;
    l_next_output='0;
	 l_next_output_temp='0;
	 l_x_temp='0;
	 l_y_temp='0;

    for(int i=0; i<`N; i++) begin//i=0,1,2,..,`N

    //// have data
      if(i_data_val[i]) begin

        //// save data
        l_data[i] = i_data[i];

        //// normal packet
        if(~l_data[i].ant) begin

          ///LOC!=dest:
          if(X_LOC != l_data[i].x_dest || Y_LOC != l_data[i].y_dest) begin 
            //send normal packet: 1.calculate_neighbor(l_dest,l_parent) 2.l_next_output=l_next_output_temp
            l_dest=l_data[i].y_dest*8+l_data[i].x_dest;
            l_parent=i;
            l_calculate_neighbor=1;//1.calculate_neighbor
              //  delay???
            l_next_output=l_next_output_temp;//2.l_next_output=l_next_output_temp

          //LOC==dest:
          end else begin
            l_next_output=5'b10000;
          end

        //// ant packet
        end else begin

	  //// forward ant packet
          if(~l_data[i].backward) begin

            /// LOC!=dest: memorize & send forward
            if(X_LOC != l_data[i].x_dest || Y_LOC != l_data[i].y_dest) begin

              // memorize:
	      l_data[i].x_memory[l_data[i].num_memory] = X_LOC;
              l_data[i].y_memory[l_data[i].num_memory] = Y_LOC;
              l_data[i].num_memory++;

              // send forward ant packet: 1.calculate_neighbor(l_dest,l_parent) 2.l_next_output=l_next_output_temp
              l_dest=l_data[i].y_dest*8+l_data[i].x_dest;
              l_parent=i;
              l_calculate_neighbor=1;//1.calculate_neighbor
              // delay???
              l_next_output=l_next_output_temp;//2.l_next_output=l_next_output_temp

            /// LOC==dest: create_&_send_backward_ant_packet
            end else begin

              // create backward:
              l_data[i].backward = 1'b1;		 
              l_x_temp = l_data[i].x_source;
              l_y_temp = l_data[i].y_source;
              l_data[i].x_source = l_data[i].x_dest;
              l_data[i].y_source = l_data[i].y_dest;
              l_data[i].x_dest = l_x_temp;
              l_data[i].y_dest = l_y_temp;
	
	      // send backward ant packet (give next_output to RC):
              if(l_data[i].x_memory[l_data[i].num_memory] != X_LOC) 
                l_next_output = (l_data[i].x_memory[l_data[i].num_memory] > X_LOC) ? 2 : 4;// 5'b00100 : 5'b00001;
              else     //if (l_data[i].y_memory[i-1] != Y_LOC)
                l_next_output = (l_data[i].y_memory[l_data[i].num_memory] > Y_LOC) ? 1 : 3;// 5'b01000 : 5'b00010;
            end		

	  //// backward ant packet	  
          end else begin
                         
            // update pheromomnes( ph[dest][next_output]++,ph[dest][other]-- ):
            l_dest=l_data[i].y_dest*8+l_data[i].x_dest;
            l_parent=i;
            l_update_signal=1;

            /// LOC!=dest: memorize & send forward
            if(X_LOC != l_data[i].x_dest || Y_LOC != l_data[i].y_dest) begin
              // send backward ant packet (give next_output to RC) && next_output= :
            
              if (l_data[i].x_memory[0]==X_LOC && l_data[i].y_memory[0]==Y_LOC) begin
                //o_output_req = dest
                if(l_data[i].x_dest != X_LOC) 
                  l_next_output = (l_data[i].x_dest > X_LOC) ? 5'b00100 : 5'b00001;//2 : 4;
                else     //if (i_ant_y_dest != Y_LOC)
                  l_next_output = (l_data[i].y_dest > Y_LOC) ? 5'b01000 : 5'b00010;//1 : 3;
              end else begin
                //o_output_req is in memory
                for(int m=1;m<l_data[i].num_memory;m++) begin
                  if (l_data[i].x_memory[m]==X_LOC && l_data[i].y_memory[m]==Y_LOC) begin
                    if(l_data[i].x_memory[m-1] != X_LOC) 
                      l_next_output = (l_data[i].x_memory[m-1] > X_LOC) ? 5'b00100 : 5'b00001;//2 : 4;
                    else //if (l_data[i].y_memory[i-1] != Y_LOC)
                      l_next_output = (l_data[i].y_memory[m-1] > Y_LOC) ? 5'b01000 : 5'b00010;//1 : 3;
                  end
                end
              end //else raise extremely异常

            /// LOC==dest:
            end else begin
              l_next_output=5'b10000;//?? need to destroy
            end

          end //backward ant packet

        end //ant data
        o_output_req[i]=l_next_output;
        o_data_val[i]=1'b1;
      end //if(i_data_val[i])
    end //for
  end //always_comb
 
  function memorize
  (
    input a, b, c, d,
	 output myfunction
  );
    begin
      myfunction = ((a+b) + (c-d));
    end
  endfunction

  // Pipeline control.
  assign o_data = l_data;

endmodule
