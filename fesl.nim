import net
import tables
import strutils
import base64

const MESSAGE_PREFIX_LEN: int = 12

type
  EaMessage* = object of RootObj
    TXN*: string
  EaMessageType* = FsysType | AcctType | SubsType | DobjType
  FsysType* =
    HelloServer | HelloClient |
    MemCheckServer | MemCheckClient |
    Ping
  AcctType* =
    LoginServer | LoginClient |
    GetSubAccountsServer | GetSubAccountsClient |
    LoginSubAccountServer | LoginSubAccountClient |
    GetAccountServer | GetAccountClient |
    GameSpyPreAuthServer | GameSpyPreAuthClient |
    AddSubAccountServer | AddSubAccountClient |
    DisableSubAccountServer | DisableSubAccountClient |
    GetCountryListServer | GetCountryListClient |
    AddAccountServer | AddAccountClient |
    RegisterGameServer | RegisterGameClient |
    UpdateAccountServer | UpdateAccountClient
  SubsType* =
    GetEntitlementByBundleServer | GetEntitlementByBundleClient
  DobjType* =
    GetObjectInventoryServer | GetObjectInventoryClient
  HelloServer* = object of EaMessage
    `domainPartition.domain`*: string
    messengerIp*: string
    messengerPort*: int
    `domainPartition.subDomain`*: string
    activityTimeoutSecs*: int
    curTime*: string
    theaterIp*: string
    theaterPort*: int
  HelloClient* = object of EaMessage
    clientString*: string # bf2142-pc
    sku*: int # 125170
    locale*: string # en_US
    clientPlatform*: string # PC
    clientVersion*: string # 1.10.112.0
    SDKVersion*: string # 2.8.0.1.0
    protocolVersion*: string # 2.0
    fragmentSize*: int # 2048
  MemCheckServer* = object of EaMessage
    `memcheck.[]`*: int
    `type`*: int
    salt*: int
  MemCheckClient* = object of EaMessage
    result*: string
  LoginServer* = object of EaMessage
    profileId*: int
    userId*: int
    displayName*: string
    lkey*: string # or int? 123456789012345678901234567.
    encryptedLoginInfo*: string
    `entitledGameFeatureWrappers.0.gameFeatureId`*: int
    `entitledGameFeatureWrappers.0.status`*: int
    `entitledGameFeatureWrappers.0.entitlementExpirationDate`*: string #?
    `entitledGameFeatureWrappers.0.message`*: string
    `entitledGameFeatureWrappers.0.entitlementExpirationDays`*: int
  LoginClient* = object of EaMessage
    returnEncryptedInfo*: int
    name*: string
    password*: string
    machineId*: string
    macAddr*: string
  GetEntitlementByBundleServer* = object of EaMessage
    localizedMessage*: string # TODO*: Check this, openspy sends*: {TXN=GetEntitlementByBundle, EntitlementByBundle.[]=0}
  GetEntitlementByBundleClient* = object of EaMessage
    bundleId*: string # client request this 3 times*: REG-PC-BF2142-UNLOCK-1, REG-PC-BF2142-UNLOCK-2 and REG-PC-BF2142-UNLOCK-3
  GetObjectInventoryServer* = object of EaMessage
    `entitlements.[]`*: int
  GetObjectInventoryClient* = object of EaMessage
    domainId*: string
    subdomainId*: string
    partitionKey*: string
    `objectIds.[]`*: int
    `objectIds.0`*: string
  GetSubAccountsServer* = object of EaMessage
    `subAccounts.0`*: string
    `subAccounts.[]`*: int
  GetSubAccountsClient* = object of EaMessage
  LoginSubAccountServer* = object of EaMessage
    lkey*: string # or int? 111111111111111111111111111.
    profileId*: int
    userId*: int
  LoginSubAccountClient* = object of EaMessage
    name*: string
  GetAccountServer* = object of EaMessage
    name*: string
    profileID*: int
    userId*: int
    email*: string
    countryCode*: string
    countryDesc*: string
    dobDay*: int
    dobMonth*: int
    dobYear*: int
    zipCode*: string
    gender*: char
    eaMailFlag*: int
    thirdPartyMailFlag*: int
  GetAccountClient* = object of EaMessage
  GameSpyPreAuthServer* = object of EaMessage
    challenge*: string
    ticket*: string
  GameSpyPreAuthClient* = object of EaMessage
  AddSubAccountServer* = object of EaMessage
    # Empty or:
    localizedMessage*: string
    errorContainer*: string
    errorCode*: int
  AddSubAccountClient* = object of EaMessage
    name*: string
  DisableSubAccountServer* = object of EaMessage
  DisableSubAccountClient* = object of EaMessage
    name*: string
  GetCountryListServer* = object of EaMessage
    # `countryList.[]*`: int
    `countryList.0.description`*: string
    `countryList.0.ISOCode`*: string
  GetCountryListClient* = object of EaMessage
  AddAccountServer* = object of EaMessage
    userId*: int
    profileId*: int
    # Or when it fails:
    errorContainer*: string
    errorCode*: int
  AddAccountClient* = object of EaMessage
    name*: string
    password*: string
    email*: string
    DOBDay*: int
    DOBMonth*: int
    DOBYear*: int
    zipCode*: string
    countryCode*: string # ISOCode
    eaMailFlag*: int # bool (checkbox)
    thirdPartyMailFlag*: int # bool (checkbox)
  RegisterGameServer* = object of EaMessage
  RegisterGameClient* = object of EaMessage
    code*: string # cdkey
    game*: string
    platform*: string
    name*: string # username
    password*: string # password
  UpdateAccountServer* = object of EaMessage
  UpdateAccountClient* = object of EaMessage
    email*: string
    parentalEmail*: string # Was this ever implemented?
    countryCode*: string # ISOCode
    eaMailFlag*: int # bool (checkbox)
    thirdPartyMailFlag*: int # bool (checkbox)
  Ping* = object of EaMessage # Server and client

proc newHelloServer*(): HelloServer =
  result.TXN = "Hello"
  result.`domainPartition.domain` = "" # "eagames"
  result.messengerIp = "" # "0.0.0.0"
  result.messengerPort = 0
  result.`domainPartition.subDomain` = "" # "battlefield2142-2006"
  result.activityTimeoutSecs = 0
  result.curTime = "\"\"" # "\"May-24-2019 23%3a31%3a57 UTC\""
  result.theaterIp = "" # "0.0.0.0"
  result.theaterPort = 0

proc newHelloClient*(): HelloClient =
  result.TXN = "Hello"
  result.clientString = "bf2142-pc"
  result.sku = 125170
  result.locale = "en_US"
  result.clientPlatform = "PC"
  result.clientVersion = "1.10.112.0"
  result.SDKVersion = "2.8.0.1.0"
  result.protocolVersion = "2.0"
  result.fragmentSize = 2048

proc newMemCheckServer*(): MemCheckServer =
  result.TXN = "MemCheck"
  result.`memcheck.[]` = 0
  result.`type` = 0
  result.salt = 0 # 1999533357

proc newMemCheckClient*(): MemCheckClient =
  result.TXN = "MemCheck"
  result.result = ""

proc newLoginServer*(username: string): LoginServer =
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

proc newLoginClient*(username, password: string): LoginClient =
  result.TXN = "Login"
  result.returnEncryptedInfo = 1
  result.name = username
  result.password = password
  result.machineId = ""
  result.macAddr = ""

proc newGetEntitlementByBundleServer*(): GetEntitlementByBundleServer =
  result.TXN = "GetEntitlementByBundle"
  result.localizedMessage = "" # "The"

proc newGetEntitlementByBundleClient*(): GetEntitlementByBundleClient =
  result.TXN = "GetEntitlementByBundle"
  # INFO: Client request this 3 times with bundleId set to REG-PC-BF2142-UNLOCK-1, REG-PC-BF2142-UNLOCK-2 and REG-PC-BF2142-UNLOCK-3
  result.bundleId = "REG-PC-BF2142-UNLOCK-1"

proc newGetObjectInventoryServer*(): GetObjectInventoryServer =
  result.TXN = "GetObjectInventory"
  result.`entitlements.[]` = 0

proc newGetObjectInventoryClient*(): GetObjectInventoryClient =
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

proc newGetSubAccountsServer*(soldier: string): GetSubAccountsServer =
  result.TXN = "GetSubAccounts"
  result.`subAccounts.0` = soldier
  result.`subAccounts.[]` = 1

proc newGetSubAccountsClient*(): GetSubAccountsClient =
  result.TXN = "GetSubAccounts"

proc newLoginSubAccountServer*(): LoginSubAccountServer =
  result.TXN = "LoginSubAccount"
  result.lkey = "" # "111111111111111111111111111."
  result.profileId = 0 # 10000012
  result.userId = 0 # 10000012

proc newLoginSubAccountClient*(soldier: string): LoginSubAccountClient =
  result.TXN = "LoginSubAccount"
  result.name = soldier

proc newGetAccountServer*(username: string): GetAccountServer =
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
  result.zipCode = "0" # 123
  result.gender = ' ' # 'U'
  result.eaMailFlag = 0
  result.thirdPartyMailFlag = 0

proc newGetAccountClient*(): GetAccountClient =
  result.TXN = "GetAccount"

proc newGameSpyPreAuthServer*(): GameSpyPreAuthServer =
  result.TXN = "GameSpyPreAuth"
  result.challenge = "a" # "ptxgdnxg" # INFO: By default they are 8 lowercase charachters
  result.ticket = "a" # "vb5Mv7pE7pkrhQJUjt+krhw5sfTFaa6Ky2QJ0zViu8H3vbZc3v7pkrBgRolqiucXfz1SGYd2QpkLRI1y2wZcXfzViO" # INFO: By default its an (ea) base64 hash

proc newGameSpyPreAuthClient*(): GameSpyPreAuthClient =
  result.TXN = "GameSpyPreAuth"

proc newAddSubAccountServer*(): AddSubAccountServer =
  result.TXN = "AddSubAccount"
  result.errorContainer = "[]"
  result.errorCode = 182 # Success

proc newAddSubAccountClient*(soldier: string): AddSubAccountClient =
  result.TXN = "AddSubAccount"
  result.name = soldier

proc newDisableSubAccountServer*(): DisableSubAccountServer =
  result.TXN = "DisableSubAccount"

proc newDisableSubAccountClient*(soldier: string): DisableSubAccountClient =
  result.TXN = "DisableSubAccount"
  result.name = soldier

proc newGetCountryListServer*(): GetCountryListServer =
  result.TXN = "GetCountryList"
  result.`countryList.0.description` = "Country"
  result.`countryList.0.ISOCode` = "ISO"

proc newGetCountryListClient*(): GetCountryListClient =
  result.TXN = "GetCountryList"

proc newAddAccountServer*(): AddAccountServer =
  result.TXN = "AddAccount"
  result.userId = 2001
  result.profileId = 2001
  # TODO: Or when it fails:
  result.errorContainer = "[]"
  result.errorCode = 0 # TODO: is there any success errorCode? Like 128?

proc newAddAccountClient*(username, password, email, countryCode: string): AddAccountClient =
  result.TXN = "AddAccount"
  result.name = username
  result.password = password
  result.email = email
  result.DOBDay = 1
  result.DOBMonth = 1
  result.DOBYear = 1900
  result.zipCode = "0"
  result.countryCode = countryCode
  result.eaMailFlag = 0
  result.thirdPartyMailFlag = 0

proc newRegisterGameServer*(): RegisterGameServer =
  result.TXN = "RegisterGame"

proc newRegisterGameClient*(username, password, cdkey: string): RegisterGameClient =
  result.TXN = "RegisterGame"
  result.code = cdkey
  result.game = "GAME-BF2142"
  result.platform = "pc"
  result.name = username
  result.password = password

proc newUpdateAccountServer*(): UpdateAccountServer =
  result.TXN = "UpdateAccount"

proc newUpdateAccountClient*(countryCode: string): UpdateAccountClient =
  result.TXN = "UpdateAccount"
  result.email = "localhost@localhost.localhost"
  result.parentalEmail = "" # Was this ever implemented?
  result.countryCode = countryCode
  result.eaMailFlag = 0
  result.thirdPartyMailFlag = 0

proc newPing*(): Ping =
  result.TXN = "Ping"

proc serialize*(obj: EaMessageType, id: uint8): string =
  if obj is FsysType:
    result = "fsys"
  elif obj is AcctType:
    result = "acct"
  elif obj is SubsType:
    result = "subs"
  elif obj is DobjType:
    result = "dobj"
  result.add("\x80\x00\x00")
  result.add(char(id))
  result.add("\x00\x00\x00\x00") # This is the length from the whole string and will be set later
  result.add("TXN=" & obj.TXN & "\n")
  for key, val in obj.fieldPairs:
    if key != "TXN":
       # INFO: ome server require that TXN is set first therefore I set it above the loop
      result.add key & "=" & $val & '\n'
  var length: uint32 = cast[uint32](result.len)
  result[MESSAGE_PREFIX_LEN - 4] = char(length shr 24)
  result[MESSAGE_PREFIX_LEN - 3] = char(length shl 8 shr 24)
  result[MESSAGE_PREFIX_LEN - 2] = char(length shl 16 shr 24)
  result[MESSAGE_PREFIX_LEN - 1] = char(length shl 24 shr 24)

proc parseData*(data: string): Table[string, string] =
  result = initTable[string, string]()
  for line in data.split('\n'):
    var keyVal: seq[string] = line.split("=", 1)
    if keyVal.len == 1: break
    result.add($cstring(keyVal[0]), $cstring(keyVal[1])) # Some server send a cstring
  if result.hasKey("data"):
    result = parseData(base64.decode(result["data"]))

proc send*(client: Socket, data: EaMessageType, id: uint8) =
  echo "SEND: ", repr data.serialize(id)
  net.send(client, data.serialize(id))

import os # TODO: Outsource this function (it's required for server and client)
proc pingInterval*(data: tuple[client: Socket, channelKillThread: ptr Channel[void]]) {.thread.} =
  while true:
    sleep(30_000)
    if cast[var Channel[void]](data.channelKillThread).peek() == -1: # TODO: Need to cast every loop, because cast creates a new object
      return
    data.client.send(newPing(), 0)

proc recv*(socket: Socket, data: var string, id: var uint8, timeout: int = -1): bool =
  var prefix: string
  var length: uint32
  if socket.recv(prefix, MESSAGE_PREFIX_LEN, timeout) == 0:
    return false
  echo "RECV.PREFIX: ", repr prefix
  if prefix.len == 0:
    return false
  id = uint8(prefix[7])
  length = (cast[uint32](prefix[MESSAGE_PREFIX_LEN - 1]) shl 0) or
            (cast[uint32](prefix[MESSAGE_PREFIX_LEN - 2]) shl 8) or
            (cast[uint32](prefix[MESSAGE_PREFIX_LEN - 3]) shl 16) or
            (cast[uint32](prefix[MESSAGE_PREFIX_LEN - 4]) shl 24)
  if socket.recv(data, int(length) - MESSAGE_PREFIX_LEN) == 0:
    return false
  echo "RECV.DATA: ", repr data
  return true
