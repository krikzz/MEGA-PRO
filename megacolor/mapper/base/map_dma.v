
`include "defs.v"

module map_dma(

	output [`BW_MAP_OUT-1:0]mapout,
	input [`BW_MAP_IN-1:0]mapin,
	input clk,
	output dma_act
);

	`include "pi_bus.v"
	`include "mapio.v"
	`include "sys_cfg.v"
	
	assign mask_off = 1;
	assign dtack = 1;
//*************************************************************************************
	assign led_r = 1;
	
	wire mem_ce[4];
	
	
	assign mem_di[`ROM0][15:0] = {pi_do[7:0], pi_do[7:0]};
	assign mem_di[`ROM1][15:0] = {pi_do[7:0], pi_do[7:0]};
	assign mem_di[`SRAM][15:0] = {pi_do[7:0], pi_do[7:0]};
	assign mem_di[`BRAM][15:0] = {pi_do[7:0], pi_do[7:0]};
	
	assign mem_addr[`ROM0][22:0] = pi_addr[22:0];
	assign mem_oe[`ROM0] = pi_ce_rom0 & pi_oe;
	assign mem_we_hi[`ROM0] = pi_ce_rom0 & pi_we_hi;
	assign mem_we_lo[`ROM0] = pi_ce_rom0 & pi_we_lo;
	
	assign mem_addr[`ROM1][22:0] = pi_addr[22:0];
	assign mem_oe[`ROM1] = pi_ce_rom1 & pi_oe;
	assign mem_we_hi[`ROM1] = pi_ce_rom1 & pi_we_hi;
	assign mem_we_lo[`ROM1] = pi_ce_rom1 & pi_we_lo;
	
	assign mem_addr[`SRAM][22:0] = pi_addr[22:0];
	assign mem_oe[`SRAM] = pi_ce_sram & pi_oe;
	assign mem_we_hi[`SRAM] = pi_ce_sram & pi_we_hi;
	assign mem_we_lo[`SRAM] = pi_ce_sram & pi_we_lo;
	
	assign mem_addr[`BRAM][22:0] = pi_addr[22:0];
	assign mem_oe[`BRAM] = pi_ce_bram & pi_oe;
	assign mem_we_hi[`BRAM] = pi_ce_bram & pi_we_hi;
	assign mem_we_lo[`BRAM] = pi_ce_bram & pi_we_lo;
//************************************************************************************* pi
	assign dma_act = pi_dst_mem & pi_busy;
	assign pi_din_map[7:0] = pi_addr[0] == 0 ? mem_do_sel[15:8] : mem_do_sel[7:0];
		
	wire [15:0]mem_do_sel = 
	pi_ce_rom0 ? mem_do[`ROM0][15:0] : 
	pi_ce_rom1 ? mem_do[`ROM1][15:0] : 
	pi_ce_sram ? mem_do[`SRAM][15:0] : 
	pi_ce_bram ? mem_do[`BRAM][15:0] : 16'hffff;
	

	
endmodule
