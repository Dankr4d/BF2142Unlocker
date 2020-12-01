import fesl
import net
import ospaths
import tables
import terminal
import strformat # Required for fmt macro

proc send*(client: Socket, data: EaMessageType, id: uint8) =
  fesl.send(client, data, id)
  stdout.styledWriteLine(fgGreen, "<== ", fgCyan, "LOGIN: ", resetStyle, $data) # data.substr(txnPos, data.find({' ', '\n'}, txnPos)))
  stdout.flushFile()

proc handleFeslClient(client: Socket) {.thread.} =
  var prefix: string
  var length: uint32
  var id: uint8
  var data: string
  var playerName: string
  var dataTbl: Table[string, string]
  var channelKillThread: Channel[void]
  var threadPingInterval: Thread[tuple[client: Socket, channelKillThread: ptr Channel[void]]]

  while true:
    if not client.recv(data, id):
      break
    dataTbl = data.parseData()
    if dataTbl.contains("TXN"):
      stdout.styledWriteLine(fgGreen, "==> ", fgCyan, "LOGIN: ", resetStyle, $dataTbl)
      stdout.flushFile()
      case dataTbl["TXN"]:
        of "Hello":
          client.send(newHelloServer(), id)
          client.send(newMemCheckServer(), id)
        of "Login":
          playerName = dataTbl["name"]
          client.send(newLoginServer(playerName), id)
        of "GetEntitlementByBundle":
          client.send(newGetEntitlementByBundleServer(), id)
        of "GetObjectInventory":
          client.send(newGetObjectInventoryServer(), id)
        of "GetSubAccounts":
          client.send(newGetSubAccountsServer(playerName), id)
        of "LoginSubAccount":
          client.send(newLoginSubAccountServer(), id)
        of "GetAccount":
          client.send(newGetAccountServer(playerName), id)
        of "GameSpyPreAuth":
          client.send(newGameSpyPreAuthServer(), id)
          channelKillThread.open()
          threadPingInterval.createThread(pingInterval, (client, addr channelKillThread))
        else:
          discard
          # echo "Unhandled TXN: ", data
    data = ""
  channelKillThread.close()
  if threadPingInterval.running:
    threadPingInterval.joinThread() # Waiting for ping thread is closed
  stdout.styledWriteLine(fgBlue, "### ", fgCyan, "LOGIN: ", resetStyle, "Client (", $client.getFd().int, ") disconnected!")
  stdout.flushFile()

proc run*(ipAddress: IpAddress) {.thread.} =
  var sslContext: SslContext = newContext(protVersion = protSSLv23, verifyMode = CVerifyNone, certFile = "ssl_certs" / "cert.pem", keyFile = "ssl_certs" / "key.pem", cipherList = "SSLv3")
  var server: Socket = newSocket()
  let port: Port = Port(18300)
  sslContext.wrapSocket(server)
  server.setSockOpt(OptReuseAddr, true)
  server.setSockOpt(OptReusePort, true)
  server.bindAddr(port, $ipAddress)
  server.listen()

  var client: Socket
  var address: string
  var thread: Thread[Socket]
  echo fmt"Login (TCP) server listening on {$ipAddress}:{$port} and waiting for clients!"
  while true:
    client = newSocket()
    address = ""
    try:
      server.acceptAddr(client, address)
      stdout.styledWriteLine(fgBlue, "### ", fgCyan, "LOGIN: ", resetStyle, "Client (", $client.getFd().int, ") connected from: ", address)
      stdout.flushFile()
      thread.createThread(handleFeslClient, client)
    except: # TODO: If clients sends wrong data (like ddos or something else)
      discard
    # thread.joinThread()

when isMainModule:
  run("0.0.0.0".parseIpAddress()) # TODO