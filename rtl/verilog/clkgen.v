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
	output	sdram_rst_o,

	output  sdram_clk_pad_o,
);

// First, deal with the asychronous reset
wire	async_rst;
wire	async_rst_n;

assign	async_rst_n  = rst_n_pad_i;
assign	async_rst  = ~async_rst_n;

// Everyone likes active-high reset signals...
assign	async_rst_o = ~async_rst_n;
wire clkop;
(* ICP_CURRENT = "12", LPF_RESISTOR = "8", MFG_ENABLE_FILTEROPAMP = "1", MFG_GMCREF_SEL = "2" *) EHXPLLL #(
	.CLKFB_DIV(1),
	.CLKI_DIV(2),
	.CLKOP_CPHASE(11),
	.CLKOP_DIV(12),
	.CLKOP_ENABLE("ENABLED"),
	.CLKOP_FPHASE(0),
	.CLKOS_CPHASE(12),
	.CLKOS_DIV(12),
	.CLKOS_ENABLE("ENABLED"),
	.CLKOS_FPHASE(4),
	.CLKOS2_CPHASE(11),
	.CLKOS2_DIV(12),
	.CLKOS2_ENABLE("ENABLED"),
	.CLKOS2_FPHASE(0),
	.FEEDBK_PATH("CLKOP"),
	.OUTDIVIDER_MUXA("DIVA"),
	.OUTDIVIDER_MUXB("DIVB"),
	.OUTDIVIDER_MUXC("DIVC"),
	.PLL_LOCK_MODE(1'd0)
) EHXPLLL_i (
	.CLKFB(clkop),
	.CLKI(sys_clk_pad_i),
	.ENCLKOP(1'd0),
	.ENCLKOS(1'd0),
	.ENCLKOS2(1'd0),
	.PHASEDIR(1'd0),
	.PHASELOADREG(1'd0),
	.PHASESEL0(1'd0),
	.PHASESEL1(1'd0),
	.PHASESTEP(1'd0),
	.PLLWAKESYNC(1'd0),
	.RST(1'd0),
	.STDBY(1'd0),
	.CLKOP(clkop),
	.CLKOS(wb_clk_o),
	.CLKOS2(sdram_clk_pad_o),
	.LOCK()
);

//
// Declare synchronous reset wires here
//

// An active-low synchronous reset signal (usually a PLL lock signal)
wire   sync_rst_n;

wire   pll_lock;


assign pll_lock = 1'b1;
assign sync_rst_n = pll_lock;

assign sdram_clk_o = wb_clk_o;

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
