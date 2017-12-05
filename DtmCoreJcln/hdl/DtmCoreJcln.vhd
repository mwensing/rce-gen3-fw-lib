-------------------------------------------------------------------------------
-- Title      : Common DTM Core Module with jitter cleaner support
-- File       : DtmCore.vhd
-- Author     : Marius Wensing, wensing@uni-wuppertal.de
-- Created    : 2017-12-05
-- Last update: 2017-12-05
-------------------------------------------------------------------------------
-- Description:
-- Common top level module for DTM
-------------------------------------------------------------------------------
-- This file is part of 'SLAC RCE DTM Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC RCE DTM Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 11/14/2013: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.RceG3Pkg.all;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

library unisim;
use unisim.vcomponents.all;

entity DtmCoreJcln is
   generic (
      TPD_G          : time           := 1 ns;
      BUILD_INFO_G   : BuildInfoType;
      RCE_DMA_MODE_G : RceDmaModeType := RCE_DMA_PPI_C);
   port (

      -- I2C
      i2cSda                  : inout sl;
      i2cScl                  : inout sl;

      -- PCI Exress
      pciRefClkP              : in    sl;
      pciRefClkM              : in    sl;
      pciRxP                  : in    sl;
      pciRxM                  : in    sl;
      pciTxP                  : out   sl;
      pciTxM                  : out   sl;
      pciResetL               : out   sl;

      -- COB Ethernet
      ethRxP                  : in    sl;
      ethRxM                  : in    sl;
      ethTxP                  : out   sl;
      ethTxM                  : out   sl;

      -- Clock Select
      clkSelA                 : out   sl;
      clkSelB                 : out   sl;

      -- Base Ethernet
      ethRxCtrl               : in    slv(1 downto 0);
      ethRxClk                : in    slv(1 downto 0);
      ethRxDataA              : in    Slv(1 downto 0);
      ethRxDataB              : in    Slv(1 downto 0);
      ethRxDataC              : in    Slv(1 downto 0);
      ethRxDataD              : in    Slv(1 downto 0);
      ethTxCtrl               : out   slv(1 downto 0);
      ethTxClk                : out   slv(1 downto 0);
      ethTxDataA              : out   Slv(1 downto 0);
      ethTxDataB              : out   Slv(1 downto 0);
      ethTxDataC              : out   Slv(1 downto 0);
      ethTxDataD              : out   Slv(1 downto 0);
      ethMdc                  : out   Slv(1 downto 0);
      ethMio                  : inout Slv(1 downto 0);
      ethResetL               : out   Slv(1 downto 0);

      -- IPMI
      dtmToIpmiP              : out   slv(1 downto 0);
      dtmToIpmiM              : out   slv(1 downto 0);

      -- Clocks
      sysClk125               : out   sl;
      sysClk125Rst            : out   sl;
      sysClk200               : out   sl;
      sysClk200Rst            : out   sl;

      -- jitter cleaner interface
      jclnSdio                : out   sl;
      jclnSdo                 : in    sl;
      jclnSclk                : out   sl;
      jclnCsN                 : out   sl;
      jclnLolL                : in    sl;

      -- External Axi Bus, 0xA0000000 - 0xAFFFFFFF
      axiClk                  : out   sl;
      axiClkRst               : out   sl;
      extAxilReadMaster       : out   AxiLiteReadMasterType;
      extAxilReadSlave        : in    AxiLiteReadSlaveType;
      extAxilWriteMaster      : out   AxiLiteWriteMasterType;
      extAxilWriteSlave       : in    AxiLiteWriteSlaveType;

      -- DMA Interfaces
      dmaClk                  : in    slv(2 downto 0);
      dmaClkRst               : in    slv(2 downto 0);
      dmaState                : out   RceDmaStateArray(2 downto 0);
      dmaObMaster             : out   AxiStreamMasterArray(2 downto 0);
      dmaObSlave              : in    AxiStreamSlaveArray(2 downto 0);
      dmaIbMaster             : in    AxiStreamMasterArray(2 downto 0);
      dmaIbSlave              : out   AxiStreamSlaveArray(2 downto 0);

      -- User Interrupts
      userInterrupt            : in    slv(USER_INT_COUNT_C-1 downto 0)

   );
end DtmCoreJcln;

architecture STRUCTURE of DtmCoreJcln is

   signal iaxiClk             : sl;
   signal iaxiClkRst          : sl;
   signal isysClk125          : sl;
   signal isysClk125Rst       : sl;
   signal isysClk200          : sl;
   signal isysClk200Rst       : sl;
   signal idmaClk             : slv(3 downto 0);
   signal idmaClkRst          : slv(3 downto 0);
   signal idmaState           : RceDmaStateArray(3 downto 0);
   signal idmaObMaster        : AxiStreamMasterArray(3 downto 0);
   signal idmaObSlave         : AxiStreamSlaveArray(3 downto 0);
   signal idmaIbMaster        : AxiStreamMasterArray(3 downto 0);
   signal idmaIbSlave         : AxiStreamSlaveArray(3 downto 0);
   signal coreAxilReadMaster  : AxiLiteReadMasterType;
   signal coreAxilReadSlave   : AxiLiteReadSlaveType;
   signal coreAxilWriteMaster : AxiLiteWriteMasterType;
   signal coreAxilWriteSlave  : AxiLiteWriteSlaveType;
   signal coreAxilWriteMasters : AxiLiteWriteMasterArray(1 downto 0);
   signal coreAxilWriteSlaves : AxiLiteWriteSlaveArray(1 downto 0);
   signal coreAxilReadMasters : AxiLiteReadMasterArray(1 downto 0);                                                                       
   signal coreAxilReadSlaves  : AxiLiteReadSlaveArray(1 downto 0);
   signal pcieAxilReadMaster  : AxiLiteReadMasterType;
   signal pcieAxilReadSlave   : AxiLiteReadSlaveType;
   signal pcieAxilWriteMaster : AxiLiteWriteMasterType;
   signal pcieAxilWriteSlave  : AxiLiteWriteSlaveType;
   signal jclnAxilReadMaster  : AxiLiteReadMasterType;
   signal jclnAxilReadSlave   : AxiLiteReadSlaveType;
   signal jclnAxilWriteMaster : AxiLiteWriteMasterType;
   signal jclnAxilWriteSlave  : AxiLiteWriteSlaveType;
   signal armEthTx            : ArmEthTxArray(1 downto 0);
   signal armEthRx            : ArmEthRxArray(1 downto 0);
   signal armEthMode          : slv(31 downto 0);

   attribute KEEP_HIERARCHY : string;
   attribute KEEP_HIERARCHY of
      U_RceG3Top,
      U_AxiCrossbar,
      U_ZynqPcieMaster,
      U_ZynqEthernet : label is "TRUE";   
   
begin

   --------------------------------------------------
   -- Outputs
   --------------------------------------------------
   axiClk          <= iaxiClk;
   axiClkRst       <= iaxiClkRst;
   sysClk125       <= isysClk125;
   sysClk125Rst    <= isysClk125Rst;
   sysClk200       <= isysClk200;
   sysClk200Rst    <= isysClk200Rst;

   -- DMA Interfaces
   idmaClk(2 downto 0)      <= dmaClk;
   idmaClkRst(2 downto 0)   <= dmaClkRst;
   dmaState                 <= idmaState(2 downto 0);
   dmaObMaster              <= idmaObMaster(2 downto 0);
   idmaObSlave(2 downto 0)  <= dmaObSlave;
   idmaIbMaster(2 downto 0) <= dmaIbMaster;
   dmaIbSlave               <= idmaIbSlave(2 downto 0);


   --------------------------------------------------
   -- RCE Core
   --------------------------------------------------
   U_RceG3Top: entity work.RceG3Top
      generic map (
         TPD_G          => TPD_G,
         BUILD_INFO_G   => BUILD_INFO_G,
         RCE_DMA_MODE_G => RCE_DMA_MODE_G
      ) port map (
         i2cSda              => i2cSda,
         i2cScl              => i2cScl,
         sysClk125           => isysClk125,
         sysClk125Rst        => isysClk125Rst,
         sysClk200           => isysClk200,
         sysClk200Rst        => isysClk200Rst,
         axiClk              => iaxiClk,
         axiClkRst           => iaxiClkRst,
         extAxilReadMaster   => extAxilReadMaster,
         extAxilReadSlave    => extAxilReadSlave ,
         extAxilWriteMaster  => extAxilWriteMaster,
         extAxilWriteSlave   => extAxilWriteSlave ,
         coreAxilReadMaster  => coreAxilReadMaster,
         coreAxilReadSlave   => coreAxilReadSlave,
         coreAxilWriteMaster => coreAxilWriteMaster,
         coreAxilWriteSlave  => coreAxilWriteSlave,
         dmaClk              => idmaClk,
         dmaClkRst           => idmaClkRst,
         dmaState            => idmaState,
         dmaObMaster         => idmaObMaster,
         dmaObSlave          => idmaObSlave,
         dmaIbMaster         => idmaIbMaster,
         dmaIbSlave          => idmaIbSlave,
         userInterrupt       => userInterrupt,
         armEthTx            => armEthTx,
         armEthRx            => armEthRx,
         armEthMode          => armEthMode,
         clkSelA             => open,
         clkSelB             => open
      );

   -- Hard code to 250Mhz
   clkSelA <= '1';
   clkSelB <= '1';


   -------------------------------------
   -- AXI Lite Crossbar
   -- Base: 0xB0000000 - 0xBFFFFFFF
   -------------------------------------
   U_AxiCrossbar : entity work.AxiLiteCrossbar 
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => 2,
         DEC_ERROR_RESP_G   => AXI_RESP_OK_C,
         MASTERS_CONFIG_G   => (

            -- Channel 1 = 0xBC000000 - 0xBC00FFFF : PCI Express Registers
            0 => ( baseAddr     => x"BC000000",
                   addrBits     => 16,
                   connectivity => x"FFFF"),
            -- Channel 2 = 0xBC010000 - 0xBC01FFFF : Jitter Cleaner control
            1 => ( baseAddr     => x"BC010000",
                   addrBits     => 16,
                   connectivity => x"FFFF")
         )
      ) port map (
         axiClk              => iaxiClk,
         axiClkRst           => iaxiClkRst,
         sAxiWriteMasters(0) => coreAxilWriteMaster,
         sAxiWriteSlaves(0)  => coreAxilWriteSlave,
         sAxiReadMasters(0)  => coreAxilReadMaster,
         sAxiReadSlaves(0)   => coreAxilReadSlave,
         mAxiWriteMasters    => coreAxilWriteMasters,
         mAxiWriteSlaves     => coreAxilWriteSlaves,
         mAxiReadMasters     => coreAxilReadMasters,
         mAxiReadSlaves      => coreAxilReadSlaves        
      );
   
   pcieAxilWriteMaster <= coreAxilWriteMasters(0);
   pcieAxilReadMaster <= coreAxilReadMasters(0);
   jclnAxilWriteMaster <= coreAxilWriteMasters(1);
   jclnAxilReadMaster <= coreAxilReadMasters(1);
   coreAxilWriteSlaves(0) <= pcieAxilWriteSlave;
   coreAxilReadSlaves(0) <= pcieAxilReadSlave;
   coreAxilWriteSlaves(1) <= jclnAxilWriteSlave;
   coreAxilReadSlaves(1) <= jclnAxilReadSlave;

   --------------------------------------------------
   -- PCI Express : 0xBC00_0000 - 0xBC00_FFFF
   --------------------------------------------------
   U_ZynqPcieMaster : entity work.ZynqPcieMaster 
      generic map (
         HSIO_MODE_G => false
      ) port map (
         axiClk          => iaxiClk,
         axiClkRst       => iaxiClkRst,
         axiReadMaster   => pcieAxilReadMaster,
         axiReadSlave    => pcieAxilReadSlave,
         axiWriteMaster  => pcieAxilWriteMaster,
         axiWriteSlave   => pcieAxilWriteSlave,
         pciRefClkP      => pciRefClkP,
         pciRefClkM      => pciRefClkM,
         pcieResetL      => pciResetL,
         pcieRxP         => pciRxP,
         pcieRxM         => pciRxM,
         pcieTxP         => pciTxP,
         pcieTxM         => pciTxM
      );

   --------------------------------------------------
   -- Jitter cleaner : 0xBC01_0000 - 0xBC01_FFFF
   --------------------------------------------------
   U_Si534x : entity work.Si534x
      generic map (
         TPD_G => TPD_G,
         AXI_CLK_PERIOD_G => 8.0e-9
      )
      port map (
         axilClk => iaxiClk,
         axilRst => iaxiClkRst,
         axilReadMaster => jclnAxilReadMaster,
         axilReadSlave => jclnAxilReadSlave,
         axilWriteMaster => jclnAxilWriteMaster,
         axilWriteSlave => jclnAxilWriteSlave,
         lol_n => jclnLolL,
         spiMISO => jclnSdo,
         spiMOSI => jclnSdio,
         spiSCK => jclnSclk,
         spiCS_N => jclnCsN
      );

   --------------------------------------------------
   -- Ethernet
   --------------------------------------------------
   U_ZynqEthernet : entity work.ZynqEthernet 
      port map (
         sysClk125          => isysClk125,
         sysClk200          => isysClk200,
         sysClk200Rst       => isysClk200Rst,
         armEthTx           => armEthTx(0),
         armEthRx           => armEthRx(0),
         ethRxP             => ethRxP,
         ethRxM             => ethRxM,
         ethTxP             => ethTxP,
         ethTxM             => ethTxM
      );

   armEthRx(1)     <= ARM_ETH_RX_INIT_C;
   armEthMode      <= x"00000001"; -- 1 Gig on lane 0
   idmaClk(3)      <= isysClk125;
   idmaClkRst(3)   <= isysClk125Rst;
   idmaObSlave(3)  <= AXI_STREAM_SLAVE_INIT_C;
   idmaIbMaster(3) <= AXI_STREAM_MASTER_INIT_C;

   --------------------------------------------------
   -- Unused
   --------------------------------------------------

   dtmToIpmiP(0) <= 'Z';
   dtmToIpmiP(1) <= 'Z';
   dtmToIpmiM(0) <= 'Z';
   dtmToIpmiM(1) <= 'Z';

end architecture STRUCTURE;

