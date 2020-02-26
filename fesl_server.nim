import net
import os
import tables, strutils
import strformat # Required for fmt macro

const MESSAGE_PREFIX_LEN: int = 12

type
  EaMessage = object of RootObj
    TXN: string
  EaMessageOut =
    HelloOut | MemCheckOut | LoginOut |
    GetEntitlementByBundleOut | GetObjectInventoryOut |
    GetSubAccountsOut | LoginSubAccountOut |
    GetAccountOut | GameSpyPreAuthOut | PingOut
  HelloOut = object of EaMessage
    `domainPartition.domain`: string
    messengerIp: string
    messengerPort: int
    `domainPartition.subDomain`: string
    activityTimeoutSecs: int
    curTime: string
    theaterIp: string
    theaterPort: int
  MemCheckOut = object of EaMessage
    `memcheck.[]`: int
    `type`: int
    salt: int
  LoginOut = object of EaMessage
    profileId: int
    userId: int
    displayName: string
    lkey: string # or int? 123456789012345678901234567.
    encryptedLoginInfo: string
    `entitledGameFeatureWrappers.0.gameFeatureId`: int
    `entitledGameFeatureWrappers.0.status`: int
    `entitledGameFeatureWrappers.0.entitlementExpirationDate`: string #?
    `entitledGameFeatureWrappers.0.message`: string
    `entitledGameFeatureWrappers.0.entitlementExpirationDays`: int
  GetEntitlementByBundleOut = object of EaMessage
    localizedMessage: string
  GetObjectInventoryOut = object of EaMessage
    `entitlements.[]`: int
  GetSubAccountsOut = object of EaMessage
    `subAccounts.0`: string
    `subAccounts.[]`: int
  LoginSubAccountOut = object of EaMessage
    lkey: string # or int? 111111111111111111111111111.
    profileId: int
    userId: int
  GetAccountOut = object of EaMessage
    name: string
    profileID: int
    userId: int
    email: string
    countryCode: string
    countryDesc: string
    dobDay: int
    dobMonth: int
    dobYear: int
    zipCode: int
    gender: char
    eaMailFlag: int
    thirdPartyMailFlag: int
  GameSpyPreAuthOut = object of EaMessage
    challenge: string
    ticket: string
  PingOut = object of EaMessage

import times
proc newHelloOut(): HelloOut =
  result = HelloOut()
  result.TXN = "Hello"
  result.`domainPartition.domain` = "" # "eagames"
  result.messengerIp = "" # "0.0.0.0"
  result.messengerPort = 0
  result.`domainPartition.subDomain` = "" # "battlefield2142-2006"
  result.activityTimeoutSecs = 0
  result.curTime = "\"\"" # "\"May-24-2019 23%3a31%3a57 UTC\""
  result.theaterIp = "" # "0.0.0.0"
  result.theaterPort = 0

proc newMemCheckOut(): MemCheckOut =
  result = MemCheckOut()
  result.TXN = "MemCheck"
  result.`memcheck.[]` = 0
  result.`type` = 0
  result.salt = 0 # 1999533357

proc newLoginOut(userName: string): LoginOut =
  result = LoginOut()
  result.TXN = "Login"
  result.profileId = 0 # 10000011
  result.userId = 0 # 10000011
  result.displayName = userName
  result.lkey = "" # "123456789012345678901234567."
  result.encryptedLoginInfo = "" # "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  result.`entitledGameFeatureWrappers.0.gameFeatureId` = 0 # 2590
  result.`entitledGameFeatureWrappers.0.status` = 0
  result.`entitledGameFeatureWrappers.0.entitlementExpirationDate`= ""
  result.`entitledGameFeatureWrappers.0.message` = ""
  result.`entitledGameFeatureWrappers.0.entitlementExpirationDays` = -1

proc newGetEntitlementByBundleOut(): GetEntitlementByBundleOut =
  result = GetEntitlementByBundleOut()
  result.TXN = "GetEntitlementByBundle"
  result.localizedMessage = "" # "The"

proc newGetObjectInventoryOut(): GetObjectInventoryOut =
  result = GetObjectInventoryOut()
  result.TXN = "GetObjectInventory"
  result.`entitlements.[]` = 0

proc newGetSubAccountsOut(soldierName: string): GetSubAccountsOut =
  result = GetSubAccountsOut()
  result.TXN = "GetSubAccounts"
  result.`subAccounts.0` = soldierName
  result.`subAccounts.[]` = 1

proc newLoginSubAccountOut(): LoginSubAccountOut =
  result = LoginSubAccountOut()
  result.TXN = "LoginSubAccount"
  result.lkey = "" # "111111111111111111111111111."
  result.profileId = 0 # 10000012
  result.userId = 0 # 10000012

proc newGetAccountOut(userName: string): GetAccountOut =
  result = GetAccountOut()
  result.TXN = "GetAccount"
  result.name = userName # Or userName?
  result.profileID = 0 # 10000011
  result.userId = 0 # 10000011
  result.email = "" # "email@local.local"
  result.countryCode = "" # "AN"
  result.countryDesc = "" # "AN"
  result.dobDay = 0
  result.dobMonth = 0
  result.dobYear = 0 # 1900
  result.zipCode = 0 # 123
  result.gender = ' ' # 'U'
  result.eaMailFlag = 0
  result.thirdPartyMailFlag = 0

proc newGameSpyPreAuthOut(): GameSpyPreAuthOut =
  result = GameSpyPreAuthOut()
  result.TXN = "GameSpyPreAuth"
  result.challenge = "a" # "ptxgdnxg" # INFO: By default they are 8 lowercase charachters
  result.ticket = "a" # "vb5Mv7pE7pkrhQJUjt+krhw5sfTFaa6Ky2QJ0zViu8H3vbZc3v7pkrBgRolqiucXfz1SGYd2QpkLRI1y2wZcXfzViO" # INFO: By default its an (ea) base64 hash

proc newPingOut(): PingOut =
  result = PingOut()
  result.TXN = "Ping"

proc serialize(obj: EaMessageOut, id: uint8): string =
  if obj is HelloOut | MemCheckOut | PingOut:
    result = "fsys"
  elif obj is LoginOut:
    result = "acct"
  elif obj is GetEntitlementByBundleOut:
    result = "subs"
  elif obj is GetObjectInventoryOut:
    result = "dobj"
  elif obj is GetSubAccountsOut | LoginSubAccountOut | GetAccountOut | GameSpyPreAuthOut:
    result = "acct"
  result.add char(0x80) & char(0x0) & char(0x0)
  result.add char(id)
  result.add char(0x0) & char(0x0) & char(0x0) & char(0x0) # This is the length from the whole string and will be set later
  for key, val in obj.fieldPairs:
    result.add key & "=" & $val & '\n'
  var length: uint32 = cast[uint32](result.len)
  result[MESSAGE_PREFIX_LEN - 4] = char(length shr 24)
  result[MESSAGE_PREFIX_LEN - 3] = char(length shl 8 shr 24)
  result[MESSAGE_PREFIX_LEN - 2] = char(length shl 16 shr 24)
  result[MESSAGE_PREFIX_LEN - 1] = char(length shl 24 shr 24)

proc parseData(data: string): Table[string, string] =
  result = initTable[string, string]()
  for line in data.split('\n'):
    var keyVal: seq[string] = line.split("=", 1)
    if keyVal.len == 1: break
    result.add(keyVal[0], keyVal[1])

proc send(client: Socket, data: string) =
  net.send(client, data)
  var txnPos: int = data.find("TXN=", MESSAGE_PREFIX_LEN) + 4
  echo "FESL - Send: ", data.substr(txnPos, data.find({' ', '\n'}, txnPos))

proc pingInterval(data: tuple[client: Socket, channelKillThread: ptr Channel[void]]) {.thread.} =
  while true:
    sleep(30_000)
    if cast[var Channel[void]](data.channelKillThread).peek() == -1: # TODO: Need to cast every loop, because cast creates a new object
      return
    data.client.send(newPingOut().serialize(0))


proc handleFeslClient(client: Socket) {.thread.} =
  var prefix: string
  var length: uint32
  var id: uint8
  var data: string
  var playerName: string
  var isConnected: bool
  var dataTbl: Table[string, string]
  var channelKillThread: Channel[void]
  var threadPingInterval: Thread[tuple[client: Socket, channelKillThread: ptr Channel[void]]]

  while true:
    isConnected = if client.recv(prefix, MESSAGE_PREFIX_LEN) == 0: false else: true
    if isConnected:
      if prefix.len == 0:
        break
      id = uint8(prefix[7])
      length = (cast[uint32](prefix[MESSAGE_PREFIX_LEN - 1]) shl 0) or
               (cast[uint32](prefix[MESSAGE_PREFIX_LEN - 2]) shl 8) or
               (cast[uint32](prefix[MESSAGE_PREFIX_LEN - 3]) shl 16) or
               (cast[uint32](prefix[MESSAGE_PREFIX_LEN - 4]) shl 24)
      isConnected = if client.recv(data, int(length) - MESSAGE_PREFIX_LEN) == 0: false else: true
    if not isConnected:
      break
    dataTbl = data.parseData()
    if dataTbl.contains("TXN"):
      echo "FESL - Received: ", dataTbl
      case dataTbl["TXN"]:
        of "Hello":
          client.send(newHelloOut().serialize(id))
          client.send(newMemCheckOut().serialize(id))
        of "Login":
          playerName = dataTbl["name"]
          client.send(newLoginOut(playerName).serialize(id))
        of "GetEntitlementByBundle":
          client.send(newGetEntitlementByBundleOut().serialize(id))
        of "GetObjectInventory":
          client.send(newGetObjectInventoryOut().serialize(id))
        of "GetSubAccounts":
          client.send(newGetSubAccountsOut(playerName).serialize(id))
        of "LoginSubAccount":
          client.send(newLoginSubAccountOut().serialize(id))
        of "GetAccount":
          client.send(newGetAccountOut(playerName).serialize(id))
        of "GameSpyPreAuth":
          client.send(newGameSpyPreAuthOut().serialize(id))
          channelKillThread.open()
          threadPingInterval.createThread(pingInterval, (client, addr channelKillThread))
        else:
          discard
          # echo "Unhandled TXN: ", data
    data = ""
  channelKillThread.close()
  if threadPingInterval.running:
    threadPingInterval.joinThread() # Waiting for ping thread is closed
  echo "FESL - Client disconnected!"

proc run*(ipAddress: IpAddress) {.thread.} =
  var sslContext: SslContext = newContext(protVersion = protSSLv23, verifyMode = CVerifyNone, certFile = "ssl_certs" / "cert.pem", keyFile = "ssl_certs" / "key.pem")
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
  echo fmt"Fesl server running on {$ipAddress}:{$port} and waiting for clients!"
  while true:
    client = newSocket()
    address = ""
    try:
      server.acceptAddr(client, address)
      echo("FESL => Client connected from: ", address)
      echo "FESL => Client.isSsl: ", client.isSsl
      thread.createThread(handleFeslClient, client)
    except: # TODO: If clients sends wrong data (like ddos or something else)
      discard
    # thread.joinThread()

when isMainModule:
  run("0.0.0.0".parseIpAddress()) # TODO