------------------------------------------------------------------------
--						voxel_filter
-- Date: 2020-12-28
-- Version: 2.0
-- Description:
-- Intantiates: voxel_quadrant, and voxel_ready_fsm
-- The module reads each from Quadrant Data Memories and organized each cuadrant from near distance
------------------------------------------------------------------------
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	USE ieee.std_logic_unsigned.all;
	USE ieee.numeric_std.all;
LIBRARY WORK;
	USE work.my_package.all;
------------------------------------------------------------------------
ENTITY voxel_filter IS
	PORT 	(		clk					: 	IN 	STD_LOGIC;
					rst					: 	IN 	STD_LOGIC;
					strobe				:	IN		STD_LOGIC;--Start bit
					q1_size				:	IN		STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0); -- Size of q2 memory
					q2_size				:	IN		STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0); -- Size of q2 memory
					q3_size				:	IN		STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0); -- Size of q2 memory
					q4_size				:	IN		STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0); -- Size of q2 memory
					
					input_data_q1		:	IN		STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					input_data_q2		:	IN		STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					input_data_q3		:	IN		STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					input_data_q4		:	IN		STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					
					rd_en_mem_q1		:	OUT	STD_LOGIC;
					rd_en_mem_q2		:	OUT	STD_LOGIC;
					rd_en_mem_q3		:	OUT	STD_LOGIC;
					rd_en_mem_q4		:	OUT	STD_LOGIC;
						
					rd_addr_from_q1	:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
					rd_addr_from_q2	:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
					rd_addr_from_q3	:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
					rd_addr_from_q4	:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
						
					voxel_q1_point		:	OUT	STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					voxel_q2_point		:	OUT	STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					voxel_q3_point		:	OUT	STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					voxel_q4_point		:	OUT	STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					wr_addr_voxel_q1	:	OUT	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
					wr_addr_voxel_q2	:	OUT	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
					wr_addr_voxel_q3	:	OUT	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
					wr_addr_voxel_q4	:	OUT	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
					wr_en_q1				:	OUT	STD_LOGIC;
					wr_en_q2				:	OUT	STD_LOGIC;
					wr_en_q3				:	OUT	STD_LOGIC;
					wr_en_q4				:	OUT	STD_LOGIC;
					q1_voxel_size		:	OUT	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
					q2_voxel_size		:	OUT	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
					q3_voxel_size		:	OUT	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
					q4_voxel_size		:	OUT	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
					data_readys			:	OUT	STD_LOGIC_VECTOR(3 DOWNTO 0);	
					data_ready			:	OUT	STD_LOGIC);

END ENTITY;
---------------------------------------------------------
ARCHITECTURE structural OF voxel_filter IS
	SIGNAL	data_ready_q1_s	:	STD_LOGIC;
	SIGNAL	data_ready_q2_s	:	STD_LOGIC;
	SIGNAL	data_ready_q3_s	:	STD_LOGIC;
	SIGNAL	data_ready_q4_s	:	STD_LOGIC;
	
	SIGNAL	data_ready_q1_reg	:	STD_LOGIC;
	SIGNAL	data_ready_q2_reg	:	STD_LOGIC;
	SIGNAL	data_ready_q3_reg	:	STD_LOGIC;
	SIGNAL	data_ready_q4_reg	:	STD_LOGIC;
	
BEGIN
	--========================================
	--			voxel_quadrant INSTANTIATIONS
	--========================================	
	voxel_filter_q1: ENTITY work.voxel_quadrant
	PORT MAP	(		clk					=>	clk,
						rst					=>	rst,
						strobe				=>	strobe,
						quadrant_size		=>	q1_size,
						input_data			=>	input_data_q1,
						rd_en					=>	rd_en_mem_q1,
						rd_add_from_q		=>	rd_addr_from_q1,
						voxel_point			=>	voxel_q1_point,
						wr_addr_voxel		=>	wr_addr_voxel_q1,
						wr_en					=>	wr_en_q1,
						voxel_size			=>	q1_voxel_size,
						data_ready			=>	data_ready_q1_s);
						
	voxel_filter_q2: ENTITY work.voxel_quadrant		
	PORT MAP	(		clk					=>	clk,
						rst					=>	rst,
						strobe				=>	strobe,
						quadrant_size		=>	q2_size,
						input_data			=>	input_data_q2,
						rd_en					=>	rd_en_mem_q2,
						rd_add_from_q		=>	rd_addr_from_q2,
						voxel_point			=>	voxel_q2_point,
						wr_addr_voxel		=>	wr_addr_voxel_q2,
						wr_en					=>	wr_en_q2,
						voxel_size			=>	q2_voxel_size,
						data_ready			=>	data_ready_q2_s);
	
	voxel_filter_q3: ENTITY work.voxel_quadrant
	PORT MAP	(		clk					=>	clk,
						rst					=>	rst,
						strobe				=>	strobe,
						quadrant_size		=>	q3_size,
						input_data			=>	input_data_q3,
						rd_en					=>	rd_en_mem_q3,
						rd_add_from_q		=>	rd_addr_from_q3,
						voxel_point			=>	voxel_q3_point,
						wr_addr_voxel		=>	wr_addr_voxel_q3,
						wr_en					=>	wr_en_q3,
						voxel_size			=>	q3_voxel_size,
						data_ready			=>	data_ready_q3_s);
	
	voxel_filter_q4: ENTITY work.voxel_quadrant		
	PORT MAP	(		clk					=>	clk,
						rst					=>	rst,
						strobe				=>	strobe,
						quadrant_size		=>	q4_size,
						input_data			=>	input_data_q4,
						rd_en					=>	rd_en_mem_q4,
						rd_add_from_q		=>	rd_addr_from_q4,
						voxel_point			=>	voxel_q4_point,
						wr_addr_voxel		=>	wr_addr_voxel_q4,
						wr_en					=>	wr_en_q4,
						voxel_size			=>	q4_voxel_size,
						data_ready			=>	data_ready_q4_s);
	--========================================
	--			voxel_fsm INSTANTIATIONS
	--========================================	
	voxel_ready_logic: ENTITY work.voxel_ready_fsm		
	PORT MAP 	(	clk					=>	clk,
						rst					=>	rst,
						ready_q1				=>	data_ready_q1_s,
						ready_q2				=>	data_ready_q2_s,
						ready_q3				=>	data_ready_q3_s,
						ready_q4				=>	data_ready_q4_s,
						data_ready			=>	data_ready);
						
data_readys(0) <= data_ready_q1_s;
data_readys(1) <= data_ready_q2_s;
data_readys(2) <= data_ready_q3_s;
data_readys(3) <= data_ready_q4_s;

END ARCHITECTURE;