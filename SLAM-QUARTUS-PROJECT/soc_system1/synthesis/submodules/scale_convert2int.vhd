-- altera vhdl_input_version vhdl_2008
------------------------------------------------------------------------
--						scale_convert2int
-- Date: 2020-10-13
-- Version: 1.0 
-- Description:
-- Instantiates altfp_mult and a FSM. 
-- Controlled by a FSM, that presents the results for one Clock cycle, and 
-- resets operation to idle.
-- The operation is activated by the strobe signal, set for one clock cycle.
-- The operation can be restarted using strobe input.
-- The operation can be stoped at any time using syn_clr input.
-- altfp_mult is set to a latency of 5 clock cycles.
-- altfp2int is set to a latency of 6 clock cycles.
-- The timer is set to issue data_ready
------------------------------------------------------------------------
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	--USE ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;
LIBRARY WORK;
	USE work.my_package.all;
------------------------------------------------------------------------
ENTITY scale_convert2int IS
	GENERIC	(	DATA_WIDTH		:	INTEGER	:=	DATA_WIDTH);			
	PORT	(		rst				:	IN		STD_LOGIC ;
					clk				: 	IN 	STD_LOGIC ;
					syn_clr			:	IN		STD_LOGIC ;
					strobe			: 	IN 	STD_LOGIC ;
					dataa				: 	IN 	STD_LOGIC_VECTOR (DATA_WIDTH-1 DOWNTO 0);
					result			: 	OUT 	STD_LOGIC_VECTOR (DATA_WIDTH-1 DOWNTO 0);
					data_ready		:	OUT 	STD_LOGIC;
					busy				:	OUT 	STD_LOGIC);					
END ENTITY scale_convert2int;
-------------------------------------------------------------------------
ARCHITECTURE structural OF scale_convert2int IS
	SIGNAL	mult_ready_s			:	STD_LOGIC;
	SIGNAL	mult_busy_s				:	STD_LOGIC;
	SIGNAL	conv_busy_s				:	STD_LOGIC;
	SIGNAL	num_scaled_s			: 	STD_LOGIC_VECTOR (DATA_WIDTH-1 DOWNTO 0);
BEGIN
	
	busy	<=	conv_busy_s OR mult_busy_s;
	
	FP_MULTIPLIER: ENTITY WORK.float_multiplier
	GENERIC	MAP	(	DATA_WIDTH		=>	DATA_WIDTH,
							LATENCY			=>	FLOAT_MULT_LATENCY)			
	PORT	MAP	(		rst				=>	rst,
							clk				=>	clk,
							syn_clr			=>	syn_clr,
							strobe			=>	strobe,
							dataa				=>	dataa,
							datab				=>	FP_THOUSAND,
							result			=>	num_scaled_s,
							data_ready		=>	mult_ready_s,
							busy				=> mult_busy_s);	
	
	FP2INT_CONVERTER: ENTITY WORK.float2int
	GENERIC	MAP	(	DATA_WIDTH		=>	DATA_WIDTH,
							LATENCY			=>	FLOAT2INT_LATENCY)
	PORT MAP	(			rst				=>	rst,
							clk				=>	clk,
							syn_clr			=>	syn_clr,
							strobe			=>	mult_ready_s,
							dataa				=>	num_scaled_s,
							result			=>	result,
							data_ready		=>	data_ready,
							busy				=>	conv_busy_s);	
	

END ARCHITECTURE;