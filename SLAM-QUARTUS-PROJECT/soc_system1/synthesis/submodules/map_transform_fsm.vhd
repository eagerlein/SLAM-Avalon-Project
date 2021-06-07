-- altera vhdl_input_version vhdl_2008
------------------------------------------------------------------------
--						map_transform_fsm
-- Date: 2020-12-12
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
ENTITY map_transform_fsm IS
	PORT(		clk					: 	IN 	STD_LOGIC;
				rst					: 	IN 	STD_LOGIC;
				strobe				:	IN 	STD_LOGIC;
				ready_transform	:	IN 	STD_LOGIC;
				map_size				:	IN		STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0);
				en_transform		:	OUT	STD_LOGIC;
				wr_en					:	OUT	STD_LOGIC;
				rd_en					:	OUT	STD_LOGIC;
				addr					:	OUT	STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0);
				data_ready			:	OUT	STD_LOGIC);
END ENTITY;
-----------------------------------------------
ARCHITECTURE fsm OF map_transform_fsm IS
	TYPE state IS (idle, fetching_point, strobe_transform, transform, writing_mem, wait_mem, inc_counter, ready); 
	SIGNAL 	pr_state				: 	state;
	SIGNAL 	nx_state				: 	state;
	
	SIGNAL	size_uns				:	UNSIGNED(MAP_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	addr_s				:	UNSIGNED(MAP_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	addr_next			:	UNSIGNED(MAP_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL 	inc_counter_s		:	STD_LOGIC;
	SIGNAL 	clr_counter_s		:	STD_LOGIC;
	SIGNAL	max_tick_s			:	STD_LOGIC;
	

BEGIN
		
	--========================================
	-- READ Counter logic
	--========================================
	size_uns		<=		unsigned(map_size);	
	-- Next count logic
	addr_next 	<=		(OTHERS =>	'0') 	WHEN 	clr_counter_s	='1' 		ELSE
							(OTHERS =>	'0') 	WHEN 	max_tick_s		='1'		ELSE
							addr_s + 1;
	
	-- Read Max tick logic
	-- Different max_tick conditions depending on which quadrant voxel is beoing read
	max_tick_s	<=	'1' when addr_s = size_uns ELSE 
						'0';
	
	-- Increment Counter ----------------------
	PROCESS(clk, rst, inc_counter_s, clr_counter_s)
	BEGIN
		IF (rst = '1') THEN
			addr_s <= (OTHERS => '0');
		ELSIF(rising_edge(clk)) THEN
			IF	(clr_counter_s = '1') THEN
				addr_s <= (OTHERS => '0');
			ELSIF (inc_counter_s = '1') THEN
				addr_s <= addr_next;
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
	PROCESS (pr_state, strobe, ready_transform, max_tick_s)
	BEGIN
		CASE pr_state IS
			---------------------------
			WHEN idle =>
				clr_counter_s	<=	'1';
				inc_counter_s	<=	'0';
				addr				<=	(OTHERS => '0');
				rd_en				<=	'0';
				wr_en				<=	'0';
				en_transform	<=	'0';
				data_ready		<=	'0';
				IF (strobe = '1') THEN
					nx_state	<=	fetching_point;
				ELSE
					nx_state	<=	idle;
				END IF;
			---------------------------
			WHEN fetching_point =>
				clr_counter_s	<=	'0';
				inc_counter_s	<=	'0';
				addr				<=	STD_LOGIC_VECTOR(addr_s); -- current read counter for adressing next fetch data point
				rd_en				<=	'1'; --rd_en from map
				wr_en				<=	'0';
				en_transform	<=	'0';
				data_ready		<=	'0';
				nx_state			<=	strobe_transform; -- wait until data_ready from strobe for scale_convert2int module
			---------------------------
			WHEN strobe_transform =>
				clr_counter_s	<=	'0';
				inc_counter_s	<=	'0';
				addr				<=	(OTHERS => '0');
				rd_en				<=	'0';
				wr_en				<=	'0';
				en_transform	<=	'1';	--Strobe coordinate transformation, registers of inputs inside transformation module
				data_ready		<=	'0';
				nx_state			<=	transform; -- wait until data_ready from strobe for scale_convert2int module
			---------------------------
			WHEN transform =>
				clr_counter_s	<=	'0';
				inc_counter_s	<=	'0';
				addr				<=	(OTHERS => '0');
				rd_en				<=	'0';
				wr_en				<=	'0';
				en_transform	<=	'0';
				data_ready		<=	'0';
				IF (ready_transform = '1') THEN -- Coordinate transformation finished
					nx_state		<=	writing_mem;
				ELSE 
					nx_state		<=	transform;				
				END IF;
			---------------------------
			WHEN writing_mem =>
				clr_counter_s	<=	'0';
				inc_counter_s	<=	'0';
				addr				<=	STD_LOGIC_VECTOR(addr_s); -- current counter to write point in the same position from it was fetched
				rd_en				<=	'0';
				wr_en				<=	'1';	-- write point in map
				en_transform	<=	'0';
				data_ready		<=	'0';
				nx_state			<=	wait_mem; -- Job done!
						---------------------------
			WHEN wait_mem =>
				clr_counter_s	<=	'0';
				inc_counter_s	<=	'0';
				addr				<=	STD_LOGIC_VECTOR(addr_s); -- current counter to write point in the same position from it was fetched
				rd_en				<=	'0';
				wr_en				<=	'1';	-- write point in map
				en_transform	<=	'0';
				data_ready		<=	'0';
				IF (max_tick_s	=	'1') THEN -- Last point was fetched in current quadrant_voxel_memory
					nx_state	<=	ready; -- Job done!
				ELSE									
					nx_state	<=	inc_counter; -- Continue fetching points
				END IF;	
			---------------------------
			WHEN inc_counter =>
				clr_counter_s	<=	'0';
				inc_counter_s	<=	'1';
				addr				<=	(OTHERS => '0'); -- current counter to write point in the same position from it was fetched
				rd_en				<=	'0';
				wr_en				<=	'0';
				en_transform	<=	'0';
				data_ready		<=	'0';
				nx_state			<=	fetching_point;
			---------------------------
			WHEN ready =>
				clr_counter_s	<=	'1';	-- clear addr counter
				inc_counter_s	<=	'1';	-- enable next count for go back to 0
				addr				<=	(OTHERS => '0'); -- current counter to write point in the same position from it was fetched
				rd_en				<=	'0';
				wr_en				<=	'0';
				en_transform	<=	'0';
				data_ready		<=	'1';
				nx_state			<=	idle;
			---------------------------
			END CASE;
	END PROCESS;
END ARCHITECTURE;