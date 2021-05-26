
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-- CONTROLLER CODE --

entity controller_arctan_CORDIC is
port (
	clk       : in std_logic);
	START     : in std_logic;
	RESET	  : in std_logic;  -- Positive reset 

    X_MSB_MAP : in std_logic;
    Y_MSB_MAP : in std_logic;
    Y_MSB     : in std_logic;

    counter   : out unsigned; 
    clk_1     : out std_logic;
    clk_2     : out std_logic;

    MUX_1     : out std_logic_vector(1 downto 0);
    MUX_2     : out std_logic_vector(1 downto 0);
    MUX_3     : out std_logic_vector(1 downto 0);
    
    DONE      : out std_logic;
   
end entity controller_arctan_CORDIC;


architecture RTL of controller_arctan_CORDIC is 
	-- Enumerated type declaration and state signal declaration
	type t_state is (S1, S2, S3, S4, S5, S6, 
					 	S7, S8, S9, S10, S11, S12); 
	
	signal state: t_state; 

	-- Flag used for holding quadrant information
	signal quadrant_flag : std_logic_vector(1 downto 0);

begin

	process(clk) is
	begin
		if rising_edge(clk) then
			if RESET = '1' then
				-- RESET values
				-- Output resets
		    	MUX_1 <= "00";
    			MUX_2 <= "00";
    			MUX_3 <= "00";
    			DONE <= "0";
    			clk_1 <= '0';
    			clk_2 <= '0';

    			-- Internal resets
    			state <= S1;
				quadrant_flag <= "00";
				counter <= 0;

			else 
			    -- DEFAULT values
				-- Outputs
		    	--MUX_1 <= "00";
    			--MUX_2 <= "00";
    			--MUX_3 <= "00";
    			--DONE <= "0";

    			-- Internal defaults
    			--state <= S1;
				--quadrant_flag <= "00";
			    --counter <= 0; 


				case state is  -- the signal "state" holds the next state 

					when S1 =>
						if START ='1' then -- start is initiated 
							clk_1 <= '1'; -- SET clock 1
							clk_2 <= '0';
	   						state <= S2; 
	   					end if;
						if start = '0' then 
		    				state <= S1; -- back to "standby mode"
						end if;

					------- State: S2 to S5 - Here we perform quadrant detection and mapping --------------------
					when S2 =>
						clk_1 <= '0'; -- RESET clock 1 
 						if X_MSB_MAP = '0' then -- next state logic 
							-- input X is positive meaning that we are either in 1st or 4th quadrant
							state <= S5;
						else	
							if Y_MSB_MAP = '1' then -- next state logic
								-- input Y and X are negative - we are in 3rd quadrant
								state <= S3;
							else 
								-- we are in the 2nd quadrant
								state <= S4;
							end if;
						end if;

					when S3 =>
						MUX_1 <= "01"; -- abs(Y_in) into REG_X
						MUX_2 <= "00"; -- Y_in into REG_Y
						quadrant_flag <= "10"; 
						state <= S6;

					when S4 =>
						MUX_1 <= "10"; -- Y_in into REG_X
						MUX_2 <= "01"; -- abs(X_in) into REG_Y
						quadrant_flag <= "01";
						state <= S6;

					when S5 => 
						MUX_1 <= "00"; -- X_in into REG_X 
						MUX_2 <= "00"; -- Y_in into REG_Y
						quadrant_flag <= "00";
						state <= S6;

					------- State S7 to S9 - Here we perform the CORDIC iterations ------------------------------

					when S6 => 
						clk_2 <= '1'; -- SET clock 2
						state <= S7;

					when S7 =>  -- identical to state 8 
						clk_2 <= '0'; -- RESET clock 2
						MUX_1 <= "11";  -- add X and Y    result in REG X    (shifted Y in following iterations)
						MUX_2 <= "11";  -- sub Y from X   result in REG Y    (shifted X in following iterations)
						MUX_3 <= "01";  -- add Z and atan_LUT(counter) 
						state <= S9;   


					when S9 =>
						clk_2 <= '1'; -- SET clock 2 
						if counter = '12'  then
							-- CORDIC iterations finished do quadrant post correction
							if quadrant_flag = "00" then -- 1st or 4th quadrant
								state <= S12;
							elsif quadrant_flag = "01" then -- 2nd quadrant
								state <= S11;
							elsif quadrant_flag = "10" then -- 3rd quadrant
								state <= S10;
							end if;
		
							-- CORDIC iterations not finished
							counter = counter + 1; 	
							state <= S7;	
						end if;
				
					when S10 =>
						clk_2 <= '0'; -- RESET clock 2
						MUX_3 <= "10";  -- subtract pi/2 to angle Z
						state <= S12;

					when S11 =>
					    clk_2 <= '0'; -- RESET clock 2
						MUX_3 <= "10"  -- add pi/2 to angle Z
						state <= S12;

			 		when S12 =>
			 			clk_2 <= '1'; -- SET clock 2
			 			DONE <= '1';-- resulting angle is now valid in register Z
			 			state <= S1;

			    end case;

			end if; -- end if/else RESET
		end if; -- end if rising edge 

	end process;

end architecture controller_arctan_CORDIC;













