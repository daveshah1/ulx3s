//////////////////////////////////////////////////////////////////////
//
// clkgen
//
// Handles clock and reset generation for rest of design
//
//
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2009, 2010 Authors and OPENCORES.ORG           ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "orpsoc-defines.v"

module clkgen
(
	// Main clocks in, depending on board
	input	sys_clk_pad_i,
	// Asynchronous, active low reset in
	input	rst_n_pad_i,
	// Input reset - through a buffer, asynchronous
	output	async_rst_o,

	// Wishbone clock and reset out
	output	wb_clk_o,
	output	wb_rst_o,

	// Main memory clocks
	output	sdram_clk_o,
	output	sdram_rst_o
);

// First, deal with the asychronous reset
wire	async_rst;
wire	async_rst_n;

assign	async_rst_n  = rst_n_pad_i;
assign	async_rst  = ~async_rst_n;

// Everyone likes active-high reset signals...
assign	async_rst_o = ~async_rst_n;

// No PLL support - phase shift SDRAM clk using LUTs :vomit:
/*
localparam sdram_shift_count  = 5;
wire [sdram_shift_count:0] sdram_clk_shift;
assign sdram_clk_shift[0] = sys_clk_pad_i;

generate
	genvar ii;
	for (ii = 0; ii < sdram_shift_count; ii=ii+1) begin
		LUT4 #(.INIT(2)) lut4_i (.A(sdram_clk_shift[ii]), .B(1'b0), .C(1'b0), .D(1'b0), .Z(sdram_clk_shift[ii+1]));
	end
endgenerate

assign sdram_clk_o = sdram_clk_shift[sdram_shift_count];
*/
assign sdram_clk_o = sys_clk_pad_i;

//
// Declare synchronous reset wires here
//

// An active-low synchronous reset signal (usually a PLL lock signal)
wire   sync_rst_n;

wire   pll_lock;

assign wb_clk_o = sys_clk_pad_i;
assign pll_lock = 1'b1;
assign sync_rst_n = pll_lock;



//
// Reset generation
//
//

// Reset generation for wishbone
reg [15:0]	wb_rst_shr;

always @(posedge wb_clk_o or posedge async_rst)
	if (async_rst)
		wb_rst_shr <= 16'hffff;
	else
		wb_rst_shr <= {wb_rst_shr[14:0], ~(sync_rst_n)};

assign wb_rst_o = wb_rst_shr[15];


// Reset generation for SDRAM controller
reg [15:0]	sdram_rst_shr;

always @(posedge sdram_clk_o or posedge async_rst)
	if (async_rst)
		sdram_rst_shr <= 16'hffff;
	else
		sdram_rst_shr <= {sdram_rst_shr[14:0], ~(sync_rst_n)};

assign sdram_rst_o = sdram_rst_shr[15];

endmodule // clkgen
