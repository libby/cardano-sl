-- | Binary serialization of Version types (software, block)

module Pos.Binary.Core.Version () where

import           Data.Binary.Get  (label)
import           Universum

import           Pos.Binary.Class (Bi (..), getAsciiString1b, putAsciiString1b)
import qualified Pos.Core.Types   as V
import qualified Pos.Core.Version as V

instance Bi V.ApplicationName where
    get = label "ApplicationName" $ V.mkApplicationName . toText
            =<< getAsciiString1b "SystemTag" V.applicationNameMaxLength
    put (toString . V.getApplicationName -> tag) = putAsciiString1b tag

instance Bi V.SoftwareVersion where
    get = label "SoftwareVersion" $ V.SoftwareVersion <$> get <*> get
    put V.SoftwareVersion {..} =  put svAppName
                               *> put svNumber

instance Bi V.BlockVersion where
    get = label "BlockVersion" $ V.BlockVersion <$> get <*> get <*> get
    put V.BlockVersion {..} =  put bvMajor
                               *> put bvMinor
                               *> put bvAlt
