LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	USE ieee.std_logic_unsigned.all;
LIBRARY WORK;
	USE work.my_package.all;
------------------------------------------------------------------------
ENTITY float_abs IS
	GENERIC	(	DATA_WIDTH	:	INTEGER	:=	DATA_WIDTH);			
	PORT	(		dataa			:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					result		:	OUT	STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0));
END ENTITY;
------------------------------------------------------------------------
ARCHITECTURE rtl OF float_abs IS
BEGIN
	result	<=	'0' & dataa (DATA_WIDTH-2 DOWNTO 0);
END ARCHITECTURE;