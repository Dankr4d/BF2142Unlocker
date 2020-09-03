import net
import strformat # Required for fmt macro

var playerId: int = 2001 # ID must start with 2001 or Battlefield 2142 will NOT unlock the weapons

proc handleClient(client: Socket) =
  var data: string
  var sdata: string
  sdata = """\lc\1\challenge\\id\1\final\"""
  client.send(sdata)
  echo "GPCM - Send: ", sdata
  try:
    client.readLine(data, maxLength = 512, timeout = 1000)
  except TimeoutError:
    discard
  echo "GPCM - Received: ", data
  sdata = """\lc\2\sesskey\""" & $playerId & """\proof\\userid\""" & $playerId & """\profileid\""" & $playerId & """\uniquenick\\id\1\final\"""
  try:
    client.send(sdata)
  except OSError:
    return # TODO: This may crash in the connection testing state from the gui.
           # It fails with: An connection was forcibly closed by the remote host.
           #                Additional info: "Could not send all data."
  echo "GPCM - Send: ", sdata
  playerId.inc()
  while true:
    try:
      client.readLine(data, maxLength = 512, timeout = 1000)
      if data.len > 0:
        echo "GPCM - RECEIVED: ", data
      else:
        break
    except TimeoutError:
      discard
  echo "GPCM - Client disconented!"
  # client.close()

proc run*(ipAddress: IpAddress) =
  var gpcmServer: Socket = newSocket()
  let port: Port = Port(29900)
  gpcmServer.setSockOpt(OptReuseAddr, true)
  gpcmServer.setSockOpt(OptReusePort, true)
  gpcmServer.bindAddr(port, $ipAddress)
  gpcmServer.listen()

  var client: Socket
  var address: string
  var thread: Thread[Socket]
  echo fmt"Gpcm server running on {$ipAddress}:{$port} and waiting for clients!"
  while true:
    client = newSocket()
    address = ""
    gpcmServer.acceptAddr(client, address)
    echo("feslAcceptLoopGPCM => Client connected from: ", address)
    thread.createThread(handleClient, client)
    # thread.joinThread()

when isMainModule:
  run("0.0.0.0".parseIpAddress())