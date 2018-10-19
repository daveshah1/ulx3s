//////////////////////////////////////////////////////////////////////
//
// ORPSoC top for de0_nano board
//
// Instantiates modules, depending on ORPSoC defines file
//
// Copyright (C) 2013 Stefan Kristiansson
//  <stefan.kristiansson@saunalahti.fi
//
// Based on de1 board by
// Franck Jullien, franck.jullien@gmail.com
// Which probably was based on the or1200-generic board by
// Olof Kindgren, which in turn was based on orpsocv2 boards by
// Julius Baxter.
//
//////////////////////////////////////////////////////////////////////
//
// This source file may be used and distributed without
// restriction provided that this copyright statement is not
// removed from the file and that any derivative work contains
// the original copyright notice and the associated disclaimer.
//
// This source file is free software; you can redistribute it
// and/or modify it under the terms of the GNU Lesser General
// Public License as published by the Free Software Foundation;
// either version 2.1 of the License, or (at your option) any
// later version.
//
// This source is distributed in the hope that it will be
// useful, but WITHOUT ANY WARRANTY; without even the implied
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
// PURPOSE.  See the GNU Lesser General Public License for more
// details.
//
// You should have received a copy of the GNU Lesser General
// Public License along with this source; if not, download it
// from http://www.opencores.org/lgpl.shtml
//
//////////////////////////////////////////////////////////////////////

`include "orpsoc-defines.v"

module orpsoc_top #(
	parameter       bootrom_file = "../src/ulx3s_0/sw/spi_uimage_loader.vh"
)(
	input		sys_clk_pad_i,
	input		btn_pad_i,

	output		tdo_pad_o,
	input		tms_pad_i,
	input		tck_pad_i,
	input		tdi_pad_i,

	output	[1:0]	sdram_ba_pad_o,
	output	[12:0]	sdram_a_pad_o,
	output		sdram_cs_n_pad_o,
	output		sdram_ras_pad_o,
	output		sdram_cas_pad_o,
	output		sdram_we_pad_o,
	inout	[15:0]	sdram_dq_pad_io,
	output	[1:0]	sdram_dqm_pad_o,
	output		sdram_cke_pad_o,
	output		sdram_clk_pad_o,

	input		uart0_srx_pad_i,
	output		uart0_stx_pad_o,

	inout	[7:0]	gpio0_io,

	output ulx3s_gpio0_pin
);



parameter	IDCODE_VALUE = 32'h14951185;


////////////////////////////////////////////////////////////////////////
//
// Clock and reset generation module
//
////////////////////////////////////////////////////////////////////////

wire	async_rst;
wire	wb_clk, wb_rst;
wire	dbg_tck;
wire	sdram_clk;
wire	sdram_rst;

wire sys_clk, btn;

(* LOC="G2" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("INPUT")) clk_buf (.B(sys_clk_pad_i), .O(sys_clk));

(* LOC="R1" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("INPUT")) btn_buf (.B(btn_pad_i), .O(btn));

(* LOC="L2" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) ulx_gpio0_buf (.B(ulx3s_gpio0_pin), .I(1'b1));


clkgen clkgen0 (
	.sys_clk_pad_i	(sys_clk),
	.rst_n_pad_i	(!btn),
	.async_rst_o	(async_rst),
	.wb_clk_o	(wb_clk),
	.wb_rst_o	(wb_rst),
	.sdram_clk_o	(sdram_clk),
	.sdram_rst_o	(sdram_rst)
);

////////////////////////////////////////////////////////////////////////
//
// Modules interconnections
//
////////////////////////////////////////////////////////////////////////
`include "wb_intercon_dbg.vh"
`include "wb_intercon.vh"

////////////////////////////////////////////////////////////////////////
//
// GENERIC JTAG TAP
//
////////////////////////////////////////////////////////////////////////

wire	dbg_if_select;
wire	dbg_if_tdo;
wire	jtag_tap_tdo;
wire	jtag_tap_shift_dr;
wire	jtag_tap_pause_dr;
wire	jtag_tap_update_dr;
wire	jtag_tap_capture_dr;

wire tdo_o, tdo_oe, tms_i, tck_i, tdi_i;

/*
TDO 0+
TDI 1+
TMS 2+
TCK 3+
*/

(* LOC="B11" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) tdo_buf (.B(tdo_pad_o), .I(tdo_o), .T(!tdo_oe));
(* LOC="A10" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("INPUT")) tdi_buf (.B(tdi_pad_i), .O(tdi_i));
(* LOC="A9" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("INPUT")) tms_buf (.B(tms_pad_i), .O(tms_i));
(* LOC="B9" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("INPUT")) tck_buf (.B(tck_pad_i), .O(tck_i));


tap_top jtag_tap0 (
	.tdo_pad_o			(tdo_o),
	.tms_pad_i			(tms_i),
	.tck_pad_i			(tck_i),
	.trst_pad_i			(async_rst),
	.tdi_pad_i			(tdi_i),

	.tdo_padoe_o			(tdo_oe),

	.tdo_o				(jtag_tap_tdo),

	.shift_dr_o			(jtag_tap_shift_dr),
	.pause_dr_o			(jtag_tap_pause_dr),
	.update_dr_o			(jtag_tap_update_dr),
	.capture_dr_o			(jtag_tap_capture_dr),

	.extest_select_o		(),
	.sample_preload_select_o	(),
	.mbist_select_o			(),
	.debug_select_o			(dbg_if_select),


	.bs_chain_tdi_i			(1'b0),
	.mbist_tdi_i			(1'b0),
	.debug_tdi_i			(dbg_if_tdo)
);


////////////////////////////////////////////////////////////////////////
//
// OR1K CPU
//
////////////////////////////////////////////////////////////////////////

wire	[31:0]	or1k_irq;

wire	[31:0]	or1k_dbg_dat_i;
wire	[31:0]	or1k_dbg_adr_i;
wire		or1k_dbg_we_i;
wire		or1k_dbg_stb_i;
wire		or1k_dbg_ack_o;
wire	[31:0]	or1k_dbg_dat_o;

wire		or1k_dbg_stall_i;
wire		or1k_dbg_ewt_i;
wire	[3:0]	or1k_dbg_lss_o;
wire	[1:0]	or1k_dbg_is_o;
wire	[10:0]	or1k_dbg_wp_o;
wire		or1k_dbg_bp_o;
wire		or1k_dbg_rst;

wire		sig_tick;
wire		or1k_rst;

assign or1k_rst = wb_rst | or1k_dbg_rst;

`ifdef OR1200

or1200_top #(.boot_adr(32'hf0000000))
or1200_top0 (
	// Instruction bus, clocks, reset
	.iwb_clk_i			(wb_clk),
	.iwb_rst_i			(wb_rst),
	.iwb_ack_i			(wb_s2m_or1k_i_ack),
	.iwb_err_i			(wb_s2m_or1k_i_err),
	.iwb_rty_i			(wb_s2m_or1k_i_rty),
	.iwb_dat_i			(wb_s2m_or1k_i_dat),

	.iwb_cyc_o			(wb_m2s_or1k_i_cyc),
	.iwb_adr_o			(wb_m2s_or1k_i_adr),
	.iwb_stb_o			(wb_m2s_or1k_i_stb),
	.iwb_we_o			(wb_m2s_or1k_i_we),
	.iwb_sel_o			(wb_m2s_or1k_i_sel),
	.iwb_dat_o			(wb_m2s_or1k_i_dat),
	.iwb_cti_o			(wb_m2s_or1k_i_cti),
	.iwb_bte_o			(wb_m2s_or1k_i_bte),

	// Data bus, clocks, reset
	.dwb_clk_i			(wb_clk),
	.dwb_rst_i			(wb_rst),
	.dwb_ack_i			(wb_s2m_or1k_d_ack),
	.dwb_err_i			(wb_s2m_or1k_d_err),
	.dwb_rty_i			(wb_s2m_or1k_d_rty),
	.dwb_dat_i			(wb_s2m_or1k_d_dat),

	.dwb_cyc_o			(wb_m2s_or1k_d_cyc),
	.dwb_adr_o			(wb_m2s_or1k_d_adr),
	.dwb_stb_o			(wb_m2s_or1k_d_stb),
	.dwb_we_o			(wb_m2s_or1k_d_we),
	.dwb_sel_o			(wb_m2s_or1k_d_sel),
	.dwb_dat_o			(wb_m2s_or1k_d_dat),
	.dwb_cti_o			(wb_m2s_or1k_d_cti),
	.dwb_bte_o			(wb_m2s_or1k_d_bte),

	// Debug interface ports
	.dbg_stall_i			(or1k_dbg_stall_i),
	.dbg_ewt_i			(1'b0),
	.dbg_lss_o			(or1k_dbg_lss_o),
	.dbg_is_o			(or1k_dbg_is_o),
	.dbg_wp_o			(or1k_dbg_wp_o),
	.dbg_bp_o			(or1k_dbg_bp_o),

	.dbg_adr_i			(or1k_dbg_adr_i),
	.dbg_we_i			(or1k_dbg_we_i),
	.dbg_stb_i			(or1k_dbg_stb_i),
	.dbg_dat_i			(or1k_dbg_dat_i),
	.dbg_dat_o			(or1k_dbg_dat_o),
	.dbg_ack_o			(or1k_dbg_ack_o),

	.pm_clksd_o			(),
	.pm_dc_gate_o			(),
	.pm_ic_gate_o			(),
	.pm_dmmu_gate_o			(),
	.pm_immu_gate_o			(),
	.pm_tt_gate_o			(),
	.pm_cpu_gate_o			(),
	.pm_wakeup_o			(),
	.pm_lvolt_o			(),

	// Core clocks, resets
	.clk_i				(wb_clk),
	.rst_i				(or1k_rst),

	.clmode_i			(2'b00),

	// Interrupts
	.pic_ints_i			(or1k_irq),
	.sig_tick			(sig_tick),

	.pm_cpustall_i			(1'b0)
);
`endif

`ifdef MOR1KX
mor1kx #(
	.FEATURE_DEBUGUNIT("ENABLED"),
	.FEATURE_CMOV("ENABLED"),
	.FEATURE_INSTRUCTIONCACHE("ENABLED"),
	.OPTION_ICACHE_BLOCK_WIDTH(5),
	.OPTION_ICACHE_SET_WIDTH(8),
	.OPTION_ICACHE_WAYS(2),
	.OPTION_ICACHE_LIMIT_WIDTH(32),
	.FEATURE_IMMU("ENABLED"),
	.FEATURE_DATACACHE("ENABLED"),
	.OPTION_DCACHE_BLOCK_WIDTH(5),
	.OPTION_DCACHE_SET_WIDTH(8),
	.OPTION_DCACHE_WAYS(2),
	.OPTION_DCACHE_LIMIT_WIDTH(31),
	.FEATURE_DMMU("ENABLED"),
	.OPTION_RF_NUM_SHADOW_GPR	(1),
	//.OPTION_PIC_TRIGGER("LATCHED_LEVEL"),

	.IBUS_WB_TYPE("B3_REGISTERED_FEEDBACK"),
	.DBUS_WB_TYPE("B3_REGISTERED_FEEDBACK"),
	.OPTION_CPU0("CAPPUCCINO"),
	.OPTION_RESET_PC(32'hf0000000)
) mor1kx0 (
	.iwbm_adr_o(wb_m2s_or1k_i_adr),
	.iwbm_stb_o(wb_m2s_or1k_i_stb),
	.iwbm_cyc_o(wb_m2s_or1k_i_cyc),
	.iwbm_sel_o(wb_m2s_or1k_i_sel),
	.iwbm_we_o (wb_m2s_or1k_i_we),
	.iwbm_cti_o(wb_m2s_or1k_i_cti),
	.iwbm_bte_o(wb_m2s_or1k_i_bte),
	.iwbm_dat_o(wb_m2s_or1k_i_dat),

	.dwbm_adr_o(wb_m2s_or1k_d_adr),
	.dwbm_stb_o(wb_m2s_or1k_d_stb),
	.dwbm_cyc_o(wb_m2s_or1k_d_cyc),
	.dwbm_sel_o(wb_m2s_or1k_d_sel),
	.dwbm_we_o (wb_m2s_or1k_d_we ),
	.dwbm_cti_o(wb_m2s_or1k_d_cti),
	.dwbm_bte_o(wb_m2s_or1k_d_bte),
	.dwbm_dat_o(wb_m2s_or1k_d_dat),

	.clk(wb_clk),
	.rst(or1k_rst),

	.iwbm_err_i(wb_s2m_or1k_i_err),
	.iwbm_ack_i(wb_s2m_or1k_i_ack),
	.iwbm_dat_i(wb_s2m_or1k_i_dat),
	.iwbm_rty_i(wb_s2m_or1k_i_rty),

	.dwbm_err_i(wb_s2m_or1k_d_err),
	.dwbm_ack_i(wb_s2m_or1k_d_ack),
	.dwbm_dat_i(wb_s2m_or1k_d_dat),
	.dwbm_rty_i(wb_s2m_or1k_d_rty),

	.irq_i(or1k_irq),

	.du_addr_i(or1k_dbg_adr_i[15:0]),
	.du_stb_i(or1k_dbg_stb_i),
	.du_dat_i(or1k_dbg_dat_i),
	.du_we_i(or1k_dbg_we_i),
	.du_dat_o(or1k_dbg_dat_o),
	.du_ack_o(or1k_dbg_ack_o),
	.du_stall_i(or1k_dbg_stall_i),
	.du_stall_o(or1k_dbg_bp_o)
);

`endif
////////////////////////////////////////////////////////////////////////
//
// Debug Interface
//
////////////////////////////////////////////////////////////////////////

adbg_top dbg_if0 (
	// OR1K interface
	.cpu0_clk_i	(wb_clk),
	.cpu0_rst_o	(or1k_dbg_rst),
	.cpu0_addr_o	(or1k_dbg_adr_i),
	.cpu0_data_o	(or1k_dbg_dat_i),
	.cpu0_stb_o	(or1k_dbg_stb_i),
	.cpu0_we_o	(or1k_dbg_we_i),
	.cpu0_data_i	(or1k_dbg_dat_o),
	.cpu0_ack_i	(or1k_dbg_ack_o),
	.cpu0_stall_o	(or1k_dbg_stall_i),
	.cpu0_bp_i	(or1k_dbg_bp_o),

	// TAP interface
	.tck_i		(tck_i),
	.tdi_i		(jtag_tap_tdo),
	.tdo_o		(dbg_if_tdo),
	.rst_i		(wb_rst),
	.capture_dr_i	(jtag_tap_capture_dr),
	.shift_dr_i	(jtag_tap_shift_dr),
	.pause_dr_i	(jtag_tap_pause_dr),
	.update_dr_i	(jtag_tap_update_dr),
	.debug_select_i	(dbg_if_select),

	// Wishbone debug master
	.wb_clk_i	(wb_clk),
	.wb_rst_i       (1'b0),
	.wb_dat_i	(wb_s2m_dbg_dat),
	.wb_ack_i	(wb_s2m_dbg_ack),
	.wb_err_i	(wb_s2m_dbg_err),

	.wb_adr_o	(wb_m2s_dbg_adr),
	.wb_dat_o	(wb_m2s_dbg_dat),
	.wb_cyc_o	(wb_m2s_dbg_cyc),
	.wb_stb_o	(wb_m2s_dbg_stb),
	.wb_sel_o	(wb_m2s_dbg_sel),
	.wb_we_o	(wb_m2s_dbg_we),
	.wb_cab_o       (),
	.wb_cti_o	(wb_m2s_dbg_cti),
	.wb_bte_o	(wb_m2s_dbg_bte),

	.wb_jsp_adr_i (32'd0),
	.wb_jsp_dat_i (32'd0),
	.wb_jsp_cyc_i (1'b0),
	.wb_jsp_stb_i (1'b0),
	.wb_jsp_sel_i (4'h0),
	.wb_jsp_we_i  (1'b0),
	.wb_jsp_cab_i (1'b0),
	.wb_jsp_cti_i (3'd0),
	.wb_jsp_bte_i (2'd0),
	.wb_jsp_dat_o (),
	.wb_jsp_ack_o (),
	.wb_jsp_err_o (),

	.int_o ()
);

////////////////////////////////////////////////////////////////////////
//
// ROM
//
////////////////////////////////////////////////////////////////////////

   localparam WB_BOOTROM_MEM_DEPTH = 1024;

wb_bootrom
  #(.DEPTH (WB_BOOTROM_MEM_DEPTH),
    .MEMFILE (bootrom_file))
   bootrom
     (//Wishbone Master interface
      .wb_clk_i (wb_clk),
      .wb_rst_i (wb_rst),
      .wb_adr_i	(wb_m2s_rom0_adr),
      .wb_cyc_i	(wb_m2s_rom0_cyc),
      .wb_stb_i	(wb_m2s_rom0_stb),
      .wb_dat_o	(wb_s2m_rom0_dat),
      .wb_ack_o (wb_s2m_rom0_ack));

   assign wb_s2m_rom0_err = 1'b0;
   assign wb_s2m_rom0_rty = 1'b0;

////////////////////////////////////////////////////////////////////////
//
// SDRAM Memory Controller
//
////////////////////////////////////////////////////////////////////////

wire	[15:0]	sdram_dq_i;
wire	[15:0]	sdram_dq_o;
wire		sdram_dq_oe;
wire	[1:0]	sdram_dqm_o;

wire [1:0] sdram_ba_o;
wire [12:0] sdram_a_o;
wire sdram_cs_n_o, sdram_ras_o, sdram_cas_o, sdram_we_o, sdram_cke_o;

(* LOC="P19" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_ba_buf_0 (.B(sdram_ba_pad_o[0]), .I(sdram_ba_o[0]));
(* LOC="N20" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_ba_buf_1 (.B(sdram_ba_pad_o[1]), .I(sdram_ba_o[1]));

(* LOC="M20" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_a_buf_0 (.B(sdram_a_pad_o[0]), .I(sdram_a_o[0]));
(* LOC="M19" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_a_buf_1 (.B(sdram_a_pad_o[1]), .I(sdram_a_o[1]));
(* LOC="L20" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_a_buf_2 (.B(sdram_a_pad_o[2]), .I(sdram_a_o[2]));
(* LOC="L19" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_a_buf_3 (.B(sdram_a_pad_o[3]), .I(sdram_a_o[3]));
(* LOC="K20" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_a_buf_4 (.B(sdram_a_pad_o[4]), .I(sdram_a_o[4]));
(* LOC="K19" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_a_buf_5 (.B(sdram_a_pad_o[5]), .I(sdram_a_o[5]));
(* LOC="K18" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_a_buf_6 (.B(sdram_a_pad_o[6]), .I(sdram_a_o[6]));
(* LOC="J20" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_a_buf_7 (.B(sdram_a_pad_o[7]), .I(sdram_a_o[7]));
(* LOC="J19" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_a_buf_8 (.B(sdram_a_pad_o[8]), .I(sdram_a_o[8]));
(* LOC="H20" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_a_buf_9 (.B(sdram_a_pad_o[9]), .I(sdram_a_o[9]));
(* LOC="N19" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_a_buf_10 (.B(sdram_a_pad_o[10]), .I(sdram_a_o[10]));
(* LOC="G20" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_a_buf_11 (.B(sdram_a_pad_o[11]), .I(sdram_a_o[11]));
(* LOC="G19" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_a_buf_12 (.B(sdram_a_pad_o[12]), .I(sdram_a_o[12]));

(* LOC="F19" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_clk_buf (.B(sdram_clk_pad_o), .I(sdram_clk));
(* LOC="F20" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_cke_buf (.B(sdram_cke_pad_o), .I(sdram_cke_o));
(* LOC="P20" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_csn_buf (.B(sdram_cs_n_pad_o), .I(sdram_cs_n_o));
(* LOC="T20" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_wen_buf (.B(sdram_we_pad_o), .I(sdram_we_o));
(* LOC="R20" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_ras_buf (.B(sdram_ras_pad_o), .I(sdram_ras_o));
(* LOC="T19" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_cas_buf (.B(sdram_cas_pad_o), .I(sdram_cas_o));

(* LOC="U19" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_dqm_buf_0 (.B(sdram_dqm_pad_o[0]), .I(sdram_dqm_o[0]));
(* LOC="E20" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) sdram_dqm_buf_1 (.B(sdram_dqm_pad_o[1]), .I(sdram_dqm_o[1]));

(* LOC="J16" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_0 (.B(sdram_dq_pad_io[0]), .I(sdram_dq_o[0]), .O(sdram_dq_i[0]), .T(!sdram_dq_oe));
(* LOC="L18" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_1 (.B(sdram_dq_pad_io[1]), .I(sdram_dq_o[1]), .O(sdram_dq_i[1]), .T(!sdram_dq_oe));
(* LOC="M18" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_2 (.B(sdram_dq_pad_io[2]), .I(sdram_dq_o[2]), .O(sdram_dq_i[2]), .T(!sdram_dq_oe));
(* LOC="N18" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_3 (.B(sdram_dq_pad_io[3]), .I(sdram_dq_o[3]), .O(sdram_dq_i[3]), .T(!sdram_dq_oe));
(* LOC="P18" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_4 (.B(sdram_dq_pad_io[4]), .I(sdram_dq_o[4]), .O(sdram_dq_i[4]), .T(!sdram_dq_oe));
(* LOC="T18" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_5 (.B(sdram_dq_pad_io[5]), .I(sdram_dq_o[5]), .O(sdram_dq_i[5]), .T(!sdram_dq_oe));
(* LOC="T17" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_6 (.B(sdram_dq_pad_io[6]), .I(sdram_dq_o[6]), .O(sdram_dq_i[6]), .T(!sdram_dq_oe));
(* LOC="U20" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_7 (.B(sdram_dq_pad_io[7]), .I(sdram_dq_o[7]), .O(sdram_dq_i[7]), .T(!sdram_dq_oe));
(* LOC="E19" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_8 (.B(sdram_dq_pad_io[8]), .I(sdram_dq_o[8]), .O(sdram_dq_i[8]), .T(!sdram_dq_oe));
(* LOC="D20" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_9 (.B(sdram_dq_pad_io[9]), .I(sdram_dq_o[9]), .O(sdram_dq_i[9]), .T(!sdram_dq_oe));
(* LOC="D19" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_10 (.B(sdram_dq_pad_io[10]), .I(sdram_dq_o[10]), .O(sdram_dq_i[10]), .T(!sdram_dq_oe));
(* LOC="C20" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_11 (.B(sdram_dq_pad_io[11]), .I(sdram_dq_o[11]), .O(sdram_dq_i[11]), .T(!sdram_dq_oe));
(* LOC="E18" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_12 (.B(sdram_dq_pad_io[12]), .I(sdram_dq_o[12]), .O(sdram_dq_i[12]), .T(!sdram_dq_oe));
(* LOC="F18" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_13 (.B(sdram_dq_pad_io[13]), .I(sdram_dq_o[13]), .O(sdram_dq_i[13]), .T(!sdram_dq_oe));
(* LOC="J18" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_14 (.B(sdram_dq_pad_io[14]), .I(sdram_dq_o[14]), .O(sdram_dq_i[14]), .T(!sdram_dq_oe));
(* LOC="J17" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("BIDIR")) sdram_dq_buf_15 (.B(sdram_dq_pad_io[15]), .I(sdram_dq_o[15]), .O(sdram_dq_i[15]), .T(!sdram_dq_oe));

assign	wb_s2m_sdram_ibus_err = 0;
assign	wb_s2m_sdram_ibus_rty = 0;

assign	wb_s2m_sdram_dbus_err = 0;
assign	wb_s2m_sdram_dbus_rty = 0;

wb_sdram_ctrl #(
`ifndef SIM
	.TECHNOLOGY         ("ECP5"),
`endif
	.CLK_FREQ_MHZ			(25),	// sdram_clk freq in MHZ
	.POWERUP_DELAY			(200),	// power up delay in us
	.REFRESH_MS			(32),	// delay between refresh cycles im ms
	.WB_PORTS			(2),	// Number of wishbone ports
	.ROW_WIDTH			(13),	// Row width
	.COL_WIDTH			(9),	// Column width
	.BA_WIDTH			(2),	// Ba width
	.tCAC				(2),	// CAS Latency
	.tRAC				(5),	// RAS Latency
	.tRP				(2),	// Command Period (PRE to ACT)
	.tRC				(7),	// Command Period (REF to REF / ACT to ACT)
	.tMRD				(2)	// Mode Register Set To Command Delay time
)

wb_sdram_ctrl0 (
	// External SDRAM interface
	.ba_pad_o	(sdram_ba_o[1:0]),
	.a_pad_o	(sdram_a_o[12:0]),
	.cs_n_pad_o	(sdram_cs_n_o),
	.ras_pad_o	(sdram_ras_o),
	.cas_pad_o	(sdram_cas_o),
	.we_pad_o	(sdram_we_o),
	.dq_i		(sdram_dq_i[15:0]),
	.dq_o		(sdram_dq_o[15:0]),
	.dqm_pad_o	(sdram_dqm_o[1:0]),
	.dq_oe		(sdram_dq_oe),
	.cke_pad_o	(sdram_cke_o),
	.sdram_clk	(sdram_clk),
	.sdram_rst	(sdram_rst),

	.wb_clk		(wb_clk),
	.wb_rst		(wb_rst),

	.wb_adr_i	({wb_m2s_sdram_ibus_adr, wb_m2s_sdram_dbus_adr}),
	.wb_stb_i	({wb_m2s_sdram_ibus_stb, wb_m2s_sdram_dbus_stb}),
	.wb_cyc_i	({wb_m2s_sdram_ibus_cyc, wb_m2s_sdram_dbus_cyc}),
	.wb_cti_i	({wb_m2s_sdram_ibus_cti, wb_m2s_sdram_dbus_cti}),
	.wb_bte_i	({wb_m2s_sdram_ibus_bte, wb_m2s_sdram_dbus_bte}),
	.wb_we_i	({wb_m2s_sdram_ibus_we,  wb_m2s_sdram_dbus_we }),
	.wb_sel_i	({wb_m2s_sdram_ibus_sel, wb_m2s_sdram_dbus_sel}),
	.wb_dat_i	({wb_m2s_sdram_ibus_dat, wb_m2s_sdram_dbus_dat}),
	.wb_dat_o	({wb_s2m_sdram_ibus_dat, wb_s2m_sdram_dbus_dat}),
	.wb_ack_o	({wb_s2m_sdram_ibus_ack, wb_s2m_sdram_dbus_ack})
);

////////////////////////////////////////////////////////////////////////
//
// UART0
//
////////////////////////////////////////////////////////////////////////

wire	uart0_irq;
wire  uart0_stx_o, uart0_srx_i;

(* LOC="L4" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) utx_buf (.B(uart0_stx_pad_o), .I(uart0_stx_o));
(* LOC="M1" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("INPUT")) urx_buf (.B(uart0_srx_pad_i), .O(uart0_srx_i));

assign	wb_s2m_uart0_err = 0;
assign	wb_s2m_uart0_rty = 0;

uart_top uart16550_0 (
	// Wishbone slave interface
	.wb_clk_i	(wb_clk),
	.wb_rst_i	(wb_rst),
	.wb_adr_i	(wb_m2s_uart0_adr[2:0]),
	.wb_dat_i	(wb_m2s_uart0_dat),
	.wb_we_i	(wb_m2s_uart0_we),
	.wb_stb_i	(wb_m2s_uart0_stb),
	.wb_cyc_i	(wb_m2s_uart0_cyc),
	.wb_sel_i	(4'b0), // Not used in 8-bit mode
	.wb_dat_o	(wb_s2m_uart0_dat),
	.wb_ack_o	(wb_s2m_uart0_ack),

	// Outputs
	.int_o		(uart0_irq),
	.stx_pad_o	(uart0_stx_o),
	.rts_pad_o	(),
	.dtr_pad_o	(),

	// Inputs
	.srx_pad_i	(uart0_srx_i),
	.cts_pad_i	(1'b0),
	.dsr_pad_i	(1'b0),
	.ri_pad_i	(1'b0),
	.dcd_pad_i	(1'b0)
);


////////////////////////////////////////////////////////////////////////
//
// GPIO 0
//
////////////////////////////////////////////////////////////////////////

(* LOC="B2" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) led_buf_0 (.B(gpio0_io[0]), .I(gpio0_out[0]));
(* LOC="C2" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) led_buf_1 (.B(gpio0_io[1]), .I(gpio0_out[1]));
(* LOC="C1" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) led_buf_2 (.B(gpio0_io[2]), .I(gpio0_out[2]));
(* LOC="D2" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) led_buf_3 (.B(gpio0_io[3]), .I(gpio0_out[3]));

(* LOC="D1" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) led_buf_4 (.B(gpio0_io[4]), .I(gpio0_out[4]));
(* LOC="E2" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) led_buf_5 (.B(gpio0_io[5]), .I(gpio0_out[5]));
(* LOC="E1" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) led_buf_6 (.B(gpio0_io[6]), .I(gpio0_out[6]));
(* LOC="H3" *) (* IO_TYPE="LVCMOS33" *)
TRELLIS_IO #(.DIR("OUTPUT")) led_buf_7 (.B(gpio0_io[7]), .I(gpio0_out[7]));

wire [7:0]	gpio0_out;

gpio gpio0 (
	// GPIO bus
	.gpio_i		(8'b0),
	.gpio_o		(gpio0_out),
	.gpio_dir_o	(),
	// Wishbone slave interface
	.wb_adr_i	(wb_m2s_gpio0_adr[0]),
	.wb_dat_i	(wb_m2s_gpio0_dat),
	.wb_we_i	(wb_m2s_gpio0_we),
	.wb_cyc_i	(wb_m2s_gpio0_cyc),
	.wb_stb_i	(wb_m2s_gpio0_stb),
	.wb_cti_i	(wb_m2s_gpio0_cti),
	.wb_bte_i	(wb_m2s_gpio0_bte),
	.wb_dat_o	(wb_s2m_gpio0_dat),
	.wb_ack_o	(wb_s2m_gpio0_ack),
	.wb_err_o	(wb_s2m_gpio0_err),
	.wb_rty_o	(wb_s2m_gpio0_rty),

	.wb_clk		(wb_clk),
	.wb_rst		(wb_rst)
);


////////////////////////////////////////////////////////////////////////
//
// Interrupt assignment
//
////////////////////////////////////////////////////////////////////////

assign or1k_irq[0] = 0; // Non-maskable inside OR1K
assign or1k_irq[1] = 0; // Non-maskable inside OR1K
assign or1k_irq[2] = uart0_irq;
assign or1k_irq[3] = 0;
assign or1k_irq[4] = 0;
assign or1k_irq[5] = 0;
assign or1k_irq[6] = 0;
assign or1k_irq[7] = 0;
assign or1k_irq[8] = 0;
assign or1k_irq[9] = 0;
assign or1k_irq[10] = 0;
assign or1k_irq[11] = 0;
assign or1k_irq[12] = 0;
assign or1k_irq[13] = 0;
assign or1k_irq[14] = 0;
assign or1k_irq[15] = 0;
assign or1k_irq[16] = 0;
assign or1k_irq[17] = 0;
assign or1k_irq[18] = 0;
assign or1k_irq[19] = 0;
assign or1k_irq[20] = 0;
assign or1k_irq[21] = 0;
assign or1k_irq[22] = 0;
assign or1k_irq[23] = 0;
assign or1k_irq[24] = 0;
assign or1k_irq[25] = 0;
assign or1k_irq[26] = 0;
assign or1k_irq[27] = 0;
assign or1k_irq[28] = 0;
assign or1k_irq[29] = 0;
assign or1k_irq[30] = 0;
assign or1k_irq[31] = 0;

endmodule // orpsoc_top
