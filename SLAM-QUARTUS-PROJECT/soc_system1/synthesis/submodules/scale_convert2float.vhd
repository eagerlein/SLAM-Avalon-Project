-- altera vhdl_input_version vhdl_2008
------------------------------------------------------------------------
--						scale_convert2float
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
ENTITY scale_convert2float IS
	GENERIC	(	DATA_WIDTH		:	INTEGER	:=	DATA_WIDTH);			
	PORT	(		rst				:	IN		STD_LOGIC ;
					clk				: 	IN 	STD_LOGIC ;
					syn_clr			:	IN		STD_LOGIC ;
					strobe			: 	IN 	STD_LOGIC ;
					dataa				: 	IN 	STD_LOGIC_VECTOR (DATA_WIDTH-1 DOWNTO 0);
					result			: 	OUT 	STD_LOGIC_VECTOR (DATA_WIDTH-1 DOWNTO 0);
					data_ready		:	OUT 	STD_LOGIC;
					busy				:	OUT 	STD_LOGIC);					
END ENTITY;
-------------------------------------------------------------------------
ARCHITECTURE structural OF scale_convert2float IS
	SIGNAL	float_ready_s			:	STD_LOGIC;
	SIGNAL	div_busy_s				:	STD_LOGIC;
	SIGNAL	conv_busy_s				:	STD_LOGIC;
	SIGNAL	num_float_s				: 	STD_LOGIC_VECTOR (DATA_WIDTH-1 DOWNTO 0);
BEGIN
	
	busy	<=	conv_busy_s OR div_busy_s;
	
	
	FP_DIVISOR: ENTITY WORK.float_divisor
	GENERIC	MAP	(	DATA_WIDTH		=>	DATA_WIDTH,
							LATENCY			=>	FLOAT_DIV_LATENCY)			
	PORT	MAP	(		rst				=>	rst,
							clk				=>	clk,
							syn_clr			=>	syn_clr,
							strobe			=>	float_ready_s,
							dataa				=>	num_float_s,
							datab				=>	FP_THOUSAND,
							result			=>	result,
							data_ready		=>	data_ready,
							busy				=> div_busy_s);	
	
	INT2FP_CONVERTER: ENTITY WORK.int2float
	GENERIC	MAP	(	DATA_WIDTH		=>	DATA_WIDTH,
							LATENCY			=>	FLOAT2INT_LATENCY) -- Same Latency
	PORT MAP	(			rst				=>	rst,
							clk				=>	clk,
							syn_clr			=>	syn_clr,
							strobe			=>	strobe,
							dataa				=>	dataa ,
							result			=>	num_float_s,
							data_ready		=>	float_ready_s,
							busy				=>	conv_busy_s);	
	

END ARCHITECTURE;