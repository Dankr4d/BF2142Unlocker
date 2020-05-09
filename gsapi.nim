import os
import strutils
import stdoutreader

proc parseCurrentMap*(pid: int): tuple[mapName: string, mapMode: string, mapSize: string, status: string] =
  var data: tuple[lastError: uint32, stdout: string] = readStdOut(pid)
  var lines: seq[string] = data.stdout.splitLines()
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
  var pid: int = getPidByName("BF2142_w32dedUnlocker.exe")
  var cnt: int = 0
  while cnt < 3:
    echo parseCurrentMap(pid)
    cnt.inc()