
module Laborantin where

import Laborantin.Types
import Laborantin.DSL
import Laborantin.Implementation
import Control.Monad.IO.Class
import Control.Monad.Reader
import Control.Monad.Error
import qualified Data.Set as S

execute :: (MonadIO m) => Backend m -> ScenarioDescription m -> ParameterSet -> m ()
execute b sc prm = execution
  where execution = do
            (exec,final) <- bPrepareExecution b sc prm 
            status <- runReaderT (runErrorT (go exec `catchError` recover exec)) (b, exec)
            let exec' = either (\_ -> exec {eStatus = Failure}) (\_ -> exec {eStatus = Success}) status
            bFinalizeExecution b exec' final
            where go exec = do 
                        bSetup b exec
                        bRun b exec
                        bTeardown b exec
                        bAnalyze b exec
                  recover exec err = bRecover b exec >> throwError err

executeExhaustive :: (MonadIO m) => Backend m -> ScenarioDescription m -> m ()
executeExhaustive b sc = mapM_ f $ paramSets $ sParams sc
    where f = execute b sc 

executeMissing :: (MonadIO m) => Backend m -> ScenarioDescription m -> m ()
executeMissing b sc = do
    execs <- load b sc
    let exhaustive = S.fromList $ paramSets (sParams sc)
    let existing = S.fromList $ map eParamSet execs
    mapM_ f $ S.toList (exhaustive `S.difference` existing)
    where f = execute b sc


load :: (MonadIO m) => Backend m -> ScenarioDescription m -> m [Execution m]
load = bLoad
