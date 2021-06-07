------------------------------------------------------------------------
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	USE ieee.std_logic_unsigned.all;
	USE ieee.numeric_std.all;
LIBRARY WORK;
	USE work.my_package.all;
------------------------------------------------------------------------
ENTITY voxel_ready_fsm IS	
	PORT 	(		clk					: 	IN 	STD_LOGIC;
					rst					: 	IN 	STD_LOGIC;
					ready_q1				:	IN		STD_LOGIC;
					ready_q2				:	IN		STD_LOGIC;
					ready_q3				:	IN		STD_LOGIC;
					ready_q4				:	IN		STD_LOGIC;
					data_ready			:	OUT	STD_LOGIC);
					
END ENTITY;
---------------------------------------------------------
ARCHITECTURE fsm OF voxel_ready_fsm IS
	TYPE state IS (idle, wait_4_ready, ready); 
	SIGNAL 	pr_state					: 	state;
	SIGNAL 	nx_state					: 	state;
	
	SIGNAL	syn_crl_s				:	STD_LOGIC;
	SIGNAL	strobe_s					:	STD_LOGIC;
	SIGNAL	all_ready_s				:	STD_LOGIC;
	SIGNAL	ready_q1_reg			:	STD_LOGIC;
	SIGNAL	ready_q2_reg			:	STD_LOGIC;
	SIGNAL	ready_q3_reg			:	STD_LOGIC;
	SIGNAL	ready_q4_reg			:	STD_LOGIC;
	
BEGIN
	--======================================
	-- Ready Signal Registers
	--======================================
	ready_q1_register: PROCESS(clk, rst, syn_crl_s, ready_q1)
	BEGIN
		IF (rst = '1') THEN
			ready_q1_reg	<= '0';
		ELSIF(rising_edge(clk)) THEN
			IF (syn_crl_s = '1') THEN
				ready_q1_reg	<= '0';
			ELSIF (ready_q1 = '1') THEN
				ready_q1_reg	<= '1';
			END IF;
		END IF;
	END PROCESS;
	
	ready_q2_register: PROCESS(clk, rst, syn_crl_s, ready_q2)
	BEGIN
		IF (rst = '1') THEN
			ready_q2_reg	<= '0';
		ELSIF(rising_edge(clk)) THEN
			IF (syn_crl_s = '1') THEN
				ready_q2_reg	<= '0';
			ELSIF (ready_q2 = '1') THEN
				ready_q2_reg	<= '1';
			END IF;
		END IF;
	END PROCESS;
	
	ready_q3_register: PROCESS(clk, rst, syn_crl_s, ready_q3)
	BEGIN
		IF (rst = '1') THEN
			ready_q3_reg	<= '0';
		ELSIF(rising_edge(clk)) THEN
			IF (syn_crl_s = '1') THEN
				ready_q3_reg	<= '0';
			ELSIF (ready_q3 = '1') THEN
				ready_q3_reg	<= '1';
			END IF;
		END IF;
	END PROCESS;
	
	ready_q4_register: PROCESS(clk, rst, syn_crl_s, ready_q4)
	BEGIN
		IF (rst = '1') THEN
			ready_q4_reg	<= '0';
		ELSIF(rising_edge(clk)) THEN
			IF (syn_crl_s = '1') THEN
				ready_q4_reg	<= '0';
			ELSIF (ready_q4 = '1') THEN
				ready_q4_reg	<= '1';
			END IF;
		END IF;
	END PROCESS;
	
	all_ready_s <= ready_q1_reg AND ready_q2_reg AND ready_q3_reg AND ready_q4_reg;
	strobe_s		<=	ready_q1 OR ready_q2 OR ready_q3 OR ready_q4;
	
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
	PROCESS (pr_state, all_ready_s, strobe_s)
	BEGIN
		
		CASE pr_state IS
			---------------------------
			WHEN idle => 
				data_ready	<=	'0';
				syn_crl_s	<=	'0';
				IF (strobe_s = '1') THEN
					nx_state	<=	wait_4_ready;
				ELSE
					nx_state	<=	idle;
				END IF;				
			---------------------------
			WHEN wait_4_ready => 
				data_ready	<=	'0';
				syn_crl_s	<=	'0';
				IF (all_ready_s = '1') THEN
					nx_state	<=	ready;
				ELSE
					nx_state	<=	wait_4_ready;
				END IF;
			---------------------------
			WHEN ready => 
				data_ready	<=	'1';
				syn_crl_s	<=	'1';
				nx_state		<=	idle;
			---------------------------
			END CASE;
	END PROCESS;
	
END ARCHITECTURE;
				
				
	