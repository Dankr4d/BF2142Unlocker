import winim

# Templates copied from: https://forum.nim-lang.org/t/1188#7366
template `+`*[T](p: ptr T, off: int): ptr T =
  cast[ptr type(p[])](cast[ByteAddress](p) +% off * sizeof(p[]))
template `[]`*[T](p: ptr T, off: int): T =
  (p + off)[]

proc stringify(buffer: PCHAR_INFO, length: int): string =
  var charInfo: CHAR_INFO
  for idx in 0..length - 1:
    charInfo = buffer[idx]
    result.add(charInfo.Char.AsciiChar)

proc readStdOut*(pid: int): tuple[lastError: uint32, stdout: string] =
  if FreeConsole().bool == false:
    return (GetLastError().uint32, "")
  if AttachConsole(pid.DWORD).bool == false:
    return (GetLastError().uint32, "")
  var stdHandle: HANDLE = GetStdHandle(STD_OUTPUT_HANDLE)
  if stdHandle == INVALID_HANDLE_VALUE:
    return (GetLastError().uint32, "")
  var screenBufferInfo: CONSOLE_SCREEN_BUFFER_INFO
  if GetConsoleScreenBufferInfo(stdHandle, addr screenBufferInfo).bool == false:
    return (GetLastError().uint32, "")
  var bufferLen: int = screenBufferInfo.dwSize.X * screenBufferInfo.dwSize.Y
  var buffer: PCHAR_INFO
  buffer = resize(buffer, bufferLen)
  var dwBufferSize: COORD
  dwBufferSize.X = screenBufferInfo.dwSize.X
  dwBufferSize.Y = screenBufferInfo.dwSize.Y
  var dwBufferCoord: COORD
  dwBufferCoord.X = 0
  dwBufferCoord.Y = 0
  var lpReadRegion: SMALL_RECT
  lpReadRegion.Left = 0
  lpReadRegion.Top = 0
  lpReadRegion.Right = screenBufferInfo.dwSize.X
  lpReadRegion.Bottom = screenBufferInfo.dwSize.Y
  if ReadConsoleOutput(stdHandle, buffer, dwBufferSize, dwBufferCoord, addr lpReadRegion).bool == false:
    return (GetLastError().uint32, "")
  if FreeConsole().bool == false:
    return (GetLastError().uint32, "")
  if AttachConsole(ATTACH_PARENT_PROCESS).bool == false:
    return (GetLastError().uint32, "")

  result = (0.uint32, stringify(buffer, bufferLen))
  dealloc(buffer)

  var cntNewLines: int = 0
  if dwBufferSize.X > 0:
    for idx in countup(dwBufferSize.X.int, result.stdout.len - dwBufferSize.X, dwBufferSize.X): # Add newline after last chracter in row
      result.stdout.insert("\n", idx + cntNewLines)
      cntNewLines.inc()

when isMainModule:
  import os
  import getprocessbyname
  var pid: int = getPidByName("BF2142_w32ded.exe")
  echo "PID: ", $pid
  while pid != 0:
    echo readStdOut(pid)
    sleep 50