-------------------------------------------------------------------------------
-- Title         : ARM Based RCE Generation 3, Package File
-- File          : RceG3Pkg.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 04/02/2013
-------------------------------------------------------------------------------
-- Description:
-- Package file for ARM based rce generation 3 processor core.
-------------------------------------------------------------------------------
-- Copyright (c) 2013 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/02/2013: created.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;

package RceG3Pkg is

   --------------------------------------------------------
   -- DMA Engine Types
   --------------------------------------------------------

   type RceDmaModeType is (RCE_DMA_PPI_C, RCE_DMA_AXIS_C );

   type RceDmaModeArray is array (natural range<>) of RceDmaModeType;


   --------------------------------------------------------
   -- AXI Configuration Constants
   --------------------------------------------------------

   constant AXI_MAST_GP_INIT_C : AxiConfigType := (
      DATA_BYTES_C      => 4,
      ID_BITS_C         => 12);

   constant AXI_SLAVE_GP_INIT_C : AxiConfigType := (
      DATA_BYTES_C      => 4,
      ID_BITS_C         => 6);

   constant AXI_ACP_INIT_C : AxiConfigType := (
      DATA_BYTES_C      => 8,
      ID_BITS_C         => 3);

   constant AXI_HP_INIT_C : AxiConfigType := (
      DATA_BYTES_C      => 8,
      ID_BITS_C         => 6);


   --------------------------------------------------------
   -- Ethernet Types
   --------------------------------------------------------

   -- Base Record
   type ArmEthTxType is record
      enetGmiiTxEn        : sl;
      enetGmiiTxEr        : sl;
      enetMdioMdc         : sl;
      enetMdioO           : sl;
      enetMdioT           : sl;
      enetPtpDelayReqRx   : sl;
      enetPtpDelayReqTx   : sl;
      enetPtpPDelayReqRx  : sl;
      enetPtpPDelayReqTx  : sl;
      enetPtpPDelayRespRx : sl;
      enetPtpPDelayRespTx : sl;
      enetPtpSyncFrameRx  : sl;
      enetPtpSyncFrameTx  : sl;
      enetSofRx           : sl;
      enetSofTx           : sl;
      enetGmiiTxD         : slv(7 downto 0);  
   end record;

   -- Initialization constants
   constant ARM_ETH_TX_INIT_C : ArmEthTxType := ( 
      enetGmiiTxEn        => '0',
      enetGmiiTxEr        => '0',
      enetMdioMdc         => '0',
      enetMdioO           => '0',
      enetMdioT           => '0',
      enetPtpDelayReqRx   => '0',
      enetPtpDelayReqTx   => '0',
      enetPtpPDelayReqRx  => '0',
      enetPtpPDelayReqTx  => '0',
      enetPtpPDelayRespRx => '0',
      enetPtpPDelayRespTx => '0',
      enetPtpSyncFrameRx  => '0',
      enetPtpSyncFrameTx  => '0',
      enetSofRx           => '0',
      enetSofTx           => '0',
      enetGmiiTxD         => (others=>'0')
   );

   -- Array
   type ArmEthTxArray is array (natural range<>) of ArmEthTxType;

   -- Base Record
   type ArmEthRxType is record
      enetGmiiCol   : sl;
      enetGmiiCrs   : sl;
      enetGmiiRxClk : sl;
      enetGmiiRxDv  : sl;
      enetGmiiRxEr  : sl;
      enetGmiiTxClk : sl;
      enetMdioI     : sl;
      enetExtInitN  : sl;
      enetGmiiRxd   : slv(7 downto 0);  
   end record;

   -- Initialization constants
   constant ARM_ETH_RX_INIT_C : ArmEthRxType := ( 
      enetGmiiCol   => '0',
      enetGmiiCrs   => '0',
      enetGmiiRxClk => '0',
      enetGmiiRxDv  => '0',
      enetGmiiRxEr  => '0',
      enetGmiiTxClk => '0',
      enetMdioI     => '0',
      enetExtInitN  => '0',
      enetGmiiRxd   => (others=>'0')
   );

   -- Array
   type ArmEthRxArray is array (natural range<>) of ArmEthRxType;

end RceG3Pkg;
