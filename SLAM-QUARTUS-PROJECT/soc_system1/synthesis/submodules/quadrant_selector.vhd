------------------------------------------------------------------------
--						QUADRANT SELECTOR CIRCUIT
-- Date: 2020-10-14
-- Version: 2.0 
-- Description:
-- Receives x,y,z coordinates. Pure combinational
-- Outputs the correspondent flag of the quadrant that the point belongst
-- Inputs:	x_in, y_in, z_in		: 32-bits floating-point of the point coodinates in meters	
-- Outputs:	q1,q2,q3,q4 			: flag tha corresponds to the quadrant that the point belongs
-- 
------------------------------------------------------------------------
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	USE ieee.std_logic_unsigned.all;
LIBRARY WORK;
	USE work.my_package.all;
------------------------------------------------------------------------
ENTITY quadrant_selector IS
	GENERIC	(	DATA_WIDTH	:	INTEGER	:=	DATA_WIDTH);			
	PORT	(		x_in			:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					y_in			:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					z_in			:	IN		STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
					
					q1				:	OUT	STD_LOGIC;
					q2				:	OUT	STD_LOGIC;
					q3				:	OUT	STD_LOGIC;
					q4				:	OUT	STD_LOGIC);
END ENTITY;
------------------------------------------------------------------------
ARCHITECTURE rtl OF quadrant_selector IS
	
	
	-----------Comparator Signals-----------
	-- Comparator signals used as flags in the comparission to 
	-- determine wich quadrant the point belongs
	-----------------------------------------
	SIGNAL	x_eq_zero	:	STD_LOGIC; 	-- Flag for x=0
	SIGNAL	x_lg_zero	:	STD_LOGIC; 	-- Flag for x>0
	SIGNAL	x_ls_zero	:	STD_LOGIC; 	-- Flag for x<0
	SIGNAL	y_eq_zero	:	STD_LOGIC;	-- Flag for y=0
	SIGNAL	y_lg_zero	:	STD_LOGIC;	-- Flag for y>0
	SIGNAL	y_ls_zero	:	STD_LOGIC;	-- Flag for y<0
	SIGNAL	z_lg_th		:	STD_LOGIC;	-- Flag for x>threshold (-380°)
	
BEGIN
	-----------Comparators-----------
	x_comparator: ENTITY work.nBitcomparator 
	GENERIC MAP	(	N	=>	DATA_WIDTH)
	PORT MAP	(		A	=>	x_in,
						B	=>	ZEROS,
						eq	=>	x_eq_zero,
						lg	=>	x_lg_zero,
						ls	=>	x_ls_zero);
	
	y_comparator: ENTITY work.nBitcomparator 
	GENERIC MAP	(	N	=>	DATA_WIDTH)
	PORT MAP	(		A	=>	y_in,
						B	=>	ZEROS,
						eq	=>	y_eq_zero,
						lg	=>	y_lg_zero,
						ls	=>	y_ls_zero);
	
	z_comparator: ENTITY work.nBitcomparator 
	GENERIC MAP	(	N	=>	DATA_WIDTH)
	PORT MAP	(		A	=>	z_in,
						B	=>	Z_THRESHOLD,
						eq	=>	OPEN,
						lg	=>	z_lg_th,
						ls	=>	OPEN);
						
	-----------Quadrant Selection Logic-----------
	quad_selector_logic: ENTITY WORK.quadrant_selector_logic
	PORT MAP	(	x_eq_zero	=>	x_eq_zero,
					x_lg_zero	=>	x_lg_zero,
					x_ls_zero	=>	x_ls_zero,
					y_eq_zero	=>	y_eq_zero,
					y_lg_zero	=>	y_lg_zero,
					y_ls_zero	=>	y_ls_zero,
					z_lg_th		=>	z_lg_th,
					q1				=>	q1,
					q2				=>	q2,
					q3				=>	q3,
					q4				=>	q4);

END ARCHITECTURE;