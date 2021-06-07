-- altera vhdl_input_version vhdl_2008
------------------------------------------------------------------------
--						map_init_fsm
-- Date: 2020-12-10
-- Version: 1.0 
-- Description:
-- 

-- Note: wr_addr in this state is the map_size in map_handler
------------------------------------------------------------------------
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	USE ieee.numeric_std.all;
LIBRARY WORK;
	USE work.my_package.all;
-----------------------------------------------
ENTITY map_init_fsm IS
	PORT(		clk					: 	IN 	STD_LOGIC;
				rst					: 	IN 	STD_LOGIC;
				strobe				:	IN 	STD_LOGIC;
				ready_voxel			:	IN 	STD_LOGIC;
				ready_sc2f			:	IN 	STD_LOGIC;
				q1_size				:	IN		STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
				q2_size				:	IN		STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
				q3_size				:	IN		STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
				q4_size				:	IN		STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
				qsel					:	OUT	STD_LOGIC_VECTOR(1 DOWNTO 0);
				en_scale				:	OUT	STD_LOGIC;
				en_inc_size			:	OUT	STD_LOGIC;
				wr_en					:	OUT	STD_LOGIC;
				rd_en					:	OUT	STD_LOGIC;
				rd_addr				:	OUT	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
				data_ready			:	OUT	STD_LOGIC);
END ENTITY;
-----------------------------------------------
ARCHITECTURE fsm OF map_init_fsm IS
	TYPE state IS (idle, wait_for_voxel, fetching_point, reg_point_strobe_convert, converting2float, writing_mem, inc_counters, inc_quadrant, ready); 
	SIGNAL 	pr_state					: 	state;
	SIGNAL 	nx_state					: 	state;
	
	SIGNAL	q1_size_uns				:	UNSIGNED(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	q2_size_uns				:	UNSIGNED(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	q3_size_uns				:	UNSIGNED(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	q4_size_uns				:	UNSIGNED(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	
	SIGNAL	qsel_s					:	UNSIGNED(1 DOWNTO 0);
	SIGNAL	qsel_next				:	UNSIGNED(1 DOWNTO 0);
	SIGNAL 	clr_qsel_s				:	STD_LOGIC;
	SIGNAL 	inc_qsel_s				:	STD_LOGIC;
	
	SIGNAL	rd_addr_s				:	UNSIGNED(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	rd_addr_next			:	UNSIGNED(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL 	inc_rd_counter_s		:	STD_LOGIC;
	SIGNAL 	clr_rd_counter_s		:	STD_LOGIC;
	SIGNAL	max_tick_rd_s			:	STD_LOGIC;
	SIGNAL	max_tick_qsel_s		:	STD_LOGIC;

BEGIN
	--========================================
	-- Quadrant selector Counter logic
	--========================================
	qsel_next	 		<=		(OTHERS =>	'0') 	WHEN 	clr_qsel_s			='1' 		ELSE
									(OTHERS =>	'0') 	WHEN 	max_tick_qsel_s	='1'		ELSE
									qsel_s + 1;
		
	max_tick_qsel_s	<=		'1' when qsel_s = "11" 	ELSE '0';
	qsel					<=		std_logic_vector(qsel_s);
	
	
	-- Increment Counter ----------------------
	PROCESS(clk, rst, inc_qsel_s, clr_qsel_s)
	BEGIN
		IF (rst = '1') THEN
			qsel_s <= (OTHERS => '0');
		ELSIF(rising_edge(clk)) THEN
			IF	(clr_qsel_s = '1') THEN
				qsel_s <= (OTHERS => '0');
			ELSIF (inc_qsel_s = '1') THEN
				qsel_s <= qsel_next;
			END IF;
		END IF;
	END PROCESS;
	
	
	--========================================
	-- READ Counter logic
	--========================================
	q1_size_uns			<=		unsigned(q1_size)-1 WHEN q1_size > ZEROS(VOXEL_ADDR_WIDTH-1 DOWNTO 0) ELSE (OTHERS =>	'0');
	q2_size_uns			<=		unsigned(q2_size)-1 WHEN q2_size > ZEROS(VOXEL_ADDR_WIDTH-1 DOWNTO 0) ELSE (OTHERS =>	'0');
	q3_size_uns			<=		unsigned(q3_size)-1 WHEN q3_size > ZEROS(VOXEL_ADDR_WIDTH-1 DOWNTO 0) ELSE (OTHERS =>	'0');
	q4_size_uns			<=		unsigned(q4_size)-1 WHEN q4_size > ZEROS(VOXEL_ADDR_WIDTH-1 DOWNTO 0) ELSE (OTHERS =>	'0');
	
	-- Next count logic
	rd_addr_next 	<=		(OTHERS =>	'0') 	WHEN 	clr_rd_counter_s	='1' 		ELSE
								(OTHERS =>	'0') 	WHEN 	max_tick_rd_s		='1'		ELSE
								rd_addr_s + 1;
	
	-- Read Max tick logic
	-- Different max_tick conditions depending on which quadrant voxel is beoing read
	max_tick_rd_s	<=	'1' when rd_addr_s = q1_size_uns AND qsel_s = "00"		ELSE 
							'1' when rd_addr_s = q2_size_uns AND qsel_s = "01"		ELSE 
							'1' when rd_addr_s = q3_size_uns AND qsel_s = "10"		ELSE
							'1' when rd_addr_s = q4_size_uns AND qsel_s = "11"		ELSE 
							'0';
	
	-- Increment Counter ----------------------
	PROCESS(clk, rst, inc_rd_counter_s, clr_rd_counter_s)
	BEGIN
		IF (rst = '1') THEN
			rd_addr_s <= (OTHERS => '0');
		ELSIF(rising_edge(clk)) THEN
			IF	(clr_rd_counter_s = '1') THEN
				rd_addr_s <= (OTHERS => '0');
			ELSIF (inc_rd_counter_s = '1') THEN
				rd_addr_s <= rd_addr_next;
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
	PROCESS (pr_state, strobe, ready_voxel, ready_sc2f, max_tick_qsel_s, max_tick_rd_s)
	BEGIN
		CASE pr_state IS
			---------------------------
			WHEN idle =>
				clr_qsel_s			<=	'1';
				inc_qsel_s			<=	'0';
				clr_rd_counter_s	<=	'1';
				inc_rd_counter_s	<=	'0';
				rd_addr				<=	(OTHERS => '0');
				rd_en					<=	'0';
				wr_en					<=	'0';
				en_scale				<=	'0';
				en_inc_size			<=	'0';
				data_ready			<=	'0';
				IF (strobe = '1') THEN
					nx_state	<=	wait_for_voxel;
				ELSE
					nx_state	<=	idle;
				END IF;
			---------------------------
			WHEN wait_for_voxel =>
				clr_qsel_s			<=	'0';
				inc_qsel_s			<=	'0';
				clr_rd_counter_s	<=	'0';
				inc_rd_counter_s	<=	'0';
				rd_addr				<=	(OTHERS => '0');
				rd_en					<=	'0';
				wr_en					<=	'0';
				en_scale				<=	'0';
				en_inc_size			<=	'0';
				data_ready			<=	'0';
				IF (ready_voxel = '1') THEN
					nx_state	<=	fetching_point;
				ELSE
					nx_state	<=	wait_for_voxel;
				END IF;
			---------------------------
			WHEN fetching_point =>
				clr_qsel_s			<=	'0';
				inc_qsel_s			<=	'0';
				clr_rd_counter_s	<=	'0';
				inc_rd_counter_s	<=	'0';
				rd_addr				<=	STD_LOGIC_VECTOR(rd_addr_s); -- current read counter for adressing next fetch data point
				rd_en					<=	'1'; --rd_en from voxel
				wr_en					<=	'0';
				en_scale				<=	'0'; -- strobe for scale_convert2float module
				en_inc_size			<=	'0';
				data_ready			<=	'0';
				nx_state				<=	reg_point_strobe_convert; -- wait until data_ready from strobe for scale_convert2int module
			---------------------------
			WHEN reg_point_strobe_convert =>
				clr_qsel_s			<=	'0';
				inc_qsel_s			<=	'0';
				clr_rd_counter_s	<=	'0';
				inc_rd_counter_s	<=	'0';
				rd_addr				<=	STD_LOGIC_VECTOR(rd_addr_s);
				rd_en					<=	'0';
				wr_en					<=	'0';
				en_scale				<=	'1'; -- strobe for scale_convert2float module. Input point is registered inside scale_convert2float module.
				en_inc_size			<=	'0';
				data_ready			<=	'0';
				nx_state				<=	converting2float; -- wait until data_ready from strobe for scale_convert2int module
			---------------------------	
			WHEN converting2float =>
				clr_qsel_s			<=	'0';
				inc_qsel_s			<=	'0';
				clr_rd_counter_s	<=	'0';
				inc_rd_counter_s	<=	'0';
				rd_addr				<=	STD_LOGIC_VECTOR(rd_addr_s);
				wr_en					<=	'0';
				en_scale				<=	'0'; 
				en_inc_size			<=	'0';
				data_ready			<=	'0';
				IF (ready_sc2f = '1') THEN
					nx_state		<=	writing_mem;
				ELSE 
					nx_state		<=	converting2float;				
				END IF;
			---------------------------
			WHEN writing_mem =>
				clr_qsel_s			<=	'0';
				inc_qsel_s			<=	'0';
				clr_rd_counter_s	<=	'0';
				inc_rd_counter_s	<=	'0';
				rd_addr				<=	(OTHERS => '0'); -- current read counter for adressing next fetch data point
				wr_en					<=	'1';	-- write point in map
				en_scale				<=	'0'; 
				en_inc_size			<=	'0';
				data_ready			<=	'0';
				IF (max_tick_rd_s	=	'1') THEN -- Last point was fetched in current quadrant_voxel_memory
					IF (max_tick_qsel_s = '1') THEN-- last voxel was finished
						nx_state	<=	ready; -- Job done!
					ELSE
						nx_state	<=	inc_quadrant;  -- Fetch next voxel_quadrant_memory
					END IF;
				ELSE									
					nx_state	<=	inc_counters; -- Continue fetching points
				END IF;
			---------------------------
			WHEN inc_counters =>
				clr_qsel_s			<=	'0';
				inc_qsel_s			<=	'0';
				clr_rd_counter_s	<=	'0';
				inc_rd_counter_s	<=	'1'; -- enable next count for rd_addr
				rd_addr				<=	(OTHERS => '0'); -- current read counter for adressing next fetch data point
				wr_en					<=	'0';	
				en_scale				<=	'0';
				en_inc_size			<=	'1'; -- Size must be incremented, since a writing just occured. Point to next available position in map
				data_ready			<=	'0';
				nx_state				<=	fetching_point;
			---------------------------
			WHEN inc_quadrant =>
				clr_qsel_s			<=	'0';
				inc_qsel_s			<=	'1';	-- enable next count for quadrant
				clr_rd_counter_s	<=	'1';	-- clear rd_addr counter
				inc_rd_counter_s	<=	'0'; 
				rd_addr				<=	(OTHERS => '0'); -- current read counter for adressing next fetch data point
				wr_en					<=	'0';	
				en_scale				<=	'0';
				en_inc_size			<=	'1';	-- Size must be incremented, since a writing just occured. Point to next available position in map
				data_ready			<=	'0';
				nx_state				<=	fetching_point;
			---------------------------
			WHEN ready =>
				clr_qsel_s			<=	'1';	-- clear quadrant counter
				inc_qsel_s			<=	'1';	-- enable next count for go back to 0
				clr_rd_counter_s	<=	'1';	-- clear rd_addr counter
				inc_rd_counter_s	<=	'1'; 	-- enable next count for go back to 0
				rd_addr				<=	(OTHERS => '0'); -- current read counter for adressing next fetch data point
				wr_en					<=	'0';	
				en_scale				<=	'0'; 
				en_inc_size			<=	'0';
				data_ready			<=	'1';
				nx_state				<=	idle;
			---------------------------
			END CASE;
	END PROCESS;
END ARCHITECTURE;