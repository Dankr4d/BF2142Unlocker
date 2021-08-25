import conparser
export conparser

type
  Global* {.Prefix: "GlobalSettings.".} = object
    defaultUser* {.Setting: "setDefaultUser", Default: "0001".}: string
    lastOnlineUser* {.Setting: "setLastOnlineUser", Default: "\"\"".}: string
    encryptedLogin* {.Setting: "setEncryptedLogin", Default: "\"\"".}: string
    namePrefix* {.Setting: "setNamePrefix", Default: "\"\"".}: string


when isMainModule:
  let path: string = """/home/dankrad/Battlefield 2142/Profiles/Global.con"""
  var global: Global
  var report: ConReport
  (global, report) = readCon[Global](path)
  for line in report.lines:
    echo line
  echo global
