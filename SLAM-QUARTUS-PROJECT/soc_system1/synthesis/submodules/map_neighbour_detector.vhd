------------------------------------------------------------------------
--						QUADRANT SELECTOR CIRCUIT
-- Date: 2020-10-14
-- Version: 2.0 
-- Description:
-- Receives x,y,z coordinates. Pure combinational
-- Outputs the correspondent flag of the quadrant that the point belongst
-- Inputs:	x_in, y_in, z_in		: 32-bits floating-point of the point coodinates in meters	
-- Outputs:	q1,q2,q3,q4 			: flag tha corresponds to the quadrant that the point belongs
-- 
------------------------------------------------------------------------
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	USE ieee.std_logic_unsigned.all;
LIBRARY WORK;
	USE work.my_package.all;
------------------------------------------------------------------------
ENTITY map_neighbour_detector IS
	GENERIC	(	DATA_WIDTH			:	INTEGER	:=	DATA_WIDTH);			
	PORT 	(		clk					: 	IN 	STD_LOGIC;
					rst					: 	IN 	STD_LOGIC;
					strobe				:	IN		STD_LOGIC;--Start bit
					syn_clr				:	IN		STD_LOGIC ;
					i_point_x			:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					i_point_y			:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					i_point_z			:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					j_point_x			:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					j_point_y			:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					j_point_z			:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					neighbour			:	OUT	STD_LOGIC;
					data_ready			:	OUT	STD_LOGIC);
END ENTITY;
------------------------------------------------------------------------
ARCHITECTURE rtl OF map_neighbour_detector IS
	SIGNAL	diff_x			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	diff_y			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	diff_z			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	abbs_diff_x		:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	abbs_diff_y		:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	abbs_diff_z		:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	point_ls_thr_x	:	STD_LOGIC;
	SIGNAL	point_ls_thr_y	:	STD_LOGIC;
	SIGNAL	point_ls_thr_z	:	STD_LOGIC;
	SIGNAL	point_ls_thr	:	STD_LOGIC;
	SIGNAL	subs_x_ready_s	:	STD_LOGIC;
	SIGNAL	subs_y_ready_s	:	STD_LOGIC;
	SIGNAL	subs_z_ready_s	:	STD_LOGIC;
	SIGNAL	comp_x_ready_s	:	STD_LOGIC;
	SIGNAL	comp_y_ready_s	:	STD_LOGIC;
	SIGNAL	comp_z_ready_s	:	STD_LOGIC;
	
	
BEGIN

	--==================================
	--		First Stage - Adders
	--==================================
	diff_x_sub: ENTITY WORK.float_add_sub
	GENERIC	MAP	(	DATA_WIDTH		=>	DATA_WIDTH,
							LATENCY			=>	FLOAT_ADD_LATENCY)			
	PORT MAP	(			rst				=>	rst,
							clk				=>	clk,
							syn_clr			=>	syn_clr,
							strobe			=>	strobe,
							add_sub			=> '0',	-- Subtraction
							dataa				=>	i_point_x,
							datab				=>	j_point_x,
							result			=>	diff_x,
							data_ready		=>	subs_x_ready_s,
							busy				=> OPEN);
	
	diff_y_sub: ENTITY WORK.float_add_sub
	GENERIC	MAP	(	DATA_WIDTH		=>	DATA_WIDTH,
							LATENCY			=>	FLOAT_ADD_LATENCY)			
	PORT MAP	(			rst				=>	rst,
							clk				=>	clk,
							syn_clr			=>	syn_clr,
							strobe			=>	strobe,
							add_sub			=> '0',	-- Subtraction
							dataa				=>	i_point_y,
							datab				=>	j_point_y,
							result			=>	diff_y,
							data_ready		=>	subs_y_ready_s,
							busy				=> OPEN);
						
	diff_z_sub: ENTITY WORK.float_add_sub
	GENERIC	MAP	(	DATA_WIDTH		=>	DATA_WIDTH,
							LATENCY			=>	FLOAT_ADD_LATENCY)			
	PORT MAP	(			rst				=>	rst,
							clk				=>	clk,
							syn_clr			=>	syn_clr,
							strobe			=>	strobe,
							add_sub			=> '0',	-- Subtraction
							dataa				=>	i_point_z,
							datab				=>	j_point_z,
							result			=>	diff_z,
							data_ready		=>	subs_z_ready_s,
							busy				=> OPEN);				
	
	--==================================
	--	Second Stage - Absolute Value
	--==================================
	
	abs_x_sub: ENTITY WORK.float_abs
	GENERIC MAP(	DATA_WIDTH	=>	DATA_WIDTH)			
	PORT MAP(		dataa			=>	diff_x,
						result		=>	abbs_diff_x);

	abs_y_sub: ENTITY WORK.float_abs
	GENERIC MAP	(	DATA_WIDTH	=>	DATA_WIDTH)			
	PORT MAP	(		dataa			=>	diff_y,
						result		=>	abbs_diff_y);

	abs_z_sub: ENTITY WORK.float_abs
	GENERIC MAP(	DATA_WIDTH	=>	DATA_WIDTH)			
	PORT MAP	(		dataa			=>	diff_z,
						result		=>	abbs_diff_z);


	
	--==================================
	--	Third Stage - COMPARATORS
	--==================================
	
	x_comparator: ENTITY WORK.float_comparator
	GENERIC MAP	(	DATA_WIDTH	=>	DATA_WIDTH,
						LATENCY		=>	FLOAT_COMP_LATENCY)			
	PORT MAP	(		rst			=>	rst,
						clk			=>	clk,
						syn_clr		=>	syn_clr,
						strobe		=>	subs_x_ready_s,
						dataa			=>	abbs_diff_x,
						datab			=>	X_MAP_THRESHOLD,
						aeb			=>	OPEN,
						agb			=>	OPEN,
						alb			=>	point_ls_thr_x,
						data_ready	=>	comp_x_ready_s,
						busy			=>	OPEN);
	
	
	y_comparator: ENTITY WORK.float_comparator
	GENERIC MAP	(	DATA_WIDTH	=>	DATA_WIDTH,
						LATENCY		=>	FLOAT_COMP_LATENCY)			
	PORT MAP(		rst			=>	rst,
						clk			=>	clk,
						syn_clr		=>	syn_clr,
						strobe		=>	subs_y_ready_s,
						dataa			=>	abbs_diff_y,
						datab			=>	Y_MAP_THRESHOLD,
						aeb			=>	OPEN,
						agb			=>	OPEN,
						alb			=>	point_ls_thr_y,
						data_ready	=>	comp_y_ready_s,
						busy			=>	OPEN);
	
	z_comparator: ENTITY WORK.float_comparator
	GENERIC MAP	(	DATA_WIDTH	=>	DATA_WIDTH,
						LATENCY		=>	FLOAT_COMP_LATENCY)			
	PORT MAP(		rst			=>	rst,
						clk			=>	clk,
						syn_clr		=>	syn_clr,
						strobe		=>	subs_z_ready_s,
						dataa			=>	abbs_diff_z,
						datab			=>	Z_MAP_THRESHOLD,
						aeb			=>	OPEN,
						agb			=>	OPEN,
						alb			=>	point_ls_thr_z,
						data_ready	=>	comp_z_ready_s,
						busy			=>	OPEN);
						
	-----------Neigbour Detection Logic-----------
	neighbour	<= point_ls_thr_x AND point_ls_thr_y AND point_ls_thr_z;
	data_ready	<=	comp_x_ready_s AND comp_y_ready_s AND comp_z_ready_s;

END ARCHITECTURE;