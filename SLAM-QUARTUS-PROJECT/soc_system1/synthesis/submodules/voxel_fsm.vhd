-- altera vhdl_input_version vhdl_2008
------------------------------------------------------------------------
--						voxel_fsm
-- Date: 2020-10-25
-- Version: 1.0 
-- Description:
-- Controls the voxel algorithm over a point cloud. 
------------------------------------------------------------------------
------------------------------------------------------------------------
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	USE ieee.std_logic_unsigned.all;
	USE ieee.numeric_std.all;
LIBRARY WORK;
	USE work.my_package.all;
------------------------------------------------------------------------
ENTITY voxel_fsm IS
	PORT 	(		clk					: 	IN 	STD_LOGIC;
					rst					: 	IN 	STD_LOGIC;
					strobe				:	IN		STD_LOGIC;-- Start bit
					quadrant_size		:	IN		STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);--Used to control de loops.
					neighbour_flag		:	IN		STD_LOGIC;-- Bit used to detec if two points are neighbours and belong to the same voxel cell
					voxel_full			:	IN		STD_LOGIC;-- Bit used to detec if voxel memroy was filled.
					rd_en					:	OUT	STD_LOGIC;-- enable signal for reading quadrant memory
					rd_add				:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0); -- read address from point cloud
					wr_addr				:	OUT	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0); -- write address to voxel memory
					n						:	OUT	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0); -- ammount of neighbours in a voxel cell to calculate centroid
					wr_en					:	OUT	STD_LOGIC;-- enable signal for writing voxel memory
					en_CR					:	OUT	STD_LOGIC;-- enable signal for current_point register
					en_J					:	OUT	STD_LOGIC;-- enable signal for j_point register
					en_accum				:	OUT	STD_LOGIC;-- enable signal for accum register
					sel_accum			:	OUT	STD_LOGIC;-- '0'=>current_point, '1'=>accum+j_point 
					en_size				:	OUT	STD_LOGIC;-- enable signal for voxel size register 
					data_ready			:	OUT	STD_LOGIC);
					
END ENTITY;
---------------------------------------------------------
ARCHITECTURE fsm OF voxel_fsm IS 
		TYPE state IS (	idle, fetching_current_point, reg_current_point, inc_i, init_new_voxel_cell, 
								fetching_j_point, reg_j_point, inc_j, calc_dist, new_neighbour, dividing, 
								write_voxel,wait_write, inc_voxel_size, register_size, ready); 
		
		SIGNAL 	pr_state					: 	state;
		SIGNAL 	nx_state					: 	state;
		SIGNAL	quadrant_size_reg		:	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
		SIGNAL	quadrant_size_s		:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
		SIGNAL	quadrant_size_temp_s	:	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
				
		
		
		SIGNAL	rd_addr_s				:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
		SIGNAL	rd_addr_next			:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
		SIGNAL 	inc_counter_wr_s		:	STD_LOGIC;
		SIGNAL 	clr_counter_wr_s		:	STD_LOGIC;
		SIGNAL 	clr_n_s					:	STD_LOGIC;
		SIGNAL 	clr_j_s					:	STD_LOGIC;
		SIGNAL 	clr_i_s					:	STD_LOGIC;
		
		SIGNAL	wr_addr_s				:	UNSIGNED(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
		SIGNAL	wr_addr_next			:	UNSIGNED(VOXEL_ADDR_WIDTH-1 DOWNTO 0);

		
		
		
		SIGNAL 	inc_i_s					:	STD_LOGIC;
		SIGNAL	max_tick_i_s			:	STD_LOGIC;
		SIGNAL	max_tick_i_sero		:	STD_LOGIC;
		SIGNAL 	i_s						:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
		SIGNAL	i_next					:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0); -- Outer loop counter
		
		SIGNAL 	inc_j_s					:	STD_LOGIC;
		SIGNAL	max_tick_j_s			:	STD_LOGIC;
		SIGNAL 	j_s						:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0); -- Inner loop counter
		SIGNAL	j_next					:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
		
		SIGNAL 	inc_n_s					:	STD_LOGIC;
		SIGNAL 	n_s						:	UNSIGNED(DATA_WIDTH-1 DOWNTO 0); --Keeps track of the ammount of neighbour points in a voxel
		SIGNAL	n_next					:	UNSIGNED(DATA_WIDTH-1 DOWNTO 0); 
		
		SIGNAL	flags						:	STD_LOGIC_VECTOR(2**QUADRANT_ADDR_WIDTH-1 DOWNTO 0); --Flags to keep track of point already filtered by the algorithm
		SIGNAL	index_s					:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0); -- Used to index individual bits of flag vector
		SIGNAL	index_int				:	INTEGER; -- Used to write individual bits of flag vector
		SIGNAL	clr_flags				:	STD_LOGIC; -- clr for the falgs bits
		SIGNAL	set_flags				:	STD_LOGIC; -- set flags(index_int) bit

BEGIN
	--========================================
	--					Register input	
	--========================================
	adder_size_adjust: ENTITY work.int_adder
	GENERIC	MAP(	N			=>	QUADRANT_ADDR_WIDTH)
	PORT MAP	(		A			=>	quadrant_size,
						B			=>	MINUS_ONE_BIN(QUADRANT_ADDR_WIDTH-1 DOWNTO 0),
						result	=>	quadrant_size_temp_s);
						
	regSize: PROCESS(strobe, clk, rst)
	BEGIN
		IF (rst = '1') THEN
			quadrant_size_reg <= (OTHERS => '0');
		ELSIF(rising_edge(clk)) THEN
			IF (strobe = '1') THEN
				quadrant_size_reg <= quadrant_size_temp_s;
			END IF;
		END IF;
	END PROCESS;
	

	--========================================
	-- 		WRITE Counters logic
	--========================================
	-- Counter used as write_address to Voxel memory
	wr_addr_next 	<=		(OTHERS =>	'0') 	WHEN 	clr_counter_wr_s	='1' ELSE
								wr_addr_s + 1;

	-- Increment Counter----------------------
	PROCESS(inc_counter_wr_s, clk, rst, clr_counter_wr_s)
	BEGIN
		IF (rst = '1') THEN
			wr_addr_s <= (OTHERS => '0');
		ELSIF(rising_edge(clk)) THEN
			IF (clr_counter_wr_s = '1') THEN
				wr_addr_s <= (OTHERS => '0');
			ELSIF (inc_counter_wr_s = '1') THEN
				wr_addr_s <= wr_addr_next;
			END IF;
		END IF;
	END PROCESS;
	
	
	--========================================
	-- 		i Loop Counters logic
	--========================================
	-- Counter to read from point Cloud in outer loop (i)
	

					
	quadrant_size_s	<=		unsigned(quadrant_size_reg) when quadrant_size > ZEROS ELSE (OTHERS =>	'0');
	
	i_next 				<=		(OTHERS =>	'0') 	WHEN 	clr_i_s			=	'1' 	ELSE
									(OTHERS =>	'0') 	WHEN 	max_tick_i_s 	=	'1'	ELSE
									i_s + 1;
	max_tick_i_s	<=	'1' when (i_s = quadrant_size_s) or (i_s > quadrant_size_s) 	ELSE '0';
	max_tick_i_sero	<= '1' when quadrant_size = ZEROS ELSE '0';
	
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
	--========================================
	-- Counter to read from point Cloud in inner loop (j)
	j_next 				<=		(OTHERS =>	'0') 	WHEN 	clr_j_s			=	'1' 	ELSE
									(OTHERS =>	'0') 	WHEN 	max_tick_j_s 	=	'1'	ELSE
									j_s + 1;
	max_tick_j_s	<=	'1' when (j_s = quadrant_size_s) or (j_s > quadrant_size_s)	ELSE '0';
	

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
	-- 		n Counter logic
	--========================================
	-- Used to keep track of the number of
	-- neighbour points discvored by the filter
	-- related to the current point. Used to
	-- find the centroid of the voxel when 
	-- dividing the accum by n.
	
	n_next 	<=		(OTHERS =>	'0') 	WHEN 	clr_n_s	='1' ELSE
						n_s + 1;

	-- Increment Counter----------------------
	PROCESS(inc_n_s, clk, rst, clr_n_s)
	BEGIN
		IF (rst = '1') THEN
			n_s <= (OTHERS => '0');
		ELSIF(rising_edge(clk)) THEN
			IF (clr_n_s = '1') THEN
				n_s <= (OTHERS => '0');
			ELSIF (inc_n_s = '1') THEN
				n_s <= n_next;
			END IF;
		END IF;
	END PROCESS;
	
	--====================================
	--				FLAGS REGISTER
	--====================================	
	-- Flags vector is used to keep track of the points in the point cloud
	-- that were already included in a voxel cell. 
	-- '0' => point not discovered
	-- '1' => point already discovered and included in voxel filter.
	index_int	<=	to_integer(index_s);
	reg_flags: PROCESS(set_flags,clr_flags, clk, rst)
	BEGIN
		IF (rst = '1') THEN
			flags	<= (OTHERS => '0');
		ELSIF(rising_edge(clk)) THEN
			IF (clr_flags = '1') THEN
				flags	<= (OTHERS => '0');
			ELSIF (set_flags = '1') THEN
				flags(index_int) <= '1';
			END IF;
		END IF;
	END PROCESS;
	
	--========================================
	-- 				OUTPUTS
	--========================================
	n	<= STD_LOGIC_VECTOR(n_s);
	
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
	PROCESS (pr_state, strobe, neighbour_flag, max_tick_j_s, max_tick_i_s, flags, voxel_full)
	BEGIN
		
		CASE pr_state IS
			---------------------------
			WHEN idle => -- Waiting for start_bit (strobe)
				rd_add				<=	(OTHERS => '0'); 	--	No read operation
				wr_addr				<=	(OTHERS => '0'); 	-- No write operation
				rd_en					<=	'0';					--	No READ operation
				wr_en					<=	'0';					--	No write operation
				en_CR					<=	'0';					--	No reading of current Point
				en_J					<=	'0';					--	No reading of j_Point
				en_accum				<=	'0';					--	No accum operation
				sel_accum			<=	'0';					-- Current point as input
				data_ready			<=	'0';					-- Data NOT ready
				clr_counter_wr_s	<=	'1';					-- Clear write counter
				clr_n_s				<=	'1';					-- Clear n
				clr_j_s				<=	'1';					-- Clear j		
				clr_i_s				<=	'1';					-- Clear i		
				inc_counter_wr_s	<=	'0';					-- No increment operation
				inc_i_s				<=	'0';					-- No increment operation
				inc_j_s				<=	'0';					-- No increment operation
				inc_n_s				<=	'0';					-- No increment operation
				clr_flags			<=	'1';					-- Clear flags vector
				set_flags			<= '0';					-- No seting a bit operation
				en_size				<= '0';					--	No write operation
				index_s				<= (OTHERS => '0');	-- Index in flags set to zero
				IF (strobe = '1') THEN
					nx_state	<=	fetching_current_point;
				ELSE
					nx_state	<=	idle;
				END IF;
			---------------------------
			WHEN fetching_current_point => -- Fetch point from the point cloud, to make convolution with the rest of points
				rd_add				<=	STD_LOGIC_VECTOR(i_s); -- current_point,i counter used for adressing next data point
				wr_addr				<=	(OTHERS => '0'); 	
				wr_en					<=	'0';					
				rd_en					<=	'1'; -- rd_en from quadrant
				en_CR					<=	'0'; 
				en_J					<=	'0';					
				en_accum				<=	'0';					
				sel_accum			<=	'0';					
				data_ready			<=	'0';					
				clr_counter_wr_s	<=	'0';					
				clr_n_s				<=	'0';					
				clr_j_s				<=	'0';					
				clr_i_s				<=	'0';					
				inc_counter_wr_s	<=	'0';					
				inc_i_s				<=	'0';					
				inc_j_s				<=	'0';					
				inc_n_s				<=	'0';
				clr_flags			<=	'0';					
				set_flags			<= '0';
				en_size				<= '0';					
				index_s				<= (OTHERS => '0');
				nx_state	<=	reg_current_point;
			---------------------------
			WHEN reg_current_point => -- Fetch point from the point cloud, to make convolution with the rest of points
				rd_add				<=	(OTHERS => '0'); -- current_point,i counter used for adressing next data point
				wr_addr				<=	(OTHERS => '0'); 	
				wr_en					<=	'0';					
				rd_en					<=	'0';
				en_CR					<=	'1'; -- Register the data from point cloud into current_point register
				en_J					<=	'0';					
				en_accum				<=	'0';					
				sel_accum			<=	'0';					
				data_ready			<=	'0';					
				clr_counter_wr_s	<=	'0';					
				clr_n_s				<=	'0';					
				clr_j_s				<=	'0';					
				clr_i_s				<=	'0';					
				inc_counter_wr_s	<=	'0';					
				inc_i_s				<=	'0';					
				inc_j_s				<=	'0';					
				inc_n_s				<=	'0';
				clr_flags			<=	'0';					
				set_flags			<= '0';
				en_size				<= '0';					
				index_s				<= (OTHERS => '0');
				IF (max_tick_i_sero = '1') THEN 	-- Exit Condition for a last point that was already discovered
						nx_state	<=	register_size;
				ELSE
						IF (flags(to_integer(i_s)) = '1') THEN -- i_point was already discovered and included in voxel
							nx_state	<=	inc_i;	-- Increment i counter to fetch next point
						ELSE
							nx_state	<=	init_new_voxel_cell;-- Point is a new voxel
						END IF;
				END IF;
			---------------------------
			WHEN inc_i => 									-- Increment counter i in outer loop
				rd_add				<=	(OTHERS => '0'); 	
				wr_addr				<=	(OTHERS => '0'); 	
				rd_en					<=	'0';
				wr_en					<=	'0';					
				en_CR					<=	'0';					
				en_J					<=	'0';					
				en_accum				<=	'0';					
				sel_accum			<=	'0';					
				data_ready			<=	'0';					
				clr_counter_wr_s	<=	'0';					
				clr_n_s				<=	'0';					
				clr_j_s				<=	'0';					
				clr_i_s				<=	'0';							
				inc_counter_wr_s	<=	'0';					
				inc_i_s				<=	'1';	-- i_s++				
				inc_j_s				<=	'0';					
				inc_n_s				<=	'0';					
				clr_flags			<=	'0';					
				set_flags			<= '0';
				en_size				<= '0';					
				index_s				<= (OTHERS => '0');
				IF (max_tick_i_s = '1') THEN 	-- i_point was the last point to be fetched
						nx_state	<=	register_size;  -- Register the voxel size
				ELSE
						nx_state	<=	fetching_current_point;	-- Increment i counter to fecth next point
				END IF;
			---------------------------
			WHEN inc_j => 									-- Increment counter j in inner loop
				rd_add				<=	(OTHERS => '0'); 	
				wr_addr				<=	(OTHERS => '0'); 	
				rd_en					<=	'0';
				wr_en					<=	'0';					
				en_CR					<=	'0';					
				en_J					<=	'0';					
				en_accum				<=	'0';					
				sel_accum			<=	'0';					
				data_ready			<=	'0';					
				clr_counter_wr_s	<=	'0';					
				clr_n_s				<=	'0';					
				clr_j_s				<=	'0';					
				clr_i_s				<=	'0';							
				inc_counter_wr_s	<=	'0';					
				inc_i_s				<=	'0';	
				inc_j_s				<=	'1';	-- j_s++					
				inc_n_s				<=	'0';					
				clr_flags			<=	'0';					
				set_flags			<= '0';
				en_size				<= '0';					
				index_s				<= (OTHERS => '0');
				IF (max_tick_j_s = '1') THEN 	-- j_point was the last point to be fetched
					nx_state	<=	dividing;  -- Calculate centroid
				ELSE
					nx_state	<=	fetching_j_point;
				END IF;					
			---------------------------
			WHEN inc_voxel_size => 		-- Increment write_addr counter 
				rd_add				<=	(OTHERS => '0'); 	
				wr_addr				<=	(OTHERS => '0'); 	
				rd_en					<=	'0';
				wr_en					<=	'0';					
				en_CR					<=	'0';					
				en_J					<=	'0';					
				en_accum				<=	'0';					
				sel_accum			<=	'0';					
				data_ready			<=	'0';					
				clr_counter_wr_s	<=	'0';					
				clr_n_s				<=	'1';					
				clr_j_s				<=	'0';					
				clr_i_s				<=	'0';							
				inc_counter_wr_s	<=	'1';	-- inc_counter_wr_s++			
				inc_i_s				<=	'0';	
				inc_j_s				<=	'0';						
				inc_n_s				<=	'0';					
				clr_flags			<=	'0';					
				set_flags			<= '0';
				en_size				<= '0';					
				index_s				<= (OTHERS => '0');
				IF (max_tick_i_s = '1') THEN 	-- i_point was the last point to be fetched
						nx_state	<=	register_size;  -- Register the voxel size
				ELSE
						nx_state	<=	inc_i;	-- Increment i counter to fecth next point
				END IF;
			---------------------------
			WHEN init_new_voxel_cell => --New voxel cell discovered. Set variables to start the convolution of current_point over the point cloud
				rd_add				<=	(OTHERS => '0'); 	
				wr_addr				<=	(OTHERS => '0'); 	
				rd_en					<=	'0';
				wr_en					<=	'0';					
				en_CR					<=	'0';					
				en_J					<=	'0';					
				en_accum				<=	'1';	--Write accum with first point
				sel_accum			<=	'0';	--Select the input port of accum register to current_point				
				data_ready			<=	'0';					
				clr_counter_wr_s	<=	'0';					
				clr_n_s				<=	'0';					
				clr_j_s				<=	'1'; 	--	Clear j counter to star new convolution
				clr_i_s				<=	'0';							
				inc_counter_wr_s	<=	'0';					
				inc_i_s				<=	'0';					
				inc_j_s				<=	'0';					
				inc_n_s				<=	'1';	-- Start count of points in the new voxel cell, n=1
				clr_flags			<=	'0';					
				set_flags			<= '1';	-- Set flag(i)
				en_size				<= '0';					
				index_s				<= i_s;
				nx_state				<=	fetching_j_point;
			---------------------------
			WHEN fetching_j_point => -- Fetch j_point from point cloud, to compare with the current_point
				rd_add				<=	STD_LOGIC_VECTOR(j_s); -- j_point, read counter for adressing next data point
				wr_addr				<=	(OTHERS => '0'); 	
				rd_en					<=	'1'; -- rd_en from quadrant memory
				wr_en					<=	'0';					
				en_CR					<=	'0';	
				en_J					<=	'0';	
				en_accum				<=	'0';		
				sel_accum			<=	'0';	
				data_ready			<=	'0';					
				clr_counter_wr_s	<=	'0';					
				clr_n_s				<=	'0';					
				clr_j_s				<=	'0';					
				clr_i_s				<=	'0';					
				inc_counter_wr_s	<=	'0';					
				inc_i_s				<=	'0';					
				inc_j_s				<=	'0';					
				inc_n_s				<=	'0';
				clr_flags			<=	'0';					
				set_flags			<= '0';
				en_size				<= '0';					
				index_s				<= (OTHERS => '0');
				nx_state	<=	reg_j_point;	-- Increment j counter to fetch next point
			---------------------------
			WHEN reg_j_point => -- Fetch j_point from point cloud, to compare with the current_point
				rd_add				<=	(OTHERS => '0'); -- j_point, read counter for adressing next data point
				wr_addr				<=	(OTHERS => '0'); 	
				rd_en					<=	'0';
				wr_en					<=	'0';					
				en_CR					<=	'0';	--	Register current point from point cloud
				en_J					<=	'1';	--	Register j_Point from point cloud
				en_accum				<=	'0';		
				sel_accum			<=	'1';	-- Select the input port of accum register to (accum + j_point) in case they belong to same voxel
				data_ready			<=	'0';					
				clr_counter_wr_s	<=	'0';					
				clr_n_s				<=	'0';					
				clr_j_s				<=	'0';					
				clr_i_s				<=	'0';					
				inc_counter_wr_s	<=	'0';					
				inc_i_s				<=	'0';					
				inc_j_s				<=	'0';					
				inc_n_s				<=	'0';
				clr_flags			<=	'0';					
				set_flags			<= '0';
				en_size				<= '0';					
				index_s				<= (OTHERS => '0');
				IF (flags(to_integer(j_s)) = '1') THEN -- j_point was already discovered and included in voxel
					nx_state	<=	inc_j;	-- Increment j counter to fetch next point
				ELSE
					nx_state	<=	calc_dist;-- j_point has not been discovered, verify distance with current_point	
				END IF;
			---------------------------
			WHEN calc_dist => -- Calculating the distance beteen current_point and j_point 
				rd_add				<=	(OTHERS => '0'); 
				wr_addr				<=	(OTHERS => '0'); 	
				rd_en					<=	'0';
				wr_en					<=	'0';					
				en_CR					<=	'0';					
				en_J					<=	'0';					
				en_accum				<=	'0';					
				sel_accum			<=	'1';	--Select the input port of accum register to (accum + j_point) in case they belong to same voxel
				data_ready			<=	'0';					
				clr_counter_wr_s	<=	'0';					
				clr_n_s				<=	'0';					
				clr_j_s				<=	'0';					
				clr_i_s				<=	'0';					
				inc_counter_wr_s	<=	'0';					
				inc_i_s				<=	'0';					
				inc_j_s				<=	'0';					
				inc_n_s				<=	'0';
				clr_flags			<=	'0';					
				set_flags			<= '0';
				en_size				<= '0';					
				index_s				<= j_s; -- Index in flags set to j
				IF(neighbour_flag = '1') THEN 	-- current_point and j_point belong to the same voxel cell
					nx_state	<=	new_neighbour;			
				ELSE-- increment j counter to fetch next point.	
					nx_state	<=	inc_j;	-- Increment j counter to fetch next point
				END IF;
			---------------------------	
			WHEN new_neighbour => --New neighbour vas discovered. Accum register is updated with the accummulated value of the neighbours coordinates
				rd_add				<=	(OTHERS => '0'); 	
				wr_addr				<=	(OTHERS => '0'); 	
				rd_en					<=	'0';
				wr_en					<=	'0';					
				en_CR					<=	'0';					
				en_J					<=	'0';					
				en_accum				<=	'1';	--Write accum with (accum + j_point)
				sel_accum			<=	'1';	--Select the input port of accum register to (accum + j_point)				
				data_ready			<=	'0';					
				clr_counter_wr_s	<=	'0';					
				clr_n_s				<=	'0';					
				clr_j_s				<=	'0'; 	
				clr_i_s				<=	'0';							
				inc_counter_wr_s	<=	'0';					
				inc_i_s				<=	'0';					
				inc_j_s				<=	'0';					
				inc_n_s				<=	'1';	-- Increment count of points in the new voxel cell
				clr_flags			<=	'0';					
				index_s				<= j_s;	-- Assign j to index to set the flag for j_point
				set_flags			<= '1';	-- Set flag(j)<='1'
				en_size				<= '0';					
				nx_state	<=	inc_j;	-- Increment j counter to fecth next point
			---------------------------
			WHEN dividing => -- Calculating centroids of the voxel cell. It represent a Wait state to compensate possible latency of the divisors
				rd_add				<=	(OTHERS => '0'); 
				wr_addr				<=	(OTHERS => '0'); 	
				rd_en					<=	'0';
				wr_en					<=	'0';					
				en_CR					<=	'0';					
				en_J					<=	'0';					
				en_accum				<=	'0';					
				sel_accum			<=	'1';	--Select the input port of accum register to (accum + j_point)
				data_ready			<=	'0';					
				clr_counter_wr_s	<=	'0';					
				clr_n_s				<=	'0';					
				clr_j_s				<=	'0';					
				clr_i_s				<=	'0';					
				inc_counter_wr_s	<=	'0';					
				inc_i_s				<=	'0';					
				inc_j_s				<=	'0';					
				inc_n_s				<=	'0';
				clr_flags			<=	'0';					
				set_flags			<= '0';
				en_size				<= '0';					
				index_s				<= (OTHERS => '0');
				IF (voxel_full = '1') THEN 	-- j_point was the last point to be fetched
					nx_state	<=	ready;  -- Register the voxel size
				ELSE
					nx_state				<=	write_voxel;
				END IF;
			---------------------------
			WHEN write_voxel => -- Write new centroid in the voxel memory
				rd_add				<=	(OTHERS => '0'); 
				wr_addr				<=	STD_LOGIC_VECTOR(wr_addr_s); 	--Write new centroid in voxel memory in awr_addr_s position
				rd_en					<=	'0';
				wr_en					<=	'1';	--wr_en for the voxel memory				
				en_CR					<=	'0';				
				en_J					<=	'0';					
				en_accum				<=	'0';					
				sel_accum			<=	'0';					
				data_ready			<=	'0';					
				clr_counter_wr_s	<=	'0';					
				clr_n_s				<=	'0';					
				clr_j_s				<=	'0';					
				clr_i_s				<=	'0';					
				inc_counter_wr_s	<=	'0';					
				inc_i_s				<=	'0';					
				inc_j_s				<=	'0';					
				inc_n_s				<=	'0';
				clr_flags			<=	'0';					
				set_flags			<= '0';
				en_size				<= '0';					
				index_s				<= (OTHERS => '0');
				nx_state				<=	wait_write;	-- Increment j counter to fecth next point
				---------------------------
			WHEN wait_write => -- Write new centroid in the voxel memory
				rd_add				<=	(OTHERS => '0'); 
				wr_addr				<=	STD_LOGIC_VECTOR(wr_addr_s); 	--Write new centroid in voxel memory in awr_addr_s position
				rd_en					<=	'0';
				wr_en					<=	'1';	--wr_en for the voxel memory				
				en_CR					<=	'0';				
				en_J					<=	'0';					
				en_accum				<=	'0';					
				sel_accum			<=	'0';					
				data_ready			<=	'0';					
				clr_counter_wr_s	<=	'0';					
				clr_n_s				<=	'0';					
				clr_j_s				<=	'0';					
				clr_i_s				<=	'0';					
				inc_counter_wr_s	<=	'0';					
				inc_i_s				<=	'0';					
				inc_j_s				<=	'0';					
				inc_n_s				<=	'0';
				clr_flags			<=	'0';					
				set_flags			<= '0';
				en_size				<= '0';					
				index_s				<= (OTHERS => '0');
				nx_state				<=	inc_voxel_size;	-- Increment j counter to fecth next point
			---------------------------
			WHEN register_size => --Registering the size of the voxel before ready state. A correction +1 must be done to adjust size
				rd_add				<=	(OTHERS => '0'); 
				wr_addr				<=	STD_LOGIC_VECTOR(wr_addr_s); --Output current Write address. Size is wr_addr+1. Addition occurs outside	
				rd_en					<=	'0';
				wr_en					<=	'0';					
				en_CR					<=	'0';	
				en_J					<=	'0';					
				en_accum				<=	'0';					
				sel_accum			<=	'0';					
				data_ready			<=	'0';					
				clr_counter_wr_s	<=	'0';					
				clr_n_s				<=	'0';					
				clr_j_s				<=	'0';					
				clr_i_s				<=	'0';					
				inc_counter_wr_s	<=	'0';					
				inc_i_s				<=	'0';					
				inc_j_s				<=	'0';					
				inc_n_s				<=	'0';
				clr_flags			<=	'0';					
				set_flags			<= '0';
				en_size				<= '1';	-- enable of voxel_size_register
				index_s				<= (OTHERS => '0');
				nx_state				<=	ready;
		---------------------------
			WHEN ready => --Issues done_tick
				rd_add				<=	(OTHERS => '0'); 
				wr_addr				<=	(OTHERS => '0'); 
				rd_en					<=	'0';
				wr_en					<=	'0';					
				en_CR					<=	'0';	
				en_J					<=	'0';					
				en_accum				<=	'0';					
				sel_accum			<=	'0';					
				data_ready			<=	'1';	--data ready
				clr_counter_wr_s	<=	'0';					
				clr_n_s				<=	'0';					
				clr_j_s				<=	'0';					
				clr_i_s				<=	'0';					
				inc_counter_wr_s	<=	'0';					
				inc_i_s				<=	'0';					
				inc_j_s				<=	'0';					
				inc_n_s				<=	'0';
				clr_flags			<=	'0';					
				set_flags			<= '0';
				en_size				<= '0';	
				index_s				<= (OTHERS => '0');
				nx_state				<=	idle;		
			---------------------------
			END CASE;
	END PROCESS;
	
END ARCHITECTURE;
	