{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

module LowLevelTests.Op where

import           Control.Concurrent             (threadDelay)
import           Data.ByteString                (isPrefixOf)
import           Foreign.Storable               (peek)
import           Test.Tasty
import           Test.Tasty.HUnit               as HU (testCase, (@?=),
                                                       assertBool)

import           Network.GRPC.LowLevel
import           Network.GRPC.LowLevel.Call
import           Network.GRPC.LowLevel.Client
import           Network.GRPC.LowLevel.Server
import           Network.GRPC.LowLevel.Op
import           Network.GRPC.LowLevel.CompletionQueue

lowLevelOpTests :: TestTree
lowLevelOpTests = testGroup "Synchronous unit tests of low-level Op interface"
  [testCancelFromServer]

testCancelFromServer :: TestTree
testCancelFromServer =
  testCase "Client/Server - client receives server cancellation" $
  runSerialTest $ \grpc ->
    withClientServerUnaryCall grpc $
    \(Client{..}, Server{..}, ClientCall{..}, sc@ServerCall{..}) -> do
      serverCallCancel sc StatusPermissionDenied "TestStatus"
      clientRes <- runOps unClientCall clientCQ clientRecvOps
      case clientRes of
        Left x -> error $ "Client recv error: " ++ show x
        Right [_,_,OpRecvStatusOnClientResult _ code details] -> do
          code @?= StatusPermissionDenied
          assertBool "Received status details or RST_STREAM error" $
            details == "TestStatus"
            ||
            isPrefixOf "Received RST_STREAM" details
          return $ Right ()
        wrong -> error $ "Unexpected op results: " ++ show wrong


runSerialTest :: (GRPC -> IO (Either GRPCIOError ())) -> IO ()
runSerialTest f =
  withGRPC f >>= \case Left x -> error $ show x
                       Right () -> return ()

withClientServerUnaryCall :: GRPC
                             -> ((Client, Server, ClientCall, ServerCall)
                                 -> IO (Either GRPCIOError a))
                             -> IO (Either GRPCIOError a)
withClientServerUnaryCall grpc f = do
  withClient grpc clientConf $ \c -> do
    crm <- clientRegisterMethod c "/foo" Normal
    withServer grpc serverConf $ \s ->
      withClientCall c crm 10 $ \cc -> do
        let srm = head (normalMethods s)
        -- NOTE: We need to send client ops here or else `withServerCall` hangs,
        -- because registered methods try to do recv ops immediately when
        -- created. If later we want to send payloads or metadata, we'll need
        -- to tweak this.
        _clientRes <- runOps (unClientCall cc) (clientCQ c) clientEmptySendOps
        withServerCall s srm $ \sc ->
          f (c, s, cc, sc)

serverConf :: ServerConfig
serverConf = ServerConfig "localhost" 50051 [("/foo", Normal)] []

clientConf :: ClientConfig
clientConf = ClientConfig "localhost" 50051 []

clientEmptySendOps :: [Op]
clientEmptySendOps = [OpSendInitialMetadata mempty,
                      OpSendMessage "",
                      OpSendCloseFromClient]

clientRecvOps :: [Op]
clientRecvOps = [OpRecvInitialMetadata,
                 OpRecvMessage,
                 OpRecvStatusOnClient]

serverEmptyRecvOps :: [Op]
serverEmptyRecvOps = [OpSendInitialMetadata mempty,
                      OpRecvMessage,
                      OpRecvCloseOnServer]
