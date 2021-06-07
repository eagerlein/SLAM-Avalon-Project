-- altera vhdl_input_version vhdl_2008
------------------------------------------------------------------------
--						quadrant_to_map_fsm
-- Date: 2020-12-15
-- Version: 1.0 
-- Description:
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
ENTITY quadrant_to_map_fsm IS		
	PORT 	(		clk					: 	IN 	STD_LOGIC;
					rst					: 	IN 	STD_LOGIC;
					strobe				:	IN		STD_LOGIC;--Start bit
					voxel_size			:	IN		STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);--Used to control voxel quadrant loop.
					map_size				:	IN		STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0);--Used to control map loop.
					voxel_point			:	IN		STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0); --Point from Voxel
					map_point			:	IN		STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0); --Point from Map
					map_new_point		:	OUT	STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0); --Point from Map
					rd_addr_from_voxel:	OUT	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0); -- read address from voxel
					rd_addr_from_map	:	OUT	STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0); -- read address from map
					rd_en_from_map		:	OUT	STD_LOGIC;
					rd_en_from_voxel	:	OUT	STD_LOGIC;
					wr_addr_to_map		:	OUT	STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0); -- write address to voxel memory
					wr_en					:	OUT	STD_LOGIC;-- enable signal for writing map memory
					en_inc_size			:	OUT	STD_LOGIC;-- enable signal for incrementing map size
					data_ready			:	OUT	STD_LOGIC);
					
END ENTITY;
---------------------------------------------------------
ARCHITECTURE fsm OF quadrant_to_map_fsm IS
	TYPE state IS (	idle, fetching_voxel_point, inc_i, write_current_point, wait_current_point, fetching_j_point, inc_j, 
							converting_to_float, update_map_size_reg, comparing_points, write_new_point,wait_new_point, 
							strobe_convert, strobe_compare, reg_j_point, inc_map_size, ready); 
		
	SIGNAL 	pr_state					: 	state;
	SIGNAL 	nx_state					: 	state;
	SIGNAL	voxel_size_reg			:	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	voxel_size_s			:	UNSIGNED(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	voxel_size_temp_s		:	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	
	SIGNAL	map_size_reg			:	STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	map_size_s				:	UNSIGNED(MAP_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	map_size_temp_s		:	STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0);
	
	
	SIGNAL	neighbour_flag_s		:	STD_LOGIC;
	SIGNAL	en_CP_s					:	STD_LOGIC;
	SIGNAL	en_J_s					:	STD_LOGIC;
	SIGNAL	j_point_x_reg			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	j_point_y_reg			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	j_point_z_reg			:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	voxel_point_x_reg		:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	voxel_point_y_reg		:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	voxel_point_z_reg		:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	new_map_point_s		:	STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
		
		
--	SIGNAL	rd_addr_s				:	UNSIGNED(ADDR_WIDTH-1 DOWNTO 0);
--	SIGNAL	rd_addr_next			:	UNSIGNED(ADDR_WIDTH-1 DOWNTO 0);
--	SIGNAL	wr_addr_s				:	UNSIGNED(ADDR_WIDTH-1 DOWNTO 0);
--	SIGNAL	wr_addr_next			:	UNSIGNED(ADDR_WIDTH-1 DOWNTO 0);
--	SIGNAL 	inc_counter_wr_s		:	STD_LOGIC;
--	SIGNAL 	clr_counter_wr_s		:	STD_LOGIC;
	
	SIGNAL 	clr_n_s					:	STD_LOGIC;
	SIGNAL 	clr_j_s					:	STD_LOGIC;
	SIGNAL 	clr_i_s					:	STD_LOGIC;
		
	
		
		
		
	SIGNAL 	inc_i_s					:	STD_LOGIC;
	SIGNAL	max_tick_i_s			:	STD_LOGIC;
	SIGNAL	max_tick_i_sero		:	STD_LOGIC;
	SIGNAL 	i_s						:	UNSIGNED(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	i_next					:	UNSIGNED(VOXEL_ADDR_WIDTH-1 DOWNTO 0); -- Outer loop counter
	
	SIGNAL 	inc_j_s					:	STD_LOGIC;
	SIGNAL	max_tick_j_s			:	STD_LOGIC;
	SIGNAL 	j_s						:	UNSIGNED(MAP_ADDR_WIDTH-1 DOWNTO 0); -- Inner loop counter
	SIGNAL	j_next					:	UNSIGNED(MAP_ADDR_WIDTH-1 DOWNTO 0);
	
	SIGNAL	en_compare_s				:	STD_LOGIC;
	SIGNAL	ready_compare_s			:	STD_LOGIC;
	SIGNAL	en_map_size_reg_s			:	STD_LOGIC;
	SIGNAL	update_map_size_reg_s	:	STD_LOGIC;
	
	SIGNAL	ready_sc2f_x				:	STD_LOGIC;
	SIGNAL	ready_sc2f_y				:	STD_LOGIC;
	SIGNAL	ready_sc2f_z				:	STD_LOGIC;
	SIGNAL	ready_sc2f_s				:	STD_LOGIC;
	SIGNAL	en_sc2f_s					:	STD_LOGIC;
	SIGNAL	map_full						:	STD_LOGIC;
	
	SIGNAL	voxel_x_point_float_s	:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	voxel_y_point_float_s	:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	SIGNAL	voxel_z_point_float_s	:	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
	
BEGIN
	--========================================
	--					Registers 
	--========================================
	voxel_size_adjust: ENTITY work.int_adder
	GENERIC	MAP(	N			=>	VOXEL_ADDR_WIDTH)
	PORT MAP	(		A			=>	voxel_size,
						B			=>	MINUS_ONE_BIN(VOXEL_ADDR_WIDTH-1 DOWNTO 0),
						result	=>	voxel_size_temp_s);
	
	quadrant_size_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	VOXEL_ADDR_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	strobe,
							syn_clr				=>	'0',
							d						=>	voxel_size_temp_s,
							q						=>	voxel_size_reg);
	
	map_size_adjust: ENTITY work.int_adder
	GENERIC	MAP(	N			=>	MAP_ADDR_WIDTH)
	PORT MAP	(		A			=>	map_size,
						B			=>	MINUS_ONE_BIN(MAP_ADDR_WIDTH-1 DOWNTO 0),
						result	=>	map_size_temp_s);
	
	en_map_size_reg_s <= update_map_size_reg_s OR strobe; 
	
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
						dataa				=>	voxel_point(X_MSB DOWNTO X_LSB),
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
						dataa				=>	voxel_point(Y_MSB DOWNTO Y_LSB),
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
						dataa				=>	voxel_point(Z_MSB DOWNTO Z_LSB),
						result			=>	voxel_z_point_float_s,
						data_ready		=>	ready_sc2f_z,
						busy				=>	OPEN);
	
	-- Ready Logic
	ready_sc2f_s	<=	ready_sc2f_x AND ready_sc2f_y AND ready_sc2f_z;
	
	
	
	
	map_size_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	MAP_ADDR_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	en_map_size_reg_s,
							syn_clr				=>	'0',
							d						=>	map_size,
							q						=>	map_size_reg);

	voxel_X_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	ready_sc2f_x,
							syn_clr				=>	'0',
							d						=>	voxel_x_point_float_s,
							q						=>	voxel_point_x_reg);
	
	voxel_Y_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	ready_sc2f_y,
							syn_clr				=>	'0',
							d						=>	voxel_y_point_float_s,
							q						=>	voxel_point_y_reg);
						
	voxel_Z_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	ready_sc2f_z,
							syn_clr				=>	'0',
							d						=>	voxel_z_point_float_s,
							q						=>	voxel_point_z_reg);
							
	j_X_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	en_J_s,
							syn_clr				=>	'0',
							d						=>	map_point(X_MSB DOWNTO X_LSB),
							q						=>	j_point_x_reg);
	
	j_Y_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	en_J_s,
							syn_clr				=>	'0',
							d						=>	map_point(Y_MSB DOWNTO Y_LSB),
							q						=>	j_point_y_reg);
						
	j_Z_register: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	DATA_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	en_J_s,
							syn_clr				=>	'0',
							d						=>	map_point(Z_MSB DOWNTO Z_LSB),
							q						=>	j_point_z_reg);
	
	new_map_point_s	<=	voxel_point_z_reg & voxel_point_y_reg & voxel_point_x_reg;
	
	--========================================
	--			Coordinate Comparator
	--========================================							
	neighbour_detector_module: ENTITY WORK.map_neighbour_detector
	GENERIC MAP	(	DATA_WIDTH			=>	DATA_WIDTH)			
	PORT MAP 	(	clk					=>	clk,
						rst					=>	rst,
						strobe				=>	en_compare_s,
						syn_clr				=>	'0',
						i_point_x			=>	voxel_point_x_reg,
						i_point_y			=>	voxel_point_y_reg,
						i_point_z			=>	voxel_point_z_reg,
						j_point_x			=>	j_point_x_reg,
						j_point_y			=>	j_point_y_reg,
						j_point_z			=>	j_point_z_reg,
						neighbour			=>	neighbour_flag_s,
						data_ready			=>	ready_compare_s);


	--========================================
	-- 		i Loop Counters logic
	--			read pointer from voxel
	--========================================
	-- Counter to read from voxel memory in outer loop (i)
		
	voxel_size_s	<=		unsigned(voxel_size_reg) WHEN voxel_size_reg > ZEROS(VOXEL_ADDR_WIDTH-1 DOWNTO 0) ELSE (OTHERS => '0');
	
	i_next 				<=		(OTHERS =>	'0') 	WHEN 	clr_i_s			=	'1' 	ELSE
									(OTHERS =>	'0') 	WHEN 	max_tick_i_s 	=	'1'	ELSE
									i_s + 1;
   max_tick_i_s	<=	'1' when (i_s = voxel_size_s) or (i_s > voxel_size_s) 	ELSE '0';
	max_tick_i_sero	<= '1' when voxel_size = ZEROS ELSE '0';
	map_full			<=	'1' when (map_size_reg= MAX_MAP_SIZE) or (map_size_reg > MAX_MAP_SIZE) ELSE '0';
	-- Increment Counter----------------------
	PROCESS(inc_i_s, clk, rst, clr_i_s)
	BEGIN
		IF (rst = '1') THEN
			i_s <= (OTHERS => '0');
		ELSIF(rising_edge(clk)) THEN
			IF (clr_i_s = '1') THEN
				i_s <= (OTHERS => '0');
			ELSIF (inc_i_s = '1') THEN
				i_s <= i_next;
			END IF;
		END IF;
	END PROCESS;
	
	--========================================
	-- 		j Loop Counters logic
	--	read and write pointer from and to map
	--========================================
	-- Counter to read from map in inner loop (j)
	map_size_s		<=		unsigned(map_size_reg);
	
	j_next 			<=		(OTHERS =>	'0') 	WHEN 	clr_j_s			=	'1' 	ELSE
								(OTHERS =>	'0') 	WHEN 	max_tick_j_s 	=	'1'	ELSE
								j_s + 1;
	
	max_tick_j_s	<=	'1' when j_s = map_size_s or j_s > map_size_s  	ELSE '0';
	

	-- Increment Counter----------------------
	PROCESS(inc_j_s, clk, rst, clr_j_s)
	BEGIN
		IF (rst = '1') THEN
			j_s <= (OTHERS => '0');
		ELSIF(rising_edge(clk)) THEN
			IF (clr_j_s = '1') THEN
				j_s <= (OTHERS => '0');
			ELSIF (inc_j_s = '1') THEN
				j_s <= j_next;
			END IF;
		END IF;
	END PROCESS;
	
	
	--========================================
	-- 						FSM
	--========================================
	
	-- Sequential Section ----------------------
	PROCESS(clk, rst)
	BEGIN
		IF (rst = '1') THEN
			pr_state <=idle;
		ELSIF(rising_edge(clk)) THEN
			pr_state <= nx_state;
		END IF;
	END PROCESS;
	
	-- Combinational Section ----------------------
	PROCESS (pr_state, strobe, neighbour_flag_s, max_tick_j_s, max_tick_i_s, ready_compare_s, ready_sc2f_s)
	BEGIN
		
		CASE pr_state IS
			---------------------------
			WHEN idle => -- Waiting for start_bit (strobe)
				rd_addr_from_voxel	<=	(OTHERS => '0'); 	-- No read operation from voxel
				rd_addr_from_map		<=	(OTHERS => '0'); 	-- No read operation from map
				wr_addr_to_map			<=	(OTHERS => '0');	-- No write operation to map
				map_new_point			<=	(OTHERS => '0');	-- No write operation to map
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'0';
				en_sc2f_s				<=	'0'; 	-- no convertion to float
				--en_CP_s					<=	'0'; 	-- no fetch i_point
				en_J_s					<=	'0';	-- no fetch j_point
				inc_i_s					<=	'0';	-- no increment i counter
				clr_i_s					<=	'1';	-- Clear i
				inc_j_s					<=	'0';	-- no increment j counter
				clr_j_s					<=	'1';	-- Clear j
				en_compare_s			<=	'0';	-- No comparison operation
				update_map_size_reg_s<=	'0';	-- No increment in map rd/wr pointer
				wr_en						<=	'0';	-- No write operation to map
				en_inc_size				<=	'0';	-- No increment of map size, stored in external register 
				data_ready				<= '0';
				IF (strobe = '1') THEN
					nx_state	<=	fetching_voxel_point;
				ELSE
					nx_state	<=	idle;
				END IF;
			---------------------------
			WHEN fetching_voxel_point => -- Fetch point from quadrant voxel memory, to make convolution with the points stored in map
				rd_addr_from_voxel	<=	STD_LOGIC_VECTOR(i_s); -- voxel_point,i counter used for adressing next data point
				rd_addr_from_map		<=	(OTHERS => '0'); 	
				wr_addr_to_map			<=	(OTHERS => '0');
				map_new_point			<=	(OTHERS => '0');
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'1';
				en_sc2f_s				<=	'0'; 	
				en_J_s					<=	'0';	
				inc_i_s					<=	'0';	
				clr_i_s					<=	'0';	
				inc_j_s					<=	'0';	
				clr_j_s					<=	'1';	-- Clear j
				en_compare_s			<=	'0';	
				update_map_size_reg_s<=	'0';	
				wr_en						<=	'0';	
				en_inc_size				<=	'0';
				data_ready				<= '0';
				IF (max_tick_i_sero = '1') THEN
						nx_state				<=	ready;	
				ELSE
					nx_state					<=	strobe_convert;
				END IF;
			---------------------------
			WHEN strobe_convert => -- 
				rd_addr_from_voxel	<=	(OTHERS => '0'); 
				rd_addr_from_map		<=	(OTHERS => '0'); 	
				wr_addr_to_map			<=	(OTHERS => '0');
				map_new_point			<=	(OTHERS => '0');
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'0';
				en_sc2f_s				<=	'1'; 	-- Strobe for convert to float
				en_J_s					<=	'0';	
				inc_i_s					<=	'0';	
				clr_i_s					<=	'0';	
				inc_j_s					<=	'0';	
				clr_j_s					<=	'1';	-- Clear j
				en_compare_s			<=	'0';	
				update_map_size_reg_s<=	'0';	
				wr_en						<=	'0';	
				en_inc_size				<=	'0';
				data_ready				<= '0';
				nx_state					<=	converting_to_float;
			---------------------------
			WHEN converting_to_float => -- Fetch point from quadrant voxel memory, to make convolution with the points stored in map
				rd_addr_from_voxel	<=	(OTHERS => '0'); -- voxel_point,i counter used for adressing next data point
				rd_addr_from_map		<=	(OTHERS => '0'); 	
				wr_addr_to_map			<=	(OTHERS => '0');
				map_new_point			<=	(OTHERS => '0');
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'0';
				en_sc2f_s				<=	'0';
				en_J_s					<=	'0';	
				inc_i_s					<=	'0';	
				clr_i_s					<=	'0';	
				inc_j_s					<=	'0';	
				clr_j_s					<=	'1';	-- Clear j
				en_compare_s			<=	'0';	
				update_map_size_reg_s<=	'0';	
				wr_en						<=	'0';	
				en_inc_size				<=	'0';
				data_ready				<= '0';
				IF (ready_sc2f_s = '1') THEN
					nx_state				<=	fetching_j_point;
				ELSE
					nx_state				<=	converting_to_float;
					END IF;
			--------------------------------
			WHEN fetching_j_point => -- Fetch point from map memory
				rd_addr_from_voxel	<=	(OTHERS => '0'); 
				rd_addr_from_map		<=	STD_LOGIC_VECTOR(j_s); -- j_point,j counter used for adressing next data point 	
				wr_addr_to_map			<=	(OTHERS => '0');
				map_new_point			<=	(OTHERS => '0');
				rd_en_from_map			<=	'1';
				rd_en_from_voxel		<=	'0';
				en_sc2f_s				<=	'0';
				en_J_s					<=	'0';	-- Register the data from map into j_point registers
				inc_i_s					<=	'0';	
				clr_i_s					<=	'0';	
				inc_j_s					<=	'0';	
				clr_j_s					<=	'0';	
				en_compare_s			<=	'0';	
				update_map_size_reg_s<=	'0';	
				wr_en						<=	'0';	
				en_inc_size				<=	'0';	
				data_ready				<= '0';
				nx_state					<=	reg_j_point;
			--------------------------------
			WHEN reg_j_point => -- Fetch point reg_j_point map memory
				rd_addr_from_voxel	<=	(OTHERS => '0'); 
				rd_addr_from_map		<=	(OTHERS => '0');
				wr_addr_to_map			<=	(OTHERS => '0');
				map_new_point			<=	(OTHERS => '0');
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'0';
				en_sc2f_s				<=	'0';
				en_J_s					<=	'1';	-- Register the data from map into j_point registers
				inc_i_s					<=	'0';	
				clr_i_s					<=	'0';	
				inc_j_s					<=	'0';	
				clr_j_s					<=	'0';	
				en_compare_s			<=	'0';	
				update_map_size_reg_s<=	'0';	
				wr_en						<=	'0';	
				en_inc_size				<=	'0';	
				data_ready				<= '0';
				nx_state					<=	strobe_compare;
			--------------------------------
			WHEN strobe_compare => 
				rd_addr_from_voxel	<=	(OTHERS => '0'); 
				rd_addr_from_map		<=	(OTHERS => '0');
				wr_addr_to_map			<=	(OTHERS => '0');
				map_new_point			<=	(OTHERS => '0');
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'0';
				en_sc2f_s				<=	'0';
				en_J_s					<=	'0';	-- Register the data from map into j_point registers
				inc_i_s					<=	'0';	
				clr_i_s					<=	'0';	
				inc_j_s					<=	'0';	
				clr_j_s					<=	'0';	
				en_compare_s			<=	'1';	 --Strobe comparing points
				update_map_size_reg_s<=	'0';	
				wr_en						<=	'0';	
				en_inc_size				<=	'0';	
				data_ready				<= '0';
				nx_state					<=	comparing_points;
			---------------------------
			WHEN comparing_points => 
				rd_addr_from_voxel	<=	(OTHERS => '0'); 
				rd_addr_from_map		<=	(OTHERS => '0'); 
				wr_addr_to_map			<=	(OTHERS => '0');
				map_new_point			<=	(OTHERS => '0');
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'0';	
				en_sc2f_s				<=	'0';
				en_J_s					<=	'0';	
				inc_i_s					<=	'0';	
				clr_i_s					<=	'0';	
				inc_j_s					<=	'0';	
				clr_j_s					<=	'0';	
				en_compare_s			<=	'0';	-- Enable 	
				update_map_size_reg_s<=	'0';	
				wr_en						<=	'0';	
				en_inc_size				<=	'0';
				data_ready				<= '0';
				IF (ready_compare_s = '1') THEN --Finisihed comparision
					IF (neighbour_flag_s ='0') THEN -- Point is not in the map
						IF(max_tick_j_s = '1') THEN -- last point from map was compared. The voxel point is new in the map
							nx_state		<=	inc_map_size;
						ELSE
							nx_state		<=	inc_j;
						end if;
					ELSE -- Point is already in the map. Update with last sensor reading
						nx_state			<=	write_current_point;
					END IF;
				ELSE
					nx_state				<=	comparing_points;
				END IF;
			---------------------------
			WHEN inc_map_size => -- Incement map size in register outside this module
				rd_addr_from_voxel	<=	(OTHERS => '0'); 
				rd_addr_from_map		<=	(OTHERS => '0'); 
				wr_addr_to_map			<=	(OTHERS => '0');
				map_new_point			<=	(OTHERS => '0');
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'0';
				en_sc2f_s				<=	'0';
				en_J_s					<=	'0';	
				inc_i_s					<=	'0';	
				clr_i_s					<=	'0';	
				inc_j_s					<=	'0';	
				clr_j_s					<=	'0';	
				en_compare_s			<=	'0';	
				update_map_size_reg_s<=	'0';	
				wr_en						<=	'0';	
				en_inc_size				<=	'1'; -- Incremet map size register	
				data_ready				<= '0';
				nx_state					<=	update_map_size_reg;
			---------------------------
			WHEN update_map_size_reg => -- Update map_size_reg with map_size-1 
				rd_addr_from_voxel	<=	(OTHERS => '0'); 
				rd_addr_from_map		<=	(OTHERS => '0'); 
				wr_addr_to_map			<=	(OTHERS => '0');
				map_new_point			<=	(OTHERS => '0');
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'0';
				en_sc2f_s				<=	'0';
				en_J_s					<=	'0';	
				inc_i_s					<=	'0';	
				clr_i_s					<=	'0';	
				inc_j_s					<=	'0';	
				clr_j_s					<=	'0';	
				en_compare_s			<=	'0';	
				update_map_size_reg_s<=	'1';	-- Update map_size_reg with map_size-1	
				wr_en						<=	'0';	
				en_inc_size				<=	'0';
				data_ready				<= '0';		
				nx_state					<=	write_new_point;
			---------------------------
			WHEN write_new_point => -- Write current voxel point in map(map_size_reg)
				rd_addr_from_voxel	<=	(OTHERS => '0'); 
				rd_addr_from_map		<=	(OTHERS => '0'); 
				wr_addr_to_map			<=	map_size_reg;	--curent size pointing to next available position
				map_new_point			<=	new_map_point_s; -- write the new point in the map
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'0';
				en_sc2f_s				<=	'0';
				en_J_s					<=	'0';	
				inc_i_s					<=	'0';	
				clr_i_s					<=	'0';	
				inc_j_s					<=	'0';	
				clr_j_s					<=	'0';	
				en_compare_s			<=	'0';	
				update_map_size_reg_s<=	'0';	
				wr_en						<=	'1'; -- wr_en for map memory	
				en_inc_size				<=	'0';
				data_ready				<= '0';
				nx_state				<=	wait_new_point;
						---------------------------
			WHEN wait_new_point => -- Write current voxel point in map(map_size_reg)
				rd_addr_from_voxel	<=	(OTHERS => '0'); 
				rd_addr_from_map		<=	(OTHERS => '0'); 
				wr_addr_to_map			<=	map_size_reg;	--curent size pointing to next available position
				map_new_point			<=	new_map_point_s; -- write the new point in the map
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'0';
				en_sc2f_s				<=	'0';
				en_J_s					<=	'0';	
				inc_i_s					<=	'0';	
				clr_i_s					<=	'0';	
				inc_j_s					<=	'0';	
				clr_j_s					<=	'0';	
				en_compare_s			<=	'0';	
				update_map_size_reg_s<=	'0';	
				wr_en						<=	'1'; -- wr_en for map memory	
				en_inc_size				<=	'0';
				data_ready				<= '0';
				IF (max_tick_i_s = '1') THEN
					nx_state				<=	ready;
				ELSE
					nx_state				<=	inc_i;
				END IF;	
			---------------------------
			WHEN inc_i => -- Increment i counter
				rd_addr_from_voxel	<=	(OTHERS => '0'); 
				rd_addr_from_map		<=	(OTHERS => '0'); 
				wr_addr_to_map			<=	(OTHERS => '0');
				map_new_point			<=	(OTHERS => '0');
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'0';
				en_sc2f_s				<=	'0';
				en_J_s					<=	'0';	
				inc_i_s					<=	'1';	-- increment i counter
				clr_i_s					<=	'0';	
				inc_j_s					<=	'0';	
				clr_j_s					<=	'0';	
				en_compare_s			<=	'0';	
				update_map_size_reg_s<=	'0';	
				wr_en						<=	'0';	
				en_inc_size				<=	'0';	
				data_ready				<= '0';
				IF(max_tick_i_s = '1') THEN -- last point from map was compared. The voxel point is new in the map
					nx_state		<=	ready;
				ELSE
					nx_state		<=	fetching_voxel_point;
				end if;
			---------------------------
			WHEN inc_j => -- Increment j counter
				rd_addr_from_voxel	<=	(OTHERS => '0'); 
				rd_addr_from_map		<=	(OTHERS => '0'); 
				wr_addr_to_map			<=	(OTHERS => '0');
				map_new_point			<=	(OTHERS => '0');
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'0';
				en_sc2f_s				<=	'0';
				en_J_s					<=	'0';	
				inc_i_s					<=	'0';	
				clr_i_s					<=	'0';	
				inc_j_s					<=	'1';	-- increment j counter
				clr_j_s					<=	'0';	
				en_compare_s			<=	'0';	
				update_map_size_reg_s<=	'0';	
				wr_en						<=	'0';	
				en_inc_size				<=	'0';		
				data_ready				<= '0';
				IF(max_tick_j_s = '1') THEN -- last point from map was compared. The voxel point is new in the map
					nx_state		<=	inc_map_size;
				ELSE
					nx_state		<=	fetching_j_point;
				end if;
			---------------------------
			WHEN write_current_point => -- Write current voxel point in map(map_size_reg)
				rd_addr_from_voxel	<=	(OTHERS => '0'); 
				rd_addr_from_map		<=	(OTHERS => '0'); 
				wr_addr_to_map			<=	std_logic_vector(j_s);	--curent j pointing to position to be updated
				map_new_point			<=	new_map_point_s; -- update map(j) with current reading
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'0';
				en_sc2f_s				<=	'0';
				en_J_s					<=	'0';	
				inc_i_s					<=	'0';	
				clr_i_s					<=	'0';	
				inc_j_s					<=	'0';	
				clr_j_s					<=	'0';	
				en_compare_s			<=	'0';	
				update_map_size_reg_s<=	'0';	
				wr_en						<=	'1'; -- wr_en for map memory	
				en_inc_size				<=	'0';
				data_ready				<= '0';
			   nx_state					<=	wait_current_point;
			---------------------------
			WHEN wait_current_point => -- Write current voxel point in map(map_size_reg)
				rd_addr_from_voxel	<=	(OTHERS => '0'); 
				rd_addr_from_map		<=	(OTHERS => '0'); 
				wr_addr_to_map			<=	std_logic_vector(j_s);	--curent j pointing to position to be updated
				map_new_point			<=	new_map_point_s; -- update map(j) with current reading
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'0';
				en_sc2f_s				<=	'0';
				en_J_s					<=	'0';	
				inc_i_s					<=	'0';	
				clr_i_s					<=	'0';	
				inc_j_s					<=	'0';	
				clr_j_s					<=	'0';	
				en_compare_s			<=	'0';	
				update_map_size_reg_s<=	'0';	
				wr_en						<=	'1'; -- wr_en for map memory	
				en_inc_size				<=	'0';
				data_ready				<= '0';
				IF (max_tick_i_s = '1') THEN
					nx_state				<=	ready;
				ELSE
					nx_state				<=	inc_i;
				END IF;	
			---------------------------
			WHEN ready => -- ready operation
				rd_addr_from_voxel	<=	(OTHERS => '0'); 
				rd_addr_from_map		<=	(OTHERS => '0'); 
				wr_addr_to_map			<=	(OTHERS => '0');
				map_new_point			<=	(OTHERS => '0');
				rd_en_from_map			<=	'0';
				rd_en_from_voxel		<=	'0';
				en_sc2f_s				<=	'0';
				en_J_s					<=	'0';	
				inc_i_s					<=	'0';	
				clr_i_s					<=	'0';	
				inc_j_s					<=	'0';	
				clr_j_s					<=	'0';	
				en_compare_s			<=	'0';	
				update_map_size_reg_s<=	'0';	
				wr_en						<=	'0';	
				en_inc_size				<=	'0';
				data_ready				<= '1'; -- Data ready
				nx_state					<=	idle;
			---------------------------
			END CASE;
	END PROCESS;
	
END ARCHITECTURE;
	