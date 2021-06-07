------------------------------------------------------------------------
--						int2float
-- Date: 2020-10-08
-- Version: 1.0 
-- Description:
-- Instantiates alt_int2float_convert and a FSM. 
-- Controlled by a FSM, that presents the results for one Clock cycle, and 
-- resets operation to idle.
-- The operation is activated by the strobe signal, set for one clock cycle.
-- The operation can be restarted using strobe input.
-- The operation can be stoped at any time using sync_clr input.
-- alt_int2float_convert is set to a latency of 6 clock cycles.
-- The timer is set to issue data_ready
------------------------------------------------------------------------
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	--USE ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;
LIBRARY WORK;
	USE work.my_package.all;
------------------------------------------------------------------------
ENTITY int2float IS
	GENERIC	(	DATA_WIDTH		:	INTEGER	:=	32;
					LATENCY			:	UNSIGNED(LATENCY_WIDTH-1 DOWNTO 0)	:=	FLOAT2INT_LATENCY);	-- Same Latency		
	PORT	(		rst				:	IN		STD_LOGIC ;
					clk				: 	IN 	STD_LOGIC ;
					syn_clr			:	IN		STD_LOGIC ;
					strobe			: 	IN 	STD_LOGIC ;
					dataa				: 	IN 	STD_LOGIC_VECTOR (DATA_WIDTH-1 DOWNTO 0);
					result			: 	OUT 	STD_LOGIC_VECTOR (DATA_WIDTH-1 DOWNTO 0);
					data_ready		:	OUT 	STD_LOGIC;
					busy				:	OUT 	STD_LOGIC);					
END ENTITY int2float;
-------------------------------------------------------------------------
ARCHITECTURE fsm OF int2float IS
	TYPE state IS (idle, operating, ready, reseting_op);
	SIGNAL 	pr_state			: 	state;
	SIGNAL 	nx_state			: 	state;
	SIGNAL	count_s			:	UNSIGNED(7 DOWNTO 0);
	SIGNAL	count_next		:	UNSIGNED(7 DOWNTO 0);
	SIGNAL 	en_counter_s	:	STD_LOGIC;
	SIGNAL 	clr_counter_s	:	STD_LOGIC;
	SIGNAL	max_tick			:	STD_LOGIC;
	SIGNAL	busy_s			:	STD_LOGIC;
	
	SIGNAL	dataa_reg		: 	STD_LOGIC_VECTOR (DATA_WIDTH-1 DOWNTO 0);
	--SIGNAL	datab_reg		: 	STD_LOGIC_VECTOR (DATA_WIDTH-1 DOWNTO 0);
	SIGNAL 	result_s			: 	STD_LOGIC_VECTOR (DATA_WIDTH-1 DOWNTO 0);
	
BEGIN
	
	busy	<=	busy_s;
	---------------Multipler-------------------
	int2float_module:	ENTITY work.alt_int2float_convert
	PORT MAP	( 	aclr		=>	rst,
					clk_en	=>	busy_s,
					clock		=>	clk,
					dataa		=>	dataa_reg,
					result	=>	result_s);
	
	-------------Register input-------------------	
	regInpunt: PROCESS(strobe, clk, rst)
	BEGIN
		IF (rst = '1') THEN
			dataa_reg <= (OTHERS => '0');
			--datab_reg <= (OTHERS => '0');
		ELSIF(rising_edge(clk)) THEN
			IF (strobe = '1') THEN
				dataa_reg <= dataa;
				--datab_reg <= datab;
			END IF;
		END IF;
	END PROCESS;
	
	-------------Counter Logic-------------------
	COUNTER:ENTITY WORK.tiny_counter
	GENERIC	MAP(	LATENCY					=>	LATENCY)
	PORT MAP		(	clk				=>	clk,
						rst				=>	rst,
						ena 				=>	en_counter_s,
						syn_clr			=>	syn_clr,
						clr_counter		=>	clr_counter_s,
						max_tick			=>	max_tick);

	--===========================================
	--              FSM
	--===========================================
	-- Sequential Section ----------------------
	seq_fsm: PROCESS(clk, rst)
	BEGIN
		IF (rst = '1') THEN
			pr_state <=idle;
		ELSIF(rising_edge(clk)) THEN
			pr_state <= nx_state;
		END IF;
	END PROCESS;
	
	-- Combinational Section ----------------------
	comb_fsm: PROCESS (pr_state, strobe, max_tick, syn_clr)
	BEGIN
		
		CASE pr_state IS
			---------------------------
			WHEN idle =>
				result			<=	(OTHERS=>'0');
				data_ready		<=	'0';
				busy_s			<=	'0';
				en_counter_s	<=	'0';
				clr_counter_s	<= '1';
				IF (strobe = '1') THEN
					nx_state	<= operating;
				ELSE
					nx_state	<= idle;
				END IF;
			---------------------------
			WHEN operating =>
				result			<=	(OTHERS=>'0');
				data_ready		<=	'0';
				busy_s			<=	'1'; -- set busy signal
				en_counter_s	<=	'1'; -- enable counter
				clr_counter_s	<= '0';
				IF (max_tick = '1') THEN 	-- Calculation finished
					nx_state	<= ready;
				ELSIF (syn_clr='1') THEN
					nx_state	<= idle;
				ELSIF (strobe='1') THEN
					nx_state	<= reseting_op;
				ELSE				-- Calculation not finished
					nx_state	<= operating; 
				END IF;
			---------------------------
			WHEN ready =>
				result			<=	result_s; -- Showing result
				data_ready		<=	'1'; -- set data ready
				busy_s			<=	'0';
				en_counter_s	<=	'0';
				clr_counter_s	<= '0';	
				nx_state			<= idle;
			
			---------------------------
			WHEN reseting_op =>
				result			<=	(OTHERS=>'0'); 
				data_ready		<=	'0';
				busy_s			<=	'1'; -- module is busy
				en_counter_s	<=	'1'; -- en_counte must be set to be reseted in next cycle
				clr_counter_s	<= '1'; -- reset counter
				nx_state			<= operating; -- to start calculation again
			---------------------------
		END CASE;
	END PROCESS;
END ARCHITECTURE fsm; 