
module Laborantin (prepare, load, remove, analyze, expandTExprToParamSpace) where

import Laborantin.Types
import Laborantin.Query
import Laborantin.Implementation
import Control.Monad.IO.Class
import Control.Monad.Reader 
import Control.Monad.State 
import Control.Monad.Error
import Control.Applicative
import qualified Data.Set as S

prepare :: (MonadIO m)    => Backend m
                          -> TExpr Bool
                          -> [Execution m]
                          -> ScenarioDescription m
                          -> [m ()]
prepare b expr execs sc = map f $ filter matching $ listDiff target existing
    where existing = map eParamSet $ filter ((== Success) . eStatus) execs
          target = expandTExprToParamSpace sc expr
          f = execute b sc
          matching = matchTExpr' expr sc

expandTExprToParamSpace sc expr = paramSets $ expandParamSpace (sParams sc) expr

execute :: (MonadIO m) => Backend m -> ScenarioDescription m -> ParameterSet -> m ()
execute b sc prm = execution
  where execution = do
            (exec,final) <- bPrepareExecution b sc prm 
            status <- liftM fst $ runReaderT (runStateT (runErrorT (go exec `catchError` recover exec)) emptyEnv) (b, exec)
            let exec' = either (\_ -> exec {eStatus = Failure}) (\_ -> exec {eStatus = Success}) status
            bFinalizeExecution b exec' final
            where go exec = do 
                        bSetup b exec
                        bRun b exec
                        bTeardown b exec
                        bAnalyze b exec
                  recover exec err = bRecover b err exec >> throwError err

listDiff l1 l2 = S.toList (S.fromList l1 `S.difference` S.fromList l2)


load :: (MonadIO m) => Backend m -> [ScenarioDescription m] -> TExpr Bool -> m [Execution m]
load = bLoad

remove :: (MonadIO m) => Backend m -> Execution m -> m ()
remove = bRemove

analyze :: (MonadIO m, Functor m) => Backend m -> Execution m -> m (Either AnalysisError ())
analyze b exec = do
    let status = runReaderT (runStateT (runErrorT (go exec)) emptyEnv) (b, exec)
    (either rebrandError Right) . fst <$> status
    where go exec = bAnalyze b exec
          rebrandError (ExecutionError str) = Left $ AnalysisError str

