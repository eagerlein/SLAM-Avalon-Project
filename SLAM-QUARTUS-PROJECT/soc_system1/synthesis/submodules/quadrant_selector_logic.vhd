------------------------------------------------------------------------
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
	USE ieee.std_logic_unsigned.all;
LIBRARY WORK;
	USE work.my_package.all;
------------------------------------------------------------------------
ENTITY quadrant_selector_logic IS
	PORT	(	x_eq_zero		:	IN		STD_LOGIC; 	-- Flag for x=0
				x_lg_zero		:	IN		STD_LOGIC; 	-- Flag for x>0
				x_ls_zero		:	IN		STD_LOGIC; 	-- Flag for x<0
				y_eq_zero		:	IN		STD_LOGIC;	-- Flag for y=0
				y_lg_zero		:	IN		STD_LOGIC;	-- Flag for y>0
				y_ls_zero		:	IN		STD_LOGIC;	-- Flag for y<0
				z_lg_th			:	IN		STD_LOGIC;	-- Flag for x>threshold (-380°)	
				q1					:	OUT	STD_LOGIC; 	-- write enable for mem_q1
				q2					:	OUT	STD_LOGIC; 	-- write enable for mem_q2
				q3					:	OUT	STD_LOGIC; 	-- write enable for mem_q3
				q4					:	OUT	STD_LOGIC); 	-- write enable for mem_q4
END ENTITY;
------------------------------------------------------------------------
ARCHITECTURE gate_level OF quadrant_selector_logic IS
BEGIN
	-----------Quadrant Selection Logic-----------
	q1	<=	z_lg_th AND ((x_eq_zero OR x_lg_zero) AND (y_eq_zero OR y_lg_zero));
	q2	<=	z_lg_th AND ((x_ls_zero) AND (y_eq_zero OR y_lg_zero));
	q3	<=	z_lg_th AND ((x_ls_zero) AND (y_ls_zero));
	q4	<=	z_lg_th AND ((x_eq_zero OR x_lg_zero) AND (y_ls_zero));
END ARCHITECTURE;