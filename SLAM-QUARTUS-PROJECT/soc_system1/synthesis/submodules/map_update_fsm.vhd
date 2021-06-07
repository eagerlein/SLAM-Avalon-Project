-- altera vhdl_input_version vhdl_2008
------------------------------------------------------------------------
--						map_update_fsm
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
ENTITY map_update_fsm IS
	PORT(		clk							: 	IN 	STD_LOGIC;
				rst							:	IN 	STD_LOGIC;
				strobe						:	IN 	STD_LOGIC;
				q1_size						:	IN		STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
				q2_size						:	IN		STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
				q3_size						:	IN		STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
				q4_size						:	IN		STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
				map_size						:	IN		STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0);--Used to control map loop.
				voxel_point					:	IN		STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0);
				map_point					:	IN		STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0); --Point from Map
				map_new_point				:	OUT	STD_LOGIC_VECTOR(3*DATA_WIDTH-1 DOWNTO 0); --Point to Map
				qsel							:	OUT	STD_LOGIC_VECTOR(1 DOWNTO 0);
				en_inc_size					:	OUT	STD_LOGIC;
				wr_en							:	OUT	STD_LOGIC;
				rd_addr_from_map			:	OUT	STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0);
				rd_en_from_map				:	OUT	STD_LOGIC;
				rd_en_from_voxel			:	OUT	STD_LOGIC;
				rd_addr_from_voxel		:	OUT	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);
				wr_addr_to_map				:	OUT	STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0);
				hps							:	OUT	STD_LOGIC;
				q_h							:	OUT	STD_LOGIC_VECTOR(1 DOWNTO 0);
				data_ready					:	OUT	STD_LOGIC);
END ENTITY;
-----------------------------------------------
ARCHITECTURE fsm OF map_update_fsm IS
	TYPE state IS (idle, strobe_vq2map, vq2map, inc_quadrant, verify_qsel, ready); 
	SIGNAL 	pr_state					: 	state;
	SIGNAL 	nx_state					: 	state;
	
	
	SIGNAL	qsel_s					:	UNSIGNED(1 DOWNTO 0);
	SIGNAL	qsel_next				:	UNSIGNED(1 DOWNTO 0);
	SIGNAL 	clr_qsel_s				:	STD_LOGIC;
	SIGNAL 	inc_qsel_s				:	STD_LOGIC;
	SIGNAL	max_tick_qsel_s		:	STD_LOGIC;
	
	SIGNAL	strobe_vq2map_s		:	STD_LOGIC;
	SIGNAL	ready_vq2map_s			:	STD_LOGIC;
	SIGNAL	voxel_size_s			:	STD_LOGIC_VECTOR(VOXEL_ADDR_WIDTH-1 DOWNTO 0);

BEGIN
	hps <=ready_vq2map_s;
	q_h <=STD_LOGIC_VECTOR(qsel_s);
	vq2map_module: ENTITY WORK.quadrant_to_map_fsm
	PORT MAP 	(	clk					=>	clk,
						rst					=>	rst,
						strobe				=>	strobe_vq2map_s,
						voxel_size			=>	voxel_size_s,
						map_size				=>	map_size,
						voxel_point			=>	voxel_point,
						map_point			=>	map_point,
						map_new_point		=>	map_new_point,
						rd_addr_from_voxel=>	rd_addr_from_voxel,
						rd_addr_from_map	=>	rd_addr_from_map,
						rd_en_from_map		=>	rd_en_from_map,
						rd_en_from_voxel	=>	rd_en_from_voxel,
						wr_addr_to_map		=>	wr_addr_to_map,
						wr_en					=>	wr_en,
						en_inc_size			=>	en_inc_size,
						data_ready			=>	ready_vq2map_s);
					
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
	
	--==============================
	-- 	Voxel size selection
	--==============================
	
	voxel_size_s	<=	q1_size WHEN qsel_s = "00"		ELSE 
							q2_size WHEN qsel_s = "01"		ELSE 
							q3_size WHEN qsel_s = "10"		ELSE
							q4_size WHEN qsel_s = "11"		ELSE 
							(OTHERS	=>	'0');
	
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
	PROCESS (pr_state, strobe, max_tick_qsel_s, ready_vq2map_s)
	BEGIN
		CASE pr_state IS
			---------------------------
			WHEN idle =>
				clr_qsel_s			<=	'1'; 	-- Clear quadrant counter
				inc_qsel_s			<=	'0';	-- No increment operation
				strobe_vq2map_s	<=	'0';	-- No convolution between map and voxel quadrant
				data_ready			<=	'0';	-- idle
				IF (strobe = '1') THEN
					nx_state	<=	strobe_vq2map;
				ELSE
					nx_state	<=	idle;
				END IF;
			---------------------------
			WHEN strobe_vq2map =>			-- Issues a tick for one clock cycle to start quadrant_to_map_fsm operation
				clr_qsel_s			<=	'0';
				inc_qsel_s			<=	'0';
				strobe_vq2map_s	<=	'1';	--	Start bit 
				data_ready			<=	'0';
				nx_state				<=	vq2map;
			---------------------------
			WHEN vq2map =>					-- Wait for ready in quadrant_to_map_fsm
				clr_qsel_s			<=	'0';
				inc_qsel_s			<=	'0';
				strobe_vq2map_s	<=	'0';
				data_ready			<=	'0';
				IF (ready_vq2map_s = '1') THEN
					nx_state	<=	verify_qsel;
				ELSE
					nx_state	<=	vq2map;
				END IF;
			---------------------------
			WHEN verify_qsel =>			-- Verify if last quadrant was integrated in the map
				clr_qsel_s			<=	'0';
				inc_qsel_s			<=	'0';
				strobe_vq2map_s	<=	'0';
				data_ready			<=	'0';
				IF (max_tick_qsel_s = '1') THEN
					nx_state	<=	ready;
				ELSE
					nx_state	<=	inc_quadrant;
				END IF;
			---------------------------
			WHEN inc_quadrant =>			-- Increment quadrant counter for reading next quadrant voxel memory
				clr_qsel_s			<=	'0';
				inc_qsel_s			<=	'1';
				strobe_vq2map_s	<=	'0';	
				data_ready			<=	'0';
				nx_state				<=	strobe_vq2map;
			---------------------------
			WHEN ready =>			
				clr_qsel_s			<=	'0';
				inc_qsel_s			<=	'0';
				strobe_vq2map_s	<=	'0';	
				data_ready			<=	'1';
				nx_state				<=	idle;
			---------------------------
			END CASE;
	END PROCESS;
END ARCHITECTURE;