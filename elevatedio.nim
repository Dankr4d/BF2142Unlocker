import os, strutils
import uri
import net # Requierd for isServerRunning
import asynchttpserver, asyncdispatch
import httpclient
when defined(windows):
  import winim

const URI = parseUri("http://127.0.0.1:8085/")

type Action {.pure.} = enum
  writeFile = "writeFile",
  copyFile = "copyFile",
  removeFile = "removeFile",
  copyDir = "copyDir",
  createDir = "createDir",
  existsOrCreateDir = "existsOrCreateDir",
  closeServer = "closeServer",

var client: HttpClient = newHttpClient()
proc handleRequest(req: Request) {.async.} =
  if not req.headers.hasKey("action"): return
  if req.headers["action"].len == 0: return

  let action: Action = parseEnum[Action](req.headers["action", 0])
  case action:
  of Action.writeFile:
    let path: string = req.headers["path", 0]
    echo "* Writing file: ", path
    writeFile(path, req.body)
  of Action.copyFile:
    let pathFrom: string = req.headers["pathFrom", 0]
    let pathTo: string = req.headers["pathTo", 0]
    echo "* Coping file '", pathFrom, "' to '", pathTo, "'"
    copyFile(pathFrom, pathTo)
  of Action.removeFile:
    let path: string = req.headers["path", 0]
    echo "* Removing file ", path
    removeFile(path)
  of Action.copyDir:
    let pathFrom: string = req.headers["pathFrom", 0]
    let pathTo: string = req.headers["pathTo", 0]
    echo "* Copying dir '", pathFrom, "' to '", pathTo, "'"
    copyDir(pathFrom, pathTo)
  of Action.createDir:
    let path: string = req.headers["path", 0]
    echo "* Creating dir ", path
    createDir(path)
  of Action.existsOrCreateDir:
    let path: string = req.headers["path", 0]
    echo "* ExistsOrCreateDir ", path
    var result: bool = existsOrCreateDir(path)
    await req.respond(Http200, $result)
    return
  of Action.closeServer:
    quit(0) # TODO: Should respons data and then quit
  await req.respond(Http200, "")

proc writeFileElevated*(path, content: string) =
  when defined(windows):
    var headers: HttpHeaders = newHttpHeaders()
    headers.add("action", $Action.writeFile)
    headers.add("path", path)
    var resp: Response = client.request(url = $URI, httpMethod = HttpGet, body = content, headers = headers)
  else:
    writeFile(path, content)

proc copyFileElevated*(pathFrom, pathTo: string) =
  when defined(windows):
    var headers: HttpHeaders = newHttpHeaders()
    headers.add("action", $Action.copyFile)
    headers.add("pathFrom", pathFrom)
    headers.add("pathTo", pathTo)
    var resp: Response = client.request(url = $URI, httpMethod = HttpGet, headers = headers)
  else:
    copyFile(pathFrom, pathTo)

proc copyDirElevated*(pathFrom, pathTo: string) =
  when defined(windows):
    var headers: HttpHeaders = newHttpHeaders()
    headers.add("action", $Action.copyDir)
    headers.add("pathFrom", pathFrom)
    headers.add("pathTo", pathTo)
    var resp: Response = client.request(url = $URI, httpMethod = HttpGet, headers = headers)
  else:
    copyDir(pathFrom, pathTo)

proc removeFileElevated*(path: string) =
  when defined(windows):
    var headers: HttpHeaders = newHttpHeaders()
    headers.add("action", $Action.removeFile)
    headers.add("path", path)
    var resp: Response = client.request(url = $URI, httpMethod = HttpGet, headers = headers)
  else:
    removeFile(path)

proc createDirElevated*(path: string) =
  when defined(windows):
    var headers: HttpHeaders = newHttpHeaders()
    headers.add("action", $Action.createDir)
    headers.add("path", path)
    var resp: Response = client.request(url = $URI, httpMethod = HttpGet, headers = headers)
  else:
    createDir(path)

proc existsOrCreateDirElevated*(path: string): bool =
  when defined(windows):
    var headers: HttpHeaders = newHttpHeaders()
    headers.add("action", $Action.existsOrCreateDir)
    headers.add("path", path)
    var resp: Response = client.request(url = $URI, httpMethod = HttpGet, headers = headers)
    return resp.body.parseBool()
  else:
    return existsOrCreateDir(path)


when defined(windows):
  proc elevate() =
    var
      pathToExe: WideCString = newWideCString(getCurrentDir() / "elevatedio.exe") # TODO
      verb = newWideCString("runas")
      params: WideCString = newWideCString("")
      lastError = ShellExecuteW(0,
        cast[LPWSTR](addr verb[0]),
        cast[LPWSTR](addr pathToExe[0]),
        cast[LPWSTR](addr params[0]),
        cast[LPWSTR](0),
        SW_SHOWNORMAL
      )
    if lastError <= 32:
      raise newException(Exception, "Cannot elevate $1 ($2)" % [$pathToExe, $lastError])

  proc isServerRunning*(): bool = # TODO: Should recv some data to determine if the server connecting to is our server
    var socket = newSocket()
    try:
      socket.connect(URI.hostname, Port(URI.port.parseInt()))
      socket.close()
      return true
    except OSError:
      if osLastError() == OSErrorCode(10061): # WSAECONNREFUSED (https://docs.microsoft.com/en-us/windows/win32/debug/system-error-codes--9000-11999-)
        return false
      else:
        discard # TODO: Some error handling?

  proc startServer*() =
    elevate()

  proc closeServer() = # TODO
    discard

  when isMainModule:
    var server = newAsyncHttpServer()
    asyncCheck server.serve(Port(URI.port.parseInt()), handleRequest, "127.0.0.1")
    runForever()
  else:
    if not isServerRunning():
      startServer()