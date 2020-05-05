when isMainModule and defined(windows):
  import os
  import osproc

  setCurrentDir(getCurrentDir() / "bin")

  ## Workarounds, because gettext is currently not working on windows: https://github.com/Dankr4d/BF2142Unlocker/issues/29
  const LANGUAGE_FILE: string = "lang.txt"
  const AVAILABLE_LANGUAGES: seq[string] = @["en_US.utf8", "de_DE.utf8"]
  const DEFAULT_LANGUAGE: string = "en_US.utf8"
  var lang: string
  if fileExists(LANGUAGE_FILE):
    lang = readFile(LANGUAGE_FILE)
  if lang != "" and lang in AVAILABLE_LANGUAGES:
    putEnv("LANG", lang)
  else:
    putEnv("LANG", DEFAULT_LANGUAGE)
  #

  discard execCmd("cmd /c " & "BF2142Unlocker.exe")