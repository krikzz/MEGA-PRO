
`include "../base/defs.v"

module cheats(
	
	input clk,
	input [`BW_MAP_IN-1:0]mapin,
	input cheats_on,
	output [15:0]cheats_do,
	output cheats_oe
);
	
	`include "../base/mdbus.v"
	`include "../base/map_in.v"
	`include "../base/sys_cfg.v"
	`include "../base/pi_bus.v"
	
	//assign cheats_oe = (cheats_oe_rom | cheats_oe_ram) & cheats_on;
	//assign cheats_do[15:0] = cheats_oe_ram ? par_do[15:0] : data[sel[3:0]][15:0];
	//wire cheats_oe_rom = !sel[4] & !ce_hi & !oe & cpu_addr[23] == 0;
	
	assign cheats_oe = cheats_on & !sel[4] & !ce_hi & !oe & cpu_addr[23] == 0;
	assign cheats_do[15:0] = data[sel[3:0]][15:0];
	
	
	integer i;
	reg [4:0]sel;
	
	always @(cpu_addr)
	begin
	
		sel = 5'h10;
		for(i = 0; i < 16; i = i + 1)
		begin
			if(addr[i][23:0] == cpu_addr[23:0])sel = i;
		end
		
	end
	
	
	reg [23:0]addr[16];//a23 acts as on/off
	reg [15:0]data[16];
	
	
	always @(negedge clk)
	if(pi_ce_ggc & pi_we & pi_sync)
	begin
		
		if(pi_addr[2:0] == 1)addr[pi_addr[6:3]][23:16] <= pi_do[7:0];
		if(pi_addr[2:0] == 2)addr[pi_addr[6:3]][15:8]  <= pi_do[7:0];
		if(pi_addr[2:0] == 3)addr[pi_addr[6:3]][7:0]   <= pi_do[7:0];
		if(pi_addr[2:0] == 4)data[pi_addr[6:3]][15:8]  <= pi_do[7:0];
		if(pi_addr[2:0] == 5)data[pi_addr[6:3]][7:0]   <= pi_do[7:0];
		
	end
	
//************************************************************************************* ram cheats
	/*
	wire cheats_oe_ram = par_on & (code_oe | vbl_oe);
	wire code_oe = !ce_hi & !oe & {cpu_addr[23:8], 8'h00} == 24'h3fff00;
	
	
	wire [15:0]par_do = 
	vbl_ce & cpu_addr[1] == 0 ? 16'h003f :
	vbl_ce & cpu_addr[1] == 1 ? 16'hff00 :
	cpu_addr[7:3] >= par_ctr ? par_do_ret : 
	par_do_cmd;
	
	wire [15:0]par_do_cmd = 
	cpu_addr[2:0] == 0 ? 16'h33FC : 
	cpu_addr[2:0] == 2 ? data[par_addr][15:0]  : 
	cpu_addr[2:0] == 4 ? addr[par_addr][23:16] : addr[par_addr][15:0];
	
	
	wire [15:0]par_do_ret = 
	cpu_addr[2:0] == 0 ? 16'h4EF9 : 
	cpu_addr[2:0] == 2 ? vbl_addr[31:16] : 
	cpu_addr[2:0] == 4 ? vbl_addr[15:0]  : 0;

	wire par_on = par_ctr != 0 & par_sw_on;
	wire [3:0]par_addr = par_idx[cpu_addr[6:3]];
	
	reg [4:0]par_ctr;
	reg [3:0]par_idx[16];
	
	always @(negedge clk)
	if(pi_ce_ggc & pi_we & pi_sync)
	begin
				
		if(pi_addr[6:0] == 0)
		begin
			par_ctr <= 0;
		end
		
		if(pi_addr[2:0] == 6 & addr[pi_addr[6:3]][23:16] == 8'hff)
		begin
			par_ctr <= par_ctr + 1;
			par_idx[par_ctr] <= pi_addr[6:3];
		end
		

	end
	
	wire vbl_ce = {cpu_addr[23:2], 2'b00} == 24'h78 & !as & !ce_lo;
	wire vbl_oe = !oe & vbl_ce;
	
	
	reg [31:0]vbl_addr;
	reg [7:0]oe_st;
	reg par_sw_on;
	reg par_close;
	
	always @(negedge clk)
	begin
	
	
		oe_st[7:0] <= {oe_st[6:0], !oe};
		
		if(map_rst)
		begin
			par_sw_on <= 0;
			vbl_addr <= 0;
		end
			else
		if(oe_st[5:0] == 6'b011111 & vbl_oe & !par_sw_on)
		begin
			if(cpu_addr[1] == 0)vbl_addr[31:16] <= cpu_data[15:0];
			if(cpu_addr[1] == 1)vbl_addr[15:0]  <= cpu_data[15:0];
		end
		
		if(oe_st[2:0] == 3'b001 & vbl_addr != 0 & vbl_oe & cpu_addr[1] == 0)par_sw_on <= 1;//turn on cheat frame
			else
		if(oe_st[2:0] == 3'b001 & cpu_addr[7:3] >= par_ctr & cpu_addr[2:0] == 4 & code_oe & par_sw_on)par_close <= 1;//turn off request at the end of rd cycle
			else
		if(oe_st[2:0] == 3'b110 & par_close)//turn off cheats frame
		begin
			par_close <= 0;
			par_sw_on <= 0;
		end
		
	end
	*/
	
endmodule




