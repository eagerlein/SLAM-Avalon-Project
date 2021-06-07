------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_signed.all;
------------------------------------------------------------------------
ENTITY nBitcomparator IS
	GENERIC	(	N		:	INTEGER	:=	4);
	PORT	(		A		:	IN		STD_LOGIC_VECTOR(N-1 DOWNTO 0);
					B		:	IN		STD_LOGIC_VECTOR(N-1 DOWNTO 0);
					eq		:	OUT	STD_LOGIC;
					lg		:	OUT	STD_LOGIC;
					ls		:	OUT	STD_LOGIC);
END ENTITY;
------------------------------------------------------------------------
ARCHITECTURE functional OF nBitcomparator IS
BEGIN
	eq <= '1' when A = B else '0';
	lg <= '1' when A > B else '0';
	ls <= '1' when A < B else '0';
end ARCHITECTURE;