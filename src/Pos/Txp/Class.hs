{-# LANGUAGE DefaultSignatures      #-}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses  #-}
{-# LANGUAGE TupleSections          #-}
{-# LANGUAGE UndecidableInstances   #-}

module Pos.Txp.Class
       (
         MonadTxpLD (..)
       , TxpLD
       , getLocalTxs
       , getLocalUndo
       , getLocalTxsNUndo
       ) where

import           Control.Monad.Trans (MonadTrans)
import qualified Data.HashMap.Strict as HM
import           Universum

import           Pos.DHT.Model.Class (DHTResponseT)
import           Pos.DHT.Real        (KademliaDHT)
import           Pos.Txp.Types       (MemPool (localTxs), UtxoView)
import           Pos.Types           (HeaderHash, IdTxWitness, TxId, TxOut)

-- | LocalData of transactions processing.
-- There are two invariants which must hold for local data
-- (where uv is UtxoView, memPool is MemPool and tip is HeaderHash):
-- 1. Suppose 'blks' is sequence of blocks from the very beggining up
-- to 'tip'. If one applies 'blks' to genesis Utxo, resulting Utxo
-- (let's call it 'utxo1') will be such that all transactions from
-- 'memPool' are valid with respect to it.
-- 2. If one applies all transactions from 'memPool' to 'utxo1',
-- resulting Utxo will be equivalent to 'uv' with respect to
-- MonadUtxo.
type TxpLD ssc = (UtxoView ssc, MemPool, HashMap TxId [TxOut], HeaderHash ssc)

class Monad m => MonadTxpLD ssc m | m -> ssc where
    getUtxoView  :: m (UtxoView ssc)
    getMemPool   :: m MemPool
    setUtxoView  :: UtxoView ssc -> m ()
    setMemPool   :: MemPool -> m ()
    modifyTxpLD  :: (TxpLD ssc -> (a, TxpLD ssc)) -> m a
    modifyTxpLD_ :: (TxpLD ssc -> TxpLD ssc) -> m ()
    modifyTxpLD_ = modifyTxpLD . (((),) .)
    getTxpLD     :: m (TxpLD ssc)
    setTxpLD     :: TxpLD ssc -> m ()
    setTxpLD txpLD = modifyTxpLD_ $ const txpLD

    default getUtxoView :: MonadTrans t => t m (UtxoView ssc)
    getUtxoView = lift  getUtxoView

    default setUtxoView :: MonadTrans t => UtxoView ssc -> t m ()
    setUtxoView = lift . setUtxoView

    default getMemPool :: MonadTrans t => t m MemPool
    getMemPool = lift getMemPool

    default setMemPool :: MonadTrans t => MemPool -> t m ()
    setMemPool  = lift . setMemPool

    default modifyTxpLD :: MonadTrans t => (TxpLD ssc -> (a, TxpLD ssc)) -> t m a
    modifyTxpLD = lift . modifyTxpLD

    default getTxpLD :: MonadTrans t => t m (TxpLD ssc)
    getTxpLD = lift getTxpLD

instance MonadTxpLD ssc m => MonadTxpLD ssc (ReaderT r m)

instance MonadTxpLD ssc m => MonadTxpLD ssc (DHTResponseT s m)

instance MonadTxpLD ssc m => MonadTxpLD ssc (KademliaDHT m)

getLocalTxs :: MonadTxpLD ssc m => m [IdTxWitness]
getLocalTxs = HM.toList . localTxs <$> getMemPool

getLocalUndo :: MonadTxpLD ssc m => m (HashMap TxId [TxOut])
getLocalUndo = do
    (_, _, undos, _) <- getTxpLD
    pure undos

getLocalTxsNUndo :: MonadTxpLD ssc m => m ([IdTxWitness], HashMap TxId [TxOut])
getLocalTxsNUndo = do
    (_, mp, undos, _) <- getTxpLD
    pure (HM.toList . localTxs $ mp, undos)