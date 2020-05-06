when isMainModule and defined(windows):
  import os
  import osproc

  setCurrentDir(getCurrentDir() / "bin")

  ## Workarounds, because gettext is currently not working on windows: https://github.com/Dankr4d/BF2142Unlocker/issues/29
  import strutils
  proc setlocale(category: int, other: cstring): cstring {.header: "<locale.h>", importc.}
  var LC_ALL {.header: "<locale.h>", importc.}: int
  const LANGUAGE_FILE: string = "lang.txt"
  const AVAILABLE_LANGUAGES: seq[string] = @["en_US.utf8", "de_DE.utf8"]
  const DEFAULT_LANGUAGE: string = "en_US.utf8"
  var lang: string
  if fileExists(LANGUAGE_FILE):
    lang = readFile(LANGUAGE_FILE)
  if lang != "" and lang in AVAILABLE_LANGUAGES:
    putEnv("LANG", lang)
  else:
    lang = $setlocale(LC_ALL, "")
    if lang.startsWith("English"):
      putEnv("LANG", "en_US.utf8")
    elif lang.startsWith("German"):
      putEnv("LANG", "de_DE.utf8")
    else:
      putEnv("LANG", DEFAULT_LANGUAGE)
  #

  discard execCmd("cmd /c " & "BF2142Unlocker.exe")