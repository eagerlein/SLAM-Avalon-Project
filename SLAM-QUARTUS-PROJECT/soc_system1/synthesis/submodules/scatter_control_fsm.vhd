-- altera vhdl_input_version vhdl_2008
------------------------------------------------------------------------
--						scatter_control_fsm
-- Date: 2020-10-15
-- Version: 1.0 
-- Description:
-- FSM CONTROL: states:
-- idle: not operating
-- fetching_point: retrive next point in the input array, and strobe the processing of a data point
-- converting2int: wait state until calculation is ready
-- writing_mem: write oputput array with the result of the calculation
-- inc_counters: increment write and write pointers, 
-- ready: issues a data_ready signal for one clock cycle
------------------------------------------------------------------------
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	USE ieee.numeric_std.all;
LIBRARY WORK;
	USE work.my_package.all;
-----------------------------------------------
ENTITY scatter_control_fsm IS
	PORT(		clk					: 	IN 	STD_LOGIC;
				rst					: 	IN 	STD_LOGIC;
				strobe				:	IN 	STD_LOGIC;
				q1						:	IN 	STD_LOGIC;
				q2						:	IN 	STD_LOGIC;
				q3						:	IN 	STD_LOGIC;
				q4						:	IN 	STD_LOGIC;
				ready_scale			:	IN 	STD_LOGIC;
				pointcloud_size	:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
				rd_addr				:	OUT	STD_LOGIC_VECTOR(INPUT_DATA_ADDR_WIDTH-1 DOWNTO 0);
				en_scale				:	OUT	STD_LOGIC;
				wr_en					:	OUT	STD_LOGIC;
				wr_addr_q1			:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
				wr_addr_q2			:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
				wr_addr_q3			:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
				wr_addr_q4			:	OUT	STD_LOGIC_VECTOR(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
				last					:	OUT	STD_LOGIC;
				rd_en_input			:	OUT	STD_LOGIC;
				data_ready			:	OUT	STD_LOGIC);
END ENTITY;
-----------------------------------------------
ARCHITECTURE fsm OF scatter_control_fsm IS
	TYPE state IS (idle, fetching_point, converting2int, writing_mem, inc_counters, strobe_convert, ready); 
	SIGNAL 	pr_state					: 	state;
	SIGNAL 	nx_state					: 	state;
	
	SIGNAL	rd_addr_s				:	UNSIGNED(INPUT_DATA_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	rd_addr_next			:	UNSIGNED(INPUT_DATA_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	wr_addr_q1_s			:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	wr_addr_q1_next		:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	wr_addr_q2_s			:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	wr_addr_q2_next		:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	wr_addr_q3_s			:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	wr_addr_q3_next		:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	wr_addr_q4_s			:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	wr_addr_q4_next		:	UNSIGNED(QUADRANT_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL	pointcloud_size_reg	:	STD_LOGIC_VECTOR(INPUT_DATA_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL 	inc_counter_rd_s		:	STD_LOGIC;
	SIGNAL 	inc_counter_wr_s		:	STD_LOGIC;
	SIGNAL 	clr_counter_s			:	STD_LOGIC;
	SIGNAL	max_tick_rd_s			:	STD_LOGIC;
	SIGNAL	max_full_q1				:	STD_LOGIC;
	SIGNAL	max_full_q2				:	STD_LOGIC;
	SIGNAL	max_full_q3				:	STD_LOGIC;
	SIGNAL	max_full_q4				:	STD_LOGIC;
	SIGNAL	size_uns_s				:	UNSIGNED(INPUT_DATA_ADDR_WIDTH-1 DOWNTO 0);

BEGIN
	--============================================
	--					Register input	
	--============================================
	regSize: ENTITY WORK.my_register
	GENERIC MAP(		DATA_WIDTH			=>	INPUT_DATA_ADDR_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	strobe,
							syn_clr				=>	'0',
							d						=>	pointcloud_size(INPUT_DATA_ADDR_WIDTH-1 DOWNTO 0),
							q						=>	pointcloud_size_reg);
	
	
	--========================================
	-- READ Counter logic
	--========================================
	size_uns_s		<=		unsigned(pointcloud_size_reg)-1;
	rd_addr_next 	<=		(OTHERS =>	'0') 	WHEN 	clr_counter_s	='1' 		ELSE
								(OTHERS =>	'0') 	WHEN 	max_tick_rd_s	='1'		ELSE
								rd_addr_s + 1;
	
	max_tick_rd_s	<=	'1' when rd_addr_s = size_uns_s 	ELSE '0';
	last 				<= max_tick_rd_s;
	
	-- Increment Counter ----------------------
	inc_rd_counter_register: ENTITY WORK.my_register_unsigned
	GENERIC MAP(		DATA_WIDTH			=>	INPUT_DATA_ADDR_WIDTH)
	PORT MAP(			clk					=>	clk,
							rst					=>	rst,
							ena 					=>	inc_counter_rd_s,
							syn_clr				=>	clr_counter_s,
							d						=>	rd_addr_next,
							q						=>	rd_addr_s);
		
	--========================================
	-- WRITE Counters logic
	--================================strobe_convert========
	-- Counter for Q1
	wr_addr_q1_next 	<=		(OTHERS =>	'0') 	WHEN 	clr_counter_s	='1' 		ELSE
									wr_addr_q1_s + 1;
	-- Counter for Q2
	wr_addr_q2_next 	<=		(OTHERS =>	'0') 	WHEN 	clr_counter_s	='1' 		ELSE
									wr_addr_q2_s + 1;
	
	-- Counter for Q3
	wr_addr_q3_next 	<=		(OTHERS =>	'0') 	WHEN 	clr_counter_s	='1' 		ELSE
									wr_addr_q3_s + 1;
	
	-- Counter for Q4
	wr_addr_q4_next 	<=		(OTHERS =>	'0') 	WHEN 	clr_counter_s	='1' 		ELSE
									wr_addr_q4_s + 1;
	
	-- Increment Counters ----------------------
	PROCESS(inc_counter_wr_s, clk, rst, q1, q2, q3, q4, clr_counter_s)
	BEGIN
		IF (rst = '1') THEN
			wr_addr_q1_s <= (OTHERS => '0');
			wr_addr_q2_s <= (OTHERS => '0');
			wr_addr_q3_s <= (OTHERS => '0');
			wr_addr_q4_s <= (OTHERS => '0');
		ELSIF(rising_edge(clk)) THEN
			IF (clr_counter_s = '1') THEN
				wr_addr_q1_s <= (OTHERS => '0');
				wr_addr_q2_s <= (OTHERS => '0');
				wr_addr_q3_s <= (OTHERS => '0');
				wr_addr_q4_s <= (OTHERS => '0');				
			ELSE
				IF (inc_counter_wr_s = '1' AND q1 = '1') THEN
					wr_addr_q1_s <= wr_addr_q1_next;
				END IF;
				IF (inc_counter_wr_s = '1' AND q2 = '1') THEN
					wr_addr_q2_s <= wr_addr_q2_next;
				END IF;
				IF (inc_counter_wr_s = '1' AND q3 = '1') THEN
					wr_addr_q3_s <= wr_addr_q3_next;
				END IF;
				IF (inc_counter_wr_s = '1' AND q4 = '1') THEN
					wr_addr_q4_s <= wr_addr_q4_next;
				END IF;
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
	PROCESS (pr_state, strobe,ready_scale,max_tick_rd_s)
	BEGIN
		CASE pr_state IS
			---------------------------
			WHEN idle =>
				rd_addr				<=	(OTHERS => '0');
				rd_en_input			<=	'0';
				wr_en					<=	'0';
				wr_addr_q1			<=	(OTHERS => '0');
				wr_addr_q2			<=	(OTHERS => '0');
				wr_addr_q3			<=	(OTHERS => '0');
				wr_addr_q4			<=	(OTHERS => '0');
				en_scale				<=	'0';
				data_ready			<=	'0';
				clr_counter_s		<= '1';
				inc_counter_wr_s	<=	'0';
				inc_counter_rd_s	<=	'0';
				IF (strobe = '1') THEN
					nx_state	<=	fetching_point;
				ELSE
					nx_state	<=	idle;
				END IF;
			---------------------------
			WHEN fetching_point =>
				rd_addr				<=	STD_LOGIC_VECTOR(rd_addr_s); -- current read counter for adressing next fetch data point
				rd_en_input			<=	'1'; -- rd_en from input. Data remains at memory q because of the type of memory: rd_en and q  unregistered
				wr_en					<=	'0';
				wr_addr_q1			<=	(OTHERS => '0');
				wr_addr_q2			<=	(OTHERS => '0');
				wr_addr_q3			<=	(OTHERS => '0');
				wr_addr_q4			<=	(OTHERS => '0');
				en_scale				<=	'0'; -- strobe for scale_convert2int module
				data_ready			<=	'0';
				clr_counter_s		<= '0';
				inc_counter_wr_s	<=	'0';
				inc_counter_rd_s	<=	'0';
				nx_state				<=	strobe_convert; --start bit for convertion module
				---------------------------
			WHEN strobe_convert =>
				rd_addr				<=	(OTHERS => '0');
				rd_en_input			<=	'0';	
				wr_en					<=	'0';
				wr_addr_q1			<=	(OTHERS => '0');
				wr_addr_q2			<=	(OTHERS => '0');
				wr_addr_q3			<=	(OTHERS => '0');
				wr_addr_q4			<=	(OTHERS => '0');
				en_scale				<=	'1'; -- strobe for scale_convert2int module
				data_ready			<=	'0';
				clr_counter_s		<= '0';
				inc_counter_wr_s	<=	'0';
				inc_counter_rd_s	<=	'0';
				nx_state				<=	converting2int;
			---------------------------
			WHEN converting2int =>
				rd_addr				<=	(OTHERS => '0');
				rd_en_input			<=	'0';
				wr_en					<=	'0';
				wr_addr_q1			<=	(OTHERS => '0');
				wr_addr_q2			<=	(OTHERS => '0');
				wr_addr_q3			<=	(OTHERS => '0');
				wr_addr_q4			<=	(OTHERS => '0');
				en_scale				<=	'0';
				data_ready			<=	'0';
				clr_counter_s		<= '0';
				inc_counter_wr_s	<=	'0';
				inc_counter_rd_s	<=	'0';
				IF (ready_scale = '1') THEN
					nx_state		<=	writing_mem;
				ELSE 
					nx_state		<=	converting2int;				
				END IF;
			---------------------------
			WHEN writing_mem =>
				rd_addr				<=	(OTHERS => '0');
				rd_en_input			<=	'0';
				wr_en					<=	'1';  -- write one of quadrant memories
				wr_addr_q1			<=	STD_LOGIC_VECTOR(wr_addr_q1_s); -- write adresss memory q1
				wr_addr_q2			<=	STD_LOGIC_VECTOR(wr_addr_q2_s); -- write adresss memory q2
				wr_addr_q3			<=	STD_LOGIC_VECTOR(wr_addr_q3_s); -- write adresss memory q3
				wr_addr_q4			<=	STD_LOGIC_VECTOR(wr_addr_q4_s); -- write adresss memory q4
				en_scale				<=	'0';
				data_ready			<=	'0';
				clr_counter_s		<= '0';
				inc_counter_wr_s	<=	'0';
				inc_counter_rd_s	<=	'0';
				IF (max_tick_rd_s	=	'1') THEN -- Last point was fetched
					nx_state				<=	ready; 
				ELSE										-- Continue fetching points
					nx_state				<=	inc_counters;
				END IF;
			---------------------------
			WHEN inc_counters =>
				rd_addr				<=	(OTHERS => '0');
				rd_en_input			<=	'0';
				wr_en					<=	'0';
				wr_addr_q1			<=	(OTHERS => '0');
				wr_addr_q2			<=	(OTHERS => '0');
				wr_addr_q3			<=	(OTHERS => '0');
				wr_addr_q4			<=	(OTHERS => '0');
				en_scale				<=	'0';
				data_ready			<=	'0';
				clr_counter_s		<= '0';
				inc_counter_wr_s	<=	'1'; -- enable next count
				inc_counter_rd_s	<=	'1'; -- enable next count
				nx_state				<=	fetching_point;
			---------------------------
			WHEN ready =>
				rd_addr				<=	(OTHERS => '0');
				rd_en_input			<=	'0';
				wr_en					<=	'0';
				wr_addr_q1			<=	(OTHERS => '0');
				wr_addr_q2			<=	(OTHERS => '0');
				wr_addr_q3			<=	(OTHERS => '0');
				wr_addr_q4			<=	(OTHERS => '0');
				en_scale				<=	'0';
				data_ready			<=	'1'; --data ready for one clock cicle
				clr_counter_s		<= '1';
				inc_counter_wr_s	<=	'1'; -- enable next count for go back to 0
				inc_counter_rd_s	<=	'1'; -- enable next count for go back to 0
				nx_state				<=	idle;
			---------------------------
			END CASE;
	END PROCESS;
	
END ARCHITECTURE;