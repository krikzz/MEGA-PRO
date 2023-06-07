

module mcd_core(

	input clk,
	input CpuBus cpu,
	input McdIO cdio,
	input map_rst,
	input slave_mode,
	input mcd_on,
	
	output [15:0]mcd_do,
	output mcd_oe,
	output [7:0]cdio_di,
	output DacBus dac,
	output mcu_sync,
	output mcu_rst,
	output led_r, led_g,
	
	MemIO 	mem_bios,
	MemIO 	mem_prg,
	MemIO_WR mem_wrm0,
	MemIO_WR mem_wrm1,
	MemIO  	mem_bram,
	MemIO  	mem_pcm
	
	
);
		CpuBus cpu_sync;
		
		always @(negedge clk)
		begin
			cpu_sync 		<= cpu;
		end
		
		assign mcd_oe 		= (mcd_ce | main_ce_regs) & !cpu_sync.oe;
		assign mcu_rst		= mcd_on ? mcu_rst_cd : 0;
		assign mcu_sync	= mcd_on ? mcu_sync_cd : 0;
		
		
		wire main_ce_regs = mcd_on & {cpu_sync.addr[23:12], 12'd0} == 24'hA12000 & !cpu_sync.as;
		wire mcd_ce 		= mcd_on & cpu_sync.addr[23:22] == (slave_mode ? 1 : 0);
		wire main_ce_bios = mcd_ce & cpu_sync.addr[21] == 0 & cpu_sync.addr[17] == 0;
		wire main_ce_pram = mcd_ce & cpu_sync.addr[21] == 0 & cpu_sync.addr[17] == 1;
		wire main_ce_wram = mcd_ce & cpu_sync.addr[21] == 1;// & mcd_ce_cap;
		wire main_vdp_dma = cpu_sync.as;
		
		wire mcu_rst_cd;
		wire mcu_sync_cd;
		
		mcd mcd_inst(

//********************************************************* mcd expansion io	
		.main_din(mcd_do),
		.main_dout(cpu_sync.data),
		.main_addr(cpu_sync.addr[17:1]),

		.main_oe(cpu_sync.oe),//aka cas0	
		.main_we_hi(cpu_sync.we_hi | cpu_sync.as),
		.main_we_lo(cpu_sync.we_lo | cpu_sync.as),
		
		.main_ce_bios(main_ce_bios),
		.main_ce_wram(main_ce_wram),
		.main_ce_pram(main_ce_pram), 
		.main_ce_regs(main_ce_regs),
		.main_vdp_dma(main_vdp_dma),
//********************************************************* var		
		.clk_asic(clk), 
		.map_rst(map_rst),
//********************************************************* bios
		.bi_data(mem_bios.dato[15:0]),
		.bi_addr(mem_bios.addr[16:0]),
		.bi_oe(mem_bios.oe),
//********************************************************* prg ram		
		.prg_din(mem_prg.dati[15:0]),
		.prg_dout(mem_prg.dato[15:0]),
		.prg_addr(mem_prg.addr[18:0]),
		.prg_we_lo(mem_prg.we_lo), 
		.prg_we_hi(mem_prg.we_hi), 
		.prg_oe(mem_prg.oe),
//********************************************************* wram
		.wram_din_a (mem_wrm0.dati),
		.wram_dout_a(mem_wrm0.dato),
		.wram_addr_a(mem_wrm0.addr),
		.wram_mask_a(mem_wrm0.mask),
		.wram_mode_a(mem_wrm0.mode),
		
		.wram_din_b (mem_wrm1.dati),
		.wram_dout_b(mem_wrm1.dato),
		.wram_addr_b(mem_wrm1.addr),
		.wram_mask_b(mem_wrm1.mask),
		.wram_mode_b(mem_wrm1.mode),
//********************************************************* bram	
		.bram_din(mem_bram.dati),
		.bram_dout(mem_bram.dato),
		.bram_addr(mem_bram.addr),
		.bram_we(mem_bram.we),
		.bram_oe(mem_bram.oe),
//********************************************************* pcm ram			
		.pcm_ram_addr(mem_pcm.addr),
		.pcm_ram_di(mem_pcm.dati),
		.pcm_ram_do(mem_pcm.dato),
		.pcm_ram_we(mem_pcm.we),
		.pcm_ram_oe(mem_pcm.oe),
//********************************************************* cdd
		.cdio(cdio),
		.cdio_di(cdio_di),
		
		.frame_sync(mcu_sync_cd),
		.mcu_reset(mcu_rst_cd),
		
		.dac_clk(dac.clk),
		.snd_r(dac.snd_r),
		.snd_l(dac.snd_l),
//********************************************************* var
		.led({led_g, led_r})
	);
	

endmodule



