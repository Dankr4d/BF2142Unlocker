import asynchttpserver, asyncdispatch

import os
import strutils
import tables
import json
import uri

import ../type/download

const ROOT_PATH: string = "/home/dankrad/Desktop/bfmapsmods"

proc main {.async.} =
  var server = newAsyncHttpServer()

  # proc streamedblabla(req: Request) =
  #   # let headers = {"Content-Type": "text/plain", "Transfer-Encoding": "chunked"}
  #   let headers = {"Content-type": "application/zip"} #, "Content-Length": "20368"}

  #   var buffer: array[512, byte]
  #   var dataLen: int
  #   var respStr: string
  #   var stream: FileStream = openFileStream(ROOT_PATH / req.url.path)
  #   while not stream.atEnd():
  #     dataLen = stream.readData(addr(buffer), buffer.len)
  #     # respStr = $toHex(dataLen, 3)
  #     # respStr = dataLen
  #     # respStr &= "\r\n"
  #     respStr = buffer.join("")
  #     # respStr &= "\r\n"
  #     # echo "########################"
  #     echo respStr
  #     # echo "########################"
  #     await req.respond(Http200, respStr, headers.newHttpHeaders())
  #   discard # Download file

  proc cb(req: Request) {.async.} =

    if req.url.path == "/":
      let headers = {"Content-Type": "application/json; charset=utf-8"}

      var games: Games = initTable[string, Game]()
      for gameTpl in walkDir(ROOT_PATH, true):
        if gameTpl.kind != pcDir:
          continue
        games[gameTpl.path] = Game()
        if dirExists(ROOT_PATH / gameTpl.path / "mods"):
          discard # iter mods
          for modTpl in walkDir(ROOT_PATH / gameTpl.path / "mods", true):
            if modTpl.kind != pcFile:
              continue
            games[gameTpl.path].mods.add(modTpl.path)
        if dirExists(ROOT_PATH / gameTpl.path / "maps"):
          games[gameTpl.path].maps = initTable[string, seq[Map]]()
          for modTpl in walkDir(ROOT_PATH / gameTpl.path / "maps", true):
            if modTpl.kind != pcDir:
              continue
            games[gameTpl.path].maps[modTpl.path] = @[]
            for mapTpl in walkDir(ROOT_PATH / gameTpl.path / "maps" / modTpl.path, true):
              if mapTpl.kind != pcDir:
                continue

              var map: Map
              map.name = splitFile(mapTpl.path).name
              for versionTpl in walkDir(ROOT_PATH / gameTpl.path / "maps" / modTpl.path / mapTpl.path, true):
                # map.size = getFileSize(ROOT_PATH / gameTpl.path / "maps" / modTpl.path / mapTpl.path / versionTpl.path)
                # echo "BEFOER: ", gameTpl.path / "maps" / modTpl.path / mapTpl.path / versionTpl.path
                var version: Version
                version.version = parseFloat(versionTpl.path)
                for filePath in walkDirRec(ROOT_PATH / gameTpl.path / "maps" / modTpl.path / mapTpl.path / versionTpl.path):
                  echo filePath
                  version.size += getFileSize(filePath)
                # echo "AFTER"
                # map.size = getFileSize
                version.locations = @[
                  $(parseUri("http://127.0.0.1:8080/") / gameTpl.path / "maps" / modTpl.path / mapTpl.path / versionTpl.path),
                  $(parseUri("http://192.168.1.107:8080/") / gameTpl.path / "maps" / modTpl.path / mapTpl.path / versionTpl.path)
                ]

                map.versions.add(version)
              games[gameTpl.path].maps[modTpl.path].add(map)

      # await req.respond(Http200, $(%*games), headers.newHttpHeaders())
      await req.respond(Http200, pretty(%*games), headers.newHttpHeaders())
    else:
      let headers = {"Content-type": "application/zip"} #, "Content-Length": "20368"}
      await req.respond(Http200, readFile(ROOT_PATH / req.url.path))




    # let path: string = req.url.path[1..^1]
    # let pathSplit: seq[string] = path.split('/')

    # if pathSplit.len == 0:
    #   await req.respond(Http404, "NO PATH SPECIFIED", headers.newHttpHeaders())
    #   return

    # if not dirExists(ROOT_PATH / pathSplit[0]): # Game named
    #   await req.respond(Http404, "GAME DOES NOT EXISTS", headers.newHttpHeaders())
    #   return

    # if pathSplit.len == 1:
    #   discard # list maps and mods
    # elif pathSplit.len == 2 and pathSplit[1] == "mods":
    #   if not dirExists(ROOT_PATH / "mods"):
    #     await req.respond(Http404, "mods folder does not exists", headers.newHttpHeaders())
    #     return
    # elif pathSplit.len == 3 and pathSplit[1] == "maps":
    #   if not dirExists(ROOT_PATH / path):
    #     await req.respond(Http404, "maps folder does not exists: " & ROOT_PATH / path, headers.newHttpHeaders())
    #     return
    #   var s: string
    #   for fileTpl in walkDir(ROOT_PATH / path, true):
    #     s &= fileTpl.path & "\n"
    #   await req.respond(Http200, s, headers.newHttpHeaders())


    #   discard
    # else:
    #   await req.respond(Http404, "MORE THEN 4 ARGS", headers.newHttpHeaders())
    #   discard  # download map


  server.listen Port(8080)

  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      poll()

asyncCheck main()
runForever()