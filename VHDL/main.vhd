

-- Author: Tor Kaufmann Gjerde

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-- CONTROLLER and datapath for arctan CORDIC co processor --

entity main is
port (

   clk         : in std_logic;
	START       : in std_logic;  -- Positive START
	RESET	      : in std_logic;  -- Positive RESET
	
	X_in		   : in signed(15 downto 0);
	Y_in		   : in signed(15 downto 0);
    
   DONE        : out std_logic;
	counter_out : out integer range 0 to 13;
   REG_X_out   : out signed(15 downto 0);
	
	Z_out       : out signed(15 downto 0)
	
	   );
end entity main;


architecture RTL of main is 

	-- Enumerated type declaration and state signal declaration
	type t_state is (S1, S2, S3, S4, S5, S6,
					 	      S10, S11, S12); 
	
	signal state: t_state; 

	-- flag used for holding quadrant information
	signal quadrant_flag : std_logic_vector(1 downto 0);
	
	-- counter for counting CORDIC iterations
   -- used for both number of shifts and LUT index	
	
	signal counter       : integer range 0 to 13;
	
	signal REG_X_input   : signed(15 downto 0);
	signal REG_Y_input   : signed(15 downto 0);
	signal REG_X         : signed(15 downto 0);
	signal REG_Y         : signed(15 downto 0);
	signal REG_Z         : signed(15 downto 0);

	signal Y_abs         : signed(15 downto 0);
	signal X_abs         : signed(15 downto 0);
		
   signal X_MSB_MAP     : std_logic;
   signal Y_MSB_MAP     : std_logic;
   signal Y_MSB         : std_logic;
	 
	signal X_add_sub     : signed(15 downto 0);
	signal Y_add_sub     : signed(15 downto 0);
	signal Z_add_sub     : signed(15 downto 0);
	
	signal MUX_1         : std_logic_vector(1 downto 0);
   signal MUX_2         : std_logic_vector(1 downto 0);
   signal MUX_3         : std_logic_vector(1 downto 0);
	signal MUX_1_out     : signed(15 downto 0);
	signal MUX_2_out     : signed(15 downto 0);
	signal MUX_3_out     : signed(15 downto 0);
	
	signal LUT_out       : signed(15 downto 0);
	

begin

	-- Mux 1 for selecting input to Register X 
	with MUX_1 select MUX_1_out <=
	REG_X_input  when "00",
	Y_abs        when "01",
	REG_Y_input  when "10",
	X_add_sub    when "11";

	-- Mux 2 for selecting input to Register Y
	with MUX_2 select MUX_2_out <= 
	REG_Y_input   when "00",
	X_abs         when "01",
	REG_X_input   when "10",
	Y_add_sub     when "11";

	-- Mux 3 for selecting input to Register Z
	with MUX_3 select MUX_3_out <=
	"0000000000000000" when "00", -- zero
	LUT_out    			 when "01", -- LUT 
	"0011001001000100" when "10", -- pi half 
	"0000000000000000" when "11"; -- zero (not used) 

	-- arctan Look Up Table - 16 bit (13 bit fraction)
	with counter select LUT_out <=
	"0001100100100010" when 0, -- decimal: 0.78...
	"0000111011010110" when 1, -- decimal:
	"0000011111010111" when 2, -- decimal:
	"0000001111111011" when 3,
	"0000000111111111" when 4,
	"0000000100000000" when 5,
	"0000000010000000" when 6,
	"0000000001000000" when 7,
	"0000000000100000" when 8,
	"0000000000010000" when 9,
	"0000000000001000" when 10,
	"0000000000000100" when 11,
	"0000000000000010" when 12,
	"0000000000000000" when 13;

	
	
	process(clk) is
	begin
		if rising_edge(clk) then
			if RESET = '1' then -- Synchronous reset
				-- RESET, output values
		    	MUX_1 <= "00";
    			MUX_2 <= "00";
    			MUX_3 <= "00";
    			DONE <= '1';


    			-- RESET, Internal values
    			state <= S1;
				quadrant_flag <= "00";
				counter <= 0;
				Z_add_sub <= "0000000000000000";
				
			else

				case state is  -- the signal "state" holds the next state 

					when S1 =>
						if START = '0' then 
							DONE <= '1';
							state <= S1; -- stay in S1 "standby mode"
						end if;
						
						if START ='1' then -- start is initiated 
							DONE <= '0';
							REG_X_input <= X_in;  -- Input register X is filled 
			            REG_Y_input <= Y_in;  -- input register Y is filled
								
							X_MSB_MAP <= X_in(15); -- get MSB used for quadrant detection and mapping
			            Y_MSB_MAP <= Y_in(15);
							
							X_abs <= abs(X_in); -- get absolute value used for quadrant mapping
							Y_abs <= abs(Y_in);

	   					state <= S2;  -- next state 	
						end if;
						

						
					------- State: S2 - Here we perform quadrant mapping --------------------
					when S2 =>
						-- Open the right output from the MUXes. The value is propagated through the MUX and into 
						-- corresponding register in the next state (S3)
						
					   counter <= 0; -- initialize counter
					   counter_out <= 0;	
						MUX_3 <= "00"; -- open up for initializing REG_Z to 0
						
						if X_MSB_MAP = '0' then -- 1st or 4th quadrant
							-- input X is positive meaning that we are either in 1st or 4th quadrant
							MUX_1 <= "00"; -- open up for X_in straight into REG_X 
							MUX_2 <= "00"; -- open up for Y_in straight into REG_Y
							quadrant_flag <= "00";
							state <= S3;
						else
						
							if Y_MSB_MAP = '1' then -- 3rd Quadrant
								MUX_1 <= "01"; -- abs(Y_in) into REG_X (mapping)
								MUX_2 <= "00"; -- Y_in into REG_Y (mapping)
								quadrant_flag <= "10"; 
								state <= S3;
							else 
								-- we are in the 2nd quadrant
								MUX_1 <= "10"; -- Y_in into REG_X
								MUX_2 <= "01"; -- abs(X_in) into REG_Y
								quadrant_flag <= "01";
								state <= S3;
								
							end if;
							
						end if;
						
	
					------- State 3 to 5 - Here we perform the CORDIC iterations -----------------------------	
				   
					when S3 =>
						REG_X <= MUX_1_out; -- insert value into register X
						REG_X_out <= MUX_1_out; -- used for testing
						REG_Y <= MUX_2_out; -- insert value into register Y 
						REG_Z <= Z_add_sub; -- insert value into register Z (on first iteration value is 0)
						Z_out <= Z_add_sub;
						
					   Y_MSB <= MUX_2_out(15); -- get the MSB of Y
						
						MUX_3 <= "01"; -- update MUX_3 therby opening up for arctan LUT
						
						-- Alternatively we continue to quadrant post mapping (PQM) if iterations are done.
						-- we want to make maximum 12 iterations (ie. 12 shifts)
						
						if counter = 13 then 
							state <= S6;
						else
							state <=S4; -- Do more iterations
						end if;
						
					
					-- first iteration -> counter should be zero. ie. no shifts take place 
					When S4 =>
						-- CORDIC updates
						if Y_MSB = '1' then 
							X_add_sub <= REG_X - shift_right(REG_Y, counter);
							Y_add_sub <= REG_Y + shift_right(REG_X, counter);
							Z_add_sub <= REG_Z - MUX_3_out; -- the LUT with "counter" used as index
						else
							X_add_sub <= REG_X + shift_right(REG_Y, counter);
							Y_add_sub <= REG_Y - shift_right(REG_X, counter);
							Z_add_sub <= REG_Z + MUX_3_out; -- the LUT with "counter" used as index
						end if;
						
						state <= S5;
				
					
					when S5 => 
					-- We now need to update the MUXes output and the counter making them ready for 
					-- the next iteration starting again from S3.  
						MUX_1 <= "11"; 
					   MUX_2 <= "11";
						
						counter <= counter + 1;
						counter_out <= counter + 1;
						state <= S3;
					
					
					when S6 =>
					-- CORDIC iterations done - peform PQM
						if quadrant_flag = "00" then -- 1st or 4th quadrant
							state <= S12;  -- no correction needed 
							
						elsif quadrant_flag = "01" then -- 2nd quadrant
						   MUX_3 <= "10";  -- open up MUX_3 in order to add pi/2 to angle Z
							state <= S11;
							
						elsif quadrant_flag = "10" then -- 3rd quadrant
							MUX_3 <= "10";  -- open up MUX_3 in order to subtract pi/2 from angle Z
							state <= S10;
						end if;
					
				
					when S10 =>
					   -- subtract pi/2 from angle Z
						REG_z <= REG_Z - MUX_3_out; 
						state <= S12;

					when S11 =>
						-- add pi/2 to angle Z
						REG_z <= REG_Z + MUX_3_out;   
						state <= S12;

			 		when S12 =>
			 			DONE <= '1'; -- resulting angle is now valid in register Z
			 			state <= S1; -- BAck to "standy mode" is state 1
						
			    end case;

			end if; -- end if RESET
			
		end if; -- end if rising edge 

	end process;

end architecture RTL;
