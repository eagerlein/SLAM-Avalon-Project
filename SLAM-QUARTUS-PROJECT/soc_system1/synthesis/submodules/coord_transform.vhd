------------------------------------------------------------------------
--						coord_transform CIRCUIT
-- Date: 2020-10-14
-- Version: 2.0 
-- Description:
-- Implement transformation of coordinates
-- temp_x = map[i][X_INDEX] - DIFF_X # Operation in float
--	temp_y = map[i][Y_INDEX] - DIFF_Y # Operation in float
--	map[j][X_INDEX] = (temp_x * COS_THETA) - (temp_y * SIN_THETA) # map is float in meters
--	map[j][Y_INDEX] = (temp_y * COS_THETA) + (temp_X * SIN_THETA) # map is float in meters
-- 
------------------------------------------------------------------------
------------------------------------------------------------------------
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	USE ieee.std_logic_unsigned.all;
	USE ieee.numeric_std.all;
LIBRARY WORK;
	USE work.my_package.all;
------------------------------------------------------------------------
ENTITY coord_transform IS
	GENERIC	(	DATA_WIDTH			:	INTEGER	:=	DATA_WIDTH);			
	PORT 	(		clk					: 	IN 	STD_LOGIC;
					rst					: 	IN 	STD_LOGIC;
					strobe				:	IN		STD_LOGIC;--Start bit
					syn_clr				:	IN		STD_LOGIC ;
					sin_theta			:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);	
					cos_theta			:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);	
					diff_x				:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					diff_y				:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					input_point_x		:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					input_point_y		:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					result_x				:	OUT	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					result_y				:	OUT	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					data_ready			:	OUT	STD_LOGIC);

END ENTITY;
---------------------------------------------------------
ARCHITECTURE structural OF coord_transform IS
	SIGNAL	temp_x							:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	temp_y							:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	temp_x_cos_theta				:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	temp_x_sin_theta				:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	temp_y_cos_theta				:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	temp_y_sin_theta				:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	
	SIGNAL	subs_x_bussy_s					:	STD_LOGIC;
	SIGNAL	subs_y_bussy_s					:	STD_LOGIC;
	SIGNAL	subs_x_ready_s					:	STD_LOGIC;
	SIGNAL	subs_y_ready_s					:	STD_LOGIC;
	SIGNAL	subs_ready_s					:	STD_LOGIC;
	SIGNAL	temp_x_sin_theta_ready_s	:	STD_LOGIC;
	SIGNAL	temp_x_sin_theta_busy_s		:	STD_LOGIC;
	SIGNAL	temp_y_sin_theta_ready_s	:	STD_LOGIC;
	SIGNAL	temp_y_sin_theta_busy_s		:	STD_LOGIC;
	SIGNAL	temp_x_cos_theta_ready_s	:	STD_LOGIC;
	SIGNAL	temp_x_cos_theta_busy_s		:	STD_LOGIC;
	SIGNAL	temp_y_cos_theta_ready_s	:	STD_LOGIC;
	SIGNAL	temp_y_cos_theta_busy_s		:	STD_LOGIC;
	SIGNAL	x_ready_s						:	STD_LOGIC;
	SIGNAL	x_busy_s							:	STD_LOGIC;
	SIGNAL	y_ready_s						:	STD_LOGIC;
	SIGNAL	y_busy_s							:	STD_LOGIC;
	SIGNAL	ready_mults_for_x				:	STD_LOGIC;
	SIGNAL	ready_mults_for_y				:	STD_LOGIC;
	
	
BEGIN
	
--	busy	<=	subs_x_bussy_s	OR	subs_y_bussy_s OR temp_x_sin_theta_busy_s OR temp_x_cos_theta_busy_s
--				OR temp_y_sin_theta_busy_s OR temp_y_cos_theta_busy_s	OR	x_busy_s	OR	y_busy_s;
	
	--==================================
	--		First Stage - Adders
	--==================================
	diff_x_sub: ENTITY WORK.float_add_sub
	GENERIC	MAP	(	DATA_WIDTH		=>	DATA_WIDTH,
							LATENCY			=>	FLOAT_ADD_LATENCY)			
	PORT	MAP	(		rst				=>	rst,
							clk				=>	clk,
							syn_clr			=>	syn_clr,
							strobe			=>	strobe,
							add_sub			=> '0',	-- Subtraction
							dataa				=>	input_point_x,
							datab				=>	diff_x,
							result			=>	temp_x,
							data_ready		=>	subs_x_ready_s,
							busy				=> subs_x_bussy_s);	
	
	diff_y_sub: ENTITY WORK.float_add_sub
	GENERIC	MAP	(	DATA_WIDTH		=>	DATA_WIDTH,
							LATENCY			=>	FLOAT_ADD_LATENCY)			
	PORT	MAP	(		rst				=>	rst,
							clk				=>	clk,
							syn_clr			=>	syn_clr,
							strobe			=>	strobe,
							add_sub			=> '0',	-- Subtraction
							dataa				=>	input_point_y,
							datab				=>	diff_y,
							result			=>	temp_y,
							data_ready		=>	subs_y_ready_s,
							busy				=> subs_y_bussy_s);	
	
	--==================================
	--			Second Stage - Multipliers
	--==================================
	tempx_sin_mult: ENTITY WORK.float_multiplier
	GENERIC	MAP	(	DATA_WIDTH		=>	DATA_WIDTH,
							LATENCY			=>	FLOAT_MULT_LATENCY)			
	PORT	MAP	(		rst				=>	rst,
							clk				=>	clk,
							syn_clr			=>	syn_clr,
							strobe			=>	subs_x_ready_s,
							dataa				=>	temp_x,
							datab				=>	sin_theta,
							result			=>	temp_x_sin_theta,
							data_ready		=>	temp_x_sin_theta_ready_s,
							busy				=> temp_x_sin_theta_busy_s);
	
	tempx_cos_mult: ENTITY WORK.float_multiplier
	GENERIC	MAP	(	DATA_WIDTH		=>	DATA_WIDTH,
							LATENCY			=>	FLOAT_MULT_LATENCY)			
	PORT	MAP	(		rst				=>	rst,
							clk				=>	clk,
							syn_clr			=>	syn_clr,
							strobe			=>	subs_x_ready_s,
							dataa				=>	temp_x,
							datab				=>	cos_theta,
							result			=>	temp_x_cos_theta,
							data_ready		=>	temp_x_cos_theta_ready_s,
							busy				=> temp_x_cos_theta_busy_s);
							
	tempy_sin_mult: ENTITY WORK.float_multiplier
	GENERIC	MAP	(	DATA_WIDTH		=>	DATA_WIDTH,
							LATENCY			=>	FLOAT_MULT_LATENCY)			
	PORT	MAP	(		rst				=>	rst,
							clk				=>	clk,
							syn_clr			=>	syn_clr,
							strobe			=>	subs_y_ready_s,
							dataa				=>	temp_y,
							datab				=>	sin_theta,
							result			=>	temp_y_sin_theta,
							data_ready		=>	temp_y_sin_theta_ready_s,
							busy				=> temp_y_sin_theta_busy_s);
	
	tempy_cos_mult: ENTITY WORK.float_multiplier
	GENERIC	MAP	(	DATA_WIDTH		=>	DATA_WIDTH,
							LATENCY			=>	FLOAT_MULT_LATENCY)			
	PORT	MAP	(		rst				=>	rst,
							clk				=>	clk,
							syn_clr			=>	syn_clr,
							strobe			=>	subs_y_ready_s,
							dataa				=>	temp_y,
							datab				=>	cos_theta,
							result			=>	temp_y_cos_theta,
							data_ready		=>	temp_y_cos_theta_ready_s,
							busy				=> temp_y_cos_theta_busy_s);
	
	ready_mults_for_x	<=	temp_x_cos_theta_ready_s AND temp_y_sin_theta_ready_s;
	ready_mults_for_y	<=	temp_y_cos_theta_ready_s AND temp_x_sin_theta_ready_s;
	
	--=================================
	--		Last Stage - Adders
	--=================================
	new_x_adder: ENTITY WORK.float_add_sub
	GENERIC	MAP	(	DATA_WIDTH		=>	DATA_WIDTH,
							LATENCY			=>	FLOAT_ADD_LATENCY)			
	PORT	MAP	(		rst				=>	rst,
							clk				=>	clk,
							syn_clr			=>	syn_clr,
							strobe			=>	ready_mults_for_x,
							add_sub			=> '0',	-- Subtraction
							dataa				=>	temp_x_cos_theta,
							datab				=>	temp_y_sin_theta,
							result			=>	result_x,
							data_ready		=>	x_ready_s,
							busy				=> x_busy_s);	
	
	new_y_adder: ENTITY WORK.float_add_sub
	GENERIC	MAP	(	DATA_WIDTH		=>	DATA_WIDTH,
							LATENCY			=>	FLOAT_ADD_LATENCY)			
	PORT	MAP	(		rst				=>	rst,
							clk				=>	clk,
							syn_clr			=>	syn_clr,
							strobe			=>	ready_mults_for_x,
							add_sub			=> '1',	-- Addition
							dataa				=>	temp_y_cos_theta,
							datab				=>	temp_x_sin_theta,
							result			=>	result_y,
							data_ready		=>	y_ready_s,
							busy				=> y_busy_s);	

	data_ready	<=	x_ready_s AND	y_ready_s;
	

END ARCHITECTURE;