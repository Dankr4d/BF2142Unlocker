import net
import strformat # Required for fmt macro
import pure/terminal

var playerId: int = 2001 # ID must start with 2001 or Battlefield 2142 will NOT unlock the weapons

proc handleClient(client: Socket) =
  var data: string
  var sdata: string
  sdata = """\lc\1\challenge\\id\1\final\"""
  client.send(sdata)
  stdout.styledWriteLine(fgGreen, "<== ", fgYellow, "LOGIN_UDP: ", resetStyle, sdata)
  stdout.flushFile()
  try:
    client.readLine(data, maxLength = 512, timeout = 1000)
  except TimeoutError:
    discard
  stdout.styledWriteLine(fgGreen, "==> ", fgYellow, "LOGIN_UDP: ", resetStyle, data)
  stdout.flushFile()
  sdata = """\lc\2\sesskey\""" & $playerId & """\proof\\userid\""" & $playerId & """\profileid\""" & $playerId & """\uniquenick\\id\1\final\"""
  client.send(sdata)
  stdout.styledWriteLine(fgGreen, "<== ", fgYellow, "LOGIN_UDP: ", resetStyle, sdata)
  stdout.flushFile()
  playerId.inc()
  while true:
    try:
      client.readLine(data, maxLength = 512, timeout = 1000)
      if data.len > 0:
        stdout.styledWriteLine(fgGreen, "==> ", fgYellow, "LOGIN_UDP: ", resetStyle, data)
        stdout.flushFile()
      else:
        break
    except TimeoutError:
      discard
  stdout.styledWriteLine(fgBlue, "### ", fgYellow, "LOGIN_UDP: ", resetStyle, "Client (", $client.getFd().int, ") disconnected!")
  stdout.flushFile()
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
  echo fmt"Login (UDP) server running on {$ipAddress}:{$port} and waiting for clients!"
  while true:
    client = newSocket()
    address = ""
    gpcmServer.acceptAddr(client, address)
    stdout.styledWriteLine(fgBlue, "### ", fgYellow, "LOGIN_UDP: ", resetStyle, "Client (", $client.getFd().int, ") connected from: ", address)
    stdout.flushFile()
    thread.createThread(handleClient, client)
    # thread.joinThread()

when isMainModule:
  run("0.0.0.0".parseIpAddress())