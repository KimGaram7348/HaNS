module Hans.Types where

import Hans.Arp (ArpState)
import Hans.Config (Config)
import Hans.Device (Device,InputPacket)
import Hans.IP4 (IP4State)

import Control.Concurrent.BoundedChan (BoundedChan)
import Data.IORef (IORef)


data NetworkStack = NetworkStack { nsConfig :: !Config
                                   -- ^ The configuration for this instance of
                                   -- the network stack.

                                 , nsInput :: !(BoundedChan InputPacket)
                                   -- ^ The input packet queue

                                 , nsDevices :: {-# UNPACK #-} !(IORef [Device])
                                   -- ^ All registered devices

                                 , nsArpState :: !ArpState
                                   -- ^ State for Arp processing

                                 , nsIP4State :: !IP4State
                                   -- ^ State for IP4 processing
                                 }
