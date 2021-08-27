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

# let games: Games = getGamesClient("/home/dankrad/.wine_bf2142/drive_c/Program Files (x86)/Electronic Arts/Battlefield 2142")
let games: Games = getGamesServer(ROOT_PATH)
echo games

proc cb(req: Request) {.async.} =
  if req.url.path == "/favicon.ico":
    return

  if req.url.path == "/":
    let headers = {"Content-Type": "application/json; charset=utf-8"}

    # let games: Games = getGamesClient("/home/dankrad/.wine_bf2142/drive_c/Program Files (x86)/Electronic Arts/Battlefield 2142")
    let games: Games = getGamesServer(ROOT_PATH)

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