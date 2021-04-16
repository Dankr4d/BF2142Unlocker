import registry

const
  REG_PATH_MY_DOCUMENTS = """Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders\"""
  REG_KEY_MY_DOCUMENTS = "Personal"

proc getDocumentsPath*(): string =
  return getUnicodeValue(REG_PATH_MY_DOCUMENTS, REG_KEY_MY_DOCUMENTS, HKEY_CURRENT_USER)

when isMainModule:
  echo getDocumentsPath()