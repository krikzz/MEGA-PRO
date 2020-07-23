
`include "defs.v"

module top(

	inout [15:0]data,
	input [23:1]addr,
	input as, cas, ce_lo, ce_hi, clk50, vclk, eclk, oe, rst, we_lo, we_hi, 
	output cart, dtak, hrst,  
	output [3:0]sms,
	
	output dat_dir, dat_oe,
	
	output spi_miso,
	input  spi_mosi, spi_sck,
	input spi_ss,
	
	output mcu_fifo_rxf, mcu_mode, mcu_sync, mcu_rst,
	input mcu_busy,
		
	inout [15:0]ram0_data,
	output [21:0]ram0_addr,
	output ram0_oe, ram0_we, ram0_ub, ram0_lb, ram0_ce,
	
	inout [15:0]ram1_data,
	output [21:0]ram1_addr,
	output ram1_oe, ram1_we, ram1_ub, ram1_lb, ram1_ce,
	
	inout [15:0]ram2_data,
	output [17:0]ram2_addr,
	output ram2_oe, ram2_we, ram2_ub, ram2_lb, ram2_ce,
	
	inout [15:0]ram3_data,
	output [17:0]ram3_addr,
	output ram3_oe, ram3_we, ram3_ub, ram3_lb, 
		
	inout [3:0]xbus,
	
	input gpclk,
	inout [4:0]gpio,
	
	output dac_mclk, dac_lrck, dac_sclk, dac_sdin,
	
	output mkey_oe, mkey_we, led_r, led_g,
	input btn

);


	
	`include "pi_bus.v"
	`include "sys_cfg.v"
	

//************************************************************************************* gpio port 
	assign gpio[0] = gp_dir[0] == 0 ? gp_o[0] : 1'bz;
	assign gpio[1] = gp_dir[1] == 0 ? gp_o[1] : 1'bz;
	assign gpio[2] = gp_dir[2] == 0 ? gp_o[2] : 1'bz;
	assign gpio[3] = gp_dir[3] == 0 ? gp_o[3] : 1'bz;
	assign gpio[4] = gp_dir[4] == 0 ? gp_o[4] : 1'bz;
	assign gp_i[4:0] = gpio[4:0];
//************************************************************************************* bus control	

	wire gp_ck;
	wire [4:0]gp_dir, gp_i, gp_o;
	wire mask_off, map_oe, map_dtack, x32_mode, sms_mode;
	wire [7:0]pi_din_map_act, pi_din_map_gam;
	wire [7:0]dbg_out;
	wire [15:0]map_do;
	
	wire [15:0]mem_di[4];
	wire [22:0]mem_addr[4];
	wire mem_oe[4];
	wire mem_we_lo[4];
	wire mem_we_hi[4];
	
	
	
	assign {
		gp_dir[4:0], gp_i[4:0], gp_o[4:0], gp_ck,
		dac_sdin, dac_sclk, dac_lrck, dac_mclk,
		mcu_rst, mcu_sync, mcu_mode, mask_off, led_r, led_g, map_oe, cart, map_dtack, x32_mode, sms_mode,
		dbg_out[7:0],
		mem_we_hi[`BRAM], mem_we_lo[`BRAM], mem_oe[`BRAM], mem_addr[`BRAM][22:0], mem_di[`BRAM][15:0],
		mem_we_hi[`SRAM], mem_we_lo[`SRAM], mem_oe[`SRAM], mem_addr[`SRAM][22:0], mem_di[`SRAM][15:0],
		mem_we_hi[`ROM1], mem_we_lo[`ROM1], mem_oe[`ROM1], mem_addr[`ROM1][22:0], mem_di[`ROM1][15:0],
		mem_we_hi[`ROM0], mem_we_lo[`ROM0], mem_oe[`ROM0], mem_addr[`ROM0][22:0], mem_di[`ROM0][15:0],
		pi_din_map_act[7:0], map_do[15:0]//this two must be first in bus (req for save states and cheats)
	} = map_out[`BW_MAP_OUT-1:0];
	
	assign pi_din_map_gam[7:0] = map_out_hub[23:16];

	assign dtak = !map_dtack ? 0 : 1'bz;
	assign data[15:0] = 
	!dat_dir ? 16'hzzzz : 
	base_io_oe ? base_io_do[15:0] :
	cheats_oe ? cheats_do[15:0] :
	map_oe ? map_do[15:0] : 
	16'h0000;
	
	//{(mem_addr[`ROM0][22:12] & rom_msk[8:0]), mem_addr[`ROM0][11:1]} 
	assign ram0_data[15:0] = mem_oe[`ROM0] ? 16'hzzzz : mem_di[`ROM0][15:0];
	assign ram0_addr[21:0] = mem_addr[`ROM0][22:1];
	assign ram0_ce = !(mem_oe[`ROM0] | mem_we_lo[`ROM0] | mem_we_hi[`ROM0]);
	assign ram0_oe = !mem_oe[`ROM0];
	assign ram0_we = !(mem_we_lo[`ROM0] | mem_we_hi[`ROM0]);
	assign ram0_ub = !(mem_we_hi[`ROM0] | mem_oe[`ROM0]);
	assign ram0_lb = !(mem_we_lo[`ROM0] | mem_oe[`ROM0]);
	
	assign ram1_data[15:0] = mem_oe[`ROM1] ? 16'hzzzz : mem_di[`ROM1][15:0];
	assign ram1_addr[21:0] = mem_addr[`ROM1][22:1];
	assign ram1_ce = !(mem_oe[`ROM1] | mem_we_lo[`ROM1] | mem_we_hi[`ROM1]);
	assign ram1_oe = !mem_oe[`ROM1];
	assign ram1_we = !(mem_we_lo[`ROM1] | mem_we_hi[`ROM1]);
	assign ram1_ub = !(mem_we_hi[`ROM1] | mem_oe[`ROM1]);
	assign ram1_lb = !(mem_we_lo[`ROM1] | mem_oe[`ROM1]);
	
	assign ram2_data[15:0] = mem_oe[`SRAM] ? 16'hzzzz : mem_di[`SRAM][15:0];
	assign ram2_addr[17:0] = mem_addr[`SRAM][22:1];
	assign ram2_ce = !(mem_oe[`SRAM] | mem_we_lo[`SRAM] | mem_we_hi[`SRAM]);
	assign ram2_oe = !mem_oe[`SRAM];
	assign ram2_we = !(mem_we_lo[`SRAM] | mem_we_hi[`SRAM]);
	assign ram2_ub = !(mem_we_hi[`SRAM] | mem_oe[`SRAM]);
	assign ram2_lb = !(mem_we_lo[`SRAM] | mem_oe[`SRAM]);
	
	assign ram3_data[15:0] = mem_oe[`BRAM] ? 16'hzzzz : mem_di[`BRAM][15:0];
	assign ram3_addr[17:0] = mem_addr[`BRAM][22:1];
	assign ram3_oe = !mem_oe[`BRAM];
	assign ram3_we = !(mem_we_lo[`BRAM] | mem_we_hi[`BRAM]);
	assign ram3_ub = !(mem_we_hi[`BRAM] | mem_oe[`BRAM]);
	assign ram3_lb = !(mem_we_lo[`BRAM] | mem_oe[`BRAM]);
	
	
	bus_ctrl bus_ctrl_inst(
		.clk(clk50),
		.sys_rst(sys_rst),
		.bus_oe(cheats_oe | map_oe | base_io_oe),
		.dat_dir(dat_dir), 
		.dat_oe(dat_oe)
	);
//************************************************************************************* mappers	
	wire tim = {addr[23:8], 8'd0} == 24'hA13000 & !as ? 0 : 1;
	wire map_rst = map_idx == 0 | !ctrl_gmode | rst_hold;
	wire [`BW_MDBUS-1:0]mdbus_as = {sst_act, map_rst, sys_rst, vclk, btn, tim, ce_lo, ce_hi, we_lo, we_hi, oe, as, addr[23:1], data[15:0]};
	wire [`BW_MEMDAT-1:0]mem_data = {ram3_data[15:0], ram2_data[15:0], ram1_data[15:0], ram0_data[15:0]};
	wire [`BW_MAP_IN-1:0]mapin = {mdbus_as[`BW_MDBUS-1:0], pi_bus[`BW_PI_BUS-1:0], sys_cfg[`BW_SYS_CFG-1:0], mdbus[`BW_MDBUS-1:0], mem_data[`BW_MEMDAT-1:0]};
	
	wire [`BW_MDBUS-1:0]mdbus = {oe, mdbus_sn[`BW_MDBUS-2:0]};//BW_MDBUS-1+(asyn wires num)
	
	reg [`BW_MDBUS-1:0]mdbus_sn;
	always @(negedge clk50)mdbus_sn <= mdbus_as;


	
	wire [`BW_MAP_OUT-1:0]map_out = 
	dma_act 		 ?	map_out_dma[`BW_MAP_OUT-1:0] :
	map_rst 		 ? map_sys_smd[`BW_MAP_OUT-1:0] :
	sst_act		 ? map_out_sst[`BW_MAP_OUT-1:0] :
						map_out_hub[`BW_MAP_OUT-1:0];
	
	
	wire [`BW_MAP_OUT-1:0]map_sys_smd;
	map_sys_smd sys_inst_smd(
		.mapout(map_sys_smd),
		.mapin(mapin),
		.clk(clk50)
	);
	
	
	wire dma_act;
	wire [7:0]pi_din_dma;
	wire [`BW_MAP_OUT-1:0]map_out_dma;
	map_dma dma_inst(
		.mapout(map_out_dma),
		.mapin(mapin),		
		.clk(clk50),
		.dma_act(dma_act),
	);

	
	wire [`BW_MAP_OUT-1:0]map_out_hub;
	map_hub map_hub_inst(
		.mapout(map_out_hub),
		.mapin(mapin),	
		.clk(clk50)
	);
	
	
//************************************************************************************* base io
	wire [`BW_SYS_CFG-1:0]sys_cfg;
	wire [7:0]pi_din_bio;
	wire [15:0]base_io_do;
	wire base_io_oe;
	
	
	base_io base_io_inst(
		.clk(clk50),
		.pi_bus(pi_bus),
		.sys_cfg(sys_cfg),
		.pi_din(pi_din_bio),
		.mdbus(mdbus),
		.base_io_do(base_io_do),
		.base_io_oe(base_io_oe),
		.mcu_busy(mcu_busy),
		.sms_mode(sms_mode),
		.pi_fifo_rxf(mcu_fifo_rxf)
	);
//************************************************************************************* pi
	wire [7:0]pi_din = 
	pi_dst_mem ? pi_din_map_act : //current controller
	pi_dst_map ? pi_din_map_gam : //current game mapper
	pi_ce_sst_map ? pi_din_map_gam :
	pi_ce_sst_sys ? pi_din_sst :
	pi_din_bio;

	wire [`BW_PI_BUS-1:0]pi_bus;
	pi_interface pi_inst(
		.miso(spi_miso), 
		.mosi(spi_mosi), 
		.ss(spi_ss), 
		.spi_clk(spi_sck), 
		.din(pi_din), 
		.pi_bus(pi_bus),
		.sys_clk(clk50)
	);

//************************************************************************************* rst ctrl
	wire rst_hold;
	wire sys_rst;
	
	rst_ctrl rst_inst(
		.clk(clk50),
		.rst(rst),
		.addr20(addr[20]),
		.btn(btn),
		.sms_mode(sms_mode),
		.x32_mode(x32_mode),
		.hrst(hrst),
		.sys_rst(sys_rst),
		.map_idx(map_idx),
		.rst_hold(rst_hold),
		.ctrl_rst_off(ctrl_rst_off)
	);
	
//************************************************************************************* save states controller		
	wire sst_act_smd, sst_act_sms;
	wire [7:0]pi_din_sst;
	wire [`BW_MAP_OUT-1:0]map_sys_sms;
	
	wire [`BW_MAP_OUT-1:0]map_out_sst = sst_act_sms ? map_sys_sms : map_sys_smd;
	wire sst_act = sst_act_smd | sst_act_sms;

	
`ifdef CFG_SST_SMS
	`define 	CFG_SST
`elsif CFG_SST_SMD
	`define 	CFG_SST
`endif	
	
	
`ifdef CFG_SST

	sst_controller sst_inst(
		.clk(clk50),
		.sms_mode(sms_mode),
		.mapin(mapin),
		.pi_din(pi_din_sst),
		.sst_act_smd(sst_act_smd),
		.sst_act_sms(sst_act_sms)
	);
	
`endif

	
`ifdef CFG_SST_SMS	

	map_sys_sms sys_inst_sms(
		.mapout(map_sys_sms),
		.mapin(mapin),
		.clk(clk50)
	);
	
`endif	

//************************************************************************************* cheats
	wire [15:0]cheats_do;
	wire cheats_oe;
	wire cheats_on = ctrl_gg_on & !map_rst & !sst_act & !sms_mode;

`ifdef CFG_CHEATS
	
	cheats cheats_inst(
		.clk(clk50),
		.mapin(mapin),
		.cheats_on(cheats_on),
		.cheats_do(cheats_do),
		.cheats_oe(cheats_oe)
	);

`endif	
//************************************************************************************* var	
	//assign sms[3:0] = sms_mode ? {1'b0, (!btn ? 1'b0 : 1'bz), 2'b01} : 4'bzzzz;
	assign {sms[3], sms[1:0]} = sms_mode ? 3'b001 : 3'bzzz;
	assign sms[2] = sms_mode & btn ? 1'b0 : 1'bz;

	
	mkey_ctrl mkey_inst(
		.clk(clk50),
		.mdbus(mdbus),
		.mkey_oe_n(mkey_oe), 
		.mkey_we(mkey_we)
	);
	
endmodule


