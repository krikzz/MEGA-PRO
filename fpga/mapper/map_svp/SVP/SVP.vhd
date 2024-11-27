library STD;
use STD.TEXTIO.ALL;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;

entity SVP is
	port(
		CLK			: in std_logic;
		CE				: in std_logic;
		RST_N			: in std_logic;
		ENABLE		: in std_logic;
		
		BUS_A			: in std_logic_vector(23 downto 1);
		BUS_DI		: in std_logic_vector(15 downto 0);
		BUS_DO		: out std_logic_vector(15 downto 0);
		BUS_AS_N		: in std_logic;
		BUS_OE_N		: in std_logic;
		BUS_LWR_N	: in std_logic;
		BUS_DTACK_N	: out std_logic;
		
		ROM_A			: out std_logic_vector(20 downto 1);		
		ROM_DI		: in std_logic_vector(15 downto 0);
		ROM_REQ		: out std_logic;
		ROM_ACK		: in std_logic;
		
		DRAM_A		: out std_logic_vector(16 downto 1);		
		DRAM_DI		: in std_logic_vector(15 downto 0);
		DRAM_DO		: out std_logic_vector(15 downto 0);
		DRAM_WE		: out std_logic;
		DRAM_REQ		: out std_logic;
		DRAM_ACK		: in std_logic
	);
end SVP;

architecture rtl of SVP is

	signal EN				: std_logic;
	
	--SSP ports
	signal SSP_PA 			: std_logic_vector(15 downto 0);
	signal SSP_PDI 		: std_logic_vector(15 downto 0);
	signal SSP_SS 			: std_logic;
	signal SSP_EA 			: std_logic_vector(2 downto 0);
	signal SSP_EXTI 		: std_logic_vector(15 downto 0);
	signal SSP_EXTO 		: std_logic_vector(15 downto 0);
	signal SSP_ESB 		: std_logic;
	signal SSP_R_NW 		: std_logic;
	signal SSP_USR01 		: std_logic_vector(1 downto 0);
	signal SSP_ST56 		: std_logic_vector(1 downto 0);
	signal SSP_BL_WR 		: std_logic;
	signal SSP_BL_RD 		: std_logic;
	
	--PMARs
	type PMAR_r is record
		MA		: std_logic_vector(31 downto 0);		--Mode/Address
		DATA	: std_logic_vector(15 downto 0);		--Read/Write data
		CD		: std_logic_vector(15 downto 0);		--Custom displacement
	end record;
	type PMARs_t is array (0 to 9) of PMAR_r;
	signal PMARS 			: PMARs_t;
	signal PMAR_SET 		: std_logic;
	signal PMAR_NUM 		: unsigned(3 downto 0);
	signal PMC 				: std_logic_vector(31 downto 0);
	signal PMC_SEL 		: std_logic;
	
	--I/O
	signal REG_SEL 		: std_logic;
	signal DTACK_N 		: std_logic;
	signal XCM 				: std_logic_vector(15 downto 0);
	signal XST 				: std_logic_vector(15 downto 0);
	signal CA 				: std_logic;
	signal SA 				: std_logic;
	signal HALT 			: std_logic;
	
	--Memory controller
	type MemAccessState_t is (
		MAS_IDLE,
		MAS_PROM_RD,
		MAS_PRAM_RD,
		MAS_ROM_RD,
		MAS_DRAM_RD,
		MAS_DRAM_WR,
		MAS_IRAM_RD,
		MAS_IRAM_WR,
		MAS_EXEC
	);
	signal MAS 				: MemAccessState_t;
	signal MEM_ADDR 		: std_logic_vector(20 downto 0);
	signal DRAM_ADDR 		: std_logic_vector(15 downto 0);
	signal SSP_WAIT 		: std_logic;
	signal SSP_ACTIVE 	: std_logic;
	signal PMAR_ACTIVE	: std_logic; 
	signal IRAM_SEL 		: std_logic;
	signal MA_ROM_REQ 	: std_logic;
	signal MA_DRAM_REQ 	: std_logic;
	signal MEM_WAIT 		: std_logic; 
	
	--IRAM
	signal IRAM_D 			: std_logic_vector(15 downto 0);
	signal IRAM_WE 		: std_logic;
	signal IRAM_Q 			: std_logic_vector(15 downto 0);
	signal IRAM_Q2 		: std_logic_vector(15 downto 0);
	
	impure function GetNextMA(pmar: PMAR_r) return std_logic_vector is
		variable displ: std_logic_vector(15 downto 0); 
		variable temp: std_logic_vector(19 downto 0); 
		variable res: std_logic_vector(31 downto 0); 
	begin
		case pmar.MA(29 downto 27) is
			when "001" => 	displ := x"0001";
			when "010" => 	displ := x"0002";
			when "011" => 	displ := x"0004";
			when "100" => 	displ := x"0008";
			when "101" => 	displ := x"0010";
			when "110" => 	displ := x"0020";
			when "111" => 	displ := pmar.CD;
			when others => displ := x"0000";
		end case;
		if pmar.MA(30) = '0' then
			if pmar.MA(31) = '0' then
				temp := std_logic_vector(unsigned(pmar.MA(19 downto 0)) + unsigned(displ));
			else
				temp := std_logic_vector(unsigned(pmar.MA(19 downto 0)) - unsigned(displ));
			end if;
		else
			if pmar.MA(0) = '0' then
				temp := std_logic_vector(unsigned(pmar.MA(19 downto 0)) + 1);
			else
				temp := std_logic_vector(unsigned(pmar.MA(19 downto 0)) + 31);
			end if;
		end if;
		
		res := pmar.MA(31 downto 20) & temp;
		return res;
	end function;
	
	impure function OverWrite(pmar: PMAR_r; old: std_logic_vector(15 downto 0)) return std_logic_vector is
		variable res: std_logic_vector(15 downto 0); 
	begin
		res := old;
		if pmar.DATA(3 downto 0) /= x"0" or pmar.MA(26) = '0' then
			res(3 downto 0) := pmar.DATA(3 downto 0);
		end if;
		if pmar.DATA(7 downto 4) /= x"0" or pmar.MA(26) = '0' then
			res(7 downto 4) := pmar.DATA(7 downto 4);
		end if;
		if pmar.DATA(11 downto 8) /= x"0" or pmar.MA(26) = '0' then
			res(11 downto 8) := pmar.DATA(11 downto 8);
		end if;
		if pmar.DATA(15 downto 12) /= x"0" or pmar.MA(26) = '0' then
			res(15 downto 12) := pmar.DATA(15 downto 12);
		end if;

		return res;
	end function;

begin

	EN <= ENABLE and CE;
	
	IRAM_SEL <= '1' when SSP_PA(15 downto 10) = "000000" else '0';
	
	SSP_WAIT <= '1' when MAS /= MAS_EXEC else '0';
	
	SSP_PDI <= IRAM_Q2 when IRAM_SEL = '1' else ROM_DI;
	SSP_SS <= EN and not SSP_WAIT;
	SSP_USR01 <= "00";
	
	SSP160x : entity work.SSP160x
	port map(
		
		CLK		=> CLK,
		RST_N		=> RST_N,
		ENABLE	=> ENABLE,
		SS			=> SSP_SS,
		
		PA			=> SSP_PA,		
		PDI		=> SSP_PDI,
		
		EA			=> SSP_EA,
		EXTI		=> SSP_EXTI,
		EXTO		=> SSP_EXTO,
		ESB		=> SSP_ESB,
		R_NW		=> SSP_R_NW,
		
		USR01		=> SSP_USR01,
		ST56		=> SSP_ST56,
		
		BLIND_RD	=> SSP_BL_RD,
		BLIND_WR	=> SSP_BL_WR
	);
	
	--I/O
	REG_SEL <= '1' when BUS_A(23 downto 8) = x"A150" and BUS_AS_N = '0' else '0';
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			PMC_SEL <= '0';
			XST <= (others => '0');
			SA <= '0';
			CA <= '0';
			DTACK_N <= '1';
			BUS_DO <= (others => '0');
			HALT <= '0';
		elsif falling_edge(CLK) then
			if ENABLE = '1' then
				if SSP_ESB = '1' and EN = '1' and MAS = MAS_EXEC then
					if SSP_R_NW = '0' then
						case SSP_EA is
							when "011" => 
								if SSP_ST56(1) = '0' then
									XST <= SSP_EXTO;
									SA <= '1';
								end if;
							when "110" => 
								PMC_SEL <= not PMC_SEL;
							when others => null;
						end case; 
					else
						case SSP_EA is
							when "000" =>
								if SSP_ST56(0) = '0' then
									CA <= '0';
								end if;
							when "110" => 
								PMC_SEL <= not PMC_SEL;
							when "111" => 
								if SSP_BL_RD = '1' then
									PMC_SEL <= '0';
								end if;
							when others =>null;
						end case; 
					end if;
				end if;
			
--				if REG_SEL = '0' then
--					DTACK_N <= '1';
--				if svp_reg_sync = '1' then
				
					if BUS_LWR_N = '0' then
						case BUS_A(3 downto 1) is
							when "000" | "001" =>
								XST <= BUS_DI;
								if BUS_DI /= x"0000" then
									CA <= '1';
								end if;
							when "011" => 
								if BUS_DI(3 downto 0) = x"A" then
									HALT <= '1';
								else
									HALT <= '0';
								end if;
							when others =>
						end case; 
						--DTACK_N <= '0';
					elsif BUS_OE_N = '0' then
						case BUS_A(3 downto 1) is
							when "000" | "001" =>
								BUS_DO <= XST;
							when "010" =>
								BUS_DO <= "00000000000000" & CA & SA;
								SA <= '0';
							when others =>
								BUS_DO <= (others => '0');
						end case; 
						--DTACK_N <= '0';
					end if;
					
--				end if;	
			end if;
		end if;
	end process;
	
	BUS_DTACK_N <= DTACK_N;
	
	process(SSP_EA, SSP_ST56, PMARS, PMC_SEL, PMC, XST, CA, SA)
	begin
		case SSP_EA is
			when "000" =>
				if SSP_ST56(0) = '0' then
					SSP_EXTI <= "00000000000000" & CA & SA;
				else
					SSP_EXTI <= PMARS(0+5).DATA;
				end if;
			when "001" =>
				if SSP_ST56(0) = '0' then
					SSP_EXTI <= (others => '0');
				else
					SSP_EXTI <= PMARS(1+5).DATA;
				end if;
			when "010" =>
				if SSP_ST56(1) = '0' then
					SSP_EXTI <= (others => '0');
				else
					SSP_EXTI <= PMARS(2+5).DATA;
				end if;
			when "011" => 
				if SSP_ST56(1) = '0' then
					SSP_EXTI <= XST;
				else
					SSP_EXTI <= PMARS(3+5).DATA;
				end if;
			when "100" =>
				SSP_EXTI <= PMARS(4+5).DATA;
			when "101" =>
				SSP_EXTI <= (others => '0');
			when "110" => 
				if PMC_SEL = '0' then
					SSP_EXTI <= PMC(15 downto 0);
				else
					SSP_EXTI <= PMC(11 downto 8) & PMC(15 downto 12) & PMC(3 downto 0) & PMC(7 downto 4);
				end if;
			when others =>
				SSP_EXTI <= (others => '0');
		end case; 
	end process;
	
	
	--PMARs
	process(CLK, RST_N)
	variable NEW_MA : std_logic_vector(31 downto 0); 
	variable NEW_PMAR_NUM : unsigned(3 downto 0); 
	begin
		if RST_N = '0' then
			PMC <= (others => '0');
			PMARS <= (others => ((others => '0'),(others => '0'),(others => '0')));
			PMAR_SET <= '0';
			MAS <= MAS_IDLE;
			PMAR_NUM <= (others => '0');
			MA_ROM_REQ <= '0';
			MA_DRAM_REQ <= '0';
			PMAR_ACTIVE <= '0';
			MEM_WAIT <= '0';
		elsif falling_edge(CLK) then
			if EN = '1' then
				if SSP_ESB = '1' and MAS = MAS_EXEC then
					if (SSP_ST56(0) = '1' and SSP_EA(2 downto 1) = "00") or 
						(SSP_ST56(1) = '1' and SSP_EA(2 downto 1) = "01") or 
						SSP_EA = "100" then			--set PMAR
						if ((SSP_BL_WR = '1' and SSP_R_NW = '0') or (SSP_BL_RD = '1' and SSP_R_NW = '1')) and PMAR_SET = '0' then
							if SSP_R_NW = '0' then
								NEW_PMAR_NUM := unsigned("0" & SSP_EA) + 0;
								PMARS(to_integer(NEW_PMAR_NUM)).MA <= PMC;
								PMAR_NUM <= NEW_PMAR_NUM;
							else
								NEW_PMAR_NUM := unsigned("0" & SSP_EA) + 5;
								PMARS(to_integer(NEW_PMAR_NUM)).MA <= PMC;
								PMAR_NUM <= NEW_PMAR_NUM;
								PMAR_ACTIVE <= '1';
							end if;
							MEM_ADDR <= PMC(20 downto 0);
							PMAR_SET <= '1';
						else
							if SSP_R_NW = '0' then
								NEW_MA := GetNextMA(PMARS(to_integer(unsigned("0" & SSP_EA) + 0)));
								NEW_PMAR_NUM := unsigned("0" & SSP_EA) + 0;
								PMARS(to_integer(NEW_PMAR_NUM)).MA <= NEW_MA;
								PMARS(to_integer(NEW_PMAR_NUM)).DATA <= SSP_EXTO;
								MEM_ADDR <= PMARS(to_integer(NEW_PMAR_NUM)).MA(20 downto 0);
								PMAR_NUM <= NEW_PMAR_NUM;
							else
								NEW_MA := GetNextMA(PMARS(to_integer(unsigned("0" & SSP_EA) + 5)));
								NEW_PMAR_NUM := unsigned("0" & SSP_EA) + 5;
								PMARS(to_integer(NEW_PMAR_NUM)).MA <= NEW_MA;
								MEM_ADDR <= NEW_MA(20 downto 0);
								PMAR_NUM <= NEW_PMAR_NUM;
							end if;
							PMC <= NEW_MA;
							PMAR_ACTIVE <= '1';
						end if;
					elsif SSP_EA = "110" then		--set PMC
						if SSP_R_NW = '0' then
							if PMC_SEL = '0' then
								PMC(15 downto 0) <= SSP_EXTO;
							else
								PMC(31 downto 16) <= SSP_EXTO;
							end if;
							PMAR_SET <= '0';
						end if;
					elsif SSP_EA = "111" then		--set custom displacement
						if SSP_R_NW = '1' and SSP_BL_RD = '1' then
							PMARS(to_integer(PMAR_NUM)).CD <= PMC(15 downto 0);
						end if;
					end if;
				end if;
			
			case MAS is
				when MAS_IDLE =>
					if PMAR_ACTIVE = '1' then
						if MEM_ADDR(20) = '0' then								--ROM 000000-1FFFFF (000000-0FFFFF)
							if PMAR_NUM >= 5 then
								MA_ROM_REQ <= not ROM_ACK;
								MAS <= MAS_ROM_RD;
							end if;
						elsif MEM_ADDR(20 downto 16) = "11000" then		--DRAM 300000-37FFFF (180000-1BFFFF)
							DRAM_ADDR <= MEM_ADDR(15 downto 0);
							MA_DRAM_REQ <= not DRAM_ACK;
							if PMAR_NUM >= 5 then
								MAS <= MAS_DRAM_RD;
							else
								MAS <= MAS_DRAM_WR;
							end if;
						elsif MEM_ADDR(20 downto 15) = "111001" then		--IRAM 390000-3907FF (1C8000-1C83FF)
							if PMAR_NUM >= 5 then
								MAS <= MAS_IRAM_RD;
								MEM_WAIT <= '1';
							else
								MAS <= MAS_IRAM_WR;
							end if;
						end if;
						PMAR_ACTIVE <= '0';
					else
						if IRAM_SEL = '0' then
							MA_ROM_REQ <= not ROM_ACK;
							MAS <= MAS_PROM_RD;
						else
							MAS <= MAS_PRAM_RD;
						end if;
					end if;
					
				when MAS_PROM_RD =>
					if MA_ROM_REQ = ROM_ACK then
						MAS <= MAS_EXEC;
					end if;
				
				when MAS_PRAM_RD =>
					MAS <= MAS_EXEC;
					
				when MAS_ROM_RD =>
					if MA_ROM_REQ = ROM_ACK then
						PMARS(to_integer(PMAR_NUM)).DATA <= ROM_DI;
						MAS <= MAS_IDLE;
					end if;
				
				when MAS_DRAM_RD =>
					if MA_DRAM_REQ = DRAM_ACK then
						PMARS(to_integer(PMAR_NUM)).DATA <= DRAM_DI;
						MAS <= MAS_IDLE;
					end if;
										
				when MAS_DRAM_WR =>
					if MA_DRAM_REQ = DRAM_ACK then
						MAS <= MAS_IDLE;
					end if;
					
				when MAS_IRAM_RD =>
					MEM_WAIT <= '0';
					if MEM_WAIT = '0' then
						PMARS(to_integer(PMAR_NUM)).DATA <= IRAM_Q;
						MAS <= MAS_IDLE;
					end if;	
					
				when MAS_IRAM_WR =>
					MAS <= MAS_IDLE;
					
				when MAS_EXEC =>
					MAS <= MAS_IDLE;
	
				when others => null;
			end case; 

			end if;
		end if;
	end process;
	
	ROM_A <= MEM_ADDR(19 downto 0) when MAS = MAS_ROM_RD else "0000" & SSP_PA;
	ROM_REQ <= MA_ROM_REQ;
	
	DRAM_REQ <= MA_DRAM_REQ;
	
	--IRAM
	IRAM_D <= PMARS(to_integer(PMAR_NUM)).DATA;
	IRAM_WE <= '1' when MAS = MAS_IRAM_WR else '0';
	IRAM : entity work.IRAM
	port map(
		clock			=> not CLK,
		address_a	=> MEM_ADDR(9 downto 0),
		data_a		=> IRAM_D,
		wren_a		=> IRAM_WE,
		q_a			=> IRAM_Q,
		
		address_b	=> SSP_PA(9 downto 0),
		data_b		=> (others => '0'),
		wren_b		=> '0',
		q_b			=> IRAM_Q2
	);
	
	--DRAM
	DRAM_A <= DRAM_ADDR;
	DRAM_DO <= OverWrite(PMARS(to_integer(PMAR_NUM)), DRAM_DI);
	DRAM_WE <= '1' when MAS = MAS_DRAM_WR else '0';
	
end rtl;
