import os, strutils
import uri
import asynchttpserver, asyncdispatch
import httpclient
import checkpermission
import nimBF2142IpPatcher
when defined(windows):
  import winim
  import getprocessbyname
  import gethwndbypid

const URI = parseUri("http://127.0.0.1:8085/")

var pid: int = 0

type Action {.pure.} = enum
  writeFile = "writeFile",
  copyFile = "copyFile",
  removeFile = "removeFile",
  copyDir = "copyDir",
  createDir = "createDir",
  existsOrCreateDir = "existsOrCreateDir",
  closeServer = "closeServer",
  preClientPatch = "preClientPatch",
  preServerPatch = "preServerPatch",
  patchClient = "patchClient",

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
    var res: bool = existsOrCreateDir(path)
    await req.respond(Http200, $res)
    return
  of Action.preClientPatch:
    let path: string = req.headers["path", 0]
    preClientPatch(path)
  of Action.preServerPatch:
    let path: string = req.headers["path", 0]
    let ip: IpAddress = req.headers["ip", 0].parseIpAddress()
    let port: Port = req.headers["port", 0].parseInt().Port
    preServerPatch(path, ip, port)
  of Action.patchClient:
    let path: string = req.headers["path", 0]
    let ip: IpAddress = req.headers["ip", 0].parseIpAddress()
    let port: Port = req.headers["port", 0].parseInt().Port
    patchClient(path, ip, port)
  of Action.closeServer:
    quit(0) # TODO: Should respons data and then quit
  await req.respond(Http200, "")

when defined(windows):
  proc elevate(): bool =
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
    pid = getPidByName("elevatedio.exe") # TODO
    return pid > 0
    # if lastError <= 32:
    #   raise newException(Exception, "Cannot elevate $1 ($2)" % [$pathToExe, $lastError])

  proc isServerRunning*(): bool =
    return pid > 0

  proc killElevatedIo*() =
    var hndlProcess = OpenProcess(PROCESS_TERMINATE, false.WINBOOL, pid.DWORD)
    discard hndlProcess.TerminateProcess(0)

proc writeFileElevated*(path, content: string): bool =
  when defined(windows):
    if hasWritePermission(path):
      writeFile(path, content)
      return true
    if not isServerRunning() and not elevate():
      return false
    var headers: HttpHeaders = newHttpHeaders()
    headers.add("action", $Action.writeFile)
    headers.add("path", path)
    var resp: Response = client.request(url = $URI, httpMethod = HttpGet, body = content, headers = headers)
  else:
    writeFile(path, content)
  return true

proc copyFileElevated*(pathFrom, pathTo: string): bool =
  when defined(windows):
    if hasWritePermission(pathTo):
      copyFile(pathFrom, pathTo)
      return true
    if not isServerRunning() and not elevate():
      return false
    var headers: HttpHeaders = newHttpHeaders()
    headers.add("action", $Action.copyFile)
    headers.add("pathFrom", pathFrom)
    headers.add("pathTo", pathTo)
    var resp: Response = client.request(url = $URI, httpMethod = HttpGet, headers = headers)
  else:
    copyFile(pathFrom, pathTo)
  return true

proc copyDirElevated*(pathFrom, pathTo: string): bool =
  when defined(windows):
    if hasWritePermission(pathTo):
      copyDir(pathFrom, pathTo)
      return true
    if not isServerRunning() and not elevate():
      return false
    var headers: HttpHeaders = newHttpHeaders()
    headers.add("action", $Action.copyDir)
    headers.add("pathFrom", pathFrom)
    headers.add("pathTo", pathTo)
    var resp: Response = client.request(url = $URI, httpMethod = HttpGet, headers = headers)
  else:
    copyDir(pathFrom, pathTo)
  return true

proc removeFileElevated*(path: string): bool =
  when defined(windows):
    if hasWritePermission(path):
      removeFile(path)
      return true
    if not isServerRunning() and not elevate():
      return false
    var headers: HttpHeaders = newHttpHeaders()
    headers.add("action", $Action.removeFile)
    headers.add("path", path)
    var resp: Response = client.request(url = $URI, httpMethod = HttpGet, headers = headers)
  else:
    removeFile(path)
  return true

proc createDirElevated*(path: string): bool =
  when defined(windows):
    if hasWritePermission(path):
      createDir(path)
      return true
    if not isServerRunning() and not elevate():
      return false
    var headers: HttpHeaders = newHttpHeaders()
    headers.add("action", $Action.createDir)
    headers.add("path", path)
    var resp: Response = client.request(url = $URI, httpMethod = HttpGet, headers = headers)
  else:
    createDir(path)
  return true

proc existsOrCreateDirElevated*(path: string): (bool, bool) = # First bool if elevation was successfull, second bool tells if dir already exists
  when defined(windows):
    if hasWritePermission(path):
      return (true, existsOrCreateDir(path))
    if not isServerRunning() and not elevate():
      return (false, false)
    var headers: HttpHeaders = newHttpHeaders()
    headers.add("action", $Action.existsOrCreateDir)
    headers.add("path", path)
    var resp: Response = client.request(url = $URI, httpMethod = HttpGet, headers = headers)
    return (true, resp.body.parseBool())
  else:
    return (true, existsOrCreateDir(path))

proc preClientPatchElevated*(path: string): bool =
  when defined(windows):
    if hasWritePermission(path):
      preClientPatch(path)
      return true
    if not isServerRunning() and not elevate():
      return false
    var headers: HttpHeaders = newHttpHeaders()
    headers.add("action", $Action.preClientPatch)
    headers.add("path", path)
    var resp: Response = client.request(url = $URI, httpMethod = HttpGet, headers = headers)
  else:
    preClientPatch(path)
  return true

proc preServerPatchElevated*(path: string, ip: IpAddress, port: Port): bool =
  when defined(windows):
    if hasWritePermission(path):
      preServerPatch(path)
      return true
    if not isServerRunning() and not elevate():
      return false
    var headers: HttpHeaders = newHttpHeaders()
    headers.add("action", $Action.preServerPatch)
    headers.add("path", path)
    headers.add("ip", ip)
    headers.add("port", port)
    var resp: Response = client.request(url = $URI, httpMethod = HttpGet, headers = headers)
  else:
    preServerPatch(path, ip, port)
  return true

proc patchClientElevated*(path: string, ip: IpAddress, port: Port): bool =
  when defined(windows):
    if hasWritePermission(path):
      patchClient(path)
      return true
    if not isServerRunning() and not elevate():
      return false
    var headers: HttpHeaders = newHttpHeaders()
    headers.add("action", $Action.patchClient)
    headers.add("path", path)
    headers.add("ip", ip)
    headers.add("port", port)
    var resp: Response = client.request(url = $URI, httpMethod = HttpGet, headers = headers)
  else:
    patchClient(path, ip, port)
  return true

when defined(windows) and isMainModule:
  var server = newAsyncHttpServer()
  asyncCheck server.serve(Port(URI.port.parseInt()), handleRequest, "127.0.0.1")
  pid = GetCurrentProcessId()
  var hwnd: HWND = getHWndByPid(pid)
  when defined(release):
    ShowWindow(hwnd, SW_HIDE)
  runForever()