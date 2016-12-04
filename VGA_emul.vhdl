
--------------------------------------------------------------------------------------------------------
--
-- Christophe Duhil
-- 
--
-- projet : mire VGA 
-- Version : 1
--         ----
----------------------------------------------

-----------------------------------------------
--Révision 6
--Test_de l'ensemble et génération d'une image
--Correction d'un décalage sur les dégradés de gris
--Correction d'un pixel sur les lignes du damier
--
--Révsion 5 
--intégration et test des signaux VGA
--
--Révision 4
--test_bench mire
--résolution Bug entity Gray
--Résolution bug entity damier

--révision 3
--mise en place démultiplexer

--résision 2
--révision 1
------------------------------------------------------------------------------------------------------

---------------------------------------------------------------
--
-- Generateur des signaux périodiques VGA
--
--------------------------------------------------------
library ieee;
library std;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use std.all;


entity VGA is
    Port (
        Reset : in std_logic ;
        H_Sync, V_Sync : out std_logic := '1' ;
        Pixel_Clk : out std_logic := '0'
    );
end VGA;

architecture Timed of VGA is
    signal clk : std_logic := '1';
    signal px_clk : std_logic := '0';
    signal h_int : std_logic := '1';
    signal v_int : std_logic := '1';
    signal cnt_v : std_logic_vector(19 downto 0) := (others => '0');
    signal cnt_h : std_logic_vector(19 downto 0) := (others => '0');
begin
    clk_100mhz : process
    begin
        clk <= '1';
        wait for 20 ns;
        clk <= '0';
        wait for 20 ns;
    end process ; -- clk
    
    pxl_clock : process (clk)
    begin
        if clk'event and clk = '1' then
            if not (h_int ='1' or v_int = '1' or cnt_h >= x"2CB" or cnt_v >= x"54417") then -- cnt conditions avoid the last px_clock on H_Sync
                px_clk <= '1';
            elsif h_int = '1' or v_int = '1' then
                px_clk <= '0';
            end if;
        elsif clk'event and clk = '0' then
            px_clk <= '0';
        end if;
        
    end process ; -- pxl_clock

    cnt_clk: process (clk, Reset)
    begin
        if Reset'event and Reset = '0' then
            cnt_v <= (others => '0');
            cnt_h <= (others => '0');
        elsif clk'event and clk = '1' then
            cnt_v <= cnt_v + '1';
            cnt_h <= cnt_h + '1';
            if cnt_h >= x"2CB" then -- 715
                cnt_h <= (others => '0');
            end if;
            if cnt_v >= x"54417" then -- 345111
                cnt_v <= (others => '0');
            end if;
        end if;

    end process; -- cnt_clock

    hsync_clock : process (cnt_h)
    begin
        if cnt_h < x"4B" then -- 75
            h_int <= '1';
        elsif cnt_h >= x"4B" then -- 75
            h_int <= '0';
        end if;
        --h_int <= '1';
        --wait for 3 us;-- 75
        --h_int <= '0';
        --wait for 25.64 us; -- 1 tick + 640
    end process ; -- hsync_clock

    vsync_clock : process (cnt_v)
    begin
        if cnt_v < x"5AF" then -- 1455
            v_int <= '1';
        elsif cnt_v >= x"5AF" then -- 1455
            v_int <= '0';
        end if;
        --v_int <= '1';
        --wait for 58.2 us;--1455
        --v_int <= '0';
        --wait for 13804.44 us;--344655
    end process ; -- vsync_clock

    H_Sync <= h_int;
    V_Sync <= v_int;
    Pixel_Clk <= px_clk;

end Timed;
----------------------------------------------
-- TEST VGA
----------------------------------------------
library worklib;
library ieee;
library std;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use std.all;

entity tb_vga_sig is
end tb_vga_sig;

architecture timed of tb_vga_sig is

    component VGA
        port (
            Reset : in std_logic ;
            H_Sync, V_Sync : out std_logic ;
            Pixel_Clk : out std_logic := '0'
        );
    end component;
    signal h_int : std_logic := '0';
    signal v_int : std_logic := '0';
    signal Pixel_Clk : std_logic := '0';
    signal Reset : std_logic := '0';
    signal cnt : std_logic_vector(9 downto 0) := "0000000001";
    signal line_produced : std_logic := '0';
    signal cnt_lines : std_logic_vector(9 downto 0) := (others => '0');

begin
    iut1 : entity work.VGA(Timed) port map (
        Reset => Reset,
        Pixel_Clk => Pixel_Clk,
        H_Sync => h_int,
        V_Sync => v_int
        );
    counter : process( Pixel_Clk, h_int, v_int )
    begin
        if (h_int'event and h_int = '1') or (v_int'event and v_int = '1') then
            cnt <= (others => '0');
        elsif Pixel_Clk'event and Pixel_Clk = '1' then
            cnt <= cnt + '1';-- 640 rows : 0x01 to 0x280
        end if;
    end process ; -- counter
    check : process( line_produced )
    begin
        if line_produced'event and line_produced = '0' then
            cnt_lines <= cnt_lines + '1';
            -- 480 lines : 0x00 to 0x1df
        end if;
    end process ; -- check
    line_produced <= '1' when cnt = "1010000000" else '0';
    Reset <= '0', '1' after 14 ms, '0' after 14.5 ms;
end timed;



---------------------------------------------------------
--
-- Connexion des composants de la mire
--
--------------------------------------------------------

library ieee;
library std;
use ieee.std_logic_1164.all;

entity Mire is
    Port (
        Reset, Pixel_Clk, H_Sync : in std_logic ;
        R,G,B : out std_logic_vector (7 downto 0)
    );
end Mire;


architecture struct of Mire is
    component line_count is
        port (
            Reset, H_Sync : in std_logic ;
            LC : out std_logic_vector (1 downto 0)
        );
    end component;

    component mul is
        port ( 
            LC : in std_logic_vector (1 downto 0) ;
            clk : in std_logic ;
            M1, M2, M3 : out std_logic := '0'
        );
    end component;

    component RGB is
        port ( 
            Reset, M1 : in std_logic ;
            R1, G1, B1 : out std_logic_vector (7 downto 0)
        );
    end component;

    component gray is
        port ( 
            Reset, M2, H_Sync : in std_logic ;
            R2, G2, B2 : out std_logic_vector (7 downto 0) 
        );
    end component;

    component damier is
        port ( 
            Reset, M3, H_Sync : in std_logic ;
            R3, G3, B3 : out std_logic_vector (7 downto 0)
        );
    end component;

    component Demultiplexer is
        port ( 
            in1, in2, in3 : in std_logic_vector (7 downto 0) ;
            selection : in std_logic_vector (1 downto 0) ;
            s : out std_logic_vector (7 downto 0) 
        );
    end component;

    signal M1, M2, M3 : std_logic := '0';
    signal select_bit : std_logic_vector (1 downto 0);
    signal R1, G1, B1 : std_logic_vector (7 downto 0);
    signal R2, G2, B2 : std_logic_vector (7 downto 0);
    signal R3, G3, B3 : std_logic_vector (7 downto 0);

begin
    line_count0 : line_count port map ( Reset, H_Sync, select_bit );
    mul0 : mul port map ( select_bit, Pixel_clk, M1, M2, M3 );
    rgb0 : RGB port map ( Reset, M1, R1, G1, B1 );
    gray0 : gray port map ( Reset, M2, H_Sync, R2, G2, B2 );
    damier0 : damier port map (Reset, M3, H_Sync, R3, G3, B3 );
    demulR : demultiplexer port map( R1, R2, R3, select_bit, R );
    demulG : demultiplexer port map( G1, G2, G3, select_bit, G );
    demulB : demultiplexer port map( B1, B2, B3, select_bit, B );
end struct;


----------------------------------------------------------------
--
-- Composant compteur de lignes
--
-----------------------------------------------------------------

library ieee;
library std;
library worklib;
use ieee.std_logic_1164.all;


entity line_count is
port (
    Reset, H_Sync : in std_logic ;
    LC : out std_logic_vector (1 downto 0) := "01"
);
end line_count;
 
 
architecture behavioral of line_count is
begin
    process (Reset, H_Sync)
        variable line_nb : integer range 0 to 480; 
    begin
        if Reset'event and Reset = '0' then
            line_nb := 0;
        elsif H_Sync'event  and  H_Sync = '0' and line_nb < 480 then
            line_nb := line_nb +1 ;
        elsif H_Sync'event  and  H_Sync = '0' and line_nb >= 480 then
            line_nb := 1;
        end if;

        if line_nb = 0 then
            LC <= "00";
        elsif line_nb < 161 then
            LC <= "01";
        elsif line_nb < 321 then
            LC <= "10";
        else
            LC <= "11";
        end if;
    end process;
end behavioral;

--------------------------------------------------------------
--
--multiplexer pour selection des composants constituant la mire
--dispatche l'horloge pixel en fonction du motif à réaliser 
--
--------------------------------------------------------------

library ieee;
--library std;-
use ieee.std_logic_1164.all;

entity mul is
    port ( 
        LC : in std_logic_vector (1 downto 0) ;
        clk : in std_logic ;
        M1, M2, M3 : out std_logic := '0'
    );
end mul;


architecture behavioral of mul is
begin
    M1 <= clk when LC = "01" else '0';
    M2 <= clk when LC = "10" else '0';
    M3 <= clk when LC = "11" else '0';
end behavioral;
-----------------------------------------------------------------
-- test bench du multipexer
---------------------------------------------------------------------
library ieee;
--library std;-
use ieee.std_logic_1164.all;

entity tb_mul is
end tb_mul;

architecture test_bench of tb_mul is
signal lc :  std_logic_vector (1 downto 0) ;


begin


end test_bench;


------------------------------------------------------------------------
-- Partie haute de la mire
-- divise l'écran en trois couleurs : rouge, bleu, vert.
-- @param reset redemarre a la couleur rouge
-- @param M1 sortie du demultiplexeur activant l'entite
------------------------------------------------------------------------

library ieee;
--library std;-
use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;
--use std.all;

entity RGB is
port ( 
    Reset, M1 : in std_logic;
    R1, G1, B1 : out std_logic_vector (7 downto 0):= (others => '0')
);
end RGB;

architecture behavioral of RGB is
    signal color : integer range 0 to 3 ;
begin
    process (Reset, M1)
        variable row : integer range 0 to 640 ;
    begin

        if Reset'event and Reset = '0' then
            row := 0;
        elsif M1'event  and  M1 = '1' and row < 640 then
            row := row +1 ;
        elsif M1'event  and  M1 = '1' and row >= 640 then
            row := 1;
        end if;

        if row = 0 then color <= 0 ;
        elsif row < 214 then color <= 1;
        elsif row < 428 then color <= 2;
        else color <= 3;
        end if;
    end process;
    
   
    B1 <= (others => '1') when color = 1 else (others => '0');
    R1 <= (others => '1') when color = 2 else (others => '0');
    G1 <= (others => '1') when color = 3 else (others => '0'); 
end behavioral;

---------------------------------------------------------------  
--
-- Milieu de la mire
-- Genere une serie de degrades de gris de 256 colonnes
--
-------------------------------------------------------------------

library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


entity gray is
port (
    Reset, M2, H_Sync : in std_logic ;
    R2, G2, B2 : out std_logic_vector (7 downto 0):= (others => '0')
);

end gray;

architecture behavioral of gray is
    signal vector_grey : std_logic_vector(7 downto 0) := (others => '0'); 
begin
    process (Reset, M2, H_Sync)
    begin
        if (Reset'event and Reset = '0') or (H_Sync'event and H_Sync ='1') then
            vector_grey <= (others => '0');
        elsif M2'event and M2 = '1' and vector_grey < x"FF" then
            vector_grey <= vector_grey + '1' ;
            R2 <= vector_grey;
            G2 <= vector_grey;
            B2 <= vector_grey;
        elsif M2'event and M2 = '1'and vector_grey >= x"FF" then
            vector_grey <= (others => '0');
            R2 <= (others => '0');
            G2 <= (others => '0');
            B2 <= (others => '0');
        end if;
    end process;     
end behavioral;

---------------------------------------------------------------------------------------------------
--
-- Partie basse de la mire
-- Genere un damier 
--
-------------------------------------------------------------------------------------------------------
library ieee;
library std;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use std.all;


entity damier is
port ( 
    Reset, M3, H_Sync : in std_logic ;
    R3, G3, B3 : out std_logic_vector (7 downto 0):= (others => '0')
);

end damier;
 
architecture Behavioral of damier is
    signal odd_col : boolean := false;
    signal odd_line : boolean := true;
    signal count_col : integer := 0;
begin
    R3 <= (others => '0') when odd_col xor odd_line  else (others => '1');
    G3 <= (others => '0') when odd_col xor odd_line  else (others => '1');
    B3 <= (others => '0') when odd_col xor odd_line  else (others => '1');

    process (H_Sync, Reset, m3)
    Variable count_line_var : integer := 0;
    variable count_col : integer:=0;
    begin
        
        if Reset'event and Reset = '0' then
           count_line_var := 0;
        elsif H_Sync'event and H_Sync = '0' then 
            count_line_var := count_line_var + 1;
            
            if count_line_var < 6  then 
                odd_line <= true;
                
            elsif
                count_line_var >= 6 and count_line_var < 11 then
                odd_line <= false;
            elsif count_line_var >= 11 then
                count_line_var := 1;
                odd_line <= true;
            end if;
        end if;
    
    
        if Reset'event and Reset= '0' then
            count_col := 0;
        elsif m3'event and m3 = '1' then 
            count_col := count_col +1;
            if count_col < 6 then 
                odd_col <= true;
            elsif
                count_col >= 6 and count_col < 11 then
                odd_col <= false;
            elsif count_col >= 11 then
                count_col := 1;
                odd_col <= true;
            end if;
        end if;
    end process;
     


end Behavioral;

------------------------------------------------------------------------------------------------------
--
--multiplexer de sortie de la mire : sélection des signaux RGB en fonction des lignes
--
------------------------------------------------------------------------------------------------------
library ieee;
library std;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use std.all;


entity Demultiplexer is
port ( 
    in1, in2, in3 : in std_logic_vector (7 downto 0) ;
    selection : in std_logic_vector (1 downto 0) := "00" ;
    s : out std_logic_vector (7 downto 0) 
);

end Demultiplexer;

architecture behavioral of demultiplexer is
begin
    process (in1, in2, in3, selection)
        begin
            case selection is
                when "00" => s <= (others => '0');
                when "01" => s <= in1;
                when "10" => s <= in2;
                when "11" => s <= in3;
                when others => s <= (others => '0');
            end case ;
        end process ;
end behavioral;


--------------------------------------------
--
--Testbench de la mire

--------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity tb_mire is
end tb_mire;

architecture test_mire of tb_mire is
    
    signal reset : std_logic := '0';
    signal clk : std_logic := '0';
    signal H_Sync : std_logic := '0';
    signal R, G, B : std_logic_vector(7 downto 0) := (others => '0');
    
begin
    iut1 : entity work.mire(struct) port map (
        Reset => reset,
        Pixel_Clk => clk,
        H_Sync => H_Sync,
        R => R,
        G=> G,
        B => B
    );

    clock : process
    begin
        clk <= '1';
        wait for 20 ns;
        clk <= '0';
        wait for 20 ns;
        
    end process ; -- clock
    
    hsync_clock : process
        begin
            H_Sync <= '1';
            wait for 3 us;
            H_Sync <= '0';
            wait for 25.6 us;
        end process ; -- hsync_clock
        
        


end test_mire;

------------------------------------------
--
-- Conexion des composants VGA et Mire

--------------------------------------------
library ieee;
use ieee.std_logic_1164.all;


entity systems is
    Port(
        Reset: in std_logic := '0' ;
        R, G, B : out std_logic_vector (7 downto 0) ;
        Pixel_Clk, H_Sync, V_Sync : out std_logic
        
    );
end systems;

architecture structure of systems is
    component Mire is
        port (
            Reset, Pixel_Clk, H_Sync : in std_logic ;
            R, G, B : out std_logic_vector (7 downto 0)
            
        );
    end component;
    component VGA is
        port (
            Reset : in std_logic ;
            H_Sync, V_Sync : out std_logic ;
            Pixel_Clk : out std_logic 
        );
    end component;
  
     
    signal px_Clk : std_logic;
    signal hSync : std_logic;
    signal vSync : std_logic;
    signal reset_mire : std_logic := '0';

begin

    
    vga0: VGA port map ( Reset, HSync, vSync, px_Clk );
    mire0: Mire port map ( reset_mire, px_Clk, hSync, R, G, B );
    
    reset_mire <= Reset when vSync = '0' else vSync;
    Pixel_Clk <= px_clk;
    H_Sync <= hsync;
    V_Sync <= vSync;
    
end structure;


--------------------------------------------
-- test bench du Systeme 
------------------------------------------------
library worklib;
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use std.all;

entity tb_system is
end tb_system;

architecture check_mire_output of tb_system is
    signal reset : std_logic := '0';
    signal clk, hsync, vsync : std_logic := '0';
    signal R1, G1, B1 : std_logic_vector(7 downto 0) := (others => '0');
    

    
begin
    iut1 : entity work.systems(structure) port map (
        reset => reset,
        H_Sync => hsync,
        V_Sync => vsync,
        Pixel_Clk => clk,
        R => R1,
        G => G1,
        B => B1
        
    );

end check_mire_output;
