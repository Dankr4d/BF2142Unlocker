import asynchttpserver, asyncdispatch
from times import epochTime
from strutils import multiReplace, split
import tables # Query params

proc handleGetAwardsInfo*(req: Request, params: Table[string, string]) {.async.} =
  var body: string
  body = "O\n"
  body &= "H\tpid\tnick\tasof\n"
  body &= "D\t"
  body &= "10000032\t" # Subaccount id
  body &= "GGGG\t" # Subaccount name
  body &= $epochTime().toInt & "\n"
  body &= "H\taward\tlevel\twhen\tfirst"

  var countOut: int = body.multiReplace([("\t", ""), ("\n", "")]).len
  body &= "\n$\t" & $countOut & "\t$\n"

  await req.respond(Http200, body)