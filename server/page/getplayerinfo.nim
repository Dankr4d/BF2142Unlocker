import asynchttpserver, asyncdispatch
from times import epochTime
from strutils import multiReplace, split
import tables # Query params

proc handleGetPlayerInfo*(req: Request, params: Table[string, string]) {.async.} =
  var isServer: bool = false # TODO: Fix this
  var body: string
  body = "O\n"
  body &= "H\tasof\tcb\n"
  body &= "D\t" & $epochTime().toInt & "\t"
  body &= (if isServer: "server" else: "client") & '\n'

  # Header
  body &= "H\tnick\tsubaccount\tpid\tbp-1\tent-1\tent-2\tent-3\trnk"
  body &= '\n'
  # Value
  body &= "D\t"
  body &= " Nick\t"
  body &= " Subaccount\t"
  body &= "2001\t"
  body &= "1\t" # Expansion pack flag
  body &= "0\t" # Best buy weapon
  body &= "1\t" # Dogtag knife? (as i knew the player need to do 50 knife kills to achieve the reskin)
  body &= "1\t" # BF2 player icon
  body &= "43\t" # Rank

  body &= '\n'
  body &= "H\tUnlockID\n"
  # Unlocks for every kit and at least special unlocks for all kits
  body &= "D\t115\n" # 1 = Kit, 1 = Unlock row, 5 = Unlocked to item 5 (last item)
  body &= "D\t125\n"
  body &= "D\t215\n"
  body &= "D\t225\n"
  body &= "D\t315\n"
  body &= "D\t325\n"
  body &= "D\t415\n"
  body &= "D\t425\n"
  body &= "D\t516\n"
  body &= "D\t524"
  var countOut: int = body.multiReplace([("\t", ""), ("\n", "")]).len
  body &= "\n$\t" & $countOut & "\t$\n"

  await req.respond(Http200, body)
