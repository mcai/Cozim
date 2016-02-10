// $Id: vcr_vc_alloc_sep_if.v 5188 2012-08-30 00:31:31Z dub $

/*
 Copyright (c) 2007-2012, Trustees of The Leland Stanford Junior University
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 Redistributions of source code must retain the above copyright notice, this 
 list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this
 list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

//==============================================================================
// VC allocator variant using separable input-first allocation
//==============================================================================

module vcr_vc_alloc_sep_if
  (clk, reset, active_ip, active_op, route_ip_ivc_op, route_ip_ivc_orc, 
   elig_op_ovc, req_ip_ivc, gnt_ip_ivc, sel_ip_ivc_ovc, gnt_op_ovc, 
   sel_op_ovc_ip, sel_op_ovc_ivc);
   
`include "clib/c_functions.sv"
`include "clib/c_constants.sv"
`include "rtr_constants.sv"
`include "vcr_constants.sv"
   
   // number of message classes (e.g. request, reply)
   parameter num_message_classes = 2;
   
   // number of resource classes (e.g. minimal, adaptive)
   parameter num_resource_classes = 2;
   
   // total number of packet classes
   localparam num_packet_classes = num_message_classes * num_resource_classes;
   
   // number of VCs per class
   parameter num_vcs_per_class = 1;
   
   // number of VCs
   localparam num_vcs = num_packet_classes * num_vcs_per_class;
   
   // number of input and output ports on switch
   parameter num_ports = 5;
   
   // select which arbiter type to use in allocator
   parameter arbiter_type = `ARBITER_TYPE_ROUND_ROBIN_BINARY;
   
   parameter reset_type = `RESET_TYPE_ASYNC;
   
   input clk;
   input reset;
   
   // input-side activity indicator
   input [0:num_ports-1] active_ip;
   
   // output-side activity indicator
   input [0:num_ports-1] active_op;
   
   // destination port select
   input [0:num_ports*num_vcs*num_ports-1] route_ip_ivc_op;
   
   // select next resource class
   input [0:num_ports*num_vcs*num_resource_classes-1] route_ip_ivc_orc;
   
   // output VC is eligible for allocation (i.e., not currently allocated)
   input [0:num_ports*num_vcs-1] 		      elig_op_ovc;
   
   // request VC allocation
   input [0:num_ports*num_vcs-1] 		      req_ip_ivc;
   
   // VC allocation successful (to input controller)
   output [0:num_ports*num_vcs-1] 		      gnt_ip_ivc;
   wire [0:num_ports*num_vcs-1] 		      gnt_ip_ivc;
   
   // granted output VC (to input controller)
   output [0:num_ports*num_vcs*num_vcs-1] 	      sel_ip_ivc_ovc;
   wire [0:num_ports*num_vcs*num_vcs-1] 	      sel_ip_ivc_ovc;
   
   // output VC was granted (to output controller)
   output [0:num_ports*num_vcs-1] 		      gnt_op_ovc;
   wire [0:num_ports*num_vcs-1] 		      gnt_op_ovc;
   
   // input port that each output VC was granted to
   output [0:num_ports*num_vcs*num_ports-1] 	      sel_op_ovc_ip;
   wire [0:num_ports*num_vcs*num_ports-1] 	      sel_op_ovc_ip;
   
   // input VC that each output VC was granted to
   output [0:num_ports*num_vcs*num_vcs-1] 	      sel_op_ovc_ivc;
   wire [0:num_ports*num_vcs*num_vcs-1] 	      sel_op_ovc_ivc;
   
   
   generate
      
      genvar 					      mc;
      
      for(mc = 0; mc < num_message_classes; mc = mc + 1)
	begin:mcs
	   
	   //-------------------------------------------------------------------
	   // global wires
	   //-------------------------------------------------------------------
	   
	   wire [0:num_ports*num_resource_classes*num_vcs_per_class*
		 num_ports*num_resource_classes*
		 num_vcs_per_class-1] req_out_ip_irc_icvc_op_orc_ocvc;
	   wire [0:num_ports*num_resource_classes*num_vcs_per_class*
		 num_ports*num_resource_classes*
		 num_vcs_per_class-1] gnt_out_ip_irc_icvc_op_orc_ocvc;
	   
	   
	   //-------------------------------------------------------------------
	   // input stage
	   //-------------------------------------------------------------------
	   
	   genvar ip;
	   
	   for(ip = 0; ip < num_ports; ip = ip + 1)
	     begin:ips
		
		wire [0:num_resource_classes*num_vcs_per_class-1] req_irc_icvc;
		assign req_irc_icvc = req_ip_ivc[(ip*num_message_classes+mc)*
						 num_resource_classes*
						 num_vcs_per_class:
						 (ip*num_message_classes+mc+1)*
						 num_resource_classes*
						 num_vcs_per_class-1];
		
		wire 						  active;
		assign active = active_ip[ip];
		
		genvar 						  irc;
		
		for(irc = 0; irc < num_resource_classes; irc = irc + 1)
		  begin:ircs
		     
		     genvar icvc;
		     
		     for(icvc = 0; icvc < num_vcs_per_class; icvc = icvc + 1)
		       begin:icvcs
			  
			  //----------------------------------------------------
			  // input-side arbitration stage (select output VC)
			  //----------------------------------------------------
			  
			  wire [0:num_ports-1] route_op;
			  assign route_op
			    = route_ip_ivc_op[(((ip*num_message_classes+mc)*
						num_resource_classes+irc)*
					       num_vcs_per_class+icvc)*
					      num_ports:
					      (((ip*num_message_classes+mc)*
						num_resource_classes+irc)*
					       num_vcs_per_class+icvc+1)*
					      num_ports-1];
			  
			  wire [0:num_resource_classes-1] route_orc;
			  
			  if(irc == (num_resource_classes - 1))
			    assign route_orc = 'd1;
			  else
			    assign route_orc
			      = route_ip_ivc_orc[(((ip*num_message_classes+mc)*
						   num_resource_classes+irc)*
						  num_vcs_per_class+icvc)*
						 num_resource_classes:
						 (((ip*num_message_classes+mc)*
						   num_resource_classes+irc)*
						  num_vcs_per_class+icvc+1)*
						 num_resource_classes-1];
			  
			  wire [0:num_vcs-1]   elig_ovc;
			  c_select_1ofn
			    #(.num_ports(num_ports),
			      .width(num_vcs))
			  elig_ovc_sel
			    (.select(route_op),
			     .data_in(elig_op_ovc),
			     .data_out(elig_ovc));
			  
			  wire [0:num_resource_classes*
				num_vcs_per_class-1] elig_orc_ocvc;
			  assign elig_orc_ocvc = elig_ovc[mc*
							  num_resource_classes*
							  num_vcs_per_class:
							  (mc+1)* 
							  num_resource_classes*
							  num_vcs_per_class-1];
			  
			  wire 			     req;
			  assign req = req_irc_icvc[irc*num_vcs_per_class+icvc];
			  
			  wire [0:num_ports*num_resource_classes*
				num_vcs_per_class-1] gnt_out_op_orc_ocvc;
			  assign gnt_out_op_orc_ocvc
			    = gnt_out_ip_irc_icvc_op_orc_ocvc
			      [((ip*num_resource_classes+irc)*
				num_vcs_per_class+icvc)*
			       num_ports*num_resource_classes*
			       num_vcs_per_class:
			       ((ip*num_resource_classes+irc)*
				num_vcs_per_class+icvc+1)*
			       num_ports*num_resource_classes*
			       num_vcs_per_class-1];
			  
			  // NOTE: Logically, what we want to do here is select 
			  // the subvector that corresponds to the current input
			  // VC's selected output port; however, because the 
			  // subvectors for all other ports will never have any 
			  // grants anyway, we can just OR all the subvectors
			  // instead of using a proper MUX.
			  wire [0:num_resource_classes*
				num_vcs_per_class-1] gnt_out_orc_ocvc;
			  c_binary_op
			    #(.num_ports(num_ports),
			      .width(num_resource_classes*num_vcs_per_class),
			      .op(`BINARY_OP_OR))
			  gnt_out_orc_ocvc_or
			    (.data_in(gnt_out_op_orc_ocvc),
			     .data_out(gnt_out_orc_ocvc));
			  
			  wire [0:num_resource_classes*
				num_vcs_per_class-1] gnt_in_orc_ocvc;
			  
			  genvar 		     orc;
			  
			  for(orc = 0; orc < num_resource_classes; 
			      orc = orc + 1)
			    begin:orcs
			       
			       wire [0:num_vcs_per_class-1] elig_ocvc;
			       assign elig_ocvc
				 = elig_orc_ocvc[orc*num_vcs_per_class:
						 (orc+1)*num_vcs_per_class-1];
			       
			       wire 			    route;
			       assign route = route_orc[orc];
			       
			       // Perform input-side arbitration regardless
			       // of whether there was a request; instead, 
			       // requests are subsequently only propagated
			       // to the output stage if there was a 
			       // requests.
			       
			       wire [0:num_vcs_per_class-1] req_ocvc;
			       assign req_ocvc = elig_ocvc;
			       
 			       wire [0:num_vcs_per_class-1] gnt_out_ocvc;
			       assign gnt_out_ocvc
				 = gnt_out_orc_ocvc[orc*
						    num_vcs_per_class:
						    (orc+1)*
						    num_vcs_per_class-1];
			       
			       wire 			    update_arb;
			       assign update_arb = |gnt_out_ocvc;
			       
			       wire [0:num_vcs_per_class-1] gnt_ocvc;
			       c_arbiter
				 #(.num_ports(num_vcs_per_class),
				   .num_priorities(1),
				   .arbiter_type(arbiter_type),
				   .reset_type(reset_type))
			       gnt_ocvc_arb
				 (.clk(clk),
				  .reset(reset),
				  .active(active),
				  .update(update_arb),
				  .req_pr(req_ocvc),
				  .gnt_pr(gnt_ocvc),
				  .gnt());
			       
			       wire [0:num_vcs_per_class-1] gnt_in_ocvc;
			       assign gnt_in_ocvc
				 = {num_vcs_per_class{route}} & gnt_ocvc;
			       
			       assign gnt_in_orc_ocvc[orc*
						      num_vcs_per_class:
						      (orc+1)*
						      num_vcs_per_class-1]
				 = gnt_in_ocvc;
			       
			    end
			  
			  
			  //----------------------------------------------------
			  // generate requests for output stage
			  //----------------------------------------------------
			  
			  wire [0:num_ports*num_resource_classes*
				num_vcs_per_class-1] req_out_op_orc_ocvc;
			  
			  genvar 		     op;
			  
			  for(op = 0; op < num_ports; op = op + 1)
			    begin:ops
			       
			       wire route;
			       assign route = route_op[op];
			       
			       assign req_out_op_orc_ocvc
				 [op*num_resource_classes*
				  num_vcs_per_class:
				  (op+1)*num_resource_classes*
				  num_vcs_per_class-1]
				 = {(num_resource_classes*
				     num_vcs_per_class){req & route}} & 
				   gnt_in_orc_ocvc;
			       
			    end
			  
			  assign req_out_ip_irc_icvc_op_orc_ocvc
			    [((ip*num_resource_classes+irc)*
			      num_vcs_per_class+icvc)*
			     num_ports*num_resource_classes*
			     num_vcs_per_class:
			     ((ip*num_resource_classes+irc)*
			      num_vcs_per_class+icvc+1)*
			     num_ports*num_resource_classes*
			     num_vcs_per_class-1]
			    = req_out_op_orc_ocvc;
			  
			  
			  //----------------------------------------------------
			  // generate global grants
			  //----------------------------------------------------
			  
			  wire [0:num_vcs-1] gnt_out_ovc;
			  c_align
			    #(.in_width(num_resource_classes*num_vcs_per_class),
			      .out_width(num_vcs),
			      .offset(mc*num_resource_classes*
				      num_vcs_per_class))
			  gnt_out_ovc_agn
			    (.data_in(gnt_out_orc_ocvc),
			     .dest_in({num_vcs{1'b0}}),
			     .data_out(gnt_out_ovc));
			  
			  assign sel_ip_ivc_ovc[(((ip*num_message_classes+mc)*
						  num_resource_classes+irc)*
						 num_vcs_per_class+icvc)*
						num_vcs:
						(((ip*num_message_classes+mc)*
						  num_resource_classes+irc)*
						 num_vcs_per_class+icvc+1)*
						num_vcs-1]
			    = gnt_out_ovc;
			  
			  assign gnt_ip_ivc[((ip*num_message_classes+mc)*
					     num_resource_classes+irc)*
					    num_vcs_per_class+icvc]
			    = |gnt_out_ovc;
			  
		       end
		     
		  end
		
	     end
	   
	   
	   //-------------------------------------------------------------------
	   // bit shuffling for changing sort order
	   //-------------------------------------------------------------------
	   
	   wire [0:num_ports*num_resource_classes*num_vcs_per_class*num_ports*
		 num_resource_classes*
		 num_vcs_per_class-1] req_out_op_orc_ocvc_ip_irc_icvc;
	   c_interleave
	     #(.width(num_ports*num_resource_classes*num_vcs_per_class*
		      num_ports*num_resource_classes*num_vcs_per_class),
	       .num_blocks(num_ports*num_resource_classes*num_vcs_per_class))
	   req_out_op_orc_ocvc_ip_irc_icvc_intl
	     (.data_in(req_out_ip_irc_icvc_op_orc_ocvc),
	      .data_out(req_out_op_orc_ocvc_ip_irc_icvc));
	   
	   wire [0:num_ports*num_resource_classes*num_vcs_per_class*num_ports*
		 num_resource_classes*
		 num_vcs_per_class-1] gnt_out_op_orc_ocvc_ip_irc_icvc;
	   c_interleave
	     #(.width(num_ports*num_resource_classes*num_vcs_per_class*
		      num_ports*num_resource_classes*num_vcs_per_class),
	       .num_blocks(num_ports*num_resource_classes*num_vcs_per_class))
	   gnt_out_op_orc_ocvc_ip_irc_iocvc_intl
	     (.data_in(gnt_out_op_orc_ocvc_ip_irc_icvc),
	      .data_out(gnt_out_ip_irc_icvc_op_orc_ocvc));
	   
	   
	   //-------------------------------------------------------------------
	   // output stage
	   //-------------------------------------------------------------------
	   
	   genvar 		      op;
	   
	   for (op = 0; op < num_ports; op = op + 1)
	     begin:ops
		
		wire active;
		assign active = active_op[op];
		
		genvar orc;
		
		for(orc = 0; orc < num_resource_classes; orc = orc + 1)
		  begin:orcs
		     
		     genvar ocvc;
		     
		     for(ocvc = 0; ocvc < num_vcs_per_class; ocvc = ocvc + 1)
		       begin:ocvcs
			  
			  //----------------------------------------------------
			  // output-side arbitration (select input port and VC)
			  //----------------------------------------------------
			  
			  wire elig;
			  assign elig = elig_op_ovc[((op*num_message_classes+
						      mc)*
						     num_resource_classes+orc)*
						    num_vcs_per_class+ocvc];
			  
			  wire [0:num_ports*num_resource_classes*
				num_vcs_per_class-1] req_out_ip_irc_icvc;
			  assign req_out_ip_irc_icvc
			    = req_out_op_orc_ocvc_ip_irc_icvc
			      [((op*num_resource_classes+orc)*
				num_vcs_per_class+ocvc)*
			       num_ports*num_resource_classes*
			       num_vcs_per_class:
			       ((op*num_resource_classes+orc)*
				num_vcs_per_class+ocvc+1)*
			       num_ports*num_resource_classes*
			       num_vcs_per_class-1];
			  
			  wire [0:num_ports-1] 	     req_out_ip;
			  c_reduce_bits
			    #(.num_ports(num_ports),
			      .width(num_resource_classes*num_vcs_per_class),
			      .op(`BINARY_OP_OR))
			  req_out_ip_rb
			    (.data_in(req_out_ip_irc_icvc),
			     .data_out(req_out_ip));
			  
			  wire [0:num_ports-1] 	     gnt_out_ip;
			  wire [0:num_ports*num_resource_classes*
				num_vcs_per_class-1] gnt_out_ip_irc_icvc;
			  
			  wire [0:num_ports*num_vcs-1] gnt_ip_ivc;
			  
			  
			  //----------------------------------------------------
			  // arbitrate between different VCs on each input port
			  //----------------------------------------------------
			  
			  genvar 		       ip;
			  
			  for(ip = 0; ip < num_ports; ip = ip + 1)
			    begin:ips
			       
			       wire [0:num_resource_classes*
				     num_vcs_per_class-1] req_out_irc_icvc;
			       assign req_out_irc_icvc
				 = req_out_ip_irc_icvc[ip*
						       num_resource_classes*
						       num_vcs_per_class:
						       (ip+1)*
						       num_resource_classes*
						       num_vcs_per_class-1];
			       
			       wire 			  update_arb;
			       assign update_arb = gnt_out_ip[ip];
			       
			       wire [0:num_resource_classes*
				     num_vcs_per_class-1] gnt_out_irc_icvc;
			       c_arbiter
				 #(.num_ports(num_resource_classes*
					      num_vcs_per_class),
				   .num_priorities(1),
				   .arbiter_type(arbiter_type),
				   .reset_type(reset_type))
			       gnt_our_irc_icvc_arb
				 (.clk(clk),
				  .reset(reset),
				  .active(active),
				  .update(update_arb),
				  .req_pr(req_out_irc_icvc),
				  .gnt_pr(gnt_out_irc_icvc),
				  .gnt());
			       
			       assign gnt_out_ip_irc_icvc[ip*
							  num_resource_classes*
							  num_vcs_per_class:
							  (ip+1)*
							  num_resource_classes*
							  num_vcs_per_class-1]
				 = gnt_out_irc_icvc & 
				   {(num_resource_classes*
				     num_vcs_per_class){gnt_out_ip[ip]}};
			       
			       wire [0:num_vcs-1] 	  gnt_out_ivc;
			       c_align
				 #(.in_width(num_resource_classes*
					     num_vcs_per_class),
				   .out_width(num_vcs),
				   .offset(mc*num_resource_classes*
					   num_vcs_per_class))
			       gnt_out_ivc_alg
				 (.data_in(gnt_out_irc_icvc),
				  .dest_in({num_vcs{1'b0}}),
				  .data_out(gnt_out_ivc));
			       
			       assign gnt_ip_ivc[ip*num_vcs:(ip+1)*num_vcs-1]
				 = gnt_out_ivc;
			       
			    end
			  
			  wire [0:num_vcs-1] 		  gnt_ivc;
			  c_select_1ofn
			    #(.num_ports(num_ports),
			      .width(num_vcs))
			  gnt_ivc_sel
			    (.select(gnt_out_ip),
			     .data_in(gnt_ip_ivc),
			     .data_out(gnt_ivc));
			  
			  wire 				  req_out;
			  assign req_out = |req_out_ip;
			  
			  wire 				  update_arb;
			  assign update_arb = req_out;
			  
			  c_arbiter
			    #(.num_ports(num_ports),
			      .num_priorities(1),
			      .arbiter_type(arbiter_type),
			      .reset_type(reset_type))
			  gnt_out_ip_arb
			    (.clk(clk),
			     .reset(reset),
			     .active(active),
			     .update(update_arb),
			     .req_pr(req_out_ip),
			     .gnt_pr(gnt_out_ip),
			     .gnt());
			  
			  assign gnt_out_op_orc_ocvc_ip_irc_icvc
			    [((op*num_resource_classes+orc)*
			      num_vcs_per_class+ocvc)*
			     num_ports*num_resource_classes*
			     num_vcs_per_class:
			     ((op*num_resource_classes+orc)*
			      num_vcs_per_class+ocvc+1)*
			     num_ports*num_resource_classes*
			     num_vcs_per_class-1]
			    = gnt_out_ip_irc_icvc;
			  
			  
			  //----------------------------------------------------
			  // generate control signals to output controller
			  //----------------------------------------------------
			  
			  assign gnt_op_ovc[((op*num_message_classes+mc)*
					     num_resource_classes+orc)*
					    num_vcs_per_class+ocvc]
			    = req_out;
			  
			  assign sel_op_ovc_ip[(((op*num_message_classes+mc)*
						 num_resource_classes+orc)*
						num_vcs_per_class+ocvc)*
					       num_ports:
					       (((op*num_message_classes+mc)*
						 num_resource_classes+orc)*
						num_vcs_per_class+ocvc+1)*
					       num_ports-1]
			    = gnt_out_ip;
			  
			  assign sel_op_ovc_ivc[(((op*num_message_classes+mc)*
						  num_resource_classes+orc)*
						 num_vcs_per_class+ocvc)*
						num_vcs:
						(((op*num_message_classes+mc)*
						  num_resource_classes+orc)*
						 num_vcs_per_class+ocvc+1)*
						num_vcs-1]
			    = gnt_ivc;
			  
		       end
		     
		  end
		
	     end
	   
	end
      
   endgenerate
   
endmodule