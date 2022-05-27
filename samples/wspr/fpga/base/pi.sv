
typedef struct{
	
	
	bit dst_mem;
	bit dst_map;
	
	bit ce_rom0;
	bit ce_rom1;
	bit ce_sram;
	bit ce_bram;
	
	bit ce_sys;
	bit ce_fifo;
	bit ce_map;
	
	bit ce_ggc;
	bit ce_cfg;
	bit ce_sst;
	
	bit ce_mcfg;
	bit ce_mod;
		
}PiMap;

typedef struct{
	
	bit [31:0]addr;
	bit [7:0]dato;
	bit oe; 
	bit we;
	bit act;
	bit clk;
	bit sync;
	bit we_sync;
	
	PiMap map;
	
}PiBus;



module pi_io_map(
	EDBus ed
);
	
	
	PiMap map;
	assign ed.pi.map 		= map;
	
	PiBus pi;
	assign pi 				= ed.pi;
	
	wire pi_on 				= ed.pi.oe | ed.pi.we;
	wire pi_act 			= ed.pi.act;
	wire [31:0]pi_addr 	= ed.pi.addr[31:0];
	wire [1:0]pi_dst 		= pi_addr[24:23];//8M blocks
	wire pi_we_sync		= ed.pi.we_sync;
	
	assign map.dst_mem	= pi_dst != 3;
	assign map.dst_map	= pi_dst == 3 & pi_addr[22:16] == 3;//64K.
	
	assign map.ce_rom0 	= pi_on  & pi_dst == 0;							 		//8M		0x0000000
	assign map.ce_rom1 	= pi_on  & pi_dst == 1;							 		//8M		0x0800000
	assign map.ce_sram 	= pi_on  & pi_dst == 2 & pi_addr[22:19] == 0;	//512K	0x1000000
	assign map.ce_bram 	= pi_on  & pi_dst == 2 & pi_addr[22:19] == 1;	//512K	0x1080000
	assign map.ce_sys  	= pi_act & pi_dst == 3 & pi_addr[22:16] == 0;	//64K		0x1800000
	assign map.ce_fifo 	= pi_act & pi_dst == 3 & pi_addr[22:16] == 1;	//64K. 	0x1810000 do not use next 64k
	assign map.ce_map  	= pi_act & map.dst_map;									//64K. 	0x1830000 mapper io
	
	//map config
	assign map.ce_ggc	 	= map.ce_sys & {pi_addr[15:7], 7'd0} == 16'h0000;//128B cheats
	assign map.ce_cfg	 	= map.ce_sys & {pi_addr[15:3], 3'd0} == 16'h00f8;//8B sys config
	assign map.ce_sst	 	= map.ce_sys & {pi_addr[15:8], 8'd0} == 16'h0100;//256B save state data. 128B sniffer, 128B map regs
	
	assign map.ce_mcfg	= map.ce_map & {pi_addr[15:8], 8'd0}  == 16'hff00;//mapper config.  256B
	assign map.ce_mod  	= map.ce_map & pi_addr[15:0] 			  == 16'hffff;//mapper mode. 
	
	
endmodule


module pi_io(

	EDBus ed,
	input [7:0]dati,
	output miso,
	input mosi, ss, spi_clk
);
	
	
	assign ed.pi.addr[31:0]		= aout[31:0];
	assign ed.pi.dato[7:0]	= dout[7:0];
	assign ed.pi.oe				= pi_oe;
	assign ed.pi.we				= pi_we;
	assign ed.pi.act				= pi_act;
	assign ed.pi.clk				= spi_clk;
	assign ed.pi.sync				= pi_sync;
	assign ed.pi.we_sync			= pi_sync & pi_we;
	
	wire clk							= ed.clk;
	
	
	//assign pi_bus[`BW_PI_BUS-1:0] = {pi_sync, spi_clk, pi_act, pi_we, pi_oe, dout[7:0], aout[31:0]};
	
	reg[7:0]dout;
	reg[31:0]aout;
	wire pi_we, pi_oe, pi_sync;
	reg pi_act;
	
	
	parameter CMD_MEM_WR	= 8'hA0;
	parameter CMD_MEM_RD	= 8'hA1;
	
	assign miso = !ss ? sout[7] : 1'bz;
	assign pi_oe = cmd[7:0] == CMD_MEM_RD & exec;
	assign pi_we = cmd[7:0] == CMD_MEM_WR & exec;
	assign pi_sync = sync_st[1:0] == 2'b01;
	
	reg [7:0]sin;
	reg [7:0]sout;
	reg [2:0]bit_ctr;
	reg [7:0]cmd;
	reg [3:0]byte_ctr;
	reg [7:0]rd_buff;
	reg wr_ok;
	reg exec;
	reg [1:0]sync_st;
	
	
	always @(negedge clk)
	begin
		sync_st[1:0] <= {sync_st[0], pi_act};
	end
	
	
	always @(posedge spi_clk)
	begin
		sin[7:0] <= {sin[6:0], mosi};
	end
	
	
	always @(negedge spi_clk)
	if(ss)
	begin
		cmd[7:0] <= 8'h00;
		sout[7:0] <= 8'hff;
		bit_ctr[2:0] <= 3'd0;
		byte_ctr[3:0] <= 4'd0;
		pi_act <= 0;
		wr_ok <= 0;
		exec <= 0;
	end
		else
	begin
		
		
		bit_ctr <= bit_ctr + 1;
				
		
		if(bit_ctr == 7 & !exec)
		begin
			if(byte_ctr[3:0] == 4'd0)cmd[7:0] <= sin[7:0];
			if(byte_ctr[3:0] == 4'd1)aout[7:0] <= sin[7:0];
			if(byte_ctr[3:0] == 4'd2)aout[15:8] <= sin[7:0];
			if(byte_ctr[3:0] == 4'd3)aout[23:16] <= sin[7:0];
			if(byte_ctr[3:0] == 4'd4)aout[31:24] <= sin[7:0];
			if(byte_ctr[3:0] == 4'd4)exec <= 1;
			byte_ctr <= byte_ctr + 1;
		end
		
		
		
		if(cmd[7:0] == CMD_MEM_WR & exec)
		begin
			if(bit_ctr == 7)dout[7:0] <= sin[7:0];
			if(bit_ctr == 7)wr_ok <= 1;
			if(bit_ctr == 0 & wr_ok)pi_act <= 1;
			if(bit_ctr == 5 & wr_ok)pi_act <= 0;
			if(bit_ctr == 6 & wr_ok)aout <= aout + 1;
		end

		
		if(cmd[7:0] == CMD_MEM_RD & exec)
		begin
			if(bit_ctr == 1)pi_act <= 1;
			if(bit_ctr == 5)rd_buff[7:0] <= dati[7:0];
			if(bit_ctr == 5)aout <= aout + 1;
			if(bit_ctr == 5)pi_act <= 0;//should not release on last cycle. otherwise spi clocked thing may not work properly
			if(bit_ctr == 7)sout[7:0] <= rd_buff[7:0];
			
			if(bit_ctr != 7)sout[7:0] <= {sout[6:0], 1'b1};
		end
		
	end

endmodule
