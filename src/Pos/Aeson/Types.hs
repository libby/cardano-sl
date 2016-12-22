{-# LANGUAGE TemplateHaskell #-}

module Pos.Aeson.Types
       (
       ) where

import           Data.Aeson       (ToJSON (toJSON))
import           Data.Aeson.TH    (defaultOptions, deriveToJSON)
import           Pos.Aeson.Crypto ()
import           Pos.Types.Types  (Address, AddressDestination, AddressVersion, Coin,
                                   EpochIndex, LocalSlotIndex, SharedSeed, SlotId, Tx,
                                   TxIn, TxOut)
import           Pos.Web.Types    (GodTossingStage)

import           Universum

instance ToJSON SharedSeed where
    toJSON = toJSON . pretty

deriveToJSON defaultOptions ''AddressVersion
deriveToJSON defaultOptions ''AddressDestination
deriveToJSON defaultOptions ''Address
deriveToJSON defaultOptions ''Tx
deriveToJSON defaultOptions ''TxOut
deriveToJSON defaultOptions ''TxIn
deriveToJSON defaultOptions ''SlotId
deriveToJSON defaultOptions ''LocalSlotIndex
deriveToJSON defaultOptions ''EpochIndex
deriveToJSON defaultOptions ''Coin
deriveToJSON defaultOptions ''GodTossingStage