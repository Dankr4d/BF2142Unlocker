import winim
import getprocessbyname

proc `$`(buffer: array[2800, CHAR_INFO]): string = # TODO: Array length
  for charInfo in buffer:
    result.add(charInfo.Char.AsciiChar)

proc readStdOut*(pid: int): string =
  discard FreeConsole()
  discard AttachConsole(pid.DWORD)
  var stdHandle: Handle = GetStdHandle(STD_OUTPUT_HANDLE)
  var screenBufferInfo: CONSOLE_SCREEN_BUFFER_INFO
  discard GetConsoleScreenBufferInfo(stdHandle, addr screenBufferInfo)
  var buffer: array[2800, CHAR_INFO] # TODO: Array length
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
  discard ReadConsoleOutput(
    stdHandle,
    cast[ptr CHAR_INFO](addr buffer),
    dwBufferSize,
    dwBufferCoord,
    addr lpReadRegion
  )
  discard FreeConsole()
  discard AttachConsole(ATTACH_PARENT_PROCESS)

  result = $buffer

  var cntNewLines: int = 0
  if dwBufferSize.X > 0:
    for idx in countup(dwBufferSize.X.int, result.len - dwBufferSize.X, dwBufferSize.X): # Add newline after last chracter in row
      result.insert("\n", idx + cntNewLines)
      cntNewLines.inc()

when isMainModule:
  var pid: int = getPidByName("BF2142_w32ded.exe")
  echo readStdOut(pid)