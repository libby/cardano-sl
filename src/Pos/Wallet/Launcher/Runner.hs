
module Pos.Wallet.Launcher.Runner
       ( runRawRealWallet
       , runWalletRealMode
       , runWalletReal
       , runWallet
       ) where

import           Formatting                  (build, sformat, (%))
import           Mockable                    (Production, bracket, fork, sleepForever)
import qualified Network.RateLimiting        as RL
import qualified STMContainers.Map           as SM
import           System.Wlog                 (logDebug, logInfo, usingLoggerName)
import           Universum                   hiding (bracket)

import           Pos.Communication           (ActionSpec (..), ListenersWithOut, OutSpecs,
                                              WorkerSpec)
import           Pos.Communication.PeerState (runPeerStateHolder)
import           Pos.DHT.Model               (getKnownPeers)
import           Pos.DHT.Real                (runKademliaDHT)
import           Pos.Launcher                (BaseParams (..), LoggingParams (..),
                                              RealModeResources (..), addDevListeners,
                                              runServer_)
import           Pos.Wallet.Context          (WalletContext (..), runContextHolder)
import           Pos.Wallet.KeyStorage       (runKeyStorage)
import           Pos.Wallet.Launcher.Param   (WalletParams (..))
import           Pos.Wallet.State            (closeState, openMemState, openState,
                                              runWalletDB)
import           Pos.Wallet.WalletMode       (WalletMode, WalletRealMode)

-- TODO: Move to some `Pos.Wallet.Communication` and provide
-- meaningful listeners
allListeners
    -- :: (MonadDHTDialog SState m, WalletMode SscGodTossing m)
    -- => [ListenerDHT SState m]
    :: Monoid b => ([a], b)
allListeners = ([], mempty)

-- TODO: Move to some `Pos.Wallet.Worker` and provide
-- meaningful ones
-- allWorkers :: WalletMode ssc m => [m ()]
allWorkers :: Monoid b => ([a], b)
allWorkers = ([], mempty)

-- | WalletMode runner
runWalletRealMode
    :: RealModeResources
    -> WalletParams
    -> (ActionSpec WalletRealMode a, OutSpecs)
    -> Production a
runWalletRealMode res wp@WalletParams {..} = runRawRealWallet res wp listeners
  where
    listeners = addDevListeners wpSystemStart allListeners

runWalletReal
    :: RealModeResources
    -> WalletParams
    -> ([WorkerSpec WalletRealMode], OutSpecs)
    -> Production ()
runWalletReal res wp = runWalletRealMode res wp . runWallet

runWallet :: WalletMode ssc m => ([WorkerSpec m], OutSpecs) -> (WorkerSpec m, OutSpecs)
runWallet (plugins', pouts) = (,outs) . ActionSpec $ \vI sendActions -> do
    logInfo "Wallet is initialized!"
    peers <- getKnownPeers
    logInfo $ sformat ("Known peers: "%build) peers
    let unpackPlugin (ActionSpec action) = action vI sendActions
    mapM_ (fork . unpackPlugin) $ plugins' ++ workers'
    logDebug "Forked all plugins successfully"
    sleepForever
  where
    (workers', wouts) = allWorkers
    outs = wouts <> pouts

runRawRealWallet
    :: RealModeResources
    -> WalletParams
    -> ListenersWithOut WalletRealMode
    -> (ActionSpec WalletRealMode a, OutSpecs)
    -> Production a
runRawRealWallet res WalletParams {..} listeners (ActionSpec action, outs) =
    usingLoggerName lpRunnerTag . bracket openDB closeDB $ \db -> do
        let walletContext = WalletContext {wcUnit = mempty}
        let rateLimiting = RL.rlLift . RL.rlLift . RL.rlLift . RL.rlLift . RL.rlLift . RL.rlLift $ rmRateLimiting res
        stateM <- liftIO SM.newIO
        runContextHolder walletContext .
            runWalletDB db .
            runKeyStorage wpKeyFilePath .
            runKademliaDHT (rmDHT res) .
            runPeerStateHolder stateM .
            runServer_ (rmTransport res) rateLimiting listeners outs . ActionSpec $ \vI sa ->
            logInfo "Started wallet, joining network" >> action vI sa
  where
    LoggingParams {..} = bpLoggingParams wpBaseParams
    openDB =
        maybe
            (openMemState wpGenesisUtxo)
            (openState wpRebuildDb wpGenesisUtxo)
            wpDbPath
    closeDB = closeState
