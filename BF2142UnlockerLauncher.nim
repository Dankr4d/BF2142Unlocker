when isMainModule and defined(windows):
  import os
  import osproc

  discard startProcess(
    command = getCurrentDir() / "bin" / "BF2142Unlocker.exe",
    workingDir = getCurrentDir() / "bin",
    options = {poParentStreams}
  )