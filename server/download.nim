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

  proc cb(req: Request) {.async.} =
    if req.url.path == "/favicon.ico":
      return

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
                for filePath in walkDirRec(ROOT_PATH / gameTpl.path / "maps" / modTpl.path / mapTpl.path / versionTpl.path, relative = true):
                  # version.files.add((path: mapTpl.path / filePath, hash: ""))
                  version.files.add(PathHash(
                    path: filePath,
                    hash32: toHex(streamedXXH32(ROOT_PATH / gameTpl.path / "maps" / modTpl.path / mapTpl.path / versionTpl.path / filePath, 1024)),
                    hash64: toHex(streamedXXH64(ROOT_PATH / gameTpl.path / "maps" / modTpl.path / mapTpl.path / versionTpl.path / filePath, 1024))
                  ))
                  version.size += getFileSize(
                    ROOT_PATH / gameTpl.path / "maps" / modTpl.path / mapTpl.path / versionTpl.path / filePath
                  )
                # echo "AFTER"
                # map.size = getFileSize
                version.locations = @[
                  $(parseUri("http://127.0.0.1:8080/") / gameTpl.path / "maps" / modTpl.path / mapTpl.path / versionTpl.path),
                  $(parseUri("http://192.168.1.107:8080/") / gameTpl.path / "maps" / modTpl.path / mapTpl.path / versionTpl.path)
                ]

                map.versions.add(version)
              games[gameTpl.path].maps[modTpl.path].add(map)

      when defined(release):
        await req.respond(Http200, $(%*games), headers.newHttpHeaders())
      else:
        await req.respond(Http200, pretty(%*games), headers.newHttpHeaders())
    else:
      let headers = {"Content-type": "application/zip"} #, "Content-Length": "20368"}
      await req.respond(Http200, readFile(ROOT_PATH / req.url.path))


  server.listen Port(8080)

  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      poll()

asyncCheck main()
runForever()