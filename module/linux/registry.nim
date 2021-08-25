from windows/registry import HKEY, HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER
import os, strutils, streams, parseutils

export HKEY, HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER


proc getUnicodeValue*(path, key: string, handle: HKEY, winePath: string = getHomeDir() / ".wine"): string =
  var foundRegPath: bool = false
  var regPath: string
  var filePath: string
  var line: string
  var token: string

  if handle == HKEY_LOCAL_MACHINE:
    filePath = winePath / "system.reg"
  elif handle == HKEY_CURRENT_USER:
    filePath = winePath / "user.reg"
  else:
    raise newException(ValueError, "HKEY '" & $handle & "'not implemented.")

  regPath = path.replace("\\", "\\\\")

  var file: File
  if not file.open(filePath, fmRead, -1):
    raise newException(ValueError, "FILE COULD NOT BE OPENED!") # TODO
  let stream: FileStream = newFileStream(file)
  while stream.readLine(line):
    if line.len == 0 or line.startsWith("#"):
      continue

    if foundRegPath:
      var pos: int
      if line.startsWith("["):
        raise newException(ValueError, "KEY NOT FOUND!") # TODO
      elif line.startsWith("@") and key == "":
        # Default
        pos = 0
        pos += line.parseUntil(token, "=\"", pos) + 2
      else:
        pos = 1
        pos += line.parseUntil(token, "\"=\"", pos) + 3

      if token != key and not (token == "@" and key == ""):
        continue

      discard line.parseUntil(token, '"', pos)
      stream.close()
      return token

    if not line.startsWith('['):
      continue

    discard line.parseUntil(token, ']', 1)
    if token == regPath:
      foundRegPath = true

  stream.close()




proc setUnicodeValue*(path, key, val: string, handle: HKEY, winePath: string = getHomeDir() / ".wine") =
  var foundRegPath, foundRegVal: bool = false
  var regPath: string
  var filePath: string
  var token: string

  if handle == HKEY_LOCAL_MACHINE:
    filePath = winePath / "system.reg"
  elif handle == HKEY_CURRENT_USER:
    filePath = winePath / "user.reg"
  else:
    raise newException(ValueError, "HKEY '" & $handle & "'not implemented.")

  regPath = path.replace("\\", "\\\\")

  let raw: string = readFile(filePath)
  if not raw.startsWith("WINE REGISTRY"):
    raise newException(ValueError, "Not a wine registry file. File doesn't start with \"WINE REGISTRY\".")

  var file: File
  if not file.open(filePath, fmWrite, -1): # TODO: Change path
    raise newException(ValueError, "FILE COULD NOT BE OPENED!") # TODO
  let stream: FileStream = newFileStream(file)

  for line in raw.splitLines:

    if foundRegVal or line.len == 0 or line.startsWith("#"):
      stream.writeLine(line)
      continue

    if foundRegPath:
      var pos: int
      if line.startsWith("["):
        raise newException(ValueError, "KEY NOT FOUND!") # TODO
      elif line.startsWith("@") and key == "":
        # Default
        pos = 0
        pos += line.parseUntil(token, "=\"", pos) + 1
      else:
        pos = 1
        pos += line.parseUntil(token, "\"=\"", pos) + 2

      if token != key:
        stream.writeLine(line)
        continue

      stream.writeLine(line[0..pos] & val & "\"")
      foundRegVal = true
      continue

    if not line.startsWith('['):
      stream.writeLine(line)
      continue

    discard line.parseUntil(token, ']', 1)
    if token == regPath:
      foundRegPath = true

    stream.writeLine(line)
  stream.close()

when isMainModule and true:
  const REG_PATH: string = """Software\Wow6432Node\Electronic Arts\EA GAMES\Battlefield 2142"""
  const REG_KEY: string = "Language"
  echo REG_KEY, ": '", getUnicodeValue(REG_PATH, REG_KEY, HKEY_LOCAL_MACHINE, getHomeDir() / ".wine_bf2142"), "'"
  setUnicodeValue(REG_PATH, REG_KEY, "English", HKEY_LOCAL_MACHINE, getHomeDir() / ".wine_bf2142")

# when isMainModule and true:
#   const REG_PATH: string = """Software\Wow6432Node\Electronic Arts\EA GAMES\Battlefield 2142\ergc"""
#   const REG_KEY: string = ""
#   # const REG_PATH: string = """Software\Wow6432Node\Electronic Arts\EA GAMES\Battlefield 2142"""
#   # const REG_KEY: string = "Language"
#   echo REG_KEY, ": '", getUnicodeValue(REG_PATH, REG_KEY, HKEY_LOCAL_MACHINE, getHomeDir() / ".wine_bf2142"), "'"
