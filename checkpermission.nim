proc hasWritePermission*(path: string): bool = # TODO: elevatedio currently only supports windows
  when defined(windows):
    var file: File
    result = file.open(path, fmReadWriteExisting)
    file.close()
  else:
    return true

when isMainModule:
  # const PATH = """C:\Program Files (x86)\Electronic Arts\Battlefield 2142\BF2142.exe"""
  const PATH = """C:\Users\peter\Desktop\test.txt"""
  echo "hasWritePermission: ", hasWritePermission(PATH)