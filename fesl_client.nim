import fesl
import net
import tables
import strutils
import random # Required for randomEmail
import sequtils # Required for randomEmail
import base64 # Some servers are decoding there data

randomize() # Required for randomEmail
const CHARS_SEQ: seq[char] = toSeq({'a' .. 'z', '0' .. '9'})

proc connect*(client: Socket, domain: string, port: Port): bool =
  var sslContext: SslContext = newContext(protVersion = protSSLv23, verifyMode = CVerifyNone, cipherList = "SSLv3")
  wrapSocket(sslContext, client)
  try:
    net.connect(client, domain, port)
  except OSError:
    return false
  return true

proc randomStr(len: int = 30): string =
  for idx in 1 .. len:
    result.add(CHARS_SEQ[rand(0 .. CHARS_SEQ.high)])

proc createAccount*(client: Socket, username, password: string, timeout: int = -1): bool =
  var dataTbl: Table[string, string]
  var data: string
  var id: uint8

  client.send(newGetCountryListClient(), 3)
  if not client.recv(data, id, timeout):
    return false # Server didn't send GetCountryList # TODO: Create custom exception

  dataTbl = parseData(data)
  let countryCode: string = dataTbl["countryList.0.ISOCode"]

  client.send(newAddAccountClient(username, password, randomStr(), countryCode), 4)
  if not client.recv(data, id, timeout):
    return false # Server didn't send AddAccount # TODO: Create custom exception

  dataTbl = parseData(data)
  if dataTbl.hasKey("errorCode"):
    return false # parseInt(dataTbl["errorCode"]) # TODO: Create custom exception
  return true


proc login*(client: Socket, username, password: string, timeout: int = -1): bool =
  var dataTbl: Table[string, string]
  var data: string
  var id: uint8

  client.send(newLoginClient(username, password), 2)

  if not client.recv(data, id, timeout):
    return false # Server didn't send Login # TODO: Create custom exception

  dataTbl = parseData(data)
  if dataTbl.hasKey("errorCode"):
    return false # parseInt(dataTbl["errorCode"]) # TODO: Create custom exception
  return true


proc soldiers*(client: Socket, timeout: int = -1): seq[string] =
  var dataTbl: Table[string, string]
  var data: string
  var id: uint8

  client.send(newGetSubAccountsClient(), 9)

  if not client.recv(data, id, timeout):
    return # TODO: Create custom exception

  dataTbl = parseData(data)

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

proc addSoldier*(client: Socket, soldier: string, timeout: int = -1): bool =
  var dataTbl: Table[string, string]
  var data: string
  var id: uint8

  client.send(newAddSubAccountClient(soldier), 15)

  if not client.recv(data, id, timeout):
    return # TODO: Create custom exception

  dataTbl = parseData(data)
  if not dataTbl.hasKey("errorCode"):
    return true

  echo repr dataTbl["errorCode"]

  let errorCode: int = parseInt(dataTbl["errorCode"])
  if errorCode == 182: # OpenSpy
    return true
  else:
    # 160 = This soldier name already exists. Please try with a new name.
    # 99  = A system error occurred. Try again later. If problem persists, contact customer support.
    # TODO: Some server send localizedMessage
    # TODO: Create an error object in fesl which contains:
    #       * TXN: string # TXN of previous message
    #       * localizedMessage*: string
    #       * errorContainer*: string
    #       * errorCode*: int
    return false # TODO: Create custom exception based on errorCode


proc delSoldier*(client: Socket, soldier: string, timeout: int = -1): bool =
  var data: string
  var id: uint8

  client.send(newDisableSubAccountClient(soldier), 14)

  if not client.recv(data, id, timeout):
    return # TODO: Create custom exception
  # TODO: Currently no error type known

  return true
