import parseutils # Required for for parsing gs output
import strutils # Required for parseEnum

type
  MapMode* = enum
    Conquest = "gpm_cq",
    Titan = "gpm_ti",
    Coop = "gpm_coop",
    SupplyLine = "gpm_sl",
    NoVehicles = "gpm_nv",
    ConquestAssault = "gpm_ca"

  GsStatus* = enum
    None = "", # This should not be in result from parseGsData proc
    Pregame = "pregame",
    Playing = "playing",
    Endgame = "endgame"

  GsData* = object
    mapName*: string # Should be in extra Map object
    mapMode*: MapMode # Should be in extra Map object
    mapSize*: int # uint8 and should be in extra Map object
    `mod`*: string
    players*: int
    maxPlayers*: int
    round*: int
    rounds*: int
    status*: GsStatus

proc parse(str, `from`, to: string, pos: var int): string =
  var parsedChars: int
  if `from` != "":
    parsedChars = str.parseUntil(result, `from`, pos)
    pos += parsedChars + `from`.len
  parsedChars = str.parseUntil(result, to, pos)
  pos += parsedChars + to.len

proc parseGsData*(raw: string): GsData =
  var currentPosition: int = 0
  result.mapName = raw.parse("Map: ", " ", currentPosition)
  result.mapMode = parseEnum[MapMode](raw.parse("Game mode: ", "/", currentPosition))
  result.mapSize = parseInt(raw.parse("", " ", currentPosition))
  result.`mod` = raw.parse("Mod: ", " ", currentPosition)
  result.players = parseInt(raw.parse("Players: ", "/", currentPosition))
  result.maxPlayers = parseInt(raw.parse("", " ", currentPosition))
  var round: string = raw.parse("Round: ", "/", currentPosition)
  if round != "N":
    result.round = parseInt(round)
  var rounds: string = raw.parse("", " ", currentPosition)
  if rounds != "A":
    result.rounds = parseInt(rounds)
  result.status = parseEnum[GsStatus](raw.parse("Status: [", "]", currentPosition))

when isMainModule:
  import os
  import getprocessbyname
  import gethwndbypid
  import stdoutreader
  import winim
  var pid: int = getPidByName("BF2142_w32dedUnlocker.exe")
  var hwnd: HWND = getHWndByPid(pid)
  SetWindowLongPtrA(hwnd, GWL_STYLE, WS_OVERLAPPED xor WS_CAPTION xor WS_SYSMENU xor WS_MINIMIZEBOX xor WS_VISIBLE)
  var cnt: int = 0
  while cnt < 3:
    var stdoutTpl: tuple[lastError: uint32, stdout: string] = readStdOut(pid)
    if stdoutTpl.lastError > 0:
      echo osErrorMsg(osLastError())
      break
    echo parseGsData(stdoutTpl.stdout)
    cnt.inc()