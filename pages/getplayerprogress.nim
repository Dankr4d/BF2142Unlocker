import asynchttpserver, asyncdispatch
from times import epochTime
from strutils import multiReplace
import tables # Query params
from strutils import split # Query params

proc handleGetPlayerProgress*(req: Request, params: Table[string, string]) {.async.} =
  var body: string
  body = "O\n"
  body &= "H\tpid\tasof\n"
  body &= "D\t1072410549\t1558369349\n"
  body &= "H\tdate\tpoints\tglobalscore\texperiencepoints\tawaybonus\n"
  body &= "D\t1557838648\t221\t72\t149\t0"

  var countOut: int = body.multiReplace([("\t", ""), ("\n", "")]).len
  body &= "\n$\t" & $countOut & "\t$\n"

  await req.respond(Http200, body)