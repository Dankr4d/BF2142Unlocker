proc hasWritePermission*(path: string): bool = # TODO: elevatedio currently only supports windows
  when defined(windows):
    var file: File
    result = file.open(path, fmReadWriteExisting)
    file.close()
  else:
    return true # TODO

when isMainModule:
  const PATH: string = """C:\Program Files (x86)\Electronic Arts\Battlefield 2142\BF2142.exe"""
  echo "hasWritePermission: ", hasWritePermission(PATH)