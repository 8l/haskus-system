{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE LambdaCase #-}

-- | Notifications on file system (poll, select, inotify, etc.)
module ViperVM.Arch.X86_64.Linux.FileSystem.Notification
   ( PollEvent(..)
   , PollEntry(..)
   , PollResult(..)
   , sysPoll
   )
where

import Foreign.Marshal.Array (withArray, peekArray)
import Foreign.Storable (Storable, peek, poke, sizeOf, alignment)
import Foreign.CStorable
import Data.Maybe (mapMaybe)
import Data.Word (Word64, Word16)
import Data.Int (Int64,Int32)
import GHC.Generics (Generic)

import ViperVM.Utils.EnumSet
import ViperVM.Arch.Linux.ErrorCode
import ViperVM.Arch.Linux.FileDescriptor
import ViperVM.Arch.X86_64.Linux.Syscall

data PollStruct = PollStruct
   { pollFD             :: Int32
   , pollEvents         :: Word16
   , pollReturnedEvents :: Word16
   } deriving (Generic)

instance CStorable PollStruct
instance Storable PollStruct where
   sizeOf      = cSizeOf
   alignment   = cAlignment
   poke        = cPoke
   peek        = cPeek

data PollEvent
   = PollReadable
   | PollWritable
   | PollPriorityReadable
   | PollError
   | PollHungUp
   | PollInvalidFileDescriptor
   | PollMessage
   | PollRemove
   | PollPeerHungUp
   | PollReadNormal
   | PollWriteNormal
   | PollReadBand
   | PollWriteBand

instance Enum PollEvent where
   fromEnum x = case x of
      PollReadable               -> 0
      PollWritable               -> 2
      PollPriorityReadable       -> 1
      PollError                  -> 3
      PollHungUp                 -> 4
      PollInvalidFileDescriptor  -> 5
      PollMessage                -> 10
      PollRemove                 -> 12
      PollPeerHungUp             -> 13
      PollReadNormal             -> 6
      PollWriteNormal            -> 8
      PollReadBand               -> 7
      PollWriteBand              -> 9
   toEnum x = case x of
      0  -> PollReadable               
      2  -> PollWritable               
      1  -> PollPriorityReadable       
      3  -> PollError                  
      4  -> PollHungUp                 
      5  -> PollInvalidFileDescriptor  
      10 -> PollMessage                
      12 -> PollRemove                 
      13 -> PollPeerHungUp             
      6  -> PollReadNormal             
      8  -> PollWriteNormal            
      7  -> PollReadBand               
      9  -> PollWriteBand              
      _  -> error "Unknown poll event"

instance EnumBitSet PollEvent

data PollEntry = PollEntry FileDescriptor [PollEvent]

-- | Result of a call to poll
data PollResult
   = PollTimeOut              -- ^ Time out
   | PollEvents [PollEntry]   -- ^ Events returned

-- | Poll a set of file descriptors
--
-- Timeout in milliseconds
sysPoll :: [PollEntry] -> Bool -> Maybe Int64 -> SysRet PollResult
sysPoll entries blocking timeout = do
   
   let 
      toPollStruct (PollEntry (FileDescriptor fd) evs) = PollStruct
         { pollFD             = fromIntegral fd -- poll allows negative FDs to indicate that the entry must be skipped, we don't
         , pollEvents         = toBitSet evs
         , pollReturnedEvents = 0
         }
      fromPollStruct (PollStruct fd _ evs) = 
         if evs == 0
            then Nothing
            else Just $ PollEntry (FileDescriptor (fromIntegral fd)) (fromBitSet evs)
      fds = fmap toPollStruct entries
      nfds = fromIntegral (length fds) :: Word64
      timeout' = if not blocking
         then 0
         else case timeout of
            Nothing -> -1 -- infinite blocking
            Just x  -> abs x
   
   withArray fds $ \fds' -> do
      onSuccessIO (syscall3 7 fds' nfds timeout') $ \case
         0 -> return PollTimeOut
         _ -> do
            retfds <- peekArray (length fds) fds'
            return (PollEvents $ mapMaybe fromPollStruct retfds)
