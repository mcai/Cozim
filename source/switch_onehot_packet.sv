`include "config.sv"

// NxM packet_t CrossBar Switch.
module switch_onehot_packet
(
  input  logic [0:`M-1][0:`N-1] i_sel, // Output ports select an input port according to a 5 bit packed number
  input  packet_t [0:`N-1] i_data, // Data in

  output packet_t [0:`M-1] o_data // Data out
);

  packet_t [0:`M-1] l_data; // Used for pipelining

  // Crossbar Switch.  Input selection is onehot.
  always_comb begin
    l_data = '0;
    for(int i=0; i<`M; i++) begin
      // compare i_sel with a one hot word to determine which input is required
      for(int j=0; j<`N; j++) begin
        if(i_sel[i] == (1<<(`N-1)-j)) l_data[i] = i_data[j];
      end
    end
  end

  // Pipeline control.
  assign o_data = l_data;

endmodule
