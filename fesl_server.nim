import net
import os
import tables, strutils
import strformat # Required for fmt macro
import terminal

const MESSAGE_PREFIX_LEN: int = 12

type
  EaMessage = object of RootObj
    TXN: string
  EaMessageType =
    HelloServer | HelloClient |
    MemCheckServer | MemCheckClient |
    LoginServer | LoginClient |
    GetEntitlementByBundleServer | GetEntitlementByBundleClient |
    GetObjectInventoryServer | GetObjectInventoryClient |
    GetSubAccountsServer | GetSubAccountsClient |
    LoginSubAccountServer | LoginSubAccountClient |
    GetAccountServer | GetAccountClient |
    GameSpyPreAuthServer | GameSpyPreAuthClient |
    Ping
  FsysType =
    HelloServer | HelloClient |
    MemCheckServer | MemCheckClient |
    Ping
  AcctType =
    LoginServer | LoginClient |
    GetSubAccountsServer | GetSubAccountsClient |
    LoginSubAccountServer | LoginSubAccountClient |
    GetAccountServer | GetAccountClient |
    GameSpyPreAuthServer | GameSpyPreAuthClient
  SubsType =
    GetEntitlementByBundleServer | GetEntitlementByBundleClient
  DobjType =
    GetObjectInventoryServer | GetObjectInventoryClient
  HelloServer = object of EaMessage
    `domainPartition.domain`: string
    messengerIp: string
    messengerPort: int
    `domainPartition.subDomain`: string
    activityTimeoutSecs: int
    curTime: string
    theaterIp: string
    theaterPort: int
  HelloClient = object of EaMessage
    clientString: string # bf2142-pc
    sku: int # 125170
    locale: string # en_US
    clientPlatform: string # PC
    clientVersion: string # 1.10.112.0
    SDKVersion: string # 2.8.0.1.0
    protocolVersion: string # 2.0
    fragmentSize: int # 2048
  MemCheckServer = object of EaMessage
    `memcheck.[]`: int
    `type`: int
    salt: int
  MemCheckClient = object of EaMessage
    result: string
  LoginServer = object of EaMessage
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
  LoginClient = object of EaMessage
    returnEncryptedInfo: int
    name: string
    password: string
    machineId: string
    macAddr: string
  GetEntitlementByBundleServer = object of EaMessage
    localizedMessage: string # TODO: Check this, openspy sends: {TXN=GetEntitlementByBundle, EntitlementByBundle.[]=0}
  GetEntitlementByBundleClient = object of EaMessage
    bundleId: string # client request this 3 times: REG-PC-BF2142-UNLOCK-1, REG-PC-BF2142-UNLOCK-2 and REG-PC-BF2142-UNLOCK-3
  GetObjectInventoryServer = object of EaMessage
    `entitlements.[]`: int
  GetObjectInventoryClient = object of EaMessage
    domainId: string
    subdomainId: string
    partitionKey: string
    `objectIds.[]`: int
    `objectIds.0`: string
  GetSubAccountsServer = object of EaMessage
    `subAccounts.0`: string
    `subAccounts.[]`: int
  GetSubAccountsClient = object of EaMessage
  LoginSubAccountServer = object of EaMessage
    lkey: string # or int? 111111111111111111111111111.
    profileId: int
    userId: int
  LoginSubAccountClient = object of EaMessage
    name: string
  GetAccountServer = object of EaMessage
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
  GetAccountClient = object of EaMessage
  GameSpyPreAuthServer = object of EaMessage
    challenge: string
    ticket: string
  GameSpyPreAuthClient = object of EaMessage
  Ping = object of EaMessage # Server and client

proc newHelloServer(): HelloServer =
  result.TXN = "Hello"
  result.`domainPartition.domain` = "" # "eagames"
  result.messengerIp = "" # "0.0.0.0"
  result.messengerPort = 0
  result.`domainPartition.subDomain` = "" # "battlefield2142-2006"
  result.activityTimeoutSecs = 0
  result.curTime = "\"\"" # "\"May-24-2019 23%3a31%3a57 UTC\""
  result.theaterIp = "" # "0.0.0.0"
  result.theaterPort = 0

proc newHelloClient(): HelloClient =
  result.TXN = "Hello"
  result.clientString = "bf2142-pc"
  result.sku = 125170
  result.locale = "en_US"
  result.clientPlatform = "PC"
  result.clientVersion = "1.10.112.0"
  result.SDKVersion = "2.8.0.1.0"
  result.protocolVersion = "2.0"
  result.fragmentSize = 2048

proc newMemCheckServer(): MemCheckServer =
  result.TXN = "MemCheck"
  result.`memcheck.[]` = 0
  result.`type` = 0
  result.salt = 0 # 1999533357

proc newMemCheckClient(): MemCheckClient =
  result.TXN = "MemCheck"
  result.result = ""

proc newLoginServer(username: string): LoginServer =
  result.TXN = "Login"
  result.profileId = 0 # 10000011
  result.userId = 0 # 10000011
  result.displayName = username
  result.lkey = "" # "123456789012345678901234567."
  result.encryptedLoginInfo = "" # "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  result.`entitledGameFeatureWrappers.0.gameFeatureId` = 0 # 2590
  result.`entitledGameFeatureWrappers.0.status` = 0
  result.`entitledGameFeatureWrappers.0.entitlementExpirationDate`= ""
  result.`entitledGameFeatureWrappers.0.message` = ""
  result.`entitledGameFeatureWrappers.0.entitlementExpirationDays` = -1

proc newLoginClient(username, password: string): LoginClient =
  result.TXN = "Login"
  result.returnEncryptedInfo = 1
  result.name = username
  result.password = password
  result.machineId = ""
  result.macAddr = ""

proc newGetEntitlementByBundleServer(): GetEntitlementByBundleServer =
  result.TXN = "GetEntitlementByBundle"
  result.localizedMessage = "" # "The"

proc newGetEntitlementByBundleClient(): GetEntitlementByBundleClient =
  result.TXN = "GetEntitlementByBundle"
  # INFO: Client request this 3 times with bundleId set to REG-PC-BF2142-UNLOCK-1, REG-PC-BF2142-UNLOCK-2 and REG-PC-BF2142-UNLOCK-3
  result.bundleId = "REG-PC-BF2142-UNLOCK-1"

proc newGetObjectInventoryServer(): GetObjectInventoryServer =
  result.TXN = "GetObjectInventory"
  result.`entitlements.[]` = 0

proc newGetObjectInventoryClient(): GetObjectInventoryClient =
  result.TXN = "GetObjectInventory"
  # INFO: Client requests this 3 times with following set:
  # 1: domainId=eagames, subdomainId=bf2142, partitionKey=online_content, objectIds.[]=1, objectIds.0=bf2142_bp1
  # 2: domainId=cqc, subdomainId=cqc, partitionKey=online_content_cqc, objectIds.[]=1, objectIds.0=bf2142_bp1
  # 3: domainId=eagames, subdomainId=bf2142, partitionKey=online_content, objectIds.[]=1, objectIds.0=bf2142_bp1_beta
  result.domainId = "eagames"
  result.subdomainId = "bf2142"
  result.partitionKey = "online_content"
  result.`objectIds.[]` = 1
  result.`objectIds.0` = "bf2142_bp1"

proc newGetSubAccountsServer(soldierName: string): GetSubAccountsServer =
  result.TXN = "GetSubAccounts"
  result.`subAccounts.0` = soldierName
  result.`subAccounts.[]` = 1

proc newGetSubAccountsClient(): GetSubAccountsClient =
  result.TXN = "GetSubAccounts"

proc newLoginSubAccountServer(): LoginSubAccountServer =
  result.TXN = "LoginSubAccount"
  result.lkey = "" # "111111111111111111111111111."
  result.profileId = 0 # 10000012
  result.userId = 0 # 10000012

proc newLoginSubAccountClient(soldierName: string): LoginSubAccountClient =
  result.TXN = "LoginSubAccount"
  result.name = soldierName

proc newGetAccountServer(username: string): GetAccountServer =
  result.TXN = "GetAccount"
  result.name = username
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

proc newGetAccountClient(): GetAccountClient =
  result.TXN = "GetAccount"

proc newGameSpyPreAuthServer(): GameSpyPreAuthServer =
  result.TXN = "GameSpyPreAuth"
  result.challenge = "a" # "ptxgdnxg" # INFO: By default they are 8 lowercase charachters
  result.ticket = "a" # "vb5Mv7pE7pkrhQJUjt+krhw5sfTFaa6Ky2QJ0zViu8H3vbZc3v7pkrBgRolqiucXfz1SGYd2QpkLRI1y2wZcXfzViO" # INFO: By default its an (ea) base64 hash

proc newGameSpyPreAuthClient(): GameSpyPreAuthClient =
  result.TXN = "GameSpyPreAuth"

proc newPing(): Ping =
  result.TXN = "Ping"

proc serialize(obj: EaMessageType, id: uint8): string =
  if obj is FsysType:
    result = "fsys"
  elif obj is AcctType:
    result = "acct"
  elif obj is SubsType:
    result = "subs"
  elif obj is DobjType:
    result = "dobj"
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

proc send(client: Socket, data: EaMessageType, id: uint8) =
  net.send(client, data.serialize(id))
  stdout.styledWriteLine(fgGreen, "<== ", fgCyan, "LOGIN: ", resetStyle, $data) # data.substr(txnPos, data.find({' ', '\n'}, txnPos)))
  stdout.flushFile()

proc pingInterval(data: tuple[client: Socket, channelKillThread: ptr Channel[void]]) {.thread.} =
  while true:
    sleep(30_000)
    if cast[var Channel[void]](data.channelKillThread).peek() == -1: # TODO: Need to cast every loop, because cast creates a new object
      return
    data.client.send(newPing(), 0)


proc recv(socket: Socket, data: var string, id: var uint8, timeout: int = -1): bool =
  var prefix: string
  var length: uint32
  if socket.recv(prefix, MESSAGE_PREFIX_LEN, timeout) == 0:
    return false
  if prefix.len == 0:
    return false
  id = uint8(prefix[7])
  length = (cast[uint32](prefix[MESSAGE_PREFIX_LEN - 1]) shl 0) or
            (cast[uint32](prefix[MESSAGE_PREFIX_LEN - 2]) shl 8) or
            (cast[uint32](prefix[MESSAGE_PREFIX_LEN - 3]) shl 16) or
            (cast[uint32](prefix[MESSAGE_PREFIX_LEN - 4]) shl 24)
  if socket.recv(data, int(length) - MESSAGE_PREFIX_LEN) == 0:
    return false
  return true


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
  echo fmt"Login server running on {$ipAddress}:{$port} and waiting for clients!"
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

proc getSoldiers*(domain: string, port: Port, username, password: string): tuple[error: int, soldiers: seq[string]] = # TODO: Create error type
  var sslContext: SslContext = newContext(protVersion = protSSLv23, verifyMode = CVerifyNone, cipherList = "SSLv3")
  var client = newSocket()
  wrapSocket(sslContext, client)
  try:
    client.connect(domain, port)
  except OSError:
    return (1, @[]) # Could not connect

  var dataTbl: Table[string, string]
  var data: string
  var id: uint8

  let helloClient: HelloClient = newHelloClient()
  client.send(helloClient, 1)

  if not client.recv(data, id):
    return (2, @[]) # Server didn't send Hello

  if not client.recv(data, id):
    return (3, @[]) # Server didn't send MemCheck

  let memCheckClient: MemCheckClient = newMemCheckClient()
  client.send(memCheckClient, 0)

  let loginClient: LoginClient = newLoginClient(username, password)
  client.send(loginClient, 2)

  discard client.recv(data, id)
  dataTbl = parseData(data)
  if dataTbl.hasKey("errorCode"):
    return (4, @[]) # Username or password incorrect

  let getSubAccountsClient: GetSubAccountsClient = newGetSubAccountsClient()
  client.send(getSubAccountsClient, 9)

  if not client.recv(data, id):
    return (5, @[]) # Server didn't send GetSubAccounts

  dataTbl = parseData(data)

  let soldierAmount: int = parseInt(dataTbl["subAccounts.[]"]) - 1
  if soldierAmount == 0:
    return (0, @[]) # No soldier
  for idx in 0..soldierAmount:
    result.soldiers.add(dataTbl["subAccounts." & $idx])

when isMainModule:
  run("0.0.0.0".parseIpAddress()) # TODO