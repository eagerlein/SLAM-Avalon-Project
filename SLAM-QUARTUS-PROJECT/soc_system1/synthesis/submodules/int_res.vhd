------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
------------------------------------------------------------------------
ENTITY int_res IS
	GENERIC	(	N		:	INTEGER	:=	32);
	PORT	(		A		:	IN		UNSIGNED(N-1 DOWNTO 0);
					B		:	IN		UNSIGNED(N-1 DOWNTO 0);
					result:	OUT	UNSIGNED(N-1 DOWNTO 0));
END ENTITY;
------------------------------------------------------------------------
ARCHITECTURE functional OF int_res IS
BEGIN
	result	<=	A-B;

end ARCHITECTURE;