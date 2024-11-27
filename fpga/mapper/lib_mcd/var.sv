

module pi_rest(

	input sub_rst,
	input clk_asic, sub_sync,
	input [15:0]sub_data,
	input [14:0]reg_addr,
	input regs_we_lo_sub,
	output pi_ready,
	output pi_rst
);
	
	
	assign pi_ready = timer == 0;
	assign pi_rst = rst_req_st;
	
	wire rst_req = regs_we_lo_sub & reg_addr == 0 & sub_data[0] == 0;//(regs_ce & !sub_we_lo & sub_data[0] == 0 & reg_addr == 9'h000);// | sub_rst;
	
	reg [22:0]timer;
	reg rst_req_st;
		
	always @(posedge clk_asic)
	if(sub_sync)
	begin
	
		rst_req_st <= rst_req;
	
		if(rst_req)timer <= 23'd1250000;
			else
		if(timer != 0)timer <= timer - 1;
		
	end
	

endmodule

module color_calc(

	input clk_asic,
	input [15:0]sub_data,
	input [14:0]regs_addr_sub,
	input regs_we_lo_sub,
	input regs_we_hi_sub,
	
	output [15:0]reg_804C_do,reg_804E_do,
	output [15:0]reg_8050_do, reg_8052_do, reg_8054_do, reg_8056_do
);

	assign reg_804C_do[15:0] = reg_804C[15:0];
	assign reg_804E_do[15:0] = reg_804E[15:0];
	
	wire [3:0]pixel_0 = reg_804C[3:0];
	wire [3:0]pixel_1 = reg_804C[7:4];
	
	assign reg_8050_do[15:12] = reg_804E[15] ? pixel_1 : pixel_0;
	assign reg_8050_do[11:8]  = reg_804E[14] ? pixel_1 : pixel_0;
	assign reg_8050_do[7:4]   = reg_804E[13] ? pixel_1 : pixel_0;
	assign reg_8050_do[3:0]   = reg_804E[12] ? pixel_1 : pixel_0;
	
	assign reg_8052_do[15:12] = reg_804E[11] ? pixel_1 : pixel_0;
	assign reg_8052_do[11:8]  = reg_804E[10] ? pixel_1 : pixel_0;
	assign reg_8052_do[7:4]   = reg_804E[9] ? pixel_1 : pixel_0;
	assign reg_8052_do[3:0]   = reg_804E[8] ? pixel_1 : pixel_0;
	
	assign reg_8054_do[15:12] = reg_804E[7] ? pixel_1 : pixel_0;
	assign reg_8054_do[11:8]  = reg_804E[6] ? pixel_1 : pixel_0;
	assign reg_8054_do[7:4]   = reg_804E[5] ? pixel_1 : pixel_0;
	assign reg_8054_do[3:0]   = reg_804E[4] ? pixel_1 : pixel_0;
	
	assign reg_8056_do[15:12] = reg_804E[3] ? pixel_1 : pixel_0;
	assign reg_8056_do[11:8]  = reg_804E[2] ? pixel_1 : pixel_0;
	assign reg_8056_do[7:4]   = reg_804E[1] ? pixel_1 : pixel_0;
	assign reg_8056_do[3:0]   = reg_804E[0] ? pixel_1 : pixel_0;
	
	reg [15:0]reg_804C, reg_804E;
	
	always @(posedge clk_asic)
	begin
		if(regs_addr_sub == 9'h04C & (regs_we_lo_sub | regs_we_hi_sub))reg_804C[7:0] <= sub_data[7:0];
		if(regs_addr_sub == 9'h04E & regs_we_hi_sub)reg_804E[15:8] <= sub_data[15:8];
		if(regs_addr_sub == 9'h04E & regs_we_lo_sub)reg_804E[7:0] <= sub_data[7:0];
	end
	
endmodule

module timer_800C(

	input rst,
	input clk_asic, sub_sync, 
	input [14:0]reg_addr,
	input regs_we_lo_sub, regs_we_hi_sub,
	output reg[15:0]reg_800C_do
);

	wire timer_tick = phase == 383;
	wire timer_rst = (regs_we_lo_sub | regs_we_hi_sub) & reg_addr == 9'h00C;
	
	reg [8:0]phase;

	always @(posedge clk_asic)
	if(sub_sync)
	begin
	
		if(timer_rst | rst)
		begin
			phase <= 0;
			reg_800C_do[11:0] <= 0;
		end
			else
		begin
			phase <= timer_tick ? 0 : phase + 1;
			if(timer_tick)reg_800C_do[11:0] <= reg_800C_do[11:0] + 1;
		end
		
	end

endmodule


module timer_8030(

	input rst,
	input clk_asic, sub_sync, 
	input regs_we_lo_sub, regs_we_hi_sub,
	input [7:0]sub_data,
	input [14:0]reg_addr,
	output reg[15:0]reg_8030_do,
	output reg irq
);



	wire ctr_on = reg_8030_do[7:0] != 0;
	wire timer_set = (regs_we_lo_sub | regs_we_hi_sub) & reg_addr == 9'h030;
	wire timer_tick = phase == 383;
	
	reg [8:0]phase;
	reg [7:0]ctr;

	always @(posedge clk_asic)
	if(rst)
	begin
		reg_8030_do[7:0] <= 0;
	end
		else
	if(sub_sync)
	begin
	
		if(timer_set)
		begin
			//phase <= 0; //popful mail fix
			ctr <= sub_data[7:0];
			reg_8030_do[7:0] <= sub_data[7:0];
		end
			else
		if(!ctr_on)
		begin
			irq <= 0;
			phase <= 0;
		end
			else
		if(timer_tick)
		begin
			phase <= 0;
			ctr 	<= ctr == 0 ? reg_8030_do[7:0] : ctr - 1;
			irq 	<= ctr == 0;
		end
			else
		begin
			//phase <= irq ? phase - 4 : phase + 1;
			phase <= phase + 1;
			irq 	<= 0;
		end
		
	end

endmodule


module cpu(

	input  clk,
	input  M68K_in  cpu_in,
	output M68K_out cpu_out
);
	
	//assign {sub_rst, clk_sub_n, clk_sub_p, sub_halt, sub_dtak, sub_vpa, sub_br, sub_bgack, sub_ipl[2:0], sub_di[15:0]} = sub_cpu_in[26:0];
	//assign sub_cpu_out[46:0] = {sub_rw, sub_as, sub_lds, sub_uds, sub_halted, sub_fc[2:0], sub_addr[23:1], sub_do[15:0]};
	
	fx68k m68_inst(
	
		.clk(clk),//
		
		.extReset(cpu_in.rst),
		.pwrUp(cpu_in.rst),
		.enPhi1(cpu_in.clk_p),
		.enPhi2(cpu_in.clk_n),

		.eRWn(cpu_out.rw),
		.ASn(cpu_out.as),
		.LDSn(cpu_out.lds),
		.UDSn(cpu_out.uds),
		//.E(sub_e),
		
		//.VMAn(sub_vma),
		.FC0(cpu_out.fc[0]),
		.FC1(cpu_out.fc[1]),
		.FC2(cpu_out.fc[2]),
		//.BGn(sub_bg),
		//.oRESETn(sub_rsto),
		.oHALTEDn(cpu_out.halted),
		.HALTn(cpu_in.halt),
		.DTACKn(cpu_in.dtak),
		.VPAn(cpu_in.vpa),
		.BERRn(1),//uused
		.BRn(cpu_in.br),
		.BGACKn(cpu_in.bgack),
		.IPL0n(cpu_in.ipl[0]),
		.IPL1n(cpu_in.ipl[1]),
		.IPL2n(cpu_in.ipl[2]),
		.iEdb(cpu_in.dati),
		.oEdb(cpu_out.dato),
		.eab(cpu_out.addr[23:1])
	);
	
endmodule


module ram_bram(

	input [7:0]din,
	output reg[7:0]dout,
	input [12:0]addr,
	input we, clk
);

	reg [7:0]ram[8192];

	initial
	begin
		$readmemh("bram.txt", ram);
	end
	
	always @(posedge clk)
	begin
		dout <= we ? din : ram[addr];
		if(we)ram[addr] <= din;
	end


endmodule


module ram_sp8(

	input [7:0]din,
	output reg[7:0]dout,
	input [15:0]addr,
	input we, clk
);

	reg [7:0]ram[65536];

	always @(posedge clk)
	begin
		dout <= we ? din : ram[addr];
		if(we)ram[addr] <= din;
	end


endmodule



module ram_dp8x(

	input [7:0]din,
	output reg [7:0]dout,
	input we, clk,
	input [15:0]addr_w,
	input [15:0]addr_r
);

	reg [7:0]ram[65536];
	
	
	always @(posedge clk)
	begin
		if(we)ram[addr_w] <= din;
	end

	always @(posedge clk)
	begin
		dout <= ram[addr_r];
	end


endmodule




module cd_key(

	input clk,
	input CpuBus cpu,
	output reg[15:0]key_val,
	output key_oe
);
	
	
	assign key_oe = key_oe_st[3:0] == 4'b1111;
	
	wire key_oe_int = cpu.addr == 24'hA10000 & !cpu.as & !cpu.oe;
	
	reg [3:0]key_oe_st;
	
	always @(posedge clk)
	begin
		
		key_oe_st[3:0] = {key_oe_st[2:0], key_oe_int};
		
		if(key_oe_st[3:2] == 2'b01)key_val[15:0] <= cpu.data[15:0] & 16'hDFDF;
		
	end
	
endmodule


module clk_dvp_cd(

	input  clk,
	input  rst,
	input  [31:0]ck_base,
	input  [31:0]ck_targ,
	
	output reg ck_out
);

	
	parameter CLK_INC = 64'h20000;
	
	wire [31:0]ratio 	= ck_base * CLK_INC / ck_targ;
	
	reg [31:0]clk_ctr;
		
	always @(posedge clk)
	if(rst)
	begin
		clk_ctr	<= 0;
		ck_out	<= 0;
	end
		else
	begin
		
		if(clk_ctr >= (ratio-CLK_INC))
		begin
			clk_ctr	<= clk_ctr - (ratio-CLK_INC);
			ck_out 	<= 1;
		end
			else
		begin
			clk_ctr 	<= clk_ctr + CLK_INC;
			ck_out 	<= 0;
		end
		
	end

endmodule

