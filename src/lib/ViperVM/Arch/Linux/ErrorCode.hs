{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}

-- | Management of returned values from syscalls
module ViperVM.Arch.Linux.ErrorCode 
   ( ErrorCode (..)
   , unhdlErr
   , toErrorCode
   , toErrorCodeVoid
   , toErrorCodePure
   )
where

import ViperVM.Format.Binary.Word
import ViperVM.Format.Binary.Enum
import ViperVM.Utils.Variant
import ViperVM.Arch.Linux.Internals.Error

-- | Convert negative values into error codes
toErrorCode :: Int64 -> Variant '[Int64,ErrorCode]
{-# INLINE toErrorCode #-}
toErrorCode r
   | r < 0     = setVariantN @1 (toCEnum (abs r))
   | otherwise = setVariantN @0 r

-- | Convert negative values into error codes, return () otherwise
toErrorCodeVoid :: Int64 -> Variant '[(),ErrorCode]
{-# INLINE toErrorCodeVoid #-}
toErrorCodeVoid r
   | r < 0     = setVariantN @1 (toCEnum (abs r))
   | otherwise = setVariantN @0 ()

-- | Convert negative values into error codes, return `f r` otherwise
toErrorCodePure :: (Int64 -> a) -> Int64 -> Variant '[a,ErrorCode]
{-# INLINE toErrorCodePure #-}
toErrorCodePure f r
   | r < 0     = setVariantN @1 (toCEnum (abs r))
   | otherwise = setVariantN @0 (f r)

-- | Error to call when a syscall returns an unexpected error value
unhdlErr :: Show err => String -> err -> a
unhdlErr str err =
   error ("Unhandled error "++ show err ++" returned by \""++str++"\". Report this as a ViperVM bug.")
