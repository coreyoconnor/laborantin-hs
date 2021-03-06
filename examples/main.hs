{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where
 
import Laborantin.DSL
import Laborantin.Types
import Laborantin.Implementation
import Laborantin.CLI
import qualified Data.Text as T

{- 
 - Example
 -}

pong :: ScenarioDescription EnvIO
pong = scenario "pong" $ do
    parameter "foo" $ do
        describe "foo"
        values [str "foo"]

ping :: ScenarioDescription EnvIO
ping = scenario "ping" $ do
  describe "ping to a remote server"
  require pong "@sc.param 'foo' == 'foo'" 
  parameter "destination" $ do
    describe "a destination server (host or ip)"
    values [str "example.com", str "probecraft.net"]
  parameter "packet-size" $ do
    describe "packet size in bytes"
    values [num 50, num 1500] 
  parameter "burst-length" $ do
    describe "number of back-to-back packets to send"
    values [range 1 100 10] 
  setup $ do
      setVar "hello" ("world"::String)
      dbg "setting up scenario"
  run $ do
    ancestors "pong" >>= liftIO . print . (\n ->  show n ++ " ancestor(s)") . length
    (Just str :: Maybe String) <- getVar "hello"
    liftIO . print . ("hello "++) $ str
    (StringParam srv) <- param "destination"
    case srv of
        "failure.example" -> err "noooo"
        str               -> dbg $ T.append "mimic sending ping to " str
    writeResult "raw-result" "a sort of result stored as a separate file"
  teardown $ dbg "here we could run some teardown action"
  recover $ \err -> dbg $ T.append "here we could recover from error: " (T.pack $ show err)
  analyze $ liftIO . print $ "analyze action"

main = defaultMain [ping, pong]
