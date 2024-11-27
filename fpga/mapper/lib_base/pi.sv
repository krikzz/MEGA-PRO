

module pi_io(

	input  clk,
	input  [7:0]dati,
	input  mosi, ss, spi_clk,
	
	output miso,
	output PiBus pi	
);
	
	
	assign pi.addr[31:0]		= aout[31:0];
	assign pi.dato[7:0]		= dout[7:0];
	assign pi.oe				= pi_oe;
	assign pi.we				= pi_we;
	assign pi.act				= pi_act;
	assign pi.clk				= spi_clk;
	assign pi.sync				= pi_sync;
	assign pi.we_sync			= pi_sync & pi_we;

	
	reg[7:0]dout;
	reg[31:0]aout;
	wire pi_we, pi_oe, pi_sync;
	reg pi_act;
	
	
	parameter CMD_MEM_WR	= 8'hA0;
	parameter CMD_MEM_RD	= 8'hA1;
	
	assign miso 	= !ss ? sout[7] : 1'bz;
	assign pi_oe 	= cmd[7:0] == CMD_MEM_RD & exec;
	assign pi_we 	= cmd[7:0] == CMD_MEM_WR & exec;
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
	
	
	always @(posedge clk)
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
		cmd[7:0] 		<= 8'h00;
		sout[7:0] 		<= 8'hff;
		bit_ctr[2:0] 	<= 3'd0;
		byte_ctr[3:0] 	<= 4'd0;
		pi_act 			<= 0;
		wr_ok 			<= 0;
		exec 				<= 0;
	end
		else
	begin
		
		
		bit_ctr <= bit_ctr + 1;
				
		
		if(bit_ctr == 7 & !exec)
		begin
			if(byte_ctr[3:0] == 4'd0)cmd[7:0] 		<= sin[7:0];
			if(byte_ctr[3:0] == 4'd1)aout[7:0] 		<= sin[7:0];
			if(byte_ctr[3:0] == 4'd2)aout[15:8] 	<= sin[7:0];
			if(byte_ctr[3:0] == 4'd3)aout[23:16] 	<= sin[7:0];
			if(byte_ctr[3:0] == 4'd4)aout[31:24] 	<= sin[7:0];
			if(byte_ctr[3:0] == 4'd4)exec <= 1;
			byte_ctr <= byte_ctr + 1;
		end
		
		
		
		if(cmd[7:0] == CMD_MEM_WR & exec)
		begin
			if(bit_ctr == 7)dout[7:0] 			<= sin[7:0];
			if(bit_ctr == 7)wr_ok 				<= 1;
			if(bit_ctr == 0 & wr_ok)pi_act 	<= 1;
			if(bit_ctr == 5 & wr_ok)pi_act 	<= 0;
			if(bit_ctr == 6 & wr_ok)aout 		<= aout + 1;
		end

		
		if(cmd[7:0] == CMD_MEM_RD & exec)
		begin
			if(bit_ctr == 1)pi_act 			<= 1;
			if(bit_ctr == 5)rd_buff[7:0] 	<= dati[7:0];
			if(bit_ctr == 5)aout 			<= aout + 1;
			if(bit_ctr == 5)pi_act 			<= 0;//should not release on last cycle. otherwise spi clocked thing may not work properly
			if(bit_ctr == 7)sout[7:0] 		<= rd_buff[7:0];
			
			if(bit_ctr != 7)sout[7:0] 		<= {sout[6:0], 1'b1};
		end
		
	end
	
//*********************************************************************************
	
	pi_map pi_map_inst(
	
		.pi(pi),
		.map(pi.map)
	);
	
endmodule
