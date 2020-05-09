import os
import strutils

type
  GsData* = object
    mapName*: string
    mapMode*: string
    mapSize*: string
    status*: string

proc parseGsData*(raw: string): GsData = # TODO: Write a real parser without substr and find
  var lines: seq[string] = raw.splitLines()
  var line: string = lines[2]
  var mapNamePosStart: int = line.find("Map: ") + 5
  var mapnamePosEnd: int = line.find(" ", mapNamePosStart) - 1
  result.mapName = line.substr(mapNamePosStart, mapnamePosEnd)
  line = lines[3]
  (result.mapMode, result.mapSize) = line.substr(11, line.find(" ", 11) - 1).split("/")
  line = lines[4]
  var statusPosStart: int = line.find("Status: ") + 9
  result.status = line.substr(statusPosStart, line.find(" ", statusPosStart) - 2)

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