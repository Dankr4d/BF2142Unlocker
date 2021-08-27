## Structure:
## .
## └── [game]
##     ├── [mod]
##     │   └── [mod_version]
##     │       ├── files
##     │       │   ├── [mod_file1]
##     │       │   ├── [mod_file2]
##     │       │   ├── [mod_dir1]
##     │       │   └── [mod_dir2]
##     │       └── levels
##     │           └── [map_name]
##     │               └── [map_version]
##     │                   ├── [map_file1]
##     │                   ├── [map_file2]
##     │                   ├── [map_dir1]
##     │                   └── [map_dir2]
##     └── patches
##         ├── [TODO1] <-- Deliver patches as binary?
##         └── [TODO2]

import asynchttpserver, asyncdispatch

import os
import strutils
import json
import uri

import ../type/download

const ROOT_PATH: string = "/home/dankrad/Desktop/bfmapsmods"

proc getGames(): Games =
  for gameTpl in walkDir(ROOT_PATH, true):
    var game: Game
    game.name = gameTpl.path

    for modTpl in walkDir(ROOT_PATH / gameTpl.path, true):
      if modTpl.path in ["patches"]:
        continue

      var `mod`: Mod
      `mod`.name = modTpl.path

      for modVersionTpl in walkDir(ROOT_PATH / gameTpl.path / modTpl.path, true):
        var version: Version
        version.version = parseFloat(modVersionTpl.path) # TODO: Replace with real version (major, minior, patch)

        if dirExists(ROOT_PATH / gameTpl.path / modTpl.path / modVersionTpl.path / "files"):
          for filePath in walkDirRec(ROOT_PATH / gameTpl.path / modTpl.path / modVersionTpl.path / "files", relative = true):
            version.files.add(PathHash(
              path: filePath,
              hash32: toHex(streamedXXH32(ROOT_PATH / gameTpl.path / modTpl.path / modVersionTpl.path / filePath, 1024)),
              hash64: toHex(streamedXXH64(ROOT_PATH / gameTpl.path / modTpl.path / modVersionTpl.path / filePath, 1024))
            ))
            version.size += getFileSize(
              ROOT_PATH / gameTpl.path / modTpl.path / modVersionTpl.path / filePath
            )
            version.locations = @[] # TODO
        `mod`.versions.add(version)

        if dirExists(ROOT_PATH / gameTpl.path / modTpl.path / modVersionTpl.path / "levels"):
          for levelTpl in walkDir(ROOT_PATH / gameTpl.path / modTpl.path / modVersionTpl.path / "levels", true):
            var level: Level
            level.name = levelTpl.path
            for levelVersionTpl in walkDir(ROOT_PATH / gameTpl.path / modTpl.path / modVersionTpl.path / "levels" / levelTpl.path, true):
              var version: Version
              version.version = parseFloat(levelVersionTpl.path) # TODO: Replace with real version (major, minior, patch)

              for filePath in walkDirRec(ROOT_PATH / gameTpl.path / modTpl.path / modVersionTpl.path / "levels" / levelTpl.path / levelVersionTpl.path, relative = true):
                version.files.add(PathHash(
                  path: filePath,
                  hash32: toHex(streamedXXH32(ROOT_PATH / gameTpl.path / modTpl.path / modVersionTpl.path / "levels" / levelTpl.path / levelVersionTpl.path / filePath, 1024)),
                  hash64: toHex(streamedXXH64(ROOT_PATH / gameTpl.path / modTpl.path / modVersionTpl.path / "levels" / levelTpl.path / levelVersionTpl.path / filePath, 1024))
                ))
                version.size += getFileSize(
                  ROOT_PATH / gameTpl.path / modTpl.path / modVersionTpl.path / "levels" / levelTpl.path / levelVersionTpl.path / filePath
                )
              version.locations = @[ # TODO
                $(parseUri("http://127.0.0.1:8080/") / gameTpl.path / modTpl.path / modVersionTpl.path / "levels" / levelTpl.path / levelVersionTpl.path),
                $(parseUri("http://192.168.1.107:8080/") / gameTpl.path / modTpl.path / modVersionTpl.path / "levels" / levelTpl.path / levelVersionTpl.path)
              ]
              level.versions.add(version)
            `mod`.levels.add(level)
      game.mods.add(`mod`)
    result.add(game)

let games: Games = getGames()
echo games

proc cb(req: Request) {.async.} =
  if req.url.path == "/favicon.ico":
    return

  if req.url.path == "/":
    let headers = {"Content-Type": "application/json; charset=utf-8"}

    let games: Games = getGames()

    when defined(release):
      await req.respond(Http200, $(%*games), headers.newHttpHeaders())
    else:
      await req.respond(Http200, pretty(%*games), headers.newHttpHeaders())
  else:
    let headers = {"Content-type": "application/zip"} #, "Content-Length": "20368"}
    await req.respond(Http200, readFile(ROOT_PATH / req.url.path))


proc main {.async.} =
  var server = newAsyncHttpServer()
  server.listen Port(8080)
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      poll()

when isMainModule:
  asyncCheck main()
  runForever()