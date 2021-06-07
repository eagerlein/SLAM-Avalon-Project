-- altera vhdl_input_version vhdl_2008
----------------------------------------
LIBRARY IEEE;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
LIBRARY WORK;
	USE work.my_package.all;
----------------------------------
ENTITY tiny_counter IS
	GENERIC	(	LATENCY			:	UNSIGNED(LATENCY_WIDTH-1 DOWNTO 0)	:=	"00000101");
	PORT		(	clk				:	IN		STD_LOGIC;
					rst				:	IN		STD_LOGIC;
					ena 				:	IN		STD_LOGIC;
					syn_clr			:	IN		STD_LOGIC;
					clr_counter		:	IN		STD_LOGIC;
					max_tick			:	OUT	STD_LOGIC);
END ENTITY tiny_counter;
-------------------------------------
ARCHITECTURE rtl OF tiny_counter IS
	SIGNAL	max_tick_s		:	STD_LOGIC;
	SIGNAL	count_s			:	UNSIGNED(LATENCY_WIDTH-1 DOWNTO 0);
	SIGNAL	count_next		:	UNSIGNED(LATENCY_WIDTH-1 DOWNTO 0);
BEGIN
	--------------- Outputs---------------------
	--counter	<= STD_LOGIC_VECTOR(count_s);
	max_tick	<=	max_tick_s;
	
	
	-------------Counter Logic-------------------
	count_next 	<=		(OTHERS =>	'0') 	WHEN 	syn_clr			='1' 		ELSE
							(OTHERS =>	'0') 	WHEN 	clr_counter		='1' 		ELSE
							(OTHERS =>	'0') 	WHEN 	max_tick_s		='1'		ELSE
							count_s + 1;
	
	max_tick_s	<=	'1' when count_s = LATENCY 	ELSE '0';
					
					
	
	regCounter: PROCESS(ena, clk, rst)
	BEGIN
		IF (rst = '1') THEN
			count_s <= (OTHERS => '0');
		ELSIF(rising_edge(clk)) THEN
			IF (ena = '1') THEN
				count_s <= count_next;
			END IF;
		END IF;
	END PROCESS;

END ARCHITECTURE rtl;