


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
	

	assign brm_do[7:0]  	= {sda_out, sda_out, sda_out, sda_out, sda_out, sda_out, 1'b0, sda_out};
	assign brm_do[15:8] 	= {sda_out, sda_out, sda_out, sda_out, sda_out, sda_out, 1'b0, sda_out};
	assign brm_oe 			= eep_ce_rd & !cpu.oe & eep_on;
	assign mem_ce 			= eep_on & (mem_oe_8 | mem_we_8 | eep_act_st);
	
	wire eep_ce_rd = 
	cfg.bram_bus == `BRAM_BUS_CODM ? (!cpu.ce_lo & cpu.addr[21:19] == 3'b111) : 
	cfg.bram_bus == `BRAM_BUS_ACLM ? eep_ce & !aclm_eep_off :
	eep_ce;
	
	wire eep_ce 	= 
	cfg.bram_bus == `BRAM_BUS_CODM ? (!cpu.ce_lo & cpu.addr[21:19] == 3'b110) : 
												(!cpu.ce_lo & cpu.addr[21] == 1'b1);
	
	wire eep_on 	= cfg.bram_type >= `BRAM_24X01 & cfg.bram_type <= `BRAM_24C64;
	wire eep_rst 	= mai.map_rst | !eep_on;
	
	wire sda_out;
	
	reg scl, sda_in;
	reg aclm_eep_off;
	reg eep_act_st;
	//!!!!!acclaim eep_off flag required!
	
	always @(negedge clk)
	if(eep_rst)
	begin
		eep_act_st <= 0;
		aclm_eep_off <= 1;
		scl <= 1;
		sda_in <= 1;
	end
		else
	if(!mai.sst.act)
	begin
		
		eep_act_st <= mem_oe_8 | mem_we_8;
		
		if(eep_we_edge)
		case(cfg.bram_bus)
			`BRAM_BUS_ACLM:begin//D=200001(0), C=200000(0)
				if(cpu.we_lo == 0 & cpu.we_hi == 1 & !aclm_eep_off)sda_in 	<= cpu.data[0];
				if(cpu.we_lo == 1 & cpu.we_hi == 0 & !aclm_eep_off)scl 		<= cpu.data[0];
				if(cpu.we_lo == 0 & cpu.we_hi == 0)aclm_eep_off 				<= cpu.data[0];
			end
			`BRAM_BUS_EART:begin//D=200000(7), C=200000(6)
				if(!cpu.we_hi)sda_in <= cpu.data[7];
				if(!cpu.we_hi)scl 	<= cpu.data[6];
			end
			`BRAM_BUS_SEGA:begin//D=200001(0), C=200001(1)
				if(!cpu.we_lo)sda_in <= cpu.data[0];
				if(!cpu.we_lo)scl 	<= cpu.data[1];
			end
			`BRAM_BUS_CODM:begin//D=300000(0), C=300000(1), RD=380001(7)
				if(!cpu.we_hi)sda_in <= cpu.data[0];
				if(!cpu.we_hi)scl 	<= cpu.data[1];
			end
		endcase
		
	end
	
	
	wire eep_we_edge;
	sync_edge eep_sync(.clk(clk), .ce(eep_ce & (!cpu.we_hi | !cpu.we_lo)), .sync(eep_we_edge));
	
	
	wire [7:0]mem_do_8, mem_di_8;
	wire [15:0]mem_addr_8;
	wire mem_oe_8, mem_we_8;
	
	eep_24cXX eep_inst(

		.clk(clk),
		.rst(eep_rst),
		.cfg(cfg),
		
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
	
	//assign led = aclm_eep_off;
	
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


module eep_24cXX(

	input clk,
	input rst,
	input SysCfg cfg,
	
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
	cfg.bram_type == `BRAM_24X01 ? ram_addr_int[6:0] : 
	cfg.bram_type == `BRAM_24C01 ? ram_addr_int[6:0] : 
	cfg.bram_type == `BRAM_24C02 ? ram_addr_int[7:0] : 
	cfg.bram_type == `BRAM_24C08 ? ram_addr_int[9:0] : 
	cfg.bram_type == `BRAM_24C16 ? ram_addr_int[10:0] : 
	cfg.bram_type == `BRAM_24C64 ? ram_addr_int[12:0] : 0;
	
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
	
	
	always @(negedge clk)
	begin
		sda_in_st <= sda_in;
		scl_st <= scl;
	end
	
	always @(negedge clk)
	if(rst)
	begin
		state <= 0;
		ram_oe <= 0;
		ram_we <= 0;
		sda_int <= 1;
	end
		else
	begin
		

		if(delay)delay <= delay - 1;
		if(delay == 0 & ram_oe)ram_buf[7:0] <= ram_do[7:0];
		if(delay == 0 & ram_oe)ram_oe <= 0;
		if(delay == 0 & ram_we)ram_we <= 0;
		
		if(scl_e_hi & bit_ctr[3] == 0)buff[7 - bit_ctr[2:0]] <= sda_in;
		if(scl_e_hi)bit_ctr <= bit_ctr == 8 ? 0 : bit_ctr + 1;
		
		
		if(stop)state <= 0;
			else
		if(start)
		begin
			sda_int <= 1;
			bit_ctr <= 0;
			if(cfg.bram_type == `BRAM_24X01)state <= 1;
			if(cfg.bram_type == `BRAM_24C01)state <= 2;
			if(cfg.bram_type == `BRAM_24C02)state <= 2;
			if(cfg.bram_type == `BRAM_24C08)state <= 2;
			if(cfg.bram_type == `BRAM_24C16)state <= 2;
			if(cfg.bram_type == `BRAM_24C64)state <= 4;
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
					ram_addr_int[6:0] <= buff[7:1];
					state <= buff[0] == 1 ? 11 : 10;
				end
			end
//************************************************************************************* rx addr 24c01 - 24c16
			2:begin
				if(scl_e_lo & bit_ctr == 8 & buff[7:4] == 4'b1010)sda_int <= 0;
				if(scl_e_hi & bit_ctr == 8 & buff[7:4] != 4'b1010)state <= 0;
				if(scl_e_hi & bit_ctr == 8 & buff[7:4] == 4'b1010)
				begin
					ram_addr_int[10:8] <= buff[3:1];
					state <= buff[0] == 1 ? 11 : state + 1;
				end
			end
			3:begin
			
				if(scl_e_lo & bit_ctr != 8)sda_int <= 1;//release ack
				if(scl_e_lo & bit_ctr == 8)sda_int <= 0;
				
				if(scl_e_hi & bit_ctr == 8)
				begin
					ram_addr_int[7:0] <= buff[7:0];
					state <= 10;
				end
			end
//************************************************************************************* rx addr 24c64
			4:begin
				if(scl_e_lo & bit_ctr == 8 & buff[7:4] == 4'b1010)sda_int <= 0;
				if(scl_e_hi & bit_ctr == 8 & buff[7:4] != 4'b1010)state <= 0;
				if(scl_e_hi & bit_ctr == 8 & buff[7:4] == 4'b1010)
				begin
					state <= buff[0] == 1 ? 11 : state + 1;
				end
			end
			5:begin
			
				if(scl_e_lo & bit_ctr != 8)sda_int <= 1;//release ack
				if(scl_e_lo & bit_ctr == 8)sda_int <= 0;
				
				if(scl_e_hi & bit_ctr == 8)
				begin
					ram_addr_int[15:8] <= buff[7:0];
					state <= state + 1;
				end
			end
			6:begin
			
				if(scl_e_lo & bit_ctr != 8)sda_int <= 1;//release ack
				if(scl_e_lo & bit_ctr == 8)sda_int <= 0;
				
				if(scl_e_hi & bit_ctr == 8)
				begin
					ram_addr_int[7:0] <= buff[7:0];
					state <= 10;
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
					if(cfg.bram_type == `BRAM_24X01)ram_addr_int[1:0] <= ram_addr_int[1:0] + 1;
					if(cfg.bram_type == `BRAM_24C01)ram_addr_int[2:0] <= ram_addr_int[2:0] + 1;
					if(cfg.bram_type == `BRAM_24C02)ram_addr_int[2:0] <= ram_addr_int[2:0] + 1;
					if(cfg.bram_type == `BRAM_24C08)ram_addr_int[3:0] <= ram_addr_int[3:0] + 1;
					if(cfg.bram_type == `BRAM_24C16)ram_addr_int[3:0] <= ram_addr_int[3:0] + 1;
					if(cfg.bram_type == `BRAM_24C64)ram_addr_int[4:0] <= ram_addr_int[4:0] + 1;
				end
				
			end
//************************************************************************************* rd op			
			11:begin
				ram_oe <= 1;
				delay <= 3;
				state <= state + 1;
			end
			12:begin
			
				if(scl_e_lo & bit_ctr != 8)sda_int <= ram_buf[7 - bit_ctr[2:0]];
				if(scl_e_lo & bit_ctr == 8)sda_int <= 1;//release bus for ack receive
				
				
				if(scl_e_hi & bit_ctr == 7)//read next byte from ram
				begin
					ram_addr_int <= ram_addr_int + 1;
					ram_oe <= 1;
					delay <= 3;//80ns
				end

				if(scl_e_hi & bit_ctr == 8 & sda_in == 1)state <= 0;//end rd if no ack
				
			end
			
		endcase
		
	end

endmodule
