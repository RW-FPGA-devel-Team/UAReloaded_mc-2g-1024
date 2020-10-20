-------------------------------------------------------------------------------
-- Some files is copyright by Grant Searle 2014
-- You are free to use this files in your own projects but must never charge for it nor use it without
-- acknowledgement.
-- Please ask permission from Grant Searle before republishing elsewhere.
-- If you use this file or any part of it, please add an acknowledgement to myself and
-- a link back to my main web site http://searle.hostei.com/grant/    
-- and to the "multicomp" page at http://searle.hostei.com/grant/Multicomp/index.html
--
-- Please check on the above web pages to see if there are any updates before using this file.
-- If for some reason the page is no longer available, please search for "Grant Searle"
-- on the internet to see if I have moved to another web hosting service.
--
-- Grant Searle
-- eMail address available on my main web page link above.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity multicore_top is
	port (
		-- Clocks
		clock_50_i			: in    std_logic;

		-- Buttons
		btn_n_i				: in    std_logic_vector(4 downto 1);

		-- SRAMs (AS7C34096)
		sram_addr_o			: out   std_logic_vector(18 downto 0)	:= (others => '0');
		sram_data_io		: inout std_logic_vector(7 downto 0)	:= (others => 'Z');
		sram_we_n_o			: out   std_logic								:= '1';
		sram_oe_n_o			: out   std_logic								:= '1';
		
		-- SDRAM	(H57V256)
		sdram_ad_o			: out std_logic_vector(12 downto 0);
		sdram_da_io			: inout std_logic_vector(15 downto 0);

		sdram_ba_o			: out std_logic_vector(1 downto 0);
		sdram_dqm_o			: out std_logic_vector(1 downto 0);

		sdram_ras_o			: out std_logic;
		sdram_cas_o			: out std_logic;
		sdram_cke_o			: out std_logic;
		sdram_clk_o			: out std_logic;
		sdram_cs_o			: out std_logic;
		sdram_we_o			: out std_logic;
	

		-- PS2
		ps2_clk_io			: inout std_logic								:= 'Z';
		ps2_data_io			: inout std_logic								:= 'Z';
		ps2_mouse_clk_io  : inout std_logic								:= 'Z';
		ps2_mouse_data_io : inout std_logic								:= 'Z';

		-- SD Card
		sd_cs_n_o			: out   std_logic								:= '1';
		sd_sclk_o			: out   std_logic								:= '0';
		sd_mosi_o			: out   std_logic								:= '0';
		sd_miso_i			: in    std_logic;

		-- Joysticks
		joy1_up_i			: in    std_logic;
		joy1_down_i			: in    std_logic;
		joy1_left_i			: in    std_logic;
		joy1_right_i		: in    std_logic;
		joy1_p6_i			: in    std_logic;
		joy1_p9_i			: in    std_logic;
		joy2_up_i			: in    std_logic;
		joy2_down_i			: in    std_logic;
		joy2_left_i			: in    std_logic;
		joy2_right_i		: in    std_logic;
		joy2_p6_i			: in    std_logic;
		joy2_p9_i			: in    std_logic;
		joyX_p7_o			: out   std_logic								:= '1';

		-- Audio
		dac_l_o				: out   std_logic								:= '0';
		dac_r_o				: out   std_logic								:= '0';
		ear_i					: in    std_logic;
		mic_o					: out   std_logic								:= '0';

		-- VGA
		VGA_R				   : out   std_logic_vector(7 downto 0)	:= (others => '0');
		VGA_G 				: out   std_logic_vector(7 downto 0)	:= (others => '0');
		VGA_B 				: out   std_logic_vector(7 downto 0)	:= (others => '0');
		VGA_VS		      : out   std_logic								:= '1';
		VGA_HS		   	: out   std_logic								:= '1';
		VGA_CLOCK         : out   std_logic;
		VGA_BLANK         : out   std_logic;


		--STM32
		stm_rx_o				: out std_logic		:= 'Z'; -- stm RX pin, so, is OUT on the slave
		stm_tx_i				: in  std_logic		:= 'Z'; -- stm TX pin, so, is IN on the slave
		stm_rst_o			: out std_logic		:= 'Z'; -- '0' to hold the microcontroller reset line, to free the SD card
		
		stm_a15_io			: inout std_logic;
		stm_b8_io			: inout std_logic		:= 'Z';
		stm_b9_io			: inout std_logic		:= 'Z';
		stm_b12_io			: inout std_logic		:= 'Z';
		stm_b13_io			: inout std_logic		:= 'Z';
		stm_b14_io			: inout std_logic		:= 'Z';
		stm_b15_io			: inout std_logic		:= 'Z'
	);
end entity;

architecture behavior of multicore_top is

	signal pll_locked			: std_logic;
	signal reset_n_s			: std_logic;

	signal clock_master		: std_logic;
	signal clock_vga_s		: std_logic;
	signal clock_dvi_s		: std_logic;

	signal sramAddr			: std_logic_vector(18 downto 0);
	signal sramWE_n			: std_logic;
	signal sramCS_n			: std_logic;
	signal sramOE_n			: std_logic;
	signal serRX				: std_logic;
	signal serTX				: std_logic;
	signal serRTS				: std_logic;
	signal hsync_n				: std_logic;
	signal vsync_n				: std_logic;
	signal blank_s				: std_logic;
	signal vgar					: std_logic_vector(1 downto 0);
	signal vgag					: std_logic_vector(1 downto 0);
	signal vgab					: std_logic_vector(1 downto 0);
	signal tdms_s				: std_logic_vector(7 downto 0);
	signal led					: std_logic;
	

	signal vga_out_s			: std_logic_vector (7 downto 0);

begin

	pll_inst: entity work.pll1
	port map (
		inclk0	=> clock_50_i,
		c0			=> clock_master,		-- 50.000 MHz
		c1			=> clock_vga_s,		-- 25.000
		c2			=> clock_dvi_s,		-- 125.000
		locked	=> pll_locked
	);

	-- Virtual TOP
	v_top: entity work.Microcomputer
	port map (
		n_reset			=> reset_n_s,				--: in std_logic;
		clk				=> clock_master,			--: in std_logic;
		sramData			=> sram_data_io,			--: inout std_logic_vector(7 downto 0);
		sramAddress		=> sramAddr,				--: out std_logic_vector(18 downto 0);
		n_sRamWE			=> sramWE_n,				--: out std_logic;
		n_sRam1CS		=> sramCS_n,				--: out std_logic;
		n_sRamOE			=> sramOE_n,				--: out std_logic;
		rxd1				=> '0',						--: in std_logic;
		txd1				=> open,						--: out std_logic;
		rts1				=> open,						--: out std_logic;
		cts1				=> 'Z',						--: out std_logic;
		rxd2				=> serRX,					--: in std_logic;
		txd2				=> serTX,					--: out std_logic;
		rts2				=> serRTS,					--: out std_logic;
		cts2				=> 'Z',						--: out std_logic;

		videoR0			=> vgar(0),					--: out std_logic;
		videoG0			=> vgag(0),					--: out std_logic;
		videoB0			=> vgab(0),					--: out std_logic;
		videoR1			=> vgar(1),					--: out std_logic;
		videoG1			=> vgag(1),					--: out std_logic;
		videoB1			=> vgab(1),					--: out std_logic;
		hSync				=> hsync_n,					--: out std_logic;
		vSync				=> vsync_n,					--: out std_logic;
		ps2Clk			=> ps2_clk_io,				--: inout std_logic;
		ps2Data			=> ps2_data_io,			--: inout std_logic;
		sdCS				=> sd_cs_n_o,				--: out std_logic;
		sdMOSI			=> sd_mosi_o,				--: out std_logic;
		sdMISO			=> sd_miso_i,				--: in std_logic;
		sdSCLK			=> sd_sclk_o,				--: out std_logic;
		driveLED			=> led						--: out std_logic :='1'	

	);

	-- Glue
	reset_n_s	<= pll_locked and (btn_n_i(3) or btn_n_i(4));

	sram_addr_o		<= sramAddr;
	sram_we_n_o		<= sramWE_n;
	sram_oe_n_o		<= sramOE_n;
	serRX				<= '0';



	vga_out_s <= vgar & '0' & vgag & '0' & vgab;

	VGA_R			<= vga_out_s(7 downto 5) & "00000";
	VGA_G			<= vga_out_s(4 downto 2) & "00000";
	VGA_B			<= vga_out_s(1 downto 0) & "000000";
	VGA_HS	   <= hsync_n;
	VGA_VS	   <= vsync_n;
	VGA_CLOCK   <= clock_master;
	VGA_BLANK   <= '1';
	

end architecture;