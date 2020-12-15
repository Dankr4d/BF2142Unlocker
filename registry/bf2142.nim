import winregistry


proc setCdKeyIfNotExists*() =
  var rhndl: RegHandle = createOrOpen(
    """HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Electronic Arts\EA Games\Battlefield 2142\ergc""",
    samRead or samWrite
  )
  try:
    discard rhndl.readString("")
  except RegistryError:
    rhndl.writeString("", "x9392")
  rhndl.close()

proc getBF2142ClientPath*(): string =
  var rhndl: RegHandle = open(
    """HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Electronic Arts\EA Games\Battlefield 2142""",
    samRead
  )
  try:
    result = rhndl.readString("InstallDir")
  except RegistryError:
    discard
  rhndl.close()


when isMainModule:
  # setCdKeyIfNotExists()
  echo getInstallDir()