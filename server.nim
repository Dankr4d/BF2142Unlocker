import fesl_server, gpcm_server, unlock_server

proc run*() =
  var
    threadFeslServer: Thread[void]
    threadGpcmServer: Thread[void]
    threadUnlockServer: Thread[void]
  threadFeslServer.createThread(fesl_server.run)
  threadGpcmServer.createThread(gpcm_server.run)
  threadUnlockServer.createThread(unlock_server.run)
  joinThreads(threadFeslServer, threadGpcmServer, threadUnlockServer)

when isMainModule:
  run()