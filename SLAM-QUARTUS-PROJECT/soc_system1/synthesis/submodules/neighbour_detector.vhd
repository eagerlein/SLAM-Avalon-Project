
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	USE ieee.std_logic_unsigned.all;
LIBRARY WORK;
	USE work.my_package.all;
------------------------------------------------------------------------
ENTITY neighbour_detector IS
	GENERIC	(	DATA_WIDTH	:	INTEGER	:=	DATA_WIDTH);			
	PORT	(		dist_x		:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					dist_y		:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					dist_z		:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					neighbour	: 	OUT	STD_LOGIC);
END ENTITY;
------------------------------------------------------------------------
ARCHITECTURE rtl OF neighbour_detector IS

	
	
	-----------Comparator Signals-----------
	-- Comparator signals used as flags in the comparission to 
	-- determine wich quadrant the point belongs
	-----------------------------------------
	SIGNAL	x_ls_100	:	STD_LOGIC; 	-- Flag for x>0
	SIGNAL	y_ls_100	:	STD_LOGIC; 	-- Flag for x>0
	SIGNAL	z_ls_100	:	STD_LOGIC; 	-- Flag for x>0
	
	
BEGIN
	-----------Comparators-----------
	x_comparator: ENTITY work.nBitcomparator 
	GENERIC MAP	(	N	=>	DATA_WIDTH)
	PORT MAP	(		A	=>	dist_x,
						B	=>	ONE_HUNDRED_BIN,
						eq	=>	OPEN,
						lg	=>	OPEN,
						ls	=>	x_ls_100);
	
	y_comparator: ENTITY work.nBitcomparator 
	GENERIC MAP	(	N	=>	DATA_WIDTH)
	PORT MAP	(		A	=>	dist_y,
						B	=>	ONE_HUNDRED_BIN,
						eq	=>	OPEN,
						lg	=>	OPEN,
						ls	=>	y_ls_100);
	
	z_comparator: ENTITY work.nBitcomparator 
	GENERIC MAP	(	N	=>	DATA_WIDTH)
	PORT MAP	(		A	=>	dist_z,
						B	=>	ONE_HUNDRED_BIN,
						eq	=>	OPEN,
						lg	=>	OPEN,
						ls	=>	z_ls_100);
						
	-----------Neigbour Detection Logic-----------
	neighbour	<= x_ls_100 AND y_ls_100 AND z_ls_100;

END ARCHITECTURE;