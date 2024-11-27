
typedef struct{
	bit sda_ck;
	bit scl_ck;
	bit sda;
	bit scl;
	bit ce_wr;
	bit ce_rd;
	bit [7:0]sda_and;//output mask
	bit [7:0]sda_or;
}EBusCfg;

typedef struct{
	bit [13:0]size;
	bit [5:0]page;
	bit [1:0]amode;
}ETypeCfg;

//************************************************************************************* eeprom entry
//*************************************************************************************
//*************************************************************************************

module bram_eep24x(

	input  MapIn mai,
	output brm_oe,
	output [15:0]brm_do,
	
	input  [15:0]mem_do,
	output [15:0]mem_di,
	output [18:0]mem_addr,
	output mem_ce, mem_oe, mem_we_lo, mem_we_hi,
	output led
		
);
	
	CpuBus cpu;
	assign cpu 	= mai.cpu;
	
	SysCfg cfg;
	assign cfg 	= mai.cfg;
	
	wire clk 	= mai.clk;
	
	ETypeCfg eep_chip;
	EBusCfg  eep_bus;
	
//**************************************************************** bus ctrl

	wire eep_on1			= (cfg.bram_type >= `BRAM_24X01 & cfg.bram_type <= `BRAM_24C64);
	wire eep_on2			= (cfg.bram_type >= `BRAM_24X02 & cfg.bram_type <= `BRAM_24C04);
	wire eep_on 			= eep_on1 | eep_on2;
	wire eep_rst 			= mai.map_rst | !eep_on;	

	wire sda_in;
	wire scl;
	wire mem_act			= mem_oe_8 | mem_we_8;
	
	
	eep_bus_ctrl eep_bus_ctrl_inst(

		.clk(clk),
		.rst(eep_rst),
		.we_edge(we_edge & !mai.sst.act),
		.eep_on(eep_on),
		.mem_act(mem_act & !mai.sst.act),
		.sda_out(sda_out),
		.cpu(cpu),
		.eep_bus(eep_bus),
		
		.mem_ce(mem_ce),
		.sda_in(sda_in),
		.scl(scl),
		.brm_oe(brm_oe),
		.brm_do(brm_do)
	);
//**************************************************************** config
		
	eep_config eep_config_inst(

		.clk(clk),
		.rst(eep_rst),
		.we_edge(we_edge & !mai.sst.act),
		.cpu(cpu),
		.cfg(cfg),
		
		.eep_chip(eep_chip),
		.eep_bus(eep_bus)
	);

//**************************************************************** edge detector
	wire eep_we = eep_bus.ce_wr & (!cpu.we_hi | !cpu.we_lo);
	
	edge_dtk edge_dtk_inst(

		.clk(clk),
		.sync_mode(1),
		.sig_i(eep_we),
		.sig_pe(we_edge),
	);
//****************************************************************  eep core
	wire [7:0]mem_do_8, mem_di_8;
	wire [15:0]mem_addr_8;
	wire mem_oe_8, mem_we_8;
	wire sda_out;
	
	eep_24cXX eep_inst(

		.clk(clk),
		.rst(eep_rst),
		.cfg(eep_chip),
		
		.scl(scl),
		.sda_in(sda_in),
		.sda_out(sda_out),
		
		.ram_do(mem_do_8[7:0]),
		.ram_di(mem_di_8[7:0]),
		.ram_addr(mem_addr_8[15:0]),
		.ram_oe(mem_oe_8), 
		.ram_we(mem_we_8),
		.led(led)
	);
//****************************************************************  mem 8 to 16
	mem_8_to_16 mem_16_inst(
	
		.dout_16(mem_do[15:0]),
		.din_16(mem_di[15:0]),
		.addr_16(mem_addr[15:0]),
		.oe_16(mem_oe), 
		.we_lo_16(mem_we_lo), 
		.we_hi_16(mem_we_hi),
		
		.dout_8(mem_do_8[7:0]),
		.din_8(mem_di_8[7:0]),
		.addr_8(mem_addr_8[15:0]),
		.oe_8(mem_oe_8), 
		.we_8(mem_we_8)
	);
	
endmodule

//************************************************************************************* bus controller
//*************************************************************************************
//*************************************************************************************

module eep_bus_ctrl(

	input  clk,
	input  rst,
	input  we_edge,
	input  eep_on,
	input  mem_act,
	input  sda_out,
	input  CpuBus cpu,
	input  EBusCfg  eep_bus,
	
	
	output mem_ce,
	output sda_in,
	output scl,
	output brm_oe,
	output [15:0]brm_do
);
	
	assign brm_oe 			= eep_bus.ce_rd & !cpu.oe & eep_on;
	assign mem_ce 			= eep_on & (mem_act | mem_act_st);
	
	assign brm_do[7:0]  	= (sda8 & eep_bus.sda_and) | eep_bus.sda_or;
	assign brm_do[15:8] 	= brm_do[7:0];
	
	wire [7:0]sda8			= {sda_out, sda_out, sda_out, sda_out, sda_out, sda_out, sda_out, sda_out};
	
	always @(posedge clk)
	if(rst)
	begin
		scl 				<= 1;
		sda_in 			<= 1;
	end
		else
	if(we_edge)
	begin
		
		
		if(eep_bus.sda_ck)
		begin
			sda_in		<=	eep_bus.sda;
		end
		
		if(eep_bus.scl_ck)
		begin
			scl			<=	eep_bus.scl;
		end
		
	end
	
	
	reg mem_act_st;//one cycle bus hold
	
	always @(posedge clk)
	if(rst)
	begin
		mem_act_st	<= 0;
	end
		else
	begin
		mem_act_st	<= mem_act;
	end
	
endmodule

//************************************************************************************* config
//*************************************************************************************
//*************************************************************************************
module eep_config(

	input  clk,
	input  rst,
	input  we_edge,
	input  CpuBus cpu,
	input  SysCfg cfg,
	
	output ETypeCfg eep_chip,
	output EBusCfg  eep_bus
);

//****************************************************************  chip config
	ETypeCfg eep_24x01;
	ETypeCfg eep_24c01;
	ETypeCfg eep_24c02;
	ETypeCfg eep_24x02;
	ETypeCfg eep_24c04;
	ETypeCfg eep_24c08;
	ETypeCfg eep_24c16;
	ETypeCfg eep_24c64;
	ETypeCfg eep_chip_off;
	
	
	assign eep_24x01.size 	= 128;
	assign eep_24x01.page 	= 4;
	assign eep_24x01.amode 	= 1;
	
	assign eep_24c01.size 	= 128;
	assign eep_24c01.page 	= 8;
	assign eep_24c01.amode 	= 2;
	
	assign eep_24c02.size 	= 256;
	assign eep_24c02.page 	= 8;
	assign eep_24c02.amode 	= 2;
	
	assign eep_24x02.size 	= 256;
	assign eep_24x02.page 	= 4;
	assign eep_24x02.amode 	= 2;
	
	assign eep_24c04.size 	= 512;
	assign eep_24c04.page 	= 16;
	assign eep_24c04.amode 	= 2;
	
	assign eep_24c08.size 	= 1024;
	assign eep_24c08.page 	= 16;
	assign eep_24c08.amode 	= 2;
	
	assign eep_24c16.size 	= 2048;
	assign eep_24c16.page 	= 16;
	assign eep_24c16.amode 	= 2;
	
	assign eep_24c64.size 	= 8192;
	assign eep_24c64.page 	= 32;
	assign eep_24c64.amode 	= 3;
	
	
	assign eep_chip			=
	cfg.bram_type == `BRAM_24X01 ? eep_24x01 :
	cfg.bram_type == `BRAM_24C01 ? eep_24c01 :
	cfg.bram_type == `BRAM_24C02 ? eep_24c02 :
	cfg.bram_type == `BRAM_24X02 ? eep_24x02 :
	cfg.bram_type == `BRAM_24C04 ? eep_24c04 :
	cfg.bram_type == `BRAM_24C08 ? eep_24c08 :
	cfg.bram_type == `BRAM_24C16 ? eep_24c16 :
	cfg.bram_type == `BRAM_24C64 ? eep_24c64 :
	eep_chip_off;

//****************************************************************  bus config
	EBusCfg acl0;//D=200001(0), C=200000(0)
	EBusCfg eart;//D=200000(7), C=200000(6)
	EBusCfg sega;//D=200001(0), C=200001(1)
	EBusCfg codm;//D=300000(0), C=300000(1), RD=380001(7)
	EBusCfg acl1;//D=200001(0), C=200001(1), RD=380001(1)
	EBusCfg eep_bus_off;
	
	assign eep_bus_off.sda_or	= 8'b11111111;
	
	assign acl0.ce_wr		= !cpu.ce_lo & cpu.addr[21] == 1'b1;
	assign acl0.ce_rd		= acl0.ce_wr & !acl0_eep_off;
	assign acl0.sda_ck	= cpu.we_lo == 0 & cpu.we_hi == 1 & !acl0_eep_off;
	assign acl0.scl_ck	= cpu.we_lo == 1 & cpu.we_hi == 0 & !acl0_eep_off;
	assign acl0.sda		= cpu.data[0];
	assign acl0.scl		= cpu.data[0];
	assign acl0.sda_and	= 8'b11111101;
	assign acl0.sda_or	= 8'b00000000;

	
	assign eart.ce_wr		= !cpu.ce_lo & cpu.addr[21] == 1'b1;
	assign eart.ce_rd		= eart.ce_wr;
	assign eart.sda_ck	= !cpu.we_hi;
	assign eart.scl_ck	= !cpu.we_hi;
	assign eart.sda		= cpu.data[7];
	assign eart.scl		= cpu.data[6];
	assign eart.sda_and	= 8'b11111101;
	assign eart.sda_or	= 8'b00000000;
	
	assign sega.ce_wr		= !cpu.ce_lo & cpu.addr[21] == 1'b1;
	assign sega.ce_rd		= sega.ce_wr;
	assign sega.sda_ck	= !cpu.we_lo;
	assign sega.scl_ck	= !cpu.we_lo;
	assign sega.sda		= cpu.data[0];
	assign sega.scl		= cpu.data[1];
	assign sega.sda_and	= 8'b11111101;
	assign sega.sda_or	= 8'b00000000;
	
	assign codm.ce_wr		= !cpu.ce_lo & cpu.addr[21:19] == 3'b110;
	assign codm.ce_rd		= !cpu.ce_lo & cpu.addr[21:19] == 3'b111;
	assign codm.sda_ck	= !cpu.we_hi;
	assign codm.scl_ck	= !cpu.we_hi;
	assign codm.sda		= cpu.data[0];
	assign codm.scl		= cpu.data[1];
	assign codm.sda_and	= 8'b11111101;
	assign codm.sda_or	= 8'b00000000;
	
	assign acl1.ce_wr		= !cpu.ce_lo & cpu.addr[21] == 1'b1;
	assign acl1.ce_rd		= acl1.ce_wr;
	assign acl1.sda_ck	= !cpu.we_lo;
	assign acl1.scl_ck	= !cpu.we_lo;
	assign acl1.sda		= cpu.data[0];
	assign acl1.scl		= cpu.data[1];
	assign acl1.sda_and	= 8'b00000010;
	assign acl1.sda_or	= 8'b11111101;
	
	
	assign eep_bus			= 
	cfg.bram_bus == `BRAM_BUS_ACL0 ? acl0 : 
	cfg.bram_bus == `BRAM_BUS_ACL1 ? acl1 : 
	cfg.bram_bus == `BRAM_BUS_EART ? eart : 
	cfg.bram_bus == `BRAM_BUS_SEGA ? sega : 
	cfg.bram_bus == `BRAM_BUS_CODM ? codm : 
	eep_bus_off;
	
//**************************************************************** 	acl0 locker
	reg acl0_eep_off;
	
	always @(posedge clk)
	if(rst)
	begin
		acl0_eep_off	<= 1;
	end
		else
	if(we_edge & !cpu.we_lo & !cpu.we_hi)
	begin
		acl0_eep_off	<= cpu.data[0];
	end
	
endmodule

//************************************************************************************* core
//*************************************************************************************
//*************************************************************************************

module eep_24cXX(

	input clk,
	input rst,
	input ETypeCfg cfg,
	
	input scl,
	input sda_in,
	output sda_out,
	
	input [7:0]ram_do,
	output [7:0]ram_di,
	output [15:0]ram_addr,
	output reg ram_oe, ram_we,
	output led
);
	
	
	assign sda_out = !sda_in ? 0 : sda_int;
	
	assign ram_di[7:0] = buff[7:0];
	
	assign ram_addr[15:0] = 
	cfg.size == 128 	? ram_addr_int[6:0] : 
	cfg.size == 256 	? ram_addr_int[7:0] : 
	cfg.size == 512 	? ram_addr_int[8:0] : 
	cfg.size == 1024 	? ram_addr_int[9:0] : 
	cfg.size == 2048 	? ram_addr_int[10:0] : 
	cfg.size == 4096 	? ram_addr_int[11:0] : 
	cfg.size == 8192 	? ram_addr_int[12:0] : 
	0;
	
	
	wire start = scl & scl_st & sda_e & sda_in == 0;//may be use scl_st 
	wire stop =  scl & scl_st & sda_e & sda_in == 1;//may be use scl_st 
	wire sda_e = sda_in != sda_in_st;
	wire scl_e_hi = scl == 1 & scl_st == 0;
	wire scl_e_lo = scl == 0 & scl_st == 1;
	
	reg [15:0]ram_addr_int;
	reg [3:0]state;
	reg [3:0]bit_ctr;
	reg [2:0]delay;
	reg [7:0]buff;
	reg [7:0]ram_buf;
	reg sda_in_st, scl_st;
	reg sda_int;
	
	assign led = state != 0;
	
	
	always @(posedge clk)
	begin
		sda_in_st 	<= sda_in;
		scl_st 		<= scl;
	end
	
	always @(posedge clk)
	if(rst)
	begin
		state 		<= 0;
		ram_oe 		<= 0;
		ram_we 		<= 0;
		sda_int 		<= 1;
	end
		else
	begin
		

		if(delay)delay <= delay - 1;
		if(delay == 0 & ram_oe)ram_buf[7:0] <= ram_do[7:0];
		if(delay == 0 & ram_oe)ram_oe <= 0;
		if(delay == 0 & ram_we)ram_we <= 0;
		
		if(scl_e_hi & bit_ctr[3] == 0)buff[7 - bit_ctr[2:0]] <= sda_in;
		if(scl_e_hi)bit_ctr <= bit_ctr == 8 ? 0 : bit_ctr + 1;
		
		
		if(stop)
		begin
			state 						<= 0;
		end
			else
		if(start)
		begin
			sda_int 						<= 1;
			bit_ctr 						<= 0;
			if(cfg.amode == 1)state	<= 1;
			if(cfg.amode == 2)state <= 2;
			if(cfg.amode == 3)state <= 4;
		end
			else
		case(state)
			0:begin//idle
				sda_int <= 1;
			end
//************************************************************************************* rx addr 24x01
			1:begin
				if(scl_e_lo & bit_ctr == 8)sda_int <= 0;
				if(scl_e_hi & bit_ctr == 8)
				begin
					ram_addr_int[6:0] 	<= buff[7:1];
					state 					<= buff[0] == 1 ? 11 : 10;
				end
			end
//************************************************************************************* rx addr 24c01 - 24c16
			2:begin
				if(scl_e_lo & bit_ctr == 8 & buff[7:4] == 4'b1010)sda_int <= 0;
				if(scl_e_hi & bit_ctr == 8 & buff[7:4] != 4'b1010)state <= 0;
				if(scl_e_hi & bit_ctr == 8 & buff[7:4] == 4'b1010)
				begin
					ram_addr_int[10:8] 	<= buff[3:1];
					state 					<= buff[0] == 1 ? 11 : state + 1;
				end
			end
			3:begin
			
				if(scl_e_lo & bit_ctr != 8)sda_int <= 1;//release ack
				if(scl_e_lo & bit_ctr == 8)sda_int <= 0;
				
				if(scl_e_hi & bit_ctr == 8)
				begin
					ram_addr_int[7:0] 	<= buff[7:0];
					state 					<= 10;
				end
			end
//************************************************************************************* rx addr 24c64
			4:begin
				if(scl_e_lo & bit_ctr == 8 & buff[7:4] == 4'b1010)sda_int <= 0;
				if(scl_e_hi & bit_ctr == 8 & buff[7:4] != 4'b1010)state <= 0;
				if(scl_e_hi & bit_ctr == 8 & buff[7:4] == 4'b1010)
				begin
					state 					<= buff[0] == 1 ? 11 : state + 1;
				end
			end
			5:begin
			
				if(scl_e_lo & bit_ctr != 8)sda_int <= 1;//release ack
				if(scl_e_lo & bit_ctr == 8)sda_int <= 0;
				
				if(scl_e_hi & bit_ctr == 8)
				begin
					ram_addr_int[15:8] 	<= buff[7:0];
					state 					<= state + 1;
				end
			end
			6:begin
			
				if(scl_e_lo & bit_ctr != 8)sda_int <= 1;//release ack
				if(scl_e_lo & bit_ctr == 8)sda_int <= 0;
				
				if(scl_e_hi & bit_ctr == 8)
				begin
					ram_addr_int[7:0] 	<= buff[7:0];
					state 					<= 10;
				end
			end
//************************************************************************************* wr op		
			10:begin
			
				if(scl_e_lo & bit_ctr != 8)sda_int <= 1;//release ack
				if(scl_e_lo & bit_ctr == 8)sda_int <= 0;
			
				if(scl_e_hi & bit_ctr == 7)
				begin
					ram_we <= 1;
					delay <= 3;//80ns
				end
				
				if(scl_e_hi & bit_ctr == 8)
				begin
					if(cfg.page ==  4)ram_addr_int[1:0] <= ram_addr_int[1:0] + 1;
					if(cfg.page ==  8)ram_addr_int[2:0] <= ram_addr_int[2:0] + 1;
					if(cfg.page == 16)ram_addr_int[3:0] <= ram_addr_int[3:0] + 1;
					if(cfg.page == 32)ram_addr_int[4:0] <= ram_addr_int[4:0] + 1;
				end
				
			end
//************************************************************************************* rd op			
			11:begin
				ram_oe 				<= 1;
				delay 				<= 3;
				state 				<= state + 1;
			end
			12:begin
			
				if(scl_e_lo & bit_ctr != 8)
				begin
					sda_int 			<= ram_buf[7 - bit_ctr[2:0]];
				end
				
				if(scl_e_lo & bit_ctr == 8)
				begin
					sda_int 			<= 1;//release bus for ack receive
				end
				
				
				if(scl_e_hi & bit_ctr == 7)//read next byte from ram
				begin
					ram_addr_int 	<= ram_addr_int + 1;
					ram_oe 			<= 1;
					delay 			<= 3;//80ns
				end

				if(scl_e_hi & bit_ctr == 8 & sda_in == 1)
				begin
					state 			<= 0;//end rd if no ack
				end
				
			end
			
		endcase
		
	end

endmodule
