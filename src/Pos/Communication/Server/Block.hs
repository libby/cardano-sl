-- | Server which handles blocks.

module Pos.Communication.Server.Block
       ( blockListeners

       , handleBlock
       , handleBlockHeader
       , handleBlockRequest
       ) where

import           Control.TimeWarp.Logging   (logDebug, logInfo)
import           Formatting                 (build, sformat, stext, (%))
import           Pos.DHT                    (ListenerDHT (..), replyToNode)
import           Serokell.Util              (VerificationRes (..), listBuilderJSON)
import           Universum

import           Control.TimeWarp.Rpc       (MonadDialog)
import           Pos.Communication.Types    (RequestBlock (..), ResponseMode,
                                             SendBlock (..), SendBlockHeader (..))
import           Pos.Crypto                 (hash)
import           Pos.Slotting               (getCurrentSlot)
import           Pos.Ssc.DynamicState.Types (SscDynamicState)
import qualified Pos.State                  as St
import           Pos.WorkMode               (WorkMode)

-- | Listeners for requests related to blocks processing.
blockListeners :: (MonadDialog m, WorkMode m) => [ListenerDHT m]
blockListeners =
    [ ListenerDHT handleBlock
    , ListenerDHT handleBlockHeader
    , ListenerDHT handleBlockRequest
    ]

handleBlock :: ResponseMode m => SendBlock SscDynamicState -> m ()
handleBlock (SendBlock block) = do
    slotId <- getCurrentSlot
    pbr <- St.processBlock slotId block
    case pbr of
        St.PBRabort msg -> do
            let fmt =
                    "Block processing is aborted for the following reason: "%stext
            logInfo $ sformat fmt msg
        St.PBRgood _ -> logInfo $ "Received block has been adopted"
        St.PBRmore h -> replyToNode $ RequestBlock h

handleBlockHeader
    :: ResponseMode m
    => SendBlockHeader SscDynamicState -> m ()
handleBlockHeader (SendBlockHeader header) =
    whenM checkUsefulness $ replyToNode (RequestBlock h)
  where
    h = hash $ Right header
    checkUsefulness = do
        slotId <- getCurrentSlot
        verRes <- St.mayBlockBeUseful slotId header
        case verRes of
            VerFailure errors -> do
                let fmt =
                        "Ignoring header with hash "%build%
                        " for the following reasons: "%build
                let msg = sformat fmt h (listBuilderJSON errors)
                False <$ logDebug msg
            VerSuccess -> pure True

handleBlockRequest
    :: ResponseMode m
    => RequestBlock SscDynamicState -> m ()
handleBlockRequest (RequestBlock h) =
    maybe (pure ()) (replyToNode . SendBlock) =<< St.getBlock h
