-------------------------------------------------------------------------------
-- Title         : 10G MAC / Import Interface
-- Project       : RCE 10G-bit MAC
-------------------------------------------------------------------------------
-- File          : XMacImport.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 02/11/2008
-------------------------------------------------------------------------------
-- Description:
-- PIC Import block for 10G MAC core for the RCE.
-------------------------------------------------------------------------------
-- Copyright (c) 2008 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 02/11/2008: created.
-- 02/23/2008: Fixed error which occurs when receiving back to back packets with
--             an idle charactor removal. crcShift4 had not cleared in time.
-- 02/29/2008: Incoming data is now ignored when phy is not ready. Byte order
--             is swapped at PIC interface. 
-- 06/06/2008: Removed header/payload re-alignment. Added automated pause frame
--             reception and transmission.
-- 08/05/2008: Added extra stages to frameShift shift register and added 
--             end detect shift register. These two shift registers replace
--             the function of crcShift register lines that are always asserted
--             in some back to back frame cases.
-- 04/22/2014: Adapted for AXI Streaming interface.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;

entity XMacImport is 
   generic (
      TPD_G         : time                := 1 ns;
      PAUSE_THOLD_G : integer             := 255;
      ADDR_WIDTH_G  : integer             := 9;
      EOH_BIT_G     : integer             := 0;
      ERR_BIT_G     : integer             := 0;
      HEADER_SIZE_G : integer             := 16; -- Number of 64-bit values to include in the header
      AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C
   );
   port ( 

      -- PPI Interface   
      dmaClk           : in  sl;
      dmaClkRst        : in  sl;
      dmaIbMaster      : out AxiStreamMasterType;
      dmaIbSlave       : in  AxiStreamSlaveType;

      -- XAUI Interface
      phyClk           : in  sl;
      phyRst           : in  sl;
      phyRxd           : in  slv(63 downto 0);
      phyRxc           : in  slv(7  downto 0);
      phyReady         : in  sl;

      -- Local mac address
      macAddress       : in  slv(47 downto 0);

      -- Pause Values
      rxPauseReq       : out sl;
      rxPauseSet       : out sl;
      rxPauseValue     : out slv(15 downto 0);

      -- Status
      rxCountEn        : out sl;
      rxOverFlow       : out sl;
      rxCrcError       : out sl
   );
end XMacImport;


-- Define architecture
architecture XMacImport of XMacImport is

   -- Local Signals
   signal frameShift0      : sl;
   signal frameShift1      : sl;
   signal frameShift2      : sl;
   signal frameShift3      : sl;
   signal frameShift4      : sl;
   signal frameShift5      : sl;
   signal rxdAlign         : sl;
   signal dlyRxd           : slv(31 downto 0);
   signal crcDataWidth     : slv(2  downto 0);
   signal nxtCrcWidth      : slv(2  downto 0);
   signal nxtCrcValid      : sl;
   signal crcDataValid     : sl;
   signal crcFifoIn        : slv(63 downto 0);
   signal crcFifoOut       : slv(63 downto 0);
   signal phyRxcDly        : slv(7  downto 0);
   signal crcWidthDly0     : slv(2  downto 0);
   signal crcWidthDly1     : slv(2  downto 0);
   signal crcWidthDly2     : slv(2  downto 0);
   signal crcWidthDly3     : slv(2  downto 0);
   signal crcShift0        : sl;
   signal crcShift1        : sl;
   signal endDetect        : sl;
   signal endShift0        : sl;
   signal endShift1        : sl;
   signal pauseShift2      : sl;
   signal pauseShift3      : sl;
   signal crcGood          : sl;
   signal intLastLine      : sl;
   signal intAdvance       : sl;
   signal lastSOF          : sl;
   signal pauseDet         : sl;
   signal dlyPause         : sl;
   signal intPause         : sl;
   signal crcIn            : slv(63 downto 0); 
   signal crcInit          : sl; 
   signal crcReset         : sl; 
   signal crcOut           : slv(31 downto 0); 
   signal intIbMaster      : AxiStreamMasterType;
   signal intIbCtrl        : AxiStreamCtrlType;
   signal macData          : slv(63 downto 0);
   signal macSize          : slv(2 downto 0);
   signal writeCount       : slv(15 downto 0);

begin

   ------------------------------------------
   -- PPI FIFO
   ------------------------------------------

   -- PPI FIFO
   U_OutFifo : entity work.AxiStreamFifo 
      generic map (
         TPD_G                => TPD_G,
         PIPE_STAGES_G        => 0,
         SLAVE_READY_EN_G     => false,
         VALID_THOLD_G        => 0,
         BRAM_EN_G            => true,
         XIL_DEVICE_G         => "7SERIES",
         USE_BUILT_IN_G       => false,
         GEN_SYNC_FIFO_G      => false,
         CASCADE_SIZE_G       => 1,
         FIFO_ADDR_WIDTH_G    => ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G  => true,
         FIFO_PAUSE_THRESH_G  => PAUSE_THOLD_G,
         SLAVE_AXI_CONFIG_G   => AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G  => AXIS_CONFIG_G 
      ) port map (
         sAxisClk        => phyClk,
         sAxisRst        => phyRst,
         sAxisMaster     => intIbMaster,
         sAxisSlave      => open,
         sAxisCtrl       => intIbCtrl,
         mAxisClk        => dmaClk,
         mAxisRst        => dmaClkRst,
         mAxisMaster     => dmaIbMaster,
         mAxisSlave      => dmaIbSlave
      );


   -- Register stage and EOH generation
   process ( phyClk ) is
      variable varMaster : AxiStreamMasterType;
   begin
      if rising_edge(phyClk) then
         varMaster := AXI_STREAM_MASTER_INIT_C;

         if phyRst = '1' then
            writeCount <= (others=>'0') after TPD_G;
            rxPauseReq <= '0'           after TPD_G;
         else
            varMaster.tData(63 downto 0) := macData;
            varMaster.tLast              := intLastLine;
            varMaster.tValid             := intAdvance;

            -- Keep
            varMaster.tKeep(7 downto 0)                     := (others=>'0');
            varMaster.tKeep(conv_integer(macSize) downto 0) := (others=>'1');

            if (HEADER_SIZE_G /= 0) and (writeCount = (HEADER_SIZE_G-1)) then
               axiStreamSetUserBit(AXIS_CONFIG_G, varMaster, EOH_BIT_G, '1');
            end if;

            if intLastLine = '1' then
               axiStreamSetUserBit(AXIS_CONFIG_G, varMaster, ERR_BIT_G, not crcGood);
            end if;

            rxPauseReq <= intIbCtrl.pause after TPD_G;

            if intAdvance = '1' then
               if intLastLine = '1' then
                  writeCount <= (others=>'0') after TPD_G;
               else
                  writeCount <= writeCount + 1 after TPD_G;
               end if;
            end if;
         end if;
      end if;

      intIbMaster <= varMaster;

   end process;


   ------------------------------------------
   -- Mac Logic
   ------------------------------------------

   -- Errors and counter
   rxCrcError <= intAdvance and intLastLine and (not crcGood);
   rxCountEn  <= intAdvance and intLastLine and crcGood;

   -- Logic to dermine CRC width and valid clear timing.
   process ( phyRxc, rxdAlign, phyRxcDly, crcDataWidth, crcDataValid ) begin

      -- Non shifted data
      if rxdAlign = '0' then
         case phyRxc is
            when x"00"  => nxtCrcWidth <= "111"; nxtCrcValid <= '1'; 
            when x"FE"  => nxtCrcWidth <= "000"; nxtCrcValid <= '1'; 
            when x"FC"  => nxtCrcWidth <= "001"; nxtCrcValid <= '1';
            when x"F8"  => nxtCrcWidth <= "010"; nxtCrcValid <= '1';
            when x"F0"  => nxtCrcWidth <= "011"; nxtCrcValid <= '1';
            when x"E0"  => nxtCrcWidth <= "100"; nxtCrcValid <= '1';
            when x"C0"  => nxtCrcWidth <= "101"; nxtCrcValid <= '1';
            when x"80"  => nxtCrcWidth <= "110"; nxtCrcValid <= '1';
            when x"FF"  => nxtCrcWidth <= "000"; nxtCrcValid <= '0';
            when others => nxtCrcWidth <= "000"; nxtCrcValid <= '0';
         end case;

      -- Shifted data
      else 

         -- Some widths look at the shifted control output
         case phyRxcDly is 
            when x"E0"  => nxtCrcWidth <= "000"; nxtCrcValid <= '1';
            when x"C0"  => nxtCrcWidth <= "001"; nxtCrcValid <= '1';
            when x"80"  => nxtCrcWidth <= "010"; nxtCrcValid <= '1';
            when x"F0"  => nxtCrcWidth <= "000"; nxtCrcValid <= '0';
            when x"FF"  => nxtCrcWidth <= "000"; nxtCrcValid <= '0';
            when x"00"  =>

               -- other widths look at the direct control output
               case phyRxc is
                  when x"FF"  => nxtCrcWidth <= "011";        nxtCrcValid <= '1';
                  when x"FE"  => nxtCrcWidth <= "100";        nxtCrcValid <= '1';
                  when x"FC"  => nxtCrcWidth <= "101";        nxtCrcValid <= '1';
                  when x"F8"  => nxtCrcWidth <= "110";        nxtCrcValid <= '1';
                  when others => nxtCrcWidth <= crcDataWidth; nxtCrcValid <= crcDataValid;
               end case;
            when others => nxtCrcWidth <= "000"; nxtCrcValid <= '0';
         end case;
      end if;
   end process;


   -- Delay stages and input to CRC block   
   process ( phyClk ) begin
      if rising_edge(phyClk) then
         if phyRst = '1' then
            frameShift0    <= '0'           after TPD_G;
            frameShift1    <= '0'           after TPD_G;
            frameShift2    <= '0'           after TPD_G;
            frameShift3    <= '0'           after TPD_G;
            frameShift4    <= '0'           after TPD_G;
            frameShift5    <= '0'           after TPD_G;
            rxdAlign       <= '0'           after TPD_G;
            lastSOF        <= '0'           after TPD_G;
            dlyRxd         <= (others=>'0') after TPD_G;
            crcInit        <= '0'           after TPD_G;
            crcDataValid   <= '0'           after TPD_G;
            crcDataWidth   <= "000"         after TPD_G;
            endDetect      <= '0'           after TPD_G;
            crcFifoIn      <= (others=>'0') after TPD_G;
            phyRxcDly      <= (others=>'0') after TPD_G;
            pauseDet       <= '0'           after TPD_G;
            rxPauseValue   <= (others=>'0') after TPD_G;
         else 

            -- Delayed copy of control signals
            phyRxcDly <= phyRxc after TPD_G;

            -- Detect SOF in shifted position
            if phyRxC(4) = '1' and phyRxd(39 downto 32) = x"FB" then
               lastSOF <= '1' after TPD_G;
            else
               lastSOF <= '0' after TPD_G;
            end if;

            -- Detect start of frame
            -- normal alignment
            if phyRxC(0) = '1' and phyRxd(7 downto 0) = x"FB" and phyReady = '1' then
               frameShift0 <= '1' after TPD_G;
               rxdAlign    <= '0' after TPD_G;

            -- shifted aligment
            elsif lastSOF = '1' and phyReady = '1' then
               frameShift0 <= '1' after TPD_G;
               rxdAlign    <= '1' after TPD_G;

            -- Detect end of frame
            elsif phyRxc /= 0 and frameShift0 = '1' then
               frameShift0 <= '0' after TPD_G;
            end if;

            -- Frame shift register
            frameShift1 <= frameShift0 after TPD_G;
            frameShift2 <= frameShift1 after TPD_G;
            frameShift3 <= frameShift2 after TPD_G;
            frameShift4 <= frameShift3 after TPD_G;
            frameShift5 <= frameShift4 after TPD_G;

            -- Delayed copy of upper data
            dlyRxd <= phyRxd(63 downto 32) after TPD_G;

            -- CRC Valid Signal
            if frameShift0 = '1' and frameShift1 = '0' then
               crcInit      <= '1'   after TPD_G;
               crcDataValid <= '1'   after TPD_G;
               crcDataWidth <= "111" after TPD_G;
            else
               crcInit <= '0' after TPD_G;

               -- Clear valid when width is not zero
               if crcDataWidth /= 7 then
                  crcDataValid <= '0'           after TPD_G;
                  crcDataWidth <= (others=>'0') after TPD_G;
               else
                  crcDataValid <= nxtCrcValid after TPD_G;
                  crcDataWidth <= nxtCrcWidth after TPD_G;
               end if;
            end if;

            -- End Detection
            if (crcDataWidth /= 7 or nxtCrcValid = '0') and crcDataValid = '1' then
               endDetect <= '1' after TPD_G;
            else
               endDetect <= '0' after TPD_G;
            end if;

            -- CRC & FIFO Input data
            if rxdAlign = '0' then
               crcFifoIn <= phyRxd after TPD_G;
            else
               crcFifoIn(63 downto 32) <= phyRxd(31 downto 0) after TPD_G;
               crcFifoIn(31 downto  0) <= dlyRxd              after TPD_G;
            end if;

            -- Pause frame detection
            if frameShift2 = '1' and frameShift3 = '0' and crcFifoIn(63 downto 32) = x"01000888" then
               pauseDet <= '1' after TPD_G;
            else
               pauseDet <= '0' after TPD_G;
            end if;

            -- Pause frame value
            if pauseDet = '1' then
               rxPauseValue <= (crcFifoIn(7 downto 0) & crcFifoIn(15 downto 8)) after TPD_G;
            end if;
         end if;
      end if;
   end process;


   -- CRC Delay FIFO
   U_CrcFifo: entity work.Fifo
      generic map (
         TPD_G              => TPD_G,
         RST_POLARITY_G     => '1',
         RST_ASYNC_G        => false,
         GEN_SYNC_FIFO_G    => true,
         BRAM_EN_G          => false,
         FWFT_EN_G          => false,
         USE_DSP48_G        => "no",
         USE_BUILT_IN_G     => false,
         XIL_DEVICE_G       => "7SERIES",
         SYNC_STAGES_G      => 3,
         DATA_WIDTH_G       => 64,
         ADDR_WIDTH_G       => 4,
         INIT_G             => "0",
         FULL_THRES_G       => 1,
         EMPTY_THRES_G      => 1
      ) port map (
         rst           => phyRst,
         wr_clk        => phyClk,
         wr_en         => crcDataValid,
         din           => crcFifoIn,
         wr_data_count => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         not_full      => open,
         rd_clk        => phyClk,
         rd_en         => crcShift1,
         dout          => crcFifoOut,
         rd_data_count => open,
         valid         => open,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open
      );


   -- Delay stages for output of CRC delay chain
   process ( phyClk ) begin
      if rising_edge(phyClk) then
         if phyRst = '1' then
            macSize      <= (others=>'0') after TPD_G;
            macData      <= (others=>'0') after TPD_G;
            crcShift0    <= '0'           after TPD_G;
            crcShift1    <= '0'           after TPD_G;
            endShift0    <= '0'           after TPD_G;
            endShift1    <= '0'           after TPD_G;
            pauseShift2  <= '0'           after TPD_G;
            pauseShift3  <= '0'           after TPD_G;
            crcWidthDly0 <= (others=>'0') after TPD_G;
            crcWidthDly1 <= (others=>'0') after TPD_G;
            crcWidthDly2 <= (others=>'0') after TPD_G;
            crcWidthDly3 <= (others=>'0') after TPD_G;
            intLastLine  <= '0'           after TPD_G;
            intAdvance   <= '0'           after TPD_G;
            dlyPause     <= '0'           after TPD_G;
            intPause     <= '0'           after TPD_G;
            rxPauseSet   <= '0'           after TPD_G;
         else

            -- CRC output shift stages
            crcShift0 <= crcDataValid after TPD_G;
            crcShift1 <= crcShift0    after TPD_G;

            -- CRC Width Delay Stages
            crcWidthDly0 <= crcDataWidth after TPD_G;
            crcWidthDly1 <= crcWidthDly0 after TPD_G;
            crcWidthDly2 <= crcWidthDly1 after TPD_G;
            crcWidthDly3 <= crcWidthDly2 after TPD_G;

            -- Last Data Shift
            endShift0 <= endDetect after TPD_G;
            endShift1 <= endShift0 after TPD_G;

            -- Pause Detection Delay Stages
            pauseShift2 <= pauseDet or (pauseShift2 and frameShift3) after TPD_G;
            pauseShift3 <= pauseShift2                               after TPD_G;

            -- Output data
            macData(63 downto 56) <= crcFifoOut(39 downto 32) after TPD_G;
            macData(55 downto 48) <= crcFifoOut(47 downto 40) after TPD_G;
            macData(47 downto 40) <= crcFifoOut(55 downto 48) after TPD_G;
            macData(39 downto 32) <= crcFifoOut(63 downto 56) after TPD_G;
            macData(31 downto 24) <= crcFifoOut( 7 downto  0) after TPD_G;
            macData(23 downto 16) <= crcFifoOut(15 downto  8) after TPD_G;
            macData(15 downto  8) <= crcFifoOut(23 downto 16) after TPD_G;
            macData( 7 downto  0) <= crcFifoOut(31 downto 24) after TPD_G;

            -- Pause Frame Received, assert for two clocks
            intPause   <= intLastLine and crcGood and (pauseShift2 or pauseShift3) after TPD_G;
            dlyPause   <= intPause after TPD_G;
            rxPauseSet <= intPause or dlyPause after TPD_G;

            -- Determine when data is output
            if frameShift4 = '1' and frameShift5 = '0' and pauseShift2 = '0' then
               intAdvance <= '1' after TPD_G;
            elsif intLastLine = '1' then
               intAdvance <= '0' after TPD_G;
            end if;

            -- Determine Last Line
            if endShift0 = '1' and crcWidthDly1 = 0 then
               macSize     <= "100" after TPD_G;
               intLastLine <= '1'   after TPD_G;
            elsif endShift0 = '1' and crcWidthDly1 = 1 then
               macSize     <= "101" after TPD_G;
               intLastLine <= '1'   after TPD_G;
            elsif endShift0 = '1' and crcWidthDly1 = 2 then
               macSize     <= "110" after TPD_G;
               intLastLine <= '1'   after TPD_G;
            elsif endShift0 = '1' and crcWidthDly1 = 3 then
               macSize     <= "111" after TPD_G;
               intLastLine <= '1'   after TPD_G;
            elsif endShift1 = '1' and crcWidthDly2 = 4 then
               macSize     <= "000" after TPD_G;
               intLastLine <= '1'   after TPD_G;
            elsif endShift1 = '1' and crcWidthDly2 = 5 then
               macSize     <= "001" after TPD_G;
               intLastLine <= '1'   after TPD_G;
            elsif endShift1 = '1' and crcWidthDly2 = 6 then
               macSize     <= "010" after TPD_G;
               intLastLine <= '1'   after TPD_G;
            elsif endShift1 = '1' and crcWidthDly2 = 7 then
               macSize     <= "011" after TPD_G;
               intLastLine <= '1'   after TPD_G;
            else
               macSize     <= "000" after TPD_G;
               intLastLine <= '0'   after TPD_G;
            end if;
         end if;
      end if;
   end process;


   ------------------------------------------
   -- CRC Logic
   ------------------------------------------

   -- CRC Input
   crcReset            <= crcInit or phyRst or (not phyReady);
   crcIn(63 downto 56) <= crcFifoIn(7  downto  0);
   crcIn(55 downto 48) <= crcFifoIn(15 downto  8);
   crcIn(47 downto 40) <= crcFifoIn(23 downto 16);
   crcIn(39 downto 32) <= crcFifoIn(31 downto 24);
   crcIn(31 downto 24) <= crcFifoIn(39 downto 32);
   crcIn(23 downto 16) <= crcFifoIn(47 downto 40);
   crcIn(15 downto  8) <= crcFifoIn(55 downto 48);
   crcIn(7  downto  0) <= crcFifoIn(63 downto 56);

   -- Detect good CRC
   crcGood <= '1' when crcOut = X"E320BBDE" else '0';

   -- CRC
--   U_Crc32 : entity work.Crc32
--      generic map (
--         BYTE_WIDTH_G => 8
--      ) port map (
--         crcOut        => crcOut,
--         crcClk        => phyClk,
--         crcDataValid  => crcDataValid,
--         crcDataWidth  => crcDataWidth,
--         crcIn         => crcIn,
--         crcReset      => crcReset
--      ); 

end XMacImport;

