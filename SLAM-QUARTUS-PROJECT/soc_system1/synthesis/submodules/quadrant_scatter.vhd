-- altera vhdl_input_version vhdl_2008
------------------------------------------------------------------------
--						quadrant_scatter
-- Date: 2020-12-28
-- Version: 2.0
-- Description:
-- Intantiates: scatter_controlFSM, quadrant_selector and scale_convert2int
-- The module reads each from point_cloud memory, scale by a factor of 1000 
-- to convert units to milimetes and convert to integer representation.
-- Adresses pptimized by memory size
------------------------------------------------------------------------
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	USE ieee.std_logic_unsigned.all;
	USE ieee.numeric_std.all;
LIBRARY WORK;
	USE work.my_package.all;
------------------------------------------------------------------------
ENTITY quadrant_scatter IS			
	PORT	(		clk						: 	IN 	STD_LOGIC;
					rst						: 	IN 	STD_LOGIC;
					strobe					:	IN		STD_LOGIC; --Start bit
					pointcloud_size		:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0); -- Size of input sample
					--Ports for Reading from input
					input_data				:	IN		STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					rd_addr_from_input	:	OUT	STD_LOGIC_VECTOR(INPUT_DATA_ADDR_WIDTH-1 DOWNTO 0);
					--Ports for writing Quadrant Memories					
					quadrant_point			:	OUT	STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					wr_addr_q1				:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
					wr_addr_q2				:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
					wr_addr_q3				:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
					wr_addr_q4				:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
					wr_en_q1					:	OUT	STD_LOGIC;
					wr_en_q2					:	OUT	STD_LOGIC;
					wr_en_q3					:	OUT	STD_LOGIC;
					wr_en_q4					:	OUT	STD_LOGIC;
					-- Size of memories
					q1_size					:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
					q2_size					:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
					q3_size					:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
					q4_size					:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
					
					rd_en_input				:	OUT	STD_LOGIC;
					data_ready				:	OUT	STD_LOGIC); -- done tick
END ENTITY;
---------------------------------------------------------
ARCHITECTURE structural OF quadrant_scatter IS
	
	SIGNAL 	ready_scale_x_s		:	STD_LOGIC; -- data_ready from scale_convert2int
	SIGNAL 	ready_scale_y_s		:	STD_LOGIC; -- data_ready from scale_convert2int
	SIGNAL 	ready_scale_z_s		:	STD_LOGIC; -- data_ready from scale_convert2int
	SIGNAL 	ready_scale_s			:	STD_LOGIC; -- data_ready from scale_convert2int
	SIGNAL	rd_addr_s				:	STD_LOGIC_VECTOR(INPUT_DATA_ADDR_WIDTH-1 DOWNTO 0);-- read address from input array
	SIGNAL	wr_en_s					:	STD_LOGIC; -- write enable for output array
	SIGNAL	wr_en_q1_s				:	STD_LOGIC; 
	SIGNAL	wr_en_q2_s				:	STD_LOGIC; 
	SIGNAL	wr_en_q3_s				:	STD_LOGIC; 
	SIGNAL	wr_en_q4_s				:	STD_LOGIC; 
	SIGNAL	en_input_reg_s			:	STD_LOGIC; 
	SIGNAL	wr_addr_q1_s			:	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0); -- write address for output array for q1
	SIGNAL	wr_addr_q2_s			:	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0); -- write address for output array for q2
	SIGNAL	wr_addr_q3_s			:	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0); -- write address for output array for q3
	SIGNAL	wr_addr_q4_s			:	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0); -- write address for output array for q4
	
	SIGNAL	en_scale_s				:	STD_LOGIC; -- strobe for scale_convert2int
	SIGNAL	last_s					:	STD_LOGIC; -- used for correction in last size
	SIGNAL	q1_s						:	STD_LOGIC; -- Holds q1 quadrant flag
	SIGNAL	q2_s						:	STD_LOGIC; -- Holds q1 quadrant flag
	SIGNAL	q3_s						:	STD_LOGIC; -- Holds q1 quadrant flag
	SIGNAL	q4_s						:	STD_LOGIC; -- Holds q1 quadrant flag
	
	SIGNAL	q1_full_n_s				:	STD_LOGIC; 
	SIGNAL	q2_full_n_s				:	STD_LOGIC;
	SIGNAL	q3_full_n_s				:	STD_LOGIC;
	SIGNAL	q4_full_n_s				:	STD_LOGIC;
	
	SIGNAL	result_s					:	STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	result_x_s				:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	result_x_reg			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	result_y_s				:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	result_y_reg			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	result_z_s				:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	result_z_reg			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);

	
	SIGNAL	q1_size_s				:	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	q2_size_s				:	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	q3_size_s				:	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	q4_size_s				:	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	q1_size_consec			:	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	q2_size_consec			:	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	q3_size_consec			:	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	q4_size_consec			:	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	wr_addr_q1_uns_s		:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0); 
	SIGNAL	wr_addr_q2_uns_s		:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0); 
	SIGNAL	wr_addr_q3_uns_s		:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0); 
	SIGNAL	wr_addr_q4_uns_s		:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	
	
BEGIN
	--========================================
	--			scatter_control INSTANTIATION
	--========================================
	control_fsm: ENTITY WORK.scatter_control_fsm
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							strobe				=>	strobe,
							q1						=>	q1_s,
							q2						=>	q2_s,
							q3						=>	q3_s,
							q4						=>	q4_s,
							ready_scale			=>	ready_scale_s,
							pointcloud_size	=>	pointcloud_size,
							rd_addr				=>	rd_addr_from_input,
							en_scale				=>	en_scale_s,
							wr_en					=>	wr_en_s,
							wr_addr_q1			=>	wr_addr_q1_s,
							wr_addr_q2			=>	wr_addr_q2_s,
							wr_addr_q3			=>	wr_addr_q3_s,
							wr_addr_q4			=>	wr_addr_q4_s,
							last					=>	last_s,
							rd_en_input			=>	rd_en_input,						
							data_ready			=>	data_ready);
	
	--=====================================
	-- Scale and Convert Modules
	-- Scale x1000 and converto floating
	-- poin to integer representation.
	--=====================================
	scale_n_convert2int_X: ENTITY WORK.scale_convert2int
	GENERIC	MAP (		DATA_WIDTH			=>	DATA_WIDTH)
	PORT	MAP(			rst					=>	rst,
							clk					=>	clk,
							syn_clr				=>	'0',
							strobe				=>	en_scale_s,
							dataa					=>	input_data(X_MSB DOWNTO X_LSB),
							result				=>	result_x_s,
							data_ready			=>	ready_scale_x_s,
							busy					=>	OPEN);
	
	scale_n_convert2int_Y: ENTITY WORK.scale_convert2int
	GENERIC	MAP (		DATA_WIDTH			=>	DATA_WIDTH)
	PORT	MAP(			rst					=>	rst,
							clk					=>	clk,
							syn_clr				=>	'0',
							strobe				=>	en_scale_s,
							dataa					=>	input_data(Y_MSB DOWNTO Y_LSB),
							result				=>	result_y_s,
							data_ready			=>	ready_scale_y_s,
							busy					=>	OPEN);
	
	scale_n_convert2int_Z: ENTITY WORK.scale_convert2int
	GENERIC	MAP (		DATA_WIDTH			=>	DATA_WIDTH)
	PORT	MAP(			rst					=>	rst,
							clk					=>	clk,
							syn_clr				=>	'0',
							strobe				=>	en_scale_s,
							dataa					=>	input_data(Z_MSB DOWNTO Z_LSB),
							result				=>	result_z_s,
							data_ready			=>	ready_scale_z_s,
							busy					=>	OPEN);
	
	ready_scale_s <= ready_scale_x_s AND ready_scale_y_s AND ready_scale_z_s;
							
	int_X_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	ready_scale_x_s,
							syn_clr				=>	'0',
							d						=>	result_x_s,
							q						=>	result_x_reg);
	
	int_Y_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	ready_scale_y_s,
							syn_clr				=>	'0',
							d						=>	result_y_s,
							q						=>	result_y_reg);
							
							
	int_Z_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	ready_scale_z_s,
							syn_clr				=>	'0',
							d						=>	result_z_s,
							q						=>	result_z_reg);
	
	result_s <= result_z_reg & result_y_reg & result_x_reg;
	
	
	--=====================================
	-- Quadrant Selector Module
	-- Reads the x,y,z coordinates and determines
	-- to wich quadrant the point belongs, by
	-- activating the qx flag.
	--=====================================
	quadrant_selector_module: ENTITY WORK.quadrant_selector
	GENERIC MAP	(	DATA_WIDTH	=>	DATA_WIDTH)			
	PORT MAP	(		x_in			=>	result_x_reg,
						y_in			=>	result_y_reg,
						z_in			=>	result_z_reg,
						q1				=>	q1_s,
						q2				=>	q2_s,
						q3				=>	q3_s,
						q4				=>	q4_s);
	
	--================================================================
	-- QUADRANT MEMORY SIZE LOGIC AND SIZE OUTPUT LOGIC
	-- The current size of the each quadrant memory is the wr_addr+1. 
	-- Aditional  wr_addr+1 must be done in the last fetching
	-- Implemented using trick to avoid a STD_LOGIC_VECTOR adder by
	-- converting to unsigned to operate as integer. Only implement
	-- cables
	--================================================================
	
	wr_addr_q1_uns_s	<= unsigned(wr_addr_q1_s);
	q1_size_consec		<= std_logic_vector(wr_addr_q1_uns_s + 1);  			
																								
	wr_addr_q2_uns_s	<= unsigned(wr_addr_q2_s); 
	q2_size_consec		<= std_logic_vector(wr_addr_q2_uns_s + 1);
	
	wr_addr_q3_uns_s	<= unsigned(wr_addr_q3_s); 
	q3_size_consec		<= std_logic_vector(wr_addr_q3_uns_s + 1);
	
	wr_addr_q4_uns_s	<= unsigned(wr_addr_q4_s); 
	q4_size_consec		<= std_logic_vector(wr_addr_q4_uns_s + 1);
	
	q1_size_s			<= q1_size_consec WHEN	last_s='1' AND q1_s='1' else
								wr_addr_q1_s ;
	q2_size_s			<= q2_size_consec WHEN	last_s='1' AND q2_s='1' else
								wr_addr_q2_s;
	q3_size_s			<= q3_size_consec WHEN	last_s='1' AND q3_s='1' else
								wr_addr_q3_s;
	q4_size_s			<= q4_size_consec WHEN	last_s='1' AND q4_s='1' else
								wr_addr_q4_s;
																

	-- Register current size to output
	size_q1_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	QUADRANT_ADDR_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	wr_en_q1_s,
							syn_clr				=>	'0',
							d						=>	q1_size_s,
							q						=>	q1_size);
	q1_full_n_s	<=	'0' 	WHEN	q1_size = MAX_QUADRANT_SIZE	ELSE	'1';
	wr_en_q1_s	<= wr_en_s AND q1_full_n_s; -- if quadrant_memory full, write_en is and-gated
	
	size_q2_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	QUADRANT_ADDR_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	wr_en_q2_s,
							syn_clr				=>	'0',
							d						=>	q2_size_s,
							q						=>	q2_size);
	q2_full_n_s	<=	'0' 	WHEN	q2_size = MAX_QUADRANT_SIZE	ELSE	'1';
	wr_en_q2_s	<= wr_en_s AND q2_full_n_s; -- if quadrant_memory full, write_en is and-gated
	
	size_q3_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	QUADRANT_ADDR_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	wr_en_q3_s,
							syn_clr				=>	'0',
							d						=>	q3_size_s,
							q						=>	q3_size);
	q3_full_n_s	<=	'0' 	WHEN	q3_size = MAX_QUADRANT_SIZE	ELSE	'1';
	wr_en_q3_s	<= wr_en_s AND q3_full_n_s;
	
	size_q4_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	QUADRANT_ADDR_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	wr_en_q4_s,
							syn_clr				=>	'0',
							d						=>	q4_size_s,
							q						=>	q4_size);
	q4_full_n_s	<=	'0' 	WHEN	q4_size = MAX_QUADRANT_SIZE	ELSE	'1';
	wr_en_q4_s	<= wr_en_s AND q4_full_n_s;
	
	--==============================================================
	-- WRITE OUTPUT MEMORIES LOGIC
	-- Only writes quadrant memory the point belongs, by AND-gating
	-- wr_en_s signal with the correspondent quadrant flag.
	-- Write Addresses come from FSM
	--===============================================================
	wr_en_q1			<=	wr_en_q1_s AND q1_s;
	wr_en_q2			<=	wr_en_q2_s AND q2_s;
	wr_en_q3			<=	wr_en_q3_s AND q3_s;
	wr_en_q4			<=	wr_en_q4_s AND q4_s;
	
	wr_addr_q1	 	<=	wr_addr_q1_s;
	wr_addr_q2 		<=	wr_addr_q2_s;
	wr_addr_q3 		<=	wr_addr_q3_s;
	wr_addr_q4 		<=	wr_addr_q4_s;
	
	quadrant_point	<=	result_s;

END ARCHITECTURE;


