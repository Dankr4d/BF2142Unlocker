import conparser
export conparser

type
  ServerSettings* {.Prefix: "GameServerSettings.".} = object
    serverName* {.Setting: "setServerName", Default: "\"Battlefield 2142\"".}: string # "Battlefield 2142"
    setPassword* {.Setting: "setPassword", Default: "\"\"".}: string # ""
    internet* {.Setting: "setInternet", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: true.}: bool # 1
    maxPlayers* {.Setting: "setMaxPlayers", Default: 64u8.}: range[0u8 .. 64u8] # 64
    spawnTime* {.Setting: "setSpawnTime", Default: 15u8.}: range[0u8 .. 30u8] # 15
    ticketRatio* {.Setting: "setTicketRatio", Default: 100u16.}: range[10u16 .. 999u16] # 100
    roundsPerMap* {.Setting: "setRoundsPerMap", Default: 3u8.}: range[0u8 .. 10u8] # 3
    timeLimit* {.Setting: "setTimeLimit", Default: 0u8.}: range[0u8 .. 120u8] # 0
    scoreLimit* {.Setting: "setScoreLimit", Default: 0u8.}: uint8 # 0 # TODO: range
    soldierFF* {.Setting: "setSoldierFF", Default: 100u8.}: range[0u8 .. 100u8] # 100
    vehicleFF* {.Setting: "setVehicleFF", Default: 100u8.}: range[0u8 .. 100u8] # 100
    soldierSplashFF* {.Setting: "setSoldierSplashFF", Default: 100u8.}: range[0u8 .. 100u8] # 100
    vehicleSplashFF* {.Setting: "setVehicleSplashFF", Default: 100u8.}: range[0u8 .. 100u8] # 100
    punishTeamKills* {.Setting: "setPunishTeamKills", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: true.}: bool # 1
    votingEnabled* {.Setting: "setVotingEnabled", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: true.}: bool # 1
    voteTime* {.Setting: "setVoteTime", Default: 90u8.}: uint8 # 90 # TODO: range
    minPlayersForVoting* {.Setting: "setMinPlayersForVoting", Default: 2u8.}: range[1u8 .. 64u8] # 2
    voipEnabled* {.Setting: "setVoipEnabled", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: true.}: bool # 1
    voipQuality* {.Setting: "setVoipQuality", Default: 3u8.}: uint8 # 3 # TODO: range
    voipServerRemote* {.Setting: "setVoipServerRemote", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: false.}: bool # 0
    voipServerRemoteIP* {.Setting: "setVoipServerRemoteIP", Default: "".}: string #
    voipServerPort* {.Setting: "setVoipServerPort", Default: 55125u16.}: uint16 # 55125
    voipBFClientPort* {.Setting: "setVoipBFClientPort", Default:55123u16.}: uint16 # 55123
    voipBFServerPort* {.Setting: "setVoipBFServerPort", Default:55124u16.}: uint16 # 55124
    voipSharedPassword* {.Setting: "setVoipSharedPassword", Default: "".}: string #
    autoRecord* {.Setting: "setAutoRecord", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: false.}: bool # 0
    svPunkBuster* {.Setting: "setSvPunkBuster", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: false.}: bool # 0
    teamRatio* {.Setting: "setTeamRatio", Default: 100u8.}: uint8 # 100 # TODO: range
    autoBalanceTeam* {.Setting: "setAutoBalanceTeam", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: false.}: bool # 0
    gameMode* {.Setting: "setGameMode", Default: "".}: string #

when isMainModule:
  let path: string = """/home/dankrad/Battlefield 2142/Profiles/0001/ServerSettings.con"""
  var serverSettings: ServerSettings = newDefault[ServerSettings]()
  var report: ConReport
  (serverSettings, report) = readCon[ServerSettings](path)
  for line in report.lines:
    echo line
  echo serverSettings
