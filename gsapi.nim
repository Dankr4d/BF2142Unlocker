import os
import strutils

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
    status*: GsStatus

proc parseGsData*(raw: string): GsData = # TODO: Write a real parser without substr and find
  var lines: seq[string] = raw.splitLines()
  var line: string
  ## Map name
  line = lines[2]
  let mapNamePosStart: int = 46
  let mapnamePosEnd: int = line.find(" ", mapNamePosStart) - 1
  result.mapName = line.substr(mapNamePosStart, mapnamePosEnd)
  #
  ## Map mode
  line = lines[3]
  let mapModePosStart: int = 11
  let mapModePosEnd: int = line.find("/", mapModePosStart) - 1
  result.mapMode = parseEnum[MapMode](line.substr(mapModePosStart, mapModePosEnd))
  #
  ## Map size
  # line = lines[3] # Not required, because this line is already set
  let mapSizePosStart: int = line.find("/") + 1
  let mapSizePosEnd: int = mapSizePosStart + 1
  result.mapSize = parseInt(line.substr(mapSizePosStart, mapSizePosEnd))
  ## Gs status
  line = lines[4]
  var statusPosStart: int = 70
  var statusPosEnd: int = line.find("]", statusPosStart) - 1
  result.status = parseEnum[GsStatus](line.substr(statusPosStart, statusPosEnd))
  #

when isMainModule:
  import getprocessbyname
  import stdoutreader
  var pid: int = getPidByName("BF2142_w32dedUnlocker.exe")
  var cnt: int = 0
  while cnt < 3:
    var stdouTpl: tuple[lastError: uint32, stdout: string] = readStdOut(pid)
    if stdouTpl.lastError > 0:
      echo osErrorMsg(osLastError())
      break
    echo parseGsData(stdouTpl.stdout)
    cnt.inc()