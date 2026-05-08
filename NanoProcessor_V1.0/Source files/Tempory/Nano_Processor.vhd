----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/30/2026 04:52:13 PM
-- Design Name: 
-- Module Name: Nano_Processor - Behavioral
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
use WORK.BusDef.All;
use WORK.constants.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Nano_Processor is
--  Port ( );
    Port ( 
           clk      : in STD_LOGIC;
           reset    : in STD_LOGIC;
           Overflow : out STD_LOGIC;
           Zero     : out STD_LOGIC;
           Reg_Out  : out Data_bus; -- Usually connected to R7
           seg      : out STD_LOGIC_VECTOR(6 downto 0); -- To the 7-seg segments
           an       : out STD_LOGIC_VECTOR(3 downto 0)
         );
end Nano_Processor;   

architecture Structural of Nano_Processor is
    component slow_clock
        Port ( clk_in  : in STD_LOGIC;
               clk_out : out STD_LOGIC);
    end component;
    
    component Program_Counter
        Port ( D     : in Address_bus;
               Clk   : in STD_LOGIC;
               Reset : in STD_LOGIC;
               Q     : out Address_bus);
        end component;
        
    component RCA_3 
        Port ( A     : in Address_bus;  
               B     : in Address_bus;  
               C_in  : in STD_LOGIC;
               S     : out Address_bus; 
               C_out : out STD_LOGIC);
    end component;
    
    component Mux_2Way_3bit
        Port ( In0     : in Address_bus;
               In1     : in Address_bus;
               sel     : in STD_LOGIC;
               out_mux : out Address_bus);
    end component;
    
    component Instruction_Decoder
        Port ( 
            Instruction        : in Instruction_bus;   
            Reg_val_for_Jump   : in Data_bus;          
            Register_address   : out Address_bus;      
            Register_select_A  : out Address_bus;      
            Register_select_B  : out Address_bus;      
            Immediate_value    : out Data_bus;         
            ADD_SUB_Select     : out STD_LOGIC;        
            Load_select        : out STD_LOGIC;        
            Jump_flag          : out STD_LOGIC;        
            Jump_Addr          : out Address_bus       
        );
    end component;
    
    component Program_ROM
        Port ( Instruction   : out Instruction_bus;
               Memory_Select : in Address_bus);
    end component;
    
    component Mux_2Way_4bit
        Port ( In0     : in Data_bus;
               In1     : in Data_bus;
               sel     : in STD_LOGIC;
               out_mux : out Data_bus);
        end component;
        
     component RegBank
        Port ( Clk              : in STD_LOGIC;
               Reset            : in STD_LOGIC;
               Data_in          : in Data_bus;
               Register_Address : in Address_bus;
               Data_out         : out Data_Bus_8x4 
              );
    end component;
    
    component Mux_8way_4bit
        Port ( input_bus  : in Data_Bus_8x4;
               reg_select : in Address_bus;
               output_bus : out Data_bus);
    end component;
    
    component ALU 
        port ( A : in Data_bus;
               B : in Data_bus;
               Add_Sub_Sel : in STD_LOGIC;
               S : out Data_bus;
               Zero : out STD_LOGIC;
               Overflow : out STD_LOGIC);
   end component;
   
   component Display_Controller
       Port ( clk      : in STD_LOGIC;
              Data_in  : in STD_LOGIC_VECTOR(3 downto 0);
              seg      : out STD_LOGIC_VECTOR(6 downto 0);
              an       : out STD_LOGIC_VECTOR(3 downto 0));
   end component;
    
    
    signal slow_clk : STD_LOGIC;
    signal next_pc : Address_bus;
    signal current_pc : Address_bus;
    signal Adder_out : Address_bus;
    signal jump_addr : Address_bus := "000";
    signal jump_flag : STD_LOGIC := '0';
    signal current_Instruction : Instruction_bus;
    signal reg_sel_A : Address_bus;
    signal reg_sel_B : Address_bus;
    signal reg_en : Address_bus;
    signal immediate : Data_bus;
    signal add_sub    : STD_LOGIC;
    signal load_sel   : STD_LOGIC;
    signal alu_out : Data_bus;
    signal data_to_reg : Data_bus;
    signal reg_array : Data_Bus_8x4;
    signal mux_a_out : Data_bus;
    signal mux_b_out : Data_bus;
    signal zero_flag : STD_LOGIC;
    signal overflow_flag : STD_LOGIC;
    
 
begin
    -- The Clock Divider
    CPU_Clock: slow_clock port map (
        clk_in  => clk,
        clk_out => slow_clk
    );
    
    PC: Program_Counter port map (
        D     => next_pc,
        Clk   => slow_clk, 
        Reset => reset,
        Q     => current_pc
     );
     
     ADDER_3_bit : RCA_3 port map(
        A => current_pc,
        B =>"001",
        C_in => '0',
        S => adder_out,
        C_out => open
     );
     
     PC_MUX: Mux_2Way_3bit port map (
         In0     => Adder_out,   -- The normal counting path
         In1     => jump_addr,   -- The jump path (currently 000)
         sel     => jump_flag,   -- The jump switch (currently 0)
         out_mux => next_pc      -- Plugs right back into the PC!
     );
     
     ROM : Program_ROM port map (
         Instruction     =>  current_Instruction,     -- Instruction form the ROM
         Memory_Select   =>  current_pc
     );
     
     Ins_Decoder : Instruction_Decoder port map(
         Instruction        => current_instruction,     -- IN: The 12-bit code from the ROM
         Reg_val_for_Jump   => mux_a_out,   -- IN: Temporarily hardwired to "0000"
         
         Register_address   => reg_en,             -- OUT: Which register to save to
         Register_select_A  => reg_sel_A,          -- OUT: Which register to send to MUX A
         Register_select_B  => reg_sel_B,          -- OUT: Which register to send to MUX B
         Immediate_value    => immediate,          -- OUT: The number value (e.g., the '5' in MOVI)
         ADD_SUB_Select     => add_sub,            -- OUT: Tells ALU to Add (0) or Subtract (1)
         Load_select        => load_sel,           -- OUT: Controls the MUX before the Register Bank
         Jump_flag          => jump_flag,          -- OUT: Directly controls your PC MUX!
         Jump_Addr          => jump_addr           -- OUT: Directly controls your PC MUX!
     
     );
     
     Load_mux : Mux_2way_4bit port map(
          In0 => immediate,
          In1 => alu_out,
          sel => load_sel,
          out_mux => data_to_reg     
     );
     
     Registers : RegBank port map (
         Clk              => slow_clk,    -- IN: The heartbeat of the CPU
         Reset            => reset,            -- IN: The main motherboard reset switch
         Data_in          => data_to_reg, -- IN: The data coming from the Load Mux
         Register_Address => reg_en,      -- IN: Which register to save to (From Decoder)
         Data_out         => reg_array    -- OUT: Blasts all 8 registers out onto the motherboard!
     );
     
     Mux_A : Mux_8way_4bit port map (
        input_bus => reg_array,
        reg_select => reg_sel_A,
        output_bus => mux_a_out
     );
     
     Mux_B : Mux_8way_4bit port map (
        input_bus => reg_array,
        reg_select => reg_sel_B,
        output_bus => mux_b_out
     );
     
     Main_ALU : ALU port map(
        A => mux_a_out,
        B => mux_b_out,
        Add_Sub_Sel => add_sub,
        S => alu_out,
        Zero => zero_flag,
        Overflow => overflow_flag
     );
     
     Seven_Seg_Driver: Display_Controller port map(
          clk     => clk,             
          Data_in => reg_array(7),    
          seg     => seg,             
          an      => an               
      );
     Reg_Out <= reg_array(7);
          
      -- Send the ALU status flags out to the LEDs
      Zero     <= zero_flag;
      Overflow <= overflow_flag;
     
end Structural;
