when isMainModule and defined(windows):
  import os
  import osproc

  setCurrentDir(getCurrentDir() / "bin")
  echo execCmd("cmd /c " & "BF2142Unlocker.exe")