----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/01/2026 05:15:24 PM
-- Design Name: 
-- Module Name: Display_Controller - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Display_Controller is
    Port ( clk      : in STD_LOGIC;                     -- The FAST 100MHz clock
           Data_in  : in STD_LOGIC_VECTOR(3 downto 0);  -- The raw CPU output (Reg_Out)
           seg      : out STD_LOGIC_VECTOR(6 downto 0); -- The 7 physical LED segments
           an       : out STD_LOGIC_VECTOR(3 downto 0));-- The 4 display power anodes
end Display_Controller;

architecture Behavioral of Display_Controller is

    -- 1. Import your custom LUT
    component LUT_16_7
        Port ( binary_in : in STD_LOGIC_VECTOR (3 downto 0);
               seven_seg : out STD_LOGIC_VECTOR (6 downto 0));
    end component;

    signal abs_value : STD_LOGIC_VECTOR(3 downto 0);
    signal digit_seg : STD_LOGIC_VECTOR(6 downto 0);
    
    -- Signals to handle the fast flashing (Multiplexing)
    signal refresh_counter : unsigned(19 downto 0) := (others => '0');
    signal active_display  : std_logic_vector(1 downto 0);

begin

    -- 2. Extract the Absolute Value (Magnitude)
    process(Data_in)
    begin
        if Data_in(3) = '1' then 
            -- If Negative: Reverse Two's Complement (Invert bits and add 1)
            abs_value <= std_logic_vector(unsigned(not Data_in) + 1);
        else
            -- If Positive: Pass it straight through
            abs_value <= Data_in;
        end if;
    end process;

    -- 3. Plug the absolute value into your LUT to get the LED pattern
    My_LUT: LUT_16_7 port map(
        binary_in => abs_value,
        seven_seg => digit_seg
    );

    -- 4. The Multiplexer Clock (Creates a fast strobe effect)
    process(clk)
    begin
        if rising_edge(clk) then
            refresh_counter <= refresh_counter + 1;
        end if;
    end process;
    -- Grab bits 19 and 18 to slow down the 100MHz clock to a visible refresh rate
    active_display <= std_logic_vector(refresh_counter(19 downto 18));

    -- 5. Flash the Displays
    process(active_display, digit_seg, Data_in)
    begin
        case active_display is
            when "00" =>
                an <= "1110";       -- Turn ON Display 0 (Rightmost screen)
                seg <= digit_seg;   -- Show the LUT number

            when "01" =>
                an <= "1101";       -- Turn ON Display 1 (Second from right)
                if Data_in(3) = '1' then
                    seg <= "0111111"; -- Show Minus sign (Only the middle 'g' segment is 0)
                else
                    seg <= "1111111"; -- Stay Blank if positive
                end if;

            when others =>
                an <= "1111";       -- Keep Displays 2 and 3 turned OFF completely
                seg <= "1111111";
        end case;
    end process;

end Behavioral;