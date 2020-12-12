import ../protocols/fesl
import net
import tables
import strutils
import random # Required for randomEmail
import sequtils # Required for randomEmail
import base64 # Some servers are decoding there data
export fesl

randomize() # Required for randomEmail
const CHARS_SEQ: seq[char] = toSeq({'a' .. 'z', '0' .. '9'})

type
  FeslExceptionType* = enum
    GetCountryList
    AddAccount
    Login
    GetSubAccounts
    AddSubAccount
    DisableSubAccount
    Unhandled
  FeslException* = ref object of Exception
    exType*: FeslExceptionType
    code*: uint32
    notReceived*: bool # Determines if data has been received or not (server is answering or not)


proc connect*(client: Socket, domain: string, port: Port = Port(18300)) =
  var sslContext: SslContext = newContext(protVersion = protSSLv23, verifyMode = CVerifyNone, cipherList = "SSLv3")
  wrapSocket(sslContext, client)
  net.connect(client, domain, port) # TODO: Handle OSError Exception


proc randomStr(len: int = 30): string =
  for idx in 1 .. len:
    result.add(CHARS_SEQ[rand(0 .. CHARS_SEQ.high)])


template parseCheckAndRaise() =
  # 160 = This soldier name already exists. Please try with a new name.
  # 99  = A system error occurred. Try again later. If problem persists, contact customer support.
  # * localizedMessage*: string
  # * errorContainer*: string
  # * errorCode*: uint16
  dataTbl = parseData(data)
  if dataTbl.hasKey("errorCode"):
    var ex: FeslException = new FeslException
    ex.exType = parseEnum[FeslExceptionType](dataTbl["TXN"], FeslExceptionType.Unhandled)
    ex.code = uint16(parseUint(dataTbl["errorCode"]))
    if ex.code != 182: # OpenSpy sends errorCode 182 when it's successfully (at least when AddSubAccount is successfully)
      if dataTbl.hasKey("localizedMessage"):
        ex.msg = dataTbl["localizedMessage"].replace("\"", "")
      raise ex


proc raiseRecvFailed(exType: FeslExceptionType) =
  var ex: FeslException
  ex.exType = exType
  ex.notReceived = true
  raise ex


proc createAccount*(client: Socket, username, password: string, timeout: int = -1) =
  var dataTbl: Table[string, string]
  var data: string
  var id: uint8

  client.send(newGetCountryListClient(), 3)
  if not client.recv(data, id, timeout):
    raiseRecvFailed(FeslExceptionType.GetCountryList)
  parseCheckAndRaise()

  let countryCode: string = dataTbl["countryList.0.ISOCode"]

  client.send(newAddAccountClient(username, password, randomStr(), countryCode), 4)
  if not client.recv(data, id, timeout):
    raiseRecvFailed(FeslExceptionType.AddAccount)
  parseCheckAndRaise()


proc login*(client: Socket, username, password: string, timeout: int = -1) =
  var dataTbl: Table[string, string]
  var data: string
  var id: uint8

  client.send(newLoginClient(username, password), 2)
  if not client.recv(data, id, timeout):
    raiseRecvFailed(FeslExceptionType.Login)
  parseCheckAndRaise()


proc soldiers*(client: Socket, timeout: int = -1): seq[string] =
  var dataTbl: Table[string, string]
  var data: string
  var id: uint8

  client.send(newGetSubAccountsClient(), 9)
  if not client.recv(data, id, timeout):
    raiseRecvFailed(FeslExceptionType.GetSubAccounts)
  parseCheckAndRaise()

  # INFO: Some server doesn't sent subAccounts.[] to set the soldier amount they set TXN to "GetSubAccountssubAccounts" -.-
  var soldierAmount: int = 4
  if dataTbl.hasKey("subAccounts.[]"):
    soldierAmount = parseInt(dataTbl["subAccounts.[]"])
  if soldierAmount == 0:
    return
  for idx in 1..soldierAmount:  # soldierAmount:
    if not dataTbl.hasKey("subAccounts." & $(idx - 1)):
      break
    # INFO: Some other server set double quotes, some not -.-
    result.add(dataTbl["subAccounts." & $(idx - 1)].replace("\"", ""))


proc addSoldier*(client: Socket, soldier: string, timeout: int = -1) =
  var dataTbl: Table[string, string]
  var data: string
  var id: uint8

  client.send(newAddSubAccountClient(soldier), 15)
  if not client.recv(data, id, timeout):
    raiseRecvFailed(FeslExceptionType.AddSubAccount)
  parseCheckAndRaise()


proc delSoldier*(client: Socket, soldier: string, timeout: int = -1) =
  var dataTbl: Table[string, string]
  var data: string
  var id: uint8

  client.send(newDisableSubAccountClient(soldier), 14)
  if not client.recv(data, id, timeout):
    raiseRecvFailed(FeslExceptionType.DisableSubAccount)
  parseCheckAndRaise()
