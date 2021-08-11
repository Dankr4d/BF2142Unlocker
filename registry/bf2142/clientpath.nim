import registry

const
  REG_PATH_INSTALL_DIR: string = """SOFTWARE\Wow6432Node\Electronic Arts\EA Games\Battlefield 2142"""
  REG_KEY_INSTALL_DIR: string = "InstallDir"

proc getBF2142ClientPath*(): string =
  try:
    return getUnicodeValue(REG_PATH_INSTALL_DIR, REG_KEY_INSTALL_DIR, HKEY_LOCAL_MACHINE)
  except OSError:
    # Cannot read out reg key
    return ""

when isMainModule:
  echo getBF2142ClientPath()