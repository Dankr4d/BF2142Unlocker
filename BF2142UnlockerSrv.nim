import servers/fesl
import servers/gpcm
import servers/stats
import net
import strformat # Required for fmt macro

when defined(windows):
  static:
    discard staticExec("windres.exe BF2142UnlockerSrv.rc -O coff -o BF2142UnlockerSrv.res")


type
  UnlockParam = tuple[ipAddress: IpAddress, unlockAllSquadGadgets: bool]

# TODO: Have a look at the comments (regarding unlockAllSquadGadgets) on the gloabl variable in unlock_server.nim
proc run*(ipAddress: IpAddress, unlockAllSquadGadgets: bool = false) =
  var
    threadFeslServer: Thread[IpAddress]
    threadGpcmServer: Thread[IpAddress]
    threadUnlockServer: Thread[UnlockParam]
  threadFeslServer.createThread(fesl.run, ipAddress)
  threadGpcmServer.createThread(gpcm.run, ipAddress)
  threadUnlockServer.createThread(stats.run, (ipAddress, unlockAllSquadGadgets))
  joinThreads(threadFeslServer, threadGpcmServer)
  joinThread(threadUnlockServer) # TODO: Why is this not in joinThreads above?

when isMainModule:
  import os # Required for commandLineParams
  let params: seq[string] = commandLineParams()
  if params.len < 1:
    echo "IP-Address param missing! Aborted starting login/unlock server."
    quit(1)
  if not params[0].isIpAddress():
    echo fmt"Passed ip address ({params[0]}) is not a valid ip address."
    quit(1)
  import strutils
  var unlockAllSquadGadgets: bool = false
  if params.len > 1:
    unlockAllSquadGadgets = params[1].parseBool()
  let ipAddress: IpAddress = params[0].parseIpAddress()
  if ipAddress.family == IPv6:
    echo "Passed IP-Address family is ipv6. Ipv4 currently only allowed."
    quit(1)
  run(ipAddress, unlockAllSquadGadgets)