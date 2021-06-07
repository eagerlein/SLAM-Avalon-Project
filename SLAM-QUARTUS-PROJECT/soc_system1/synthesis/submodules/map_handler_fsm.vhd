------------------------------------------------------------------------
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	USE ieee.std_logic_unsigned.all;
	USE ieee.numeric_std.all;
LIBRARY WORK;
	USE work.my_package.all;
------------------------------------------------------------------------
ENTITY map_handler_fsm IS			
	PORT 	(		clk					: 	IN 	STD_LOGIC;
					rst					: 	IN 	STD_LOGIC;
					strobe				:	IN		STD_LOGIC;--Start bit
					update_signal		:	IN		STD_LOGIC;
					map_size				:	IN		STD_LOGIC_VECTOR(MAP_ADDR_WIDTH-1 DOWNTO 0);
					ready_init			:	IN		STD_LOGIC;
					ready_transform	:	IN		STD_LOGIC;
					ready_update		:	IN		STD_LOGIC;
					ready_voxel			:	IN		STD_LOGIC;
					en_init				:	OUT	STD_LOGIC;
					en_transform		:	OUT	STD_LOGIC;
					en_update			:	OUT	STD_LOGIC;
					clr_map_size		:	OUT	STD_LOGIC;
					fsm_sel				:	OUT	STD_LOGIC_VECTOR(1 DOWNTO 0);
					data_ready			:	OUT	STD_LOGIC);
					
END ENTITY;
---------------------------------------------------------
ARCHITECTURE fsm OF map_handler_fsm IS
	TYPE state IS (idle, strobe_transform, wait_for_vx_and_tf, strobe_update, wait_for_update, strobe_init, wait_for_init, ready); 
	SIGNAL 	pr_state					: 	state;
	SIGNAL 	nx_state					: 	state;
	
	SIGNAL	map_empty_s				:	STD_LOGIC;
	SIGNAL	ready_vx_tr_s			:	STD_LOGIC;
	SIGNAL	ready_transform_reg	:	STD_LOGIC;
	SIGNAL	ready_voxel_reg		:	STD_LOGIC;
	SIGNAL	crl_registers_s		:	STD_LOGIC;
	
BEGIN
	--========================================
	-- 		Ready Registers
	--========================================
	PROCESS(clk, rst, ready_transform)
	BEGIN
		IF (rst = '1') THEN
			ready_transform_reg	<= '0';
		ELSIF(rising_edge(clk)) THEN
			IF (crl_registers_s = '1') THEN
				ready_transform_reg	<= '0';
			ELSIF (ready_transform = '1') THEN
				ready_transform_reg	<= '1';
			END IF;
		END IF;
	END PROCESS;
	
	ready_voxel_register: PROCESS(clk, rst, ready_voxel)
	BEGIN
		IF (rst = '1') THEN
			ready_voxel_reg	<= '0';
		ELSIF(rising_edge(clk)) THEN
			IF (crl_registers_s = '1') THEN
				ready_voxel_reg	<= '0';
			ELSIF (ready_voxel = '1') THEN
				ready_voxel_reg	<= '1';
			END IF;
		END IF;
	END PROCESS;
	
	ready_vx_tr_s 	<=	ready_transform_reg AND ready_voxel_reg;
	
	map_empty_s		<=	'1' when map_size = ZEROS(MAP_ADDR_WIDTH-1 DOWNTO 0) 	ELSE '0';
	
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
	PROCESS (pr_state, strobe, map_empty_s, ready_init, ready_transform, ready_update, ready_voxel, ready_vx_tr_s)
	--idle, strobe_transform, wait_for_vx_and_tf, strobe_update, wait_for_update, , , ready
	BEGIN
		CASE pr_state IS
			---------------------------
			WHEN idle =>
				en_init				<=	'0';
				en_transform		<=	'0';
				en_update			<=	'0';
				clr_map_size		<=	'0';
				fsm_sel				<=	"00";
				data_ready			<=	'0';
				crl_registers_s	<=	'1'; --Clear ready registers
				IF (strobe = '1') THEN
					IF(map_empty_s = '1') THEN
						nx_state	<=	strobe_init;
					ELSE
						nx_state	<=	strobe_transform;
					END IF;
				ELSE
					nx_state	<=	idle;
				END IF;
			---------------------------
			WHEN strobe_init =>
				en_init				<=	'1'; -- Strobe init
				en_transform		<=	'0';
				en_update			<=	'0';
				clr_map_size		<=	'0';
				fsm_sel				<=	"01";
				data_ready			<=	'0';
				crl_registers_s	<=	'0';
				nx_state				<=	wait_for_init;
			---------------------------
			WHEN wait_for_init =>
				en_init				<=	'0'; 
				en_transform		<=	'0';
				en_update			<=	'0';
				clr_map_size		<=	'0';
				fsm_sel				<=	"01"; -- Init takes control outside the module
				data_ready			<=	'0';
				crl_registers_s	<=	'0';
				IF (ready_init = '1') THEN
					nx_state			<=	ready;
				ELSE
					nx_state			<=	wait_for_init;
				END IF;
			---------------------------
			WHEN strobe_transform =>
				en_init				<=	'0'; 
				en_transform		<=	'1';
				en_update			<=	'0';
				clr_map_size		<=	'0';
				fsm_sel				<=	"10"; -- Init takes control outside the module 
				data_ready			<=	'0';
				crl_registers_s	<=	'0';
				nx_state				<=	wait_for_vx_and_tf;
			---------------------------
			WHEN wait_for_vx_and_tf =>
				en_init				<=	'0'; 
				en_transform		<=	'0';
				en_update			<=	'0';
				clr_map_size		<=	'0';
				fsm_sel				<=	"10"; -- Transform takes control outside the module
				data_ready			<=	'0';
				crl_registers_s	<=	'0';
				IF (ready_vx_tr_s = '1') THEN
--						nx_state			<=	strobe_update;
						IF(update_signal='1') THEN
							nx_state			<=	ready;
						ELSE 
							nx_state			<=	strobe_update;
						END IF;
				ELSE
						nx_state			<=	wait_for_vx_and_tf;
				END IF;
			---------------------------
			WHEN strobe_update =>
				en_init				<=	'0'; 
				en_transform		<=	'0';
				en_update			<=	'1';
				clr_map_size		<=	'0';
				fsm_sel				<=	"11"; -- Update takes control outside the module 
				data_ready			<=	'0';
				crl_registers_s	<=	'0'; -- Clear ready registers
				nx_state				<=	wait_for_update;
			---------------------------
			WHEN wait_for_update =>
				en_init				<=	'0'; 
				en_transform		<=	'0';
				en_update			<=	'0';
				clr_map_size		<=	'0';
				fsm_sel				<=	"11"; -- Update takes control outside the module
				data_ready			<=	'0';
				crl_registers_s	<=	'0';
				IF (ready_update = '1') THEN
					nx_state			<=	ready;
				ELSE
					nx_state			<=	wait_for_update;
				END IF;
			---------------------------
			WHEN ready =>
				en_init				<=	'0'; 
				en_transform		<=	'0';
				en_update			<=	'0';
				clr_map_size		<=	'0';
				fsm_sel				<=	"00"; 
				data_ready			<=	'1'; -- Data ready
				crl_registers_s	<=	'1'; 
				nx_state				<=	idle;
			---------------------------
			END CASE;
	END PROCESS;
END ARCHITECTURE;