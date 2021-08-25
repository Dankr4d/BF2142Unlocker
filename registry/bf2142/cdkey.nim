import registry

const
  REG_PATH_CD_KEY: string = """SOFTWARE\Wow6432Node\Electronic Arts\EA Games\Battlefield 2142\ergc"""
  REG_KEY_CD_KEY: string = ""

proc setCdKeyIfNotExists*() =
  try:
    discard getUnicodeValue(REG_PATH_CD_KEY, REG_KEY_CD_KEY, HKEY_LOCAL_MACHINE)
  except OSError:
    # Set empty cd key if registry key doesn't exists
    setUnicodeValue(REG_PATH_CD_KEY, REG_KEY_CD_KEY, "x9392", HKEY_LOCAL_MACHINE)

when isMainModule:
  setCdKeyIfNotExists()