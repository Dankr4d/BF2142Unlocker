import winregistry

const
  REG_PATH = """HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders\"""
  MY_DOCUMENTS_REG_KEY = "Personal"

proc getDocumentsPath*(): string =
  var rhndl: RegHandle = open(REG_PATH, samRead)
  result = rhndl.readString(MY_DOCUMENTS_REG_KEY)
  rhndl.close()

when isMainModule:
  echo getDocumentsPath()