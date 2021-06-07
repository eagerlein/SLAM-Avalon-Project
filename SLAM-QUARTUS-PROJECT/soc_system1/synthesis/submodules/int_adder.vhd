------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
------------------------------------------------------------------------
ENTITY int_adder IS
	GENERIC	(	N		:	INTEGER	:=	32);
	PORT	(		A		:	IN		STD_LOGIC_VECTOR(N-1 DOWNTO 0);
					B		:	IN		STD_LOGIC_VECTOR(N-1 DOWNTO 0);
					result:	OUT	STD_LOGIC_VECTOR(N-1 DOWNTO 0));
END ENTITY;
------------------------------------------------------------------------
ARCHITECTURE functional OF int_adder IS
BEGIN
	result	<=	STD_LOGIC_VECTOR(signed(A)+signed(B));

end ARCHITECTURE;