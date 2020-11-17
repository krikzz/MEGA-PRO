
	
	`include "mdbus.v"
	`include "map_in.v"

	wire gp_ck;
	wire [4:0]gp_dir, gp_i, gp_o;
	wire dac_sdin, dac_sclk, dac_lrck, dac_mclk;
	wire mcu_rst, mcu_sync, mcu_mode, mask_off, led_r, led_g, map_oe, cart, dtack, x32_mode, sms_mode;
	wire [15:0]map_do;
	wire [7:0]pi_din_map;
	wire [7:0]dbg_out;
	
	wire [15:0]mem_di[4];
	wire [22:0]mem_addr[4];
	wire mem_oe[4];
	wire mem_we_lo[4];
	wire mem_we_hi[4];
	
	
	assign mapout[`BW_MAP_OUT-1:0] = {
		gp_dir[4:0], gp_i[4:0], gp_o[4:0], gp_ck,
		dac_sdin, dac_sclk, dac_lrck, dac_mclk,
		mcu_rst, mcu_sync, !mcu_mode, mask_off, led_r, led_g, map_oe, cart, dtack, x32_mode, sms_mode, 
		dbg_out[7:0],
		mem_we_hi[`BRAM], mem_we_lo[`BRAM], mem_oe[`BRAM], brm_addr_out[22:0], mem_di[`BRAM][15:0],
		mem_we_hi[`SRAM], mem_we_lo[`SRAM], mem_oe[`SRAM], mem_addr[`SRAM][22:0], mem_di[`SRAM][15:0],
		mem_we_hi[`ROM1], mem_we_lo[`ROM1], mem_oe[`ROM1], mem_addr[`ROM1][22:0], mem_di[`ROM1][15:0],
		mem_we_hi[`ROM0], mem_we_lo[`ROM0], mem_oe[`ROM0], rom_addr_out[22:0], mem_di[`ROM0][15:0],
		pi_din_map[7:0], map_do[15:0]//this two must be first in bus
	};
	
	
	
	wire [15:0]mem_do[4];
	assign {mem_do[3][15:0], mem_do[2][15:0], mem_do[1][15:0], mem_do[0][15:0]} = mem_data[`BW_MEMDAT-1:0];
	
	wire [22:0]rom_addr_out = mask_off ? mem_addr[`ROM0][22:0] : rom_addr_msk[22:0];
	wire [22:0]brm_addr_out = mask_off ? mem_addr[`BRAM][22:0] : brm_addr_msk[22:0];
	
	wire [22:0]rom_addr_msk = {(mem_addr[`ROM0][22:13] & rom_msk[9:0]), mem_addr[`ROM0][12:0]};
	wire [22:0]brm_addr_msk = {(mem_addr[`BRAM][22:13] & brm_msk[9:0]), mem_addr[`BRAM][12:0]};
	
	