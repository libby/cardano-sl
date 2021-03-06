module Pos.Lrc.Consumers
       (
         allLrcConsumers
       ) where

import           Data.Tagged           (untag)
import           Universum

import           Pos.Delegation.Lrc    (delegationLrcConsumer)
import           Pos.Lrc.Consumer      (LrcConsumer)
import           Pos.Ssc.Class.Workers (SscWorkersClass (sscLrcConsumers))
import           Pos.WorkMode          (WorkMode)
import           Pos.Update.Lrc        (usLrcConsumer)

allLrcConsumers
    :: (SscWorkersClass ssc, WorkMode ssc m)
    => [LrcConsumer m]
allLrcConsumers = [delegationLrcConsumer, usLrcConsumer] ++ untag sscLrcConsumers
