when isMainModule and defined(windows):
  import os
  import osproc

  discard startProcess(
    command = "cmd",
    args = @["/c", "BF2142Unlocker.exe"],
    workingDir = getCurrentDir() / "bin"
  )