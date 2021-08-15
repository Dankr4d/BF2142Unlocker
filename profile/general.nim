import conparser
export conparser

type
  RGB* = object of RootObj
    r*, g*, b* {.Default: 255u8.}: range[0u8 .. 255u8]
  RGBA* = object of RGB
    a* {.Default: 255u8.}: range[0u8 .. 255u8]
  General* {.Prefix: "GeneralSettings.".} = object
    setSortOrder* {.Setting: "setSortOrder".}: string # TODO # 0
    setSortKey* {.Setting: "setSortKey".}: string # TODO # ""
    setNumRoundsPlayed* {.Setting: "setNumRoundsPlayed".}: string # TODO # 0
    setServerFilter* {.Setting: "setServerFilter".}: string # TODO # ""
    hudTransparency* {.Setting: "setHUDTransparency", Default: 255u8.}: range[0u8 .. 255u8] # 255
    crosshairColor* {.Setting: "setCrosshairColor", Format: "[r] [g] [b] [a]", Default: RGBA(r: 255, g: 255, b: 255, a: 255).}: RGBA # 255 255 255 255
    setBuddytagColor* {.Setting: "setBuddytagColor".}: string # TODO # 0 0 0
    setSquadtagColor* {.Setting: "setSquadtagColor".}: string # TODO # 0 255 0
    minimapRotate* {.Setting: "setMinimapRotate", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: true.}: bool # 1
    minimapTransparency* {.Setting: "setMinimapTransparency", Default: 170u8.}: range[0u8 .. 255u8] # 170
    setViewIntroMovie* {.Setting: "setViewIntroMovie".}: string # TODO # 1 # TODO: Doesn't work
    outOfVoting* {.Setting: "setOutOfVoting", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: false.}: bool # 0
    setBFTVSaveDirectory* {.Setting: "setBFTVSaveDirectory".}: string # TODO} # ""
    setConfirmQuit* {.Setting: "setConfirmQuit".}: string # TODO # 0
    mapIconAlphaTransparency* {.Setting: "setMapIconAlphaTransparency", Default: 255u8.}: range[0u8 .. 255u8]
    setMaxBots* {.Setting: "setMaxBots".}: string # TODO # 64
    setMaxBotsIncludeHumans* {.Setting: "setMaxBotsIncludeHumans".}: string # TODO # 0
    setBotSkill* {.Setting: "setBotSkill".}: string # TODO # 0.5
    setAutoScreenshot* {.Setting: "setAutoScreenshot".}: string # TODO # 0
    ignoreBuddyRequests* {.Setting: "setIgnoreBuddyRequests", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: false.}: bool # 0
    cameraShake* {.Setting: "setCameraShake", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: true.}: bool # 1
    setColorBlindFriendly* {.Setting: "setColorBlindFriendly".}: string # TODO # 0
    helpPopups* {.Setting: "setHelpPopups", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: true.}: bool # 1
    killMessagesFilter* {.Setting: "setKillMessagesFilter", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: true.}: bool # 1
    radioMessagesFilter* {.Setting: "setRadioMessagesFilter", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: true.}: bool # 1
    chatMessagesFilter* {.Setting: "setChatMessagesFilter", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: true.}: bool # 1
    setLastAwardsCheckDate* {.Setting: "setLastAwardsCheckDate".}: string # TODO # 1560022998
    setAllowPunkBuster* {.Setting: "setAllowPunkBuster".}: string # TODO # 1
    reverseMousewheelSelection* {.Setting: "setItemSelectionReverseItems", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: true.}: bool # 1
    setToggleFilters* {.Setting: "setToggleFilters".}: string # TODO # 312194
    autoReload* {.Setting: "setAutoReload", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: true.}: bool # 1
    setConnectionType* {.Setting: "setConnectionType".}: string # TODO # 5
    setLCDDisplayModes* {.Setting: "setLCDDisplayModes".}: string # TODO # 0
    setConfirmLaunchEADownloader* {.Setting: "setConfirmLaunchEADownloader".}: string # TODO # 0
    setConfirmLaunchBFWeb* {.Setting: "setConfirmLaunchBFWeb".}: string # TODO # 0
    setConfirmDuplicateKey* {.Setting: "setConfirmDuplicateKey".}: string # TODO # 0
    setConfirmLogout* {.Setting: "setConfirmLogout".}: string # TODO # 0
    setConfirmDiscardBuddyMessages* {.Setting: "setConfirmDiscardBuddyMessages".}: string # TODO # 0
    setConfirmInstantAction* {.Setting: "setConfirmInstantAction".}: string # TODO # 0
    setConfirmReservedSlotsWarning* {.Setting: "setConfirmReservedSlotsWarning".}: string # TODO # 0

when isMainModule and false:
  let path: string = """/home/dankrad/Battlefield 2142/Profiles/0001/General.con"""
  var general: General
  var report: ConReport
  (general, report) = readCon[General](path)
  for line in report.lines:
    echo line
