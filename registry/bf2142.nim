import winregistry

const REG_PATH = """HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Electronic Arts\EA Games\Battlefield 2142\ergc"""

proc setCdKeyIfNotExists*() =
  var rhndl: RegHandle = createOrOpen(REG_PATH, samRead or samWrite)
  try:
    discard rhndl.readString("")
  except RegistryError:
    rhndl.writeString("", "x9392")
  rhndl.close()

when isMainModule:
  setCdKeyIfNotExists()