-------------------------------------------------------------------------------
-- Title         : General Purpopse PPI Status Monitoring
-- File          : PpiStatus.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 03/21/2014
-------------------------------------------------------------------------------
-- Description:
-- PPI block to transmit status messages.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 03/21/2014: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.PpiPkg.all;
use work.RceG3Pkg.all;
use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity PpiStatus is
   generic (
      TPD_G                  : time                   := 1 ns;
      NUM_STATUS_WORDS_G     : natural range 1 to 30  := 30;
      STATUS_SEND_WIDTH_G    : natural                := 1
   );
   port (

      -- PPI Interface
      ppiClk           : in  sl;
      ppiClkRst        : in  sl;
      ppiIbMaster      : out AxiStreamMasterType;
      ppiIbSlave       : in  AxiStreamSlaveType;
      ppiObMaster      : in  AxiStreamMasterType;
      ppiObSlave       : out AxiStreamSlaveType;
      ppiState         : in  RceDmaStateType;

      -- Status Busses
      statusClk        : in  sl;
      statusClkRst     : in  sl;
      statusWords      : in  Slv64Array(NUM_STATUS_WORDS_G-1 downto 0);
      statusSend       : in  slv(STATUS_SEND_WIDTH_G-1 downto 0)
   );
end PpiStatus;

architecture structure of PpiStatus is

   -- Local signals
   signal swReqIn          : sl;
   signal swReqEdge        : sl;
   signal intIbMaster      : AxiStreamMasterType;
   signal intIbCtrl        : AxiStreamCtrlType;
   signal statusSendGen    : sl;
   signal statusSendEdge   : sl;
   signal intState         : RceDmaStateType;

   type StateType is (S_IDLE_C, S_WAIT_C, S_FIRST_C, S_MESSAGE_C, S_LAST_C );

   type RegType is record
      statusWords     : Slv64Array(NUM_STATUS_WORDS_G-1 downto 0);
      count           : slv(4 downto 0);
      state           : StateType;
      intIbMaster     : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      statusWords     => (others=>(others=>'0')),
      count           => (others=>'0'),
      state           => S_IDLE_C,
      intIbMaster     => AXI_STREAM_MASTER_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   ------------------------------------
   -- Generate status request pulse
   ------------------------------------
   swReqIn    <= ppiObMaster.tValid and ppiObMaster.tlast;
   ppiObSlave <= AXI_STREAM_SLAVE_FORCE_C;

   U_SwSync : entity work.SynchronizerOneShot
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1'
      ) port map (
         clk     => statusClk,
         dataIn  => swReqIn,
         dataOut => swReqEdge
      );

   -- Sync State
   U_StateSync: entity work.PpiStateSync
      generic map (
         TPD_G => TPD_G
      ) port map (
         ppiState  => ppiState,
         locClk    => statusClk,
         locClkRst => statusClkRst,
         locState  => intState
      );

   statusSendGen <= uor(statusSend);

   -- Request edge detect
   U_ReqSync : entity work.SynchronizerOneShot
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1'
      ) port map (
         clk     => statusClk,
         dataIn  => statusSendGen,
         dataOut => statusSendEdge
      );


   ------------------------------------
   -- FIFO
   ------------------------------------
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
         FIFO_ADDR_WIDTH_G    => 9,
         FIFO_FIXED_THRESH_G  => true,
         FIFO_PAUSE_THRESH_G  => 255,
         SLAVE_AXI_CONFIG_G   => PPI_AXIS_CONFIG_INIT_C,
         MASTER_AXI_CONFIG_G  => PPI_AXIS_CONFIG_INIT_C 
      ) port map (
         sAxisClk        => statusClk,
         sAxisRst        => statusClkRst,
         sAxisMaster     => intIbMaster,
         sAxisSlave      => open,
         sAxisCtrl       => intIbCtrl,
         mAxisClk        => ppiClk,
         mAxisRst        => ppiClkRst,
         mAxisMaster     => ppiIbMaster,
         mAxisSlave      => ppiIbSlave
      );


   ------------------------------------
   -- Status Messages
   ------------------------------------

   -- Sync
   process (statusClk) is
   begin
      if (rising_edge(statusClk)) then
         r <= rin after TPD_G;
      end if;
   end process;

   -- Async
   process (statusClkRst, r, intIbCtrl, swReqEdge, statusSendEdge, intState, statusWords ) is
      variable v : RegType;
   begin
      v := r;

      -- Init
      v.intIbMaster.tValid  := '0';

      -- State Machine
      case r.state is

         -- Idle
         when S_IDLE_C =>
            v.intIbMaster    := AXI_STREAM_MASTER_INIT_C;
            v.count          := (others=>'0');
            v.statusWords    := statusWords;

            -- When to send a message, transition to online, sw request or firmware request
            if swReqEdge = '1' or (statusSendEdge = '1' and intState.online = '1') then
               v.state := S_WAIT_C;
            end if;

         -- Latch Status
         when S_WAIT_C =>

            -- Proceeed when pause is de-asserted
            if intIbCtrl.pause = '0' then
               v.state := S_FIRST_C;
            end if;

         -- First Word
         when S_FIRST_C =>
            v.intIbMaster.tData    := (others=>'0');
            v.intIbMaster.tValid   := '1';
            v.intIbMaster.tLast    := '0';
            v.state                := S_MESSAGE_C;

         -- Status message
         when S_MESSAGE_C =>
            v.intIbMaster.tData(63 downto 0) := r.statusWords(conv_integer(r.count));
            v.intIbmaster.tvalid             := '1';
            v.count                          := r.count + 1;

            if r.count = (NUM_STATUS_WORDS_G - 1) then
               v.state := S_LAST_C;
            end if;

         -- Last Word
         when S_LAST_C =>
            v.intIbMaster.tData    := (others=>'0');
            v.intIbMaster.tValid   := '1';
            v.intIbMaster.tLast    := '1';
            v.state                := S_IDLE_C;

         when others =>
            v.state := S_IDLE_C;

      end case;

      -- Reset
      if statusClkRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Next register assignment
      rin <= v;

      -- Outputs
      intIbMaster <= r.intIbMaster;

   end process;

end architecture structure;
