when isMainModule and defined(windows):
  import os
  import osproc

  setCurrentDir(getCurrentDir() / "bin")
  discard execCmd("cmd /c " & "BF2142Unlocker.exe")