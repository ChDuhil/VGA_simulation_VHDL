----------------------------------------------------------------------------------
-- Company: UBO
-- Engineer: Christophe Duhil
-- 
-- Create Date: 10.10.2016 09:19:56
-- Design Name: 
-- Module Name: System_to_File - Behavioral
-- Project Name: Projet VGA
-- Target Devices: none
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- this module is a bridge between VGA structure and the final testBench
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity System_to_File is
    Port ( reset : in STD_LOGIC);
end System_to_File;

architecture structure of System_to_File is
component systems is
    Port(
        Reset: in std_logic := '0' ;
        R, G, B : out std_logic_vector (7 downto 0) ;
        Pixel_Clk, H_Sync, V_Sync : out std_logic
        
    );
end component;

component image_file is
  generic ( V_SIZE :integer := 480;
   H_SIZE : integer := 640);
  port ( clk, reset : in std_logic;
         r,g,b      : in std_logic_vector);
end component;




signal r, g, b : std_logic_vector (7 downto 0);
signal Pixel_Clk : std_logic;

begin



image_file0 : image_file port map ( Pixel_Clk, reset, r,g, b);
system0 : systems port map ( reset, r, g, b, Pixel_Clk);


end structure;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_system_to_file is
end entity;


architecture tb_syst of tb_system_to_file is

signal reset : std_logic :='0';

begin

    iut : entity work.System_to_File(structure)
    port map (
        reset => reset
        
        );

reset <= '0', '1' after 10 ns, '0' after 60 ns ;

end tb_syst;
