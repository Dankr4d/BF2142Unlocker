when isMainModule and defined(windows):
  import os
  import osproc

  when defined(gcc):
    {.link: "icon.res".}

  setCurrentDir(getCurrentDir() / "bin")
  discard startProcess("bin" / "BF2142Unlocker.exe")