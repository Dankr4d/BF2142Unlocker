import ../protocol/fesl
import net
import tables
import terminal
import strformat # Required for fmt macro
import os

const PROXY_ADDRESS*: string = "127.0.0.1"
const PROXY_PORT*: Port = Port(18301)

const RECV_TIMEOUT: int = 1_000


var channelKill: Channel[bool]
channelKill.open()
channelKill.close() # TODO: WTF Why do i need to call open and close only to check if peek returns -1? !?!?!

proc send(client: Socket, data: EaMessageType, id: uint8) =
  fesl.send(client, data, id)
  stdout.styledWriteLine(fgGreen, "<== ", fgCyan, "FESL: ", resetStyle, $data) # data.substr(txnPos, data.find({' ', '\n'}, txnPos)))
  stdout.flushFile()

proc connect(client: Socket, domain: string, port: Port = Port(18300)) =
  var sslContext: SslContext = newContext(protVersion = protSSLv23, verifyMode = CVerifyNone, cipherList = "SSLv3")
  wrapSocket(sslContext, client)
  net.connect(client, domain, port) # TODO: Handle OSError Exception


proc proxySocketData(sockets: tuple[src: Socket, dst: Socket]) {.thread.} =
  var data: string

  while true:
    data = ""

    if channelKill.peek > 0:
      sockets.src.close()
      return

    try:
      if sockets.src.recvRaw(data, RECV_TIMEOUT) == 0:
        channelKill.send(true)
        return
    except TimeoutError:
      continue
    except IndexDefect:
      # connection closed during recv
      channelKill.send(true)
      return

    net.send(sockets.dst, data)


proc running*(): bool =
  return channelKill.peek != -1


proc stop*() =
  if running():
    channelKill.send(true)
    while running():
      sleep(50)


proc run(dest: tuple[address: string, port: Port]) {.thread.} =
  channelKill = Channel[bool]() # Required.. stupid behaviour ..
  channelKill.open()

  var sslContext: SslContext = newContext(protVersion = protSSLv23, verifyMode = CVerifyNone, certFile = "cert" / "cert.pem", keyFile = "cert" / "key.pem", cipherList = "SSLv3")
  var server: Socket = newSocket()
  sslContext.wrapSocket(server)
  server.setSockOpt(OptReuseAddr, true)
  server.setSockOpt(OptReusePort, true)
  server.bindAddr(PROXY_PORT, PROXY_ADDRESS)
  server.listen()

  var client: Socket
  var address: string
  echo fmt"Fesl server listening on {PROXY_ADDRESS}:{$PROXY_PORT} and waiting for clients!"
  # while true:
  client = newSocket()
  address = ""
  try:
    server.acceptAddr(client, address)
    stdout.styledWriteLine(fgBlue, "### ", fgCyan, "FESL PROXY: ", resetStyle, "Client (", $client.getFd().int, ") connected from: ", address)
    stdout.flushFile()

    var destination: Socket = newSocket()
    connect(destination, dest.address, dest.port)

    var thread: Thread[tuple[src: Socket, dst: Socket]]
    var thread2: Thread[tuple[src: Socket, dst: Socket]]

    thread.createThread(proxySocketData, (client, destination))
    thread2.createThread(proxySocketData, (destination, client))

    joinThreads(thread, thread2)
    channelKill.close()
    server.close()
  except:
    discard # TODO


proc start*(address: string, port: Port): Thread[tuple[address: string, port: Port]] =
  if running():
    stop() # TODO: Throw an exception?
  result.createThread(run, (address, port))


when isMainModule:
  var thread: Thread[tuple[address: string, port: Port]] = start("fesl.openspy.net", Port(18301))
  # var thread: Thread[tuple[address: string, port: Port]] = start("2142.novgames.ru", Port(18300))
  joinThread(thread)
