when defined(windows):
  import registry
else:
  import ../../module/linux/registry
import os, strutils

const REG_PATH: string = """Software\Wow6432Node\Electronic Arts\EA GAMES\Battlefield 2142"""
const REG_KEY: string = "Language"

type
  Language* {.pure.} = enum
    English
    French
    German
    Italian
    Russian
    Spanish

when defined(windows):
  proc setGameLanguage*(lang: Language) =
    setUnicodeValue(REG_PATH, REG_KEY, $lang, HKEY_LOCAL_MACHINE)
else:
  proc setGameLanguage*(lang: Language, winePath: string = getHomeDir() / ".wine") =
    setUnicodeValue(REG_PATH, REG_KEY, $lang, HKEY_LOCAL_MACHINE, winePath)

when defined(windows):
  proc getGameLanguage*(): Language =
    return parseEnum[Language](getUnicodeValue(REG_PATH, REG_KEY, HKEY_LOCAL_MACHINE))
else:
  proc getGameLanguage*(winePath: string = getHomeDir() / ".wine"): Language =
    return parseEnum[Language](getUnicodeValue(REG_PATH, REG_KEY, HKEY_LOCAL_MACHINE, winePath))



when isMainModule:
  # setUnicodeValue(REG_PATH, REG_KEY, $Language.English, HKEY_LOCAL_MACHINE, getHomeDir() / ".wine_bf2142")
  echo REG_KEY, ": ", getGameLanguage(getHomeDir() / ".wine_bf2142")
  setGameLanguage(Language.English, getHomeDir() / ".wine_bf2142")
  echo REG_KEY, ": ", getGameLanguage(getHomeDir() / ".wine_bf2142")