import asynchttpserver, asyncdispatch
import tables # Query params
import strutils
import strformat # Required for fmt macro
import net # Required for IpAddress type

# import ea

### PAGES
import pages/getbackendinfo
import pages/getplayerinfo
import pages/getunlocksinfo
import pages/getawardsinfo
import pages/getplayerprogress
##

#[
 TODO: This should be handled later by an unlocks config when all unlocks are customizable.
 Currently for release 0.9.3 this is implemented to provide squad leader gadgets unlock
 for mods that can handle this like Project Remaster. Bots in original game cannot handle
 those squad leader gadgets.
]#
var unlockAllSquadGadgets: bool

proc getQueryParams(query: string): Table[string, string] =
  # TODO: Crappy code
  result = initTable[string, string]()
  var paramsSeq: seq[string] = query.split({'&', '='})
  var cnt: int = 0
  while cnt < paramsSeq.len - 1:
    result[paramsSeq[cnt]] = paramsSeq[cnt + 1]
    cnt += 2

proc handleClient*(req: Request) {.async, gcsafe.} =
  var query: string = req.url.query
  if query.startsWith("&"):
    query = query[1 .. ^1]
  var params: Table[string, string] = getQueryParams(query)
  echo "Got Request to: ", req.url

  # var isServer: bool = false
  # if params.hasKey("auth"):
  #   var code: string = ""
  #   code = ea.DefDecryptBlock(ea.getBase64Decode(params["auth"])).toHex
  #   if parseHexInt(code[26] & code[27] & code[24] & code[25]) == 1:
  #     # Isn't requierd for unlocks server side?!? lol .. saw that getunlocksinfo doesnt have a "server" string in response
  #     # Not passed to handlePAGE functions, momently always "client" is set
  #     echo "---> REQUEST FROM SERVER!"
  #     isServer = true

  #[ INFO:
    It seems that only getunlocksinfo is required.
    Also getunlocksinfo doesnt send the right id or playername in all pages. BUT: Id must be > 0
    BF2142.exe makes multiple requests to at least getplayerinfo.aspx
  ]#
  case req.url.path
    of "/getbackendinfo.aspx":
      await req.handleGetBackendInfo(params)
    of "/getplayerinfo.aspx":
      await req.handleGetPlayerInfo(params)
    of "/getunlocksinfo.aspx":
      await req.handleGetUnlocksInfo(params, unlockAllSquadGadgets)
    of "/getawardsinfo.aspx":
      await req.handleGetAwardsInfo(params)
    of "/getplayerprogress.aspx": # only mode: point .. mode also is ignored
      await req.handleGetPlayerProgress(params)
    else:
      await req.respond(Http200, "Hello World!")

proc run*(data: tuple[ipAddress: IpAddress, unlockAllSquadGadgets: bool]) =
  var server = newAsyncHttpServer()
  let port = Port(8080)
  echo fmt"Unlock server running on {$data.ipAddress}:{$port} and waiting for clients!"
  unlockAllSquadGadgets = data.unlockAllSquadGadgets
  waitFor server.serve(port, handleClient, $data.ipAddress)

when isMainModule:
  run("0.0.0.0".parseIpAddress(), false)