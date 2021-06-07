-- altera vhdl_input_version vhdl_2008
--------------------------------------
LIBRARY IEEE;
USE ieee.std_logic_1164.all;
----------------------------------
ENTITY my_register IS
	GENERIC	(	DATA_WIDTH	:	INTEGER	:=	32);
	PORT		(	clk			:	IN		STD_LOGIC;
					rst			:	IN		STD_LOGIC;
					ena 			:	IN		STD_LOGIC;
					syn_clr		:	IN		STD_LOGIC;
					d				:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					q				: 	OUT	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0));
END ENTITY;
-------------------------------------
ARCHITECTURE rtl OF my_register IS
BEGIN
		
	PROCESS(clk,rst,ena)
	BEGIN
		IF(rst='1') THEN
			q	<= (OTHERS => '0');
		ELSIF (rising_edge(clk)) THEN
			IF (syn_clr = '1') THEN
				q	<= (OTHERS => '0');
			ELSIF (ena ='1') THEN
				q	<= d;
			END IF;
		END IF;
	END PROCESS;
END ARCHITECTURE;