import asynchttpserver, asyncdispatch
from times import epochTime
from strutils import multiReplace
import tables # Query params
from strutils import split # Query params

proc handleGetUnlocksInfo*(req: Request, params: Table[string, string]) {.async.} =
  var body: string
  body = "O\n"
  body &= "H\tpid\tnick\tasof\n"
  body &= "D\t1\t" # Subaccount id
  body &= "SUBACCOUNT_NAME\t" # Subaccount name
  body &= $epochTime().toInt & '\n'
  body &= "H\tAvcred\n"
  body &= "D\t0\n"
  body &= "H\tUnlockID\n"
  body &= "D\t115\n" # 1 = Kit, 1 = Unlock row, 5 = Unlocked to item 5 (last item)
  body &= "D\t125\n"
  body &= "D\t215\n"
  body &= "D\t225\n"
  body &= "D\t315\n"
  body &= "D\t325\n"
  body &= "D\t415\n"
  body &= "D\t425\n"
  body &= "D\t516\n"
  body &= "D\t521"
  # TODO: Unlocks should be configured via gui and stored in unlocks.ini
  # It's recomended to not unlock drones because most of the time bots are endless spawning drones
  # body &= "D\t524"

  var countOut: int = body.multiReplace([("\t", ""), ("\n", "")]).len
  body &= "\n$\t" & $countOut & "\t$\n"

  await req.respond(Http200, body)
