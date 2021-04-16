import registry

const
  REG_PATH_CD_KEY: string = """SOFTWARE\Wow6432Node\Electronic Arts\EA Games\Battlefield 2142\ergc"""
  REG_KEY_CD_KEY: string = ""

const
  REG_PATH_INSTALL_DIR: string = """SOFTWARE\Wow6432Node\Electronic Arts\EA Games\Battlefield 2142"""
  REG_KEY_INSTALL_DIR: string = "InstallDir"


proc setCdKeyIfNotExists*() =
  try:
    discard getUnicodeValue(REG_PATH_CD_KEY, REG_KEY_CD_KEY, HKEY_LOCAL_MACHINE)
  except OSError:
    # Set empty cd key if registry key doesn't exists
    setUnicodeValue(REG_PATH_CD_KEY, REG_KEY_CD_KEY, "x9392", HKEY_LOCAL_MACHINE)

proc getBF2142ClientPath*(): string =
  try:
    return getUnicodeValue(REG_PATH_INSTALL_DIR, REG_KEY_INSTALL_DIR, HKEY_LOCAL_MACHINE)
  except OSError:
    # Cannot read out reg key
    return ""


when isMainModule:
  echo getBF2142ClientPath()
  setCdKeyIfNotExists()