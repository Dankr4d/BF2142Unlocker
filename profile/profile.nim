import conparser
export conparser

type
  # Armors* = seq[Armor]
  Armor* = object of RootObj
    team*: range[0u8 .. 1u8]
    kit*: range[0u8 .. 3u8]
    val* {.Valid: Bools01, Default: false.}: bool
  # Kits* = seq[Kit]
  Kit* = object of RootObj
    team*: range[0u8 .. 1u8]
    kit*: range[0u8 .. 3u8]
    num*: range[0u8 .. 3u8]
    val*: uint8

func getDefaultKits(): seq[Kit] =
  for team in 0u8..1u8:
    for kit in 0u8..3u8:
      for num in 0u8..3u8:
        result.add(Kit(team: team, kit: kit, num: num, val: 0))

func getDefaultArmors(): seq[Armor] =
  for team in 0u8..1u8:
    for kit in 0u8..3u8:
      result.add(Armor(team: team, kit: kit, val: false))

type
  Profile* {.Prefix: "LocalProfile.".} = object
    name* {.Setting: "setName", Default: "\"\"".}: string # ""
    gamespyNick* {.Setting: "setGamespyNick", Default: "\"\"".}: string # ""
    eAOnlineMasterAccount* {.Setting: "setEAOnlineMasterAccount", Default: "\"\"".}: string # ""
    eAOnlineSubAccount* {.Setting: "setEAOnlineSubAccount", Default: "\"\"".}: string # ""
    totalPlayedTime* {.Setting: "setTotalPlayedTime", Default: float(0), RoundW: 3.}: float # 0
    numTimesLoggedIn* {.Setting: "setNumTimesLoggedIn", Default: 1u.}: uint # 1
    rank* {.Setting: "setRank", Default: 0u8.}: range[0u8 .. 43u8] # 0
    careerPoints* {.Setting: "setCareerPoints", Default: 0u16.}: range[0u16 .. 57700u16]  # 0
    lastBaseUpdate* {.Setting: "setLastBaseUpdate", Default: 0u.}: uint # 1560022967
    kits* {.Setting: "setCurrentProfileKitSetting", Format: "[team] [kit] [num] [val]", Default: getDefaultKits().}: seq[Kit]
    armors* {.Setting: "setCurrentProfileHeavyArmor", Format: "[team] [kit] [val]", Default: getDefaultArmors().}: seq[Armor]


when isMainModule:
  let path: string = """/home/dankrad/Battlefield 2142/Profiles/0001/Profile.con"""
  var profile: Profile
  var report: ConReport
  (profile, report) = readCon[Profile](path)
  # for line in report.lines:
  #   echo line
  # echo "################################"
  # echo profile
  profile.writeCon("/home/dankrad/Desktop/profile.con")
