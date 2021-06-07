------------------------------------------------------------------------
------------------------------------------------------------------------
--						Map_handler
-- Date: 2020-12-28
-- Version: 2.0
-- Description:
-- Intantiates: REGISTERS,  MAP SIZE COUNTER LOGIC , Read and write multiplexers ,
-- Scale and Convert to float, Coordinate Transformation and FSMs
-- The Module create and update the map of the robot, the input parameters are from voxel cloud memories and 
-- the odometry of the robot. Dependind of the map_handler control the other fsm units 
-- will work (map_init,map_transform, map_update) to finally write on the map_hanlder_memory
------------------------------------------------------------------------
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	USE ieee.std_logic_unsigned.all;
	USE ieee.numeric_std.all;
LIBRARY WORK;
	USE work.my_package.all;
------------------------------------------------------------------------
ENTITY map_handler IS
	PORT 	(		clk					: 	IN 	STD_LOGIC;
					rst					: 	IN 	STD_LOGIC;
					strobe				:	IN		STD_LOGIC;--Start bit
					
					ready_voxel			:	IN		STD_LOGIC;	
					sin_theta			:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);	
					cos_theta			:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);	
					diff_x				:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					diff_y				:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					q1_voxel_size		:	IN		STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
					q2_voxel_size		:	IN		STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
					q3_voxel_size		:	IN		STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
					q4_voxel_size		:	IN		STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
					voxel_q1_point		:	IN		STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					voxel_q2_point		:	IN		STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					voxel_q3_point		:	IN		STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					voxel_q4_point		:	IN		STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					update_signal		:	IN 	STD_LOGIC;
					rd_en_voxel_q1		:	OUT	STD_LOGIC;	
					rd_en_voxel_q2		:	OUT	STD_LOGIC;
					rd_en_voxel_q3		:	OUT	STD_LOGIC;
					rd_en_voxel_q4		:	OUT	STD_LOGIC;
					rd_addr_from_voxel:	OUT	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
					rd_en_map			:	OUT	STD_LOGIC;
					rd_point_from_map	:	IN		STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					rd_addr_from_map	:	OUT	STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0);
					wr_en					:	OUT	STD_LOGIC;
					wr_addr_map			:	OUT	STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0);
					map_point			:	OUT	STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
					map_size				:	OUT	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					map_full				:	OUT	STD_LOGIC;
					en_sc2f				:	OUT	STD_LOGIC;
					ready_sc2f			:	OUT	STD_LOGIC;
					hps					:	OUT	STD_LOGIC;
					q_h					:	OUT	STD_LOGIC_VECTOR(1 DOWNTO 0);
					data_ready			:	OUT	STD_LOGIC);

END ENTITY;
---------------------------------------------------------
ARCHITECTURE structural OF map_handler IS
	SIGNAL	q1_voxel_size_reg		:	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	q2_voxel_size_reg		:	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	q3_voxel_size_reg		:	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	q4_voxel_size_reg		:	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	
	SIGNAL	update_signal_s		:	STD_LOGIC;
	 
	SIGNAL	voxel_x_point_float_s	:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	voxel_y_point_float_s	:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	voxel_z_point_float_s	:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	voxel_x_point_float_reg	:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	voxel_y_point_float_reg	:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	voxel_z_point_float_reg	:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	
	SIGNAL	result_x_ct_s				:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	result_y_ct_s				:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	result_x_ct_reg			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	result_y_ct_reg			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	result_z_ct_reg			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	en_ct_s						:	STD_LOGIC;
	SIGNAL	ready_ct_s					:	STD_LOGIC;
	SIGNAL	ready_transform_s			:	STD_LOGIC;
	SIGNAL	en_transform_s				:	STD_LOGIC;
	SIGNAL	rd_en_transform			:	STD_LOGIC;
	SIGNAL	map_point_transform		:	STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	addr_transform_s			:	STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0);
	

	
	SIGNAL	map_point_init			:	STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	rd_addr_init			:	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	qsel_init_s				:	STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL	qsel_s					:	STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL	fsm_sel					:	STD_LOGIC_VECTOR(1 DOWNTO 0);
	
	SIGNAL	sin_theta_reg			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);	
	SIGNAL	cos_theta_reg			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);	
	SIGNAL	diff_x_reg				:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	diff_y_reg				:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	
	
	SIGNAL	map_size_reg			:	UNSIGNED(MAP_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	map_size_slv			:	STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	map_size_next			:	UNSIGNED(MAP_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	clr_map_size_s			:	STD_LOGIC;
	SIGNAL	inc_map_size_s			:	STD_LOGIC;
	SIGNAL	inc_map_size_init_s	:	STD_LOGIC;
	
	
	SIGNAL	ready_update_s			:	STD_LOGIC;
	SIGNAL	ready_init_s			:	STD_LOGIC;
	SIGNAL	en_init_s				:	STD_LOGIC;
	SIGNAL	rd_en_init				:	STD_LOGIC;
	
	SIGNAL	en_update_s				:	STD_LOGIC;
	SIGNAL	en_sc2f_s				:	STD_LOGIC;
	SIGNAL	en_comp					:	STD_LOGIC;
	
	SIGNAL	ready_comp_x_s			:	STD_LOGIC;
	SIGNAL	ready_comp_y_s			:	STD_LOGIC;
	SIGNAL	ready_comp_z_s			:	STD_LOGIC;
	SIGNAL	ready_comp_s			:	STD_LOGIC;
	
	SIGNAL	ready_sc2f_x			:	STD_LOGIC;
	SIGNAL	ready_sc2f_y			:	STD_LOGIC;
	SIGNAL	ready_sc2f_z			:	STD_LOGIC;
	SIGNAL	ready_sc2f_s			:	STD_LOGIC;
	SIGNAL	tf_point_x_s			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	tf_point_y_s			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	
	SIGNAL	input_data_x_s			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	input_data_y_s			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	input_data_z_s			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	
	
	SIGNAL	neighbour_x_flag		:	STD_LOGIC;
	SIGNAL	neighbour_y_flag		:	STD_LOGIC;
	SIGNAL	neighbour_z_flag		:	STD_LOGIC;
	SIGNAL	neighbour_flag			:	STD_LOGIC;
	SIGNAL	wr_en_init				:	STD_LOGIC;
	SIGNAL	wr_en_transform		:	STD_LOGIC;
	
	SIGNAL	input_data_s			:	STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	map_point_update		:	STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0); -- to write in map 
	SIGNAL	qsel_update_s			:	STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL	inc_map_size_update_s:	STD_LOGIC;
	SIGNAL	wr_en_update			:	STD_LOGIC;
	
	SIGNAL	rd_addr_from_voxel_update	:	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	rd_addr_from_map_update		:	STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	wr_addr_update					:	STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	rd_en_from_voxel_update		:	STD_LOGIC;
	SIGNAL	rd_en_from_map_update		:	STD_LOGIC;
	
	
	
	
	
BEGIN	
	--===================================
	--			REGISTERS
	--===================================					
	q1_voxel_size_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	VOXEL_ADDR_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	ready_voxel,
							syn_clr				=>	'0',
							d						=>	q1_voxel_size,
							q						=>	q1_voxel_size_reg);
	
	q2_voxel_size_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	VOXEL_ADDR_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	ready_voxel,
							syn_clr				=>	'0',
							d						=>	q2_voxel_size,
							q						=>	q2_voxel_size_reg);
	
	q3_voxel_size_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	VOXEL_ADDR_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	ready_voxel,
							syn_clr				=>	'0',
							d						=>	q3_voxel_size,
							q						=>	q3_voxel_size_reg);
	
	q4_voxel_size_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	VOXEL_ADDR_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	ready_voxel,
							syn_clr				=>	'0',
							d						=>	q4_voxel_size,
							q						=>	q4_voxel_size_reg);

	sin_theta_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	strobe,
							syn_clr				=>	'0',
							d						=>	sin_theta,
							q						=>	sin_theta_reg);
	
	cos_theta_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	strobe,
							syn_clr				=>	'0',
							d						=>	cos_theta,
							q						=>	cos_theta_reg);
	
	diff_x_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	strobe,
							syn_clr				=>	'0',
							d						=>	diff_x,
							q						=>	diff_x_reg);
	
	diff_y_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	strobe,
							syn_clr				=>	'0',
							d						=>	diff_y,
							q						=>	diff_y_reg);					
	
	--========================================
	-- 		MAP SIZE COUNTER LOGIC
	--========================================
	-- map_size_reg is incremented after every map write process, in map_init or map_update.
	-- Therefore, it will allways point to the next available position in the map.
	-- map_size_reg represents the current ammount of points in the map, so no need
	-- of adjustent +1 at the end of the algorithm.
	
	map_size_next 	<=		(OTHERS =>	'0') 	WHEN 	clr_map_size_s	='1' ELSE
								map_size_reg + 1;
	
	map_size_slv	<=		std_logic_vector(map_size_reg);
	map_size			<=		PADDING_Z_MAP_ADDR2DATA & map_size_slv; -- Output size
	inc_map_size_s	<=		inc_map_size_init_s	OR inc_map_size_update_s;

	increment_map_size: ENTITY WORK.my_register_unsigned
	GENERIC MAP(		DATA_WIDTH			=>	MAP_ADDR_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	inc_map_size_s,
							syn_clr				=>	clr_map_size_s,
							d						=>	map_size_next,
							q						=>	map_size_reg);
							
	--========================================
	-- 		Read and write multiplexers
	--========================================
	qsel_s					<=		qsel_init_s		WHEN	fsm_sel = "01"	ELSE 	-- map_init_fsm takes control
										qsel_update_s	WHEN	fsm_sel = "11"	ELSE 	-- map_update_fsm takes control
										"00";
	
	rd_addr_from_voxel	<=		rd_addr_init					WHEN	fsm_sel = "01"	ELSE 	-- map_init_fsm takes control
										rd_addr_from_voxel_update	WHEN	fsm_sel = "11"	ELSE 	-- map_update_fsm takes control
										(OTHERS => '0');
	
	rd_en_voxel_q1			<=		rd_en_init					WHEN fsm_sel="01" AND qsel_s="00" ELSE  -- Read from voxel_q1, map_init_fsm takes control
										rd_en_from_voxel_update	WHEN fsm_sel="11" AND qsel_s="11" ELSE  -- Read from voxel_q1, map_update_fsm takes control
										'0';
	
	rd_en_voxel_q2			<=		rd_en_init					WHEN fsm_sel="01" AND qsel_s="01" ELSE  -- Read from voxel_q2, map_init_fsm takes control
										rd_en_from_voxel_update	WHEN fsm_sel="11" AND qsel_s="01" ELSE  -- Read from voxel_q2, map_update_fsm takes control
										'0';
										
	rd_en_voxel_q3			<=		rd_en_init					WHEN fsm_sel="01" AND qsel_s="10" ELSE  -- Read from voxel_q3, map_init_fsm takes control
										rd_en_from_voxel_update	WHEN fsm_sel="11" AND qsel_s="10" ELSE  -- Read from voxel_q3, map_update_fsm takes control
										'0';
	
	rd_en_voxel_q4			<=		rd_en_init					WHEN fsm_sel="01" AND qsel_s="11" ELSE  -- Read from voxel_q4, map_init_fsm takes control
										rd_en_from_voxel_update	WHEN fsm_sel="11" AND qsel_s="11" ELSE  -- Read from voxel_q4, map_update_fsm takes control
										'0';
	
	
	input_data_x_s	<=	voxel_q1_point(X_MSB DOWNTO X_LSB) WHEN qsel_s	= "00"	ELSE 	--Read from voxel_q1
							voxel_q2_point(X_MSB DOWNTO X_LSB) WHEN qsel_s	= "01"	ELSE 	--Read from voxel_q2
							voxel_q3_point(X_MSB DOWNTO X_LSB) WHEN qsel_s	= "10"	ELSE	--Read from voxel_q3
							voxel_q4_point(X_MSB DOWNTO X_LSB);										--Read from voxel_q4
	
	input_data_y_s	<=	voxel_q1_point(Y_MSB DOWNTO Y_LSB) WHEN qsel_s	= "00"	ELSE	--Read from voxel_q1
							voxel_q2_point(Y_MSB DOWNTO Y_LSB) WHEN qsel_s	= "01"	ELSE	--Read from voxel_q2
							voxel_q3_point(Y_MSB DOWNTO Y_LSB) WHEN qsel_s	= "10"	ELSE	--Read from voxel_q3
							voxel_q4_point(Y_MSB DOWNTO Y_LSB);										--Read from voxel_q4
	
	input_data_z_s	<=	voxel_q1_point(Z_MSB DOWNTO Z_LSB) WHEN qsel_s	= "00"	ELSE	--Read from voxel_q1
							voxel_q2_point(Z_MSB DOWNTO Z_LSB) WHEN qsel_s	= "01"	ELSE	--Read from voxel_q2
							voxel_q3_point(Z_MSB DOWNTO Z_LSB) WHEN qsel_s	= "10"	ELSE	--Read from voxel_q3
							voxel_q4_point(Z_MSB DOWNTO Z_LSB);										--Read from voxel_q4
	
	input_data_s	<=	voxel_q1_point WHEN qsel_s	= "00"	ELSE	--Read from voxel_q1
							voxel_q2_point WHEN qsel_s	= "01"	ELSE	--Read from voxel_q2
							voxel_q3_point WHEN qsel_s	= "10"	ELSE	--Read from voxel_q3
							voxel_q4_point;									--Read from voxel_q4
								
	wr_en				<=	wr_en_init 			WHEN	fsm_sel = "01"	ELSE 	-- map_init_fsm takes control
							wr_en_transform	WHEN	fsm_sel = "10"	ELSE 	-- map_transform_fsm takes control
							wr_en_update		WHEN	fsm_sel = "11"	ELSE 	-- map_update_fsm takes control
							'0';
							
	wr_addr_map		<=	map_size_slv 		WHEN	fsm_sel = "01"	ELSE 	-- map_init_fsm takes control
							addr_transform_s	WHEN	fsm_sel = "10"	ELSE 	-- map_transform_fsm takes control
							wr_addr_update		WHEN	fsm_sel = "11"	ELSE 	-- map_update_fsm takes control
							(OTHERS => 'Z');
							
	map_point		<= map_point_init			WHEN	fsm_sel = "01"	ELSE 	-- map_init_fsm takes control
							map_point_transform	WHEN	fsm_sel = "10"	ELSE 	-- map_transform_fsm takes control
							map_point_update		WHEN	fsm_sel = "11"	ELSE 	-- map_update_fsm takes control
							(OTHERS => '0');
	
	rd_addr_from_map	<=	addr_transform_s			WHEN	fsm_sel = "10"	ELSE	-- map_transform_fsm takes control
								rd_addr_from_map_update	WHEN	fsm_sel = "11"	ELSE	-- map_update_fsm takes control
								(OTHERS => '0');
	
	rd_en_map			<= rd_en_transform			WHEN	fsm_sel = "10"	ELSE	-- map_transform_fsm takes control
								rd_en_from_map_update	WHEN	fsm_sel = "11"	ELSE	-- map_update_fsm takes control
								'0';
	
	
	--===================================
	--		Scale and Convert to float
	--===================================	
	-- X COORDINATE						
	sc2f_x:	ENTITY WORK.scale_convert2float
	GENERIC MAP	(	DATA_WIDTH		=>	DATA_WIDTH)			
	PORT MAP	(		rst				=>	rst,
						clk				=>	clk,
						syn_clr			=>	'0',
						strobe			=>	en_sc2f_s,
						dataa				=>	input_data_x_s,
						result			=>	voxel_x_point_float_s,
						data_ready		=>	ready_sc2f_x,
						busy				=>	OPEN);	
	
	-- Y COORDINATE
	sc2f_y:	ENTITY WORK.scale_convert2float
	GENERIC MAP	(	DATA_WIDTH		=>	DATA_WIDTH)			
	PORT MAP	(		rst				=>	rst,
						clk				=>	clk,
						syn_clr			=>	'0',
						strobe			=>	en_sc2f_s,
						dataa				=>	input_data_y_s,
						result			=>	voxel_y_point_float_s,
						data_ready		=>	ready_sc2f_y,
						busy				=>	OPEN);
	
	-- Z COORDINATE							
	sc2f_z:	ENTITY WORK.scale_convert2float
	GENERIC MAP	(	DATA_WIDTH		=>	DATA_WIDTH)			
	PORT MAP	(		rst				=>	rst,
						clk				=>	clk,
						syn_clr			=>	'0',
						strobe			=>	en_sc2f_s,
						dataa				=>	input_data_z_s,
						result			=>	voxel_z_point_float_s,
						data_ready		=>	ready_sc2f_z,
						busy				=>	OPEN);
	
	-- Ready Logic
	ready_sc2f_s	<=	ready_sc2f_x AND ready_sc2f_y AND ready_sc2f_z;
	-- Point concatenation
	map_point_init	<= voxel_z_point_float_reg & voxel_y_point_float_reg & voxel_x_point_float_reg;

	
	--		Register Results scale_convert2float
	result_x_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	ready_sc2f_x,
							syn_clr				=>	'0',
							d						=>	voxel_x_point_float_s,
							q						=>	voxel_x_point_float_reg);
	
	result_y_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	ready_sc2f_y,
							syn_clr				=>	'0',
							d						=>	voxel_y_point_float_s,
							q						=>	voxel_y_point_float_reg);
	
	result_z_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	ready_sc2f_z,
							syn_clr				=>	'0',
							d						=>	voxel_z_point_float_s,
							q						=>	voxel_z_point_float_reg);

	--===================================
	--		Coordinate Transformation
	--===================================
	
	coord_transform_module:ENTITY WORK.coord_transform
	GENERIC MAP	(	DATA_WIDTH		=>	DATA_WIDTH)			
	PORT MAP 	(	clk				=>	clk,
						rst				=>	rst,
						strobe			=>	en_ct_s,
						syn_clr			=>	'0',
						sin_theta		=>	sin_theta_reg,
						cos_theta		=>	cos_theta_reg,
						diff_x			=>	diff_x_reg,
						diff_y			=>	diff_y_reg,
						input_point_x	=>	rd_point_from_map(X_MSB DOWNTO X_LSB),
						input_point_y	=>	rd_point_from_map(Y_MSB DOWNTO Y_LSB),
						result_x			=>	result_x_ct_s,
						result_y			=>	result_y_ct_s,
						data_ready		=>	ready_ct_s);
	
	--		Register Results coord_transform
	ct_x_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	ready_ct_s,
							syn_clr				=>	'0',
							d						=>	result_x_ct_s,
							q						=>	result_x_ct_reg);
	
	ct_y_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	ready_ct_s,
							syn_clr				=>	'0',
							d						=>	result_y_ct_s,
							q						=>	result_y_ct_reg);
	
	ct_z_register: ENTITY WORK.my_register --Z coordinate is not transformed. The point coming from map must be strored to be returned
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	en_ct_s,
							syn_clr				=>	'0',
							d						=>	rd_point_from_map(Z_MSB DOWNTO Z_LSB),
							q						=>	result_z_ct_reg);
	
	-- Point concatenation
	map_point_transform	<= result_z_ct_reg & result_y_ct_reg & result_x_ct_reg;

	
	--====================================
	-- 		FSMs
	--====================================
	map_init_control: ENTITY WORK.map_init_fsm
	PORT MAP(		clk					=>	clk,
						rst					=>	rst,
						strobe				=>	en_init_s,
						ready_voxel			=>	ready_voxel,
						ready_sc2f			=>	ready_sc2f_s,
						q1_size				=>	q1_voxel_size_reg,
						q2_size				=>	q2_voxel_size_reg,
						q3_size				=>	q3_voxel_size_reg,
						q4_size				=>	q4_voxel_size_reg,
						qsel					=>	qsel_init_s,
						en_scale				=>	en_sc2f_s,
						en_inc_size			=>	inc_map_size_init_s,
						wr_en					=>	wr_en_init,
						rd_en					=>	rd_en_init,
						rd_addr				=>	rd_addr_init,
						data_ready			=>	ready_init_s);
	
	map_cord_transf_control: ENTITY WORK.map_transform_fsm
	PORT MAP(	clk					=>	clk,
					rst					=>	rst,
					strobe				=>	en_transform_s,
					ready_transform	=>	ready_ct_s,
					map_size				=>	map_size_slv,
					en_transform		=>	en_ct_s,
					wr_en					=>	wr_en_transform,
					rd_en					=>	rd_en_transform,
					addr					=>	addr_transform_s,
					data_ready			=>	ready_transform_s);
					
	map_update_control: ENTITY WORK.map_update_fsm
	PORT MAP(	clk						=>	clk,
					rst						=>	rst,
					strobe					=>	en_update_s,
					q1_size					=>	q1_voxel_size_reg,
					q2_size					=>	q2_voxel_size_reg,
					q3_size					=>	q3_voxel_size_reg,
					q4_size					=>	q4_voxel_size_reg,
					map_size					=>	map_size_slv,
					voxel_point				=>	input_data_s,
					map_point				=>	rd_point_from_map,
					map_new_point			=>	map_point_update,
					qsel						=>	qsel_update_s,
					en_inc_size				=>	inc_map_size_update_s,
					wr_en						=>	wr_en_update,
					rd_addr_from_map		=>	rd_addr_from_map_update,
					rd_en_from_map			=>	rd_en_from_map_update,
					rd_en_from_voxel		=>	rd_en_from_voxel_update,
					rd_addr_from_voxel	=>	rd_addr_from_voxel_update,
					wr_addr_to_map			=>	wr_addr_update,
					hps						=> hps,
					q_h						=> q_h,
					data_ready				=>	ready_update_s);
	
	map_handler_control:	ENTITY WORK.map_handler_fsm
	PORT MAP(		clk					=>	clk,
						rst					=>	rst,
						strobe				=>	strobe,
						update_signal		=>	update_signal,
						map_size				=>	map_size_slv,
						clr_map_size		=>	clr_map_size_s,
						ready_init			=>	ready_init_s,
						ready_transform	=>	ready_transform_s,
						ready_update		=>	ready_update_s,
						ready_voxel			=>	ready_voxel,
						en_init				=>	en_init_s,
						en_transform		=>	en_transform_s,
						en_update			=>	en_update_s,
						fsm_sel				=>	fsm_sel,
						data_ready			=>	data_ready);
en_sc2f<=ready_transform_s;
ready_sc2f<=ready_update_s;
END ARCHITECTURE;


