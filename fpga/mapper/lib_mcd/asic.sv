 

module asic(

	input rst, 
	input clk_asic,
	input sub_sync,
	input [15:0]sub_data,
	input [14:0]reg_addr,
	input regs_we_lo_sub, regs_we_hi_sub,
	
	output [15:0]reg_8058_do, reg_805A_do, reg_805C_do, reg_805E_do,
	output [15:0]reg_8060_do, reg_8062_do, reg_8064_do, reg_8066_do,
	
	
	input [15:0]wram_dout_asic,
	output reg[15:0]wram_din_asic,
	output [17:1]wram_addr_asic,
	output reg wram_we_asic, wram_oe_asic,
	input wram_mode, wram_for_sub,
	
	
	output asic_irq
);

	
	parameter ADDR_VECTOR	= 4'd0;
	parameter ADDR_STMAP		= 4'd1;
	parameter ADDR_STGFX		= 4'd2;
	parameter ADDR_BUFF		= 4'd3;
	
	assign reg_8058_do[15:0] = {busy, 12'd0, reg_8058[2:0]};
	assign reg_805A_do[15:0] = {reg_805A[15:5], 5'd0};
	assign reg_805C_do[15:0] = {11'd0, reg_805C[4:0]};
	assign reg_805E_do[15:0] = {reg_805E[15:3], 3'd0};
	assign reg_8060_do[15:0] = {10'd0, reg_8060[5:0]};
	assign reg_8062_do[15:0] = {7'd0, reg_8062[8:0]};
	assign reg_8064_do[15:0] = {8'd0, reg_8064[7:0]};
	assign reg_8066_do[15:0] = {reg_8066[17:3], 1'd0};
	
	
	assign wram_addr_asic[17:1] = 
	addr_sel == ADDR_VECTOR ? reg_8066[17:1] : 
	addr_sel == ADDR_STMAP  ? stamp_addr_map[17:1] :
	addr_sel == ADDR_STGFX  ? stamp_addr_gfx[17:1] : 
	buff_addr[18:2];
	
	assign asic_irq = busy_st[1:0] == 2'b10;
	
	wire regs_we_lo = regs_we_lo_sub;
	wire regs_we_hi = regs_we_hi_sub;
	wire regs_we_xx = regs_we_lo | regs_we_hi;
	
	wire set_vbase = regs_we_xx & reg_addr == 9'h066;
	wire busy = delay != 0 | state != 0;
	
	
//***************************************************************************** tile mapping
	wire [2:0]flip = stamp_tile[15:13];
	wire stamp_rep = reg_8058[0];
	wire stamp_32 = reg_8058[1];
	wire map_16x = reg_8058[2];
	wire zero_tile = stamp_32 ? stamp_tile[10:2] == 0 : stamp_tile[10:0] == 0;
	wire out_of_stamp = map_16x ? (sx[12] | sy[12]) : (sx[12:8] != 0 | sy[12:8] != 0);
	
	wire [12:0]sx = stamp_x[23:11];//stamp_x without point
	wire [12:0]sy = stamp_y[23:11];//stamp_y without point
	
	wire [3:0]stamp_pixel = 
	!stamp_rep & out_of_stamp ? 0 : 
	zero_tile ? 0 : 
	flip_x[1:0] == 0 ? wram_dout_asic[15:12] : 
	flip_x[1:0] == 1 ? wram_dout_asic[11:8] : 
	flip_x[1:0] == 2 ? wram_dout_asic[7:4] : wram_dout_asic[3:0];
	
	wire [17:1]stamp_addr_map = 
	stamp_32 == 0 & map_16x == 0 ? {reg_805A[15:7], in_map_addr_s16m1[7:0]} : 
	stamp_32 == 1 & map_16x == 0 ? {reg_805A[15:5], in_map_addr_s32m1[5:0]} :
	stamp_32 == 0 & map_16x == 1 ? {1'b1, in_map_addr_s16m16[15:0]} :
	{reg_805A[15:13], in_map_addr_s32m16[13:0]};
	
	
	wire [17:1]stamp_addr_gfx = 
	stamp_32 ? {stamp_tile[10:2], in_tile_addr_x32[7:0]} : 
	{stamp_tile[10:0], in_tile_addr_x16[5:0]};
	
	
	wire [4:0]val_x[3];
	wire [4:0]val_y[3];
	assign val_x[0] = flip[0] == 0 ? sx[4:0] : sy[4:0];
	assign val_x[1] = flip[1] == flip[0] ? val_x[0] : 31 - val_x[0];
	assign val_x[2] = {flip[2], flip[0]} != 2'b10 ? val_x[1] : 31 - val_x[1];
	
	assign val_y[0] = flip[0] == 0 ? sy[4:0] : sx[4:0];
	assign val_y[1] = flip[1] == 0 ? val_y[0] : 31 - val_y[0];
	assign val_y[2] = {flip[2], flip[0]} != 2'b11 ? val_y[1] : 31 - val_y[1];
	
	wire [4:0]flip_x = val_x[2][4:0];
	wire [4:0]flip_y = val_y[2][4:0];

	
	wire [5:0]in_tile_addr_x16 = {flip_x[3], flip_y[3:0], flip_x[2]};
	wire [7:0]in_tile_addr_x32 = {flip_x[4:3], flip_y[4:0], flip_x[2]};
	
	wire [7:0]in_map_addr_s16m1 = {sy[7:4], sx[7:4]};
	wire [5:0]in_map_addr_s32m1 = {sy[7:5], sx[7:5]};
	
	wire [15:0]in_map_addr_s16m16 = {sy[11:4], sx[11:4]};
	wire [13:0]in_map_addr_s32m16 = {sy[11:5], sx[11:5]};

	
	
//***************************************************************************** 	
	
	
	reg [23:0]stamp_x, stamp_y;
	reg [15:0]delta_x, delta_y;
	reg [4:0]state;
	reg [2:0]delay;
	
	reg [18:0]buff_addr;
	reg [1:0]addr_sel;
	
	reg [7:0]y_pos;
	reg [8:0]x_ctr;
	reg [15:0]stamp_tile;
	reg [1:0]busy_st;
	
	
	reg [15:0]reg_8058, reg_805A, reg_805C, reg_805E;
	reg [15:0]reg_8060, reg_8062, reg_8064; 
	reg [17:0]reg_8066;
	

	
	always @(posedge clk_asic)
	if(rst)
	begin
		busy_st <= 0;
		state <= 0;
		wram_oe_asic <= 0;
		wram_we_asic <= 0;
		//asic_irq <= 0;
		delay <= 0;
		
		reg_8058 <= 0;
		reg_805A <= 0;
		reg_805C <= 0;
		reg_805E <= 0;
		reg_8060 <= 0;
		reg_8062 <= 0;
		reg_8064 <= 0;
		reg_8066 <= 0;
	end
		else
	if(sub_sync)
	begin
		
		//if(wram_we_asic & delay == 1)wram_we_asic <= 0;
		//if(wram_mode)wram_we_asic <= 0;
		//if(wram_mode)wram_oe_asic <= 0;
		
		if(busy)delay <= !wram_for_sub | wram_mode | delay == 0 ? 2 : delay - 1;//roll back delay if ram access was intercepted
		
		if(set_vbase & state == 0)state <= 1;
		
		busy_st[1:0] <= {busy_st[0], busy};
		
		//if(asic_irq)asic_irq <= 0;
		//if(busy_st[1:0] == 2'b10)asic_irq <= 1;
		
		if(delay == 0 & wram_mode == 0 & wram_for_sub)
		case(state)
		
			0:begin
				wram_oe_asic <= 0;
				wram_we_asic <= 0;
				y_pos <= 0;
			end
			
			1:begin
				addr_sel <= ADDR_VECTOR;
				buff_addr[18:0] <= {reg_805E[15:3], reg_8060[5:0]} + {y_pos[7:0], 3'b0};
				x_ctr[8:0] <= reg_8062[8:0];
				wram_oe_asic <= 1;
				state <= state + 1;
				wram_din_asic <= 0;
			end
			2:begin
				stamp_x[23:0] <= {wram_dout_asic[15:0], 8'h00};
				reg_8066 <= reg_8066 + 2;
				state <= state + 1;
			end
			3:begin
				stamp_y[23:0] <= {wram_dout_asic[15:0], 8'h00};
				reg_8066 <= reg_8066 + 2;
				state <= state + 1;
			end
			4:begin
				delta_x[15:0] <= wram_dout_asic[15:0];
				reg_8066 <= reg_8066 + 2;
				state <= state + 1;
			end
			5:begin
				addr_sel <= ADDR_STMAP;
				delta_y[15:0] <= wram_dout_asic[15:0];
				reg_8066 <= reg_8066 + 2;
				state <= state + 1;
			end
			6:begin
				addr_sel <= ADDR_STGFX;
				stamp_tile <= wram_dout_asic[15:0];
				state <= state + 1;
				if(buff_addr[1:0] == 0)wram_din_asic <= 0;
			end
			7:begin
				if(x_ctr != 0)x_ctr <= x_ctr - 1;
				buff_addr[1:0] <= buff_addr[1:0] + 1;
				
				stamp_x <= delta_x[15] == 0 ? stamp_x + delta_x : stamp_x - (17'h10000 - delta_x);
				stamp_y <= delta_y[15] == 0 ? stamp_y + delta_y : stamp_y - (17'h10000 - delta_y);
				//stamp_x <= stamp_x + delta_x;
				//stamp_y <= stamp_y + delta_y;
				
				if(buff_addr[1:0] == 0 & x_ctr != 0)wram_din_asic[15:12] <= stamp_pixel[3:0];
				if(buff_addr[1:0] == 1 & x_ctr != 0)wram_din_asic[11:8] <= stamp_pixel[3:0];
				if(buff_addr[1:0] == 2 & x_ctr != 0)wram_din_asic[7:4] <= stamp_pixel[3:0];
				if(buff_addr[1:0] == 3 & x_ctr != 0)wram_din_asic[3:0] <= stamp_pixel[3:0];
				
				if(buff_addr[1:0] == 3 | x_ctr[8:1] == 0)
				begin
					wram_oe_asic <= 0;
					wram_we_asic <= 1;
					state <= state + 1;
					addr_sel <= ADDR_BUFF;
				end
					else
				begin
					state <= state - 1;
					addr_sel <= ADDR_STMAP;
				end
				
			end
			8:begin
				wram_oe_asic <= 1;
				wram_we_asic <= 0;
				addr_sel <= ADDR_STMAP;
				
				buff_addr[2] <= !buff_addr[2];//tile pixels 0-3,4-7
				if(buff_addr[2] == 1)buff_addr[18:6] <= buff_addr[18:6] + (reg_805C[4:0] + 1);
				
				if(x_ctr != 0)state <= 6;
				if(x_ctr == 0)reg_8064[7:0] <= reg_8064[7:0] - 1;//y_ctr
				if(x_ctr == 0)y_pos <= y_pos + 1;
				if(x_ctr == 0 & reg_8064[7:0] == 1)state <= 0;
				if(x_ctr == 0 & reg_8064[7:0] != 1)state <= 1;
				
			end
			
			default:begin
				state <= 0;
			end
			
		endcase
		
		
		if(regs_we_xx)
		case(reg_addr)
			9'h058:reg_8058 <= sub_data;//2-0.stamp cfg
			9'h05A:reg_805A <= sub_data;//stam map addr
			9'h05C:reg_805C <= sub_data;//4-0. buff cell vsize
			9'h05E:reg_805E <= sub_data;//15-3.buff addr
			9'h060:reg_8060 <= sub_data;//5-0. in-tile offset
			9'h062:reg_8062 <= sub_data;//buff hsize x.
			9'h064:reg_8064 <= sub_data;//buff vsize y. direct ctr
			9'h066:reg_8066[17:0] <= {sub_data[15:1], 3'd0};//vector base. direct ctr
		endcase
		
	end
		

	
endmodule
