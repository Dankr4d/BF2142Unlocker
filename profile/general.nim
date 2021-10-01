import conparser
export conparser

type
  RGB* = object of RootObj
    r*, g*, b* {.Default: 255u8.}: range[0u8 .. 255u8]
  RGBA* = object of RGB
    a* {.Default: 255u8.}: range[0u8 .. 255u8]
  General* {.Prefix: "GeneralSettings.", IgnoreSettings: @["addServerHistory", "setPlayedVOHelp", "addFavouriteServer"].} = object # TODO: Fix sequence in conparser!
    setSortOrder* {.Setting: "setSortOrder", Default: "0".}: string # TODO # 0
    setSortKey* {.Setting: "setSortKey", Default: "\"\"".}: string # TODO # ""
    setNumRoundsPlayed* {.Setting: "setNumRoundsPlayed", Default: "0".}: string # TODO # 0
    setServerFilter* {.Setting: "setServerFilter", Default: "\"\"".}: string # TODO # ""
    hudTransparency* {.Setting: "setHUDTransparency", Default: 255u8.}: range[0u8 .. 255u8] # 255
    crosshairColor* {.Setting: "setCrosshairColor", Format: "[r] [g] [b] [a]", Default: RGBA(r: 255, g: 255, b: 255, a: 255).}: RGBA # 255 255 255 255
    setBuddytagColor* {.Setting: "setBuddytagColor", Default: "0 0 0".}: string # TODO # 0 0 0
    setSquadtagColor* {.Setting: "setSquadtagColor", Default: "0 255 0".}: string # TODO # 0 255 0
    minimapRotate* {.Setting: "setMinimapRotate", Valid: Bools01, Default: true.}: bool # 1
    minimapTransparency* {.Setting: "setMinimapTransparency", Default: 170u8.}: range[0u8 .. 255u8] # 170
    setViewIntroMovie* {.Setting: "setViewIntroMovie", Default: "1".}: string # TODO # 1 # TODO: Doesn't work
    outOfVoting* {.Setting: "setOutOfVoting", Valid: Bools01, Default: false.}: bool # 0
    setBFTVSaveDirectory* {.Setting: "setBFTVSaveDirectory", Default: "\"\"".}: string # TODO} # ""
    setConfirmQuit* {.Setting: "setConfirmQuit", Default: "0".}: string # TODO # 0
    mapIconAlphaTransparency* {.Setting: "setMapIconAlphaTransparency", Default: 255u8.}: range[0u8 .. 255u8]
    setMaxBots* {.Setting: "setMaxBots", Default: "64".}: string # TODO # 64
    setMaxBotsIncludeHumans* {.Setting: "setMaxBotsIncludeHumans", Default: "0".}: string # TODO # 0
    setBotSkill* {.Setting: "setBotSkill", Default: "0.5".}: string # TODO # 0.5
    setAutoScreenshot* {.Setting: "setAutoScreenshot", Default: "0".}: string # TODO # 0
    ignoreBuddyRequests* {.Setting: "setIgnoreBuddyRequests", Valid: Bools01, Default: false.}: bool # 0
    cameraShake* {.Setting: "setCameraShake", Valid: Bools01, Default: true.}: bool # 1
    setColorBlindFriendly* {.Setting: "setColorBlindFriendly", Default: "0".}: string # TODO # 0
    helpPopups* {.Setting: "setHelpPopups", Valid: Bools01, Default: true.}: bool # 1
    killMessagesFilter* {.Setting: "setKillMessagesFilter", Valid: Bools01, Default: true.}: bool # 1
    radioMessagesFilter* {.Setting: "setRadioMessagesFilter", Valid: Bools01, Default: true.}: bool # 1
    chatMessagesFilter* {.Setting: "setChatMessagesFilter", Valid: Bools01, Default: true.}: bool # 1
    setLastAwardsCheckDate* {.Setting: "setLastAwardsCheckDate", Default: "1560022998".}: string # TODO # 1560022998
    setAllowPunkBuster* {.Setting: "setAllowPunkBuster", Default: "1".}: string # TODO # 1
    reverseMousewheelSelection* {.Setting: "setItemSelectionReverseItems", Valid: Bools01, Default: true.}: bool # 1
    setToggleFilters* {.Setting: "setToggleFilters", Default: "312194".}: string # TODO # 312194
    autoReload* {.Setting: "setAutoReload", Valid: Bools01, Default: true.}: bool # 1
    setConnectionType* {.Setting: "setConnectionType", Default: "5".}: string # TODO # 5
    setLCDDisplayModes* {.Setting: "setLCDDisplayModes", Default: "0".}: string # TODO # 0
    setConfirmLaunchEADownloader* {.Setting: "setConfirmLaunchEADownloader", Default: "0".}: string # TODO # 0
    setConfirmLaunchBFWeb* {.Setting: "setConfirmLaunchBFWeb", Default: "0".}: string # TODO # 0
    setConfirmDuplicateKey* {.Setting: "setConfirmDuplicateKey", Default: "0".}: string # TODO # 0
    setConfirmLogout* {.Setting: "setConfirmLogout", Default: "0".}: string # TODO # 0
    setConfirmDiscardBuddyMessages* {.Setting: "setConfirmDiscardBuddyMessages", Default: "0".}: string # TODO # 0
    setConfirmInstantAction* {.Setting: "setConfirmInstantAction", Default: "0".}: string # TODO # 0
    setConfirmReservedSlotsWarning* {.Setting: "setConfirmReservedSlotsWarning", Default: "0".}: string # TODO # 0

when isMainModule:
  let path: string = """/home/dankrad/Battlefield 2142/Profiles/0001/General.con"""
  var general: General
  var report: ConReport
  (general, report) = readCon[General](path)
  for line in report.lines:
    echo line
