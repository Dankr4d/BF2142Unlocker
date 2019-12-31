import osproc

proc install(pkgName: string): int = # Returns exit code
  return execCmd("nimble install " & pkgName & " -y")

when (compiles do: import gintro/gtk):
  discard
else:
  discard install("gintro")

when defined(windows):
  when (compiles do: import winim):
    discard
  else:
    discard install("winim")

  when (compiles do: import winregistry):
    discard
  else:
    discard install("winregistry")
