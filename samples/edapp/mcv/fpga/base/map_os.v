
`include "defs.v"

module map_sys_smd(

	output [`BW_MAP_OUT-1:0]mapout,
	input [`BW_MAP_IN-1:0]mapin,
	input clk
);
	
	`include "mapio.v"
	`include "sys_cfg.v"
	

	//assign mcu_mode = sst_act;
	assign dtack = 1;
	assign mask_off = 1;
//*************************************************************************************
	assign mem_di[`ROM1][15:0] = cpu_data[15:0];
	assign mem_addr[`ROM1][22:0] = ibuf_ce ? {4'hE, cpu_addr[18:0]} : {4'hF, cpu_addr[18:0]};
	assign mem_oe[`ROM1] = mem_ce & !oe;
	assign mem_we_lo[`ROM1] = (ram_ce | ibuf_ce) & !we_lo;
	assign mem_we_hi[`ROM1] = (ram_ce | ibuf_ce) & !we_hi;
	assign map_oe = mem_ce & !oe;
	
	assign led_r = sst_act;
	assign map_do[15:0] =  mem_do[`ROM1][15:0];
	
	
	wire cart_ce = !ce_lo & !sys_rst;
	wire mem_ce  = cart_ce & (rom_ce | ram_ce | ibuf_ce);
	wire rom_ce  = cart_ce & cpu_addr[23:18] == 0;//256K
	wire ram_ce  = cart_ce & cpu_addr[23:18] == 1;//256K
	wire ibuf_ce = cart_ce & cpu_addr[23:19] == 1;//512K io buffer. mostly for save states
//************************************************************************************* dac mute
	assign dac_mclk = ctr[1];
	assign dac_sclk = 1;
	assign dac_lrck = ctr[9];
	assign dac_sdin = 0;
	reg [15:0]ctr;
	reg mute_req;
	
	always @(negedge clk)	
	begin
		
		if(ctrl_gmode)
		begin
			mute_req <= map_idx == `MAP_MCD | map_idx == `MAP_SMS;
		end
		
		if(mute_req)ctr <= ctr + 1;
			else
		ctr <= 0;	
		
	end
	

endmodule



