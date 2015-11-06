{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE PatternSynonyms #-}

module Hans.Arp (
    module Exports,
    module Hans.Arp
  ) where

import Hans.Arp.Types as Exports
import Hans.Config
import Hans.Device (Device(..))
import Hans.Ethernet
import Hans.IP4 (IP4)
import Hans.Monad (Hans,decode,io,escape)
import Hans.Serialize (runPutPacket)

import           Control.Monad (unless,when)
import qualified Data.ByteString as S
import qualified Data.ByteString.Lazy as L
import           Data.IORef (readIORef)
import           Data.List (find)


-- | Handle incoming Arp packets.
processArp :: Config -> ArpState -> Device -> S.ByteString -> Hans ()
processArp cfg arp dev payload =
  do ArpPacket { .. } <- decode (devStats dev) getArpPacket payload

     merge <- io (updateEntry cfg arp arpSHA arpSPA)

     -- are we the target of the request?
     dev' <- guardLocalAddress arpTPA arp
     let lha = devMac dev'

     -- add the entry if it didn't already exist
     unless merge (io (addEntry arpSPA arpSHA (cfgArpTableLifetime cfg) (arpTable arp)))

     -- respond if the packet was a who-has request for our mac
     when (arpOper == ArpRequest)
       $ sendEthernet dev' arpSHA ETYPE_ARP
       $ runPutPacket 28 100 L.empty
       $ putArpPacket ArpPacket { arpSHA  = lha,    arpSPA = arpTPA
                                , arpTHA  = arpSHA, arpTPA = arpSPA
                                , arpOper = ArpReply }


-- | Update an entry in the arp table, if it exists already.
updateEntry :: Config -> ArpState -> Mac -> IP4 -> IO Bool
updateEntry Config { .. } ArpState { .. } sha spa =
  do mb <- lookupEntry spa arpTable
     case mb of

       Just _  -> do addEntry spa sha cfgArpTableLifetime arpTable
                     return True

       Nothing -> return False


-- | Require that the address given belongs to one of the managed devices. If
-- the address is unknown, invoke the escape continuation to abort packet
-- processing.
guardLocalAddress :: IP4 -> ArpState -> Hans Device
guardLocalAddress tpa ArpState { .. } =
  do addrs <- io (readIORef arpAddrs)
     case find hasTPA addrs of
       Just (_,dev) -> return dev
       Nothing      -> escape
  where

  hasTPA (addr,_) = addr == tpa
