import winim
import gethwndbypid

proc sendMsg*(pid: int, data: string) =
  var h: HWND = getHWndByPid(pid)
  var lastChar: char
  for ch in data:
    if lastChar == ch:
      # SendMessageA works, but sending keys to bf2142 game server swallow keys if they are the same :s
      discard SendMessageA(h, WM_CHAR, ord(' ').WPARAM, 0)
      discard SendMessageA(h, WM_CHAR, ord('\b').WPARAM, 0)
    discard SendMessageA(h, WM_CHAR, ord(ch).WPARAM, 0)
    lastChar = ch
  CloseHandle(h)

when isMainModule:
  import getprocessbyname
  import math
  import os
  var botSkill: float = 0.0
  var pid: int = getPidByName("BF2142_w32dedUnlocker.exe")
  var doIter: bool = true
  while doIter:
    sendMsg(pid, "sv.botSkill " & $botSkill & "\r")
    sendMsg(pid, "sv.botSkill\r")
    if botSkill == 1.0:
      doIter = false
    else:
      botSkill = round(botSkill + 0.1, 1)
    sleep 100