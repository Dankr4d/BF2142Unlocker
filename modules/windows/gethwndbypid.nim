import winim

type
  HandleData = ref object
    pid: DWORD # IN PARAM
    hWnd: HWND # OUT PARAM

proc EnumWindowsProcHWndByPid(hwnd: HWND, lParam: LPARAM): WINBOOL {.stdcall.} =
  var handleData: HandleData = cast[HandleData](lparam)
  var lpdwProcessId: DWORD
  GetWindowThreadProcessId(hwnd, addr lpdwProcessId)
  if lpdwProcessId == handleData.pid:
    handleData.hwnd = hwnd
    return FALSE
  return TRUE

proc getHWndByPid*(pid: int): HWND =
  var handleData: HandleData = new HandleData
  handleData.pid = pid.DWORD
  EnumWindows(EnumWindowsProcHWndByPid, cast[LPARAM](handleData));
  return handleData.hWnd


when isMainModule:
  import getprocessbyname
  var pid: int = getPidByName("BF2142_w32ded.exe")
  echo "ShowWindow: ", ShowWindow(getHWndByPid(pid), SW_HIDE)