# Incoming and outgoing traffic must be configured for the following GameSpy ports:
# 6667 (IRC)
# 27900 (Master Server UDP Heartbeat)
# 28900 (Master Server List Request)
# 29900 (GP Connection Manager)
# 29901 (GP Search Manager)
# 13139 (Custom UDP Pings)
# 6515 (Dplay UDP)
# 6500 (Query Port)
# ----------------------------------------------
# Outgoing UDP 27900
# Outgoing UDP 29910
# Outgoing UDP 29960
# Outgoing TCP 80
# Incoming UDP 16567 (might be different - see sv.gameport in your mods/bf2/settings/serversettings.con)
# Incoming UDP 29900 (might be different - see sv.gameSpyPort in your mods/bf2/settings/serversettings.con)
# ----------------------------------------------
# https://bf2tech.uturista.pt/index.php/GameSpy_Protocol


import asyncnet, asyncdispatch, net
# import times
import parseutils
import strutils
import tables # TODO: Remove


type
  # Flag {.packed.} = enum
  #   Disabled = (byte) 0x00
  #   Enabled = (byte) 0xFF
  Flag = byte
  Magic = array[2, byte]
  ProtocolId = enum
    Protocol00 = 0x00.byte
  # TypeId = enum
  #   Server = 0x00.byte
  #   Player = 0x01.byte
  #   Team = 0x02.byte
  TimeStamp = uint32  # array[4, byte]

const MAGIC_VALUE: Magic = [0xFE.byte, 0xFD.byte]

type # Protcol 00
  Header00 {.packed.} = object
    magic: Magic
    protocolId: ProtocolId
    timeStamp: TimeStamp
  Protocol00A {.packed.} = object
    header: Header00
    giveHeaders: Flag # Ignored in Subprotocol B
    givePlayers: Flag # Ignored in Subprotocol B
    giveTeams: Flag # Ignored in Subprotocol B
  Protocol00B = Protocol00A
  Response00 {.packed.} = object
    protocolId: ProtocolId
    timeStamp: TimeStamp
    splitNum: byte
    messageNumber: byte
    data: string

type
  GSpyServer* = object
    hostport*: uint16 # "17567",
    gamemode*: string # "openplaying",
    bf2142_spawntime*: float # "15.000000",
    bf2142_pure*: bool # "0",
    bf2142_d_idx*: string # "http://",
    bf2142_team2*: string # "reb",
    numplayers*: uint8 # "0",
    bf2142_maxrank*: uint16 # What is maxrank? # "0",
    bf2142_teamratio*: float # Maybe uint8? # "100.000000",
    bf2142_custom_map_url*: string # "0http://www.moddb.com/mods/first-strike/downloads",
    mapname*: string # "Endor_Clearing",
    bf2142_globalunlocks*: bool # What does globalunlocks? # "1",
    bf2142_ticketratio*: uint8 # "100",
    password*: bool # "0",
    bf2142_d_dl*: string # "http://",
    bf2142_sponsortext*: string # "",
    bf2142_region*: string # "",
    gamevariant*: string # "firststrike",
    gametype*: string # "gpm_coop",
    bf2142_ranked*: bool # "0",
    bf2142_averageping*: uint16 # "0",
    bf2142_provider*: string # "",
    bf2142_ranked_tournament*: bool # "0",
    bf2142_anticheat*: bool # "0",
    bf2142_friendlyfire*: bool # "1",
    bf2142_communitylogo_url*: string # "http://cdn-images.imagevenue.com/47/2d/9c/ME122MV2_o.jpg",
    maxplayers*: uint8 # "32",
    bf2142_voip*: bool # "1",
    bf2142_reservedslots*: uint8 # Or bool? "0",
    bf2142_type*: string # Don't know what this is. # "0",
    gamename*: string # "stella",
    bf2142_mapsize*: uint8 # "32",
    bf2142_scorelimit*: uint # Or bool or uint8/unit16? # "0",
    bf2142_allow_spectators*: bool # "0",
    gamever*: string # "1.10.112.0",
    bf2142_tkmode*: string # Maybe enum # "Punish",
    bf2142_autobalanced*: bool # "1",
    bf2142_team1*: string # "imp",
    bf2142_autorec*: bool # "0",
    bf2142_sponsorlogo_url*: string # "http://cdn-images.imagevenue.com/47/2d/9c/ME122MV2_o.jpg",
    timelimit*: uint16 # Or uint8? Minutes or milliseconds? # "0",
    hostname*: string # "First Strike - 1.63 Test",
    roundtime*: uint8 # Is this how much rounds a map is played? # "1",
    bf2142_startdelay*: uint8 # Or uint16. Check the max startdelay (seconds) # "15"
  GSpyTeam* = object
    team_t*: seq[string]
    score_t*: seq[uint16]
  GSpyPlayer* = object
    deaths*: seq[uint16]
    pid*: seq[uint32] # Maybe uint16
    score*: seq[int16]
    skill*: seq[uint16]
    team*: seq[uint8] # Or bool, because there are only two teams
    ping*: seq[uint16]
    player*: seq[string]

proc newHeader00(protocolId: ProtocolId = Protocol00, timeStamp: TimeStamp = TimeStamp.high): Header00 =
  result.magic = MAGIC_VALUE
  result.protocolId = protocolId
  result.timeStamp = timeStamp

proc newProtocol00B*(): Protocol00B =
  result.header = newHeader00()

proc serialize(protocol00B: Protocol00B): string =
  result = newString(sizeof(protocol00B))
  copyMem(addr result[0], unsafeAddr protocol00B, sizeof(Protocol00B))
  result.add(char(0x01))

proc recvProto00*(address: string, port: Port, protocol00B: Protocol00B, timeout: int = 0): Future[seq[string]] {.async.} =
  var messages: Table[int, string]
  var socket = newAsyncSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  await socket.sendTo(address, port, protocol00B.serialize())

  while true: ## todo read up to a max limit to not stall the client when server fucks up
    # var resp: tuple[data: string, address: string, port: Port] = waitFor socket.recvFrom(1400)
    var respFuture: Future[tuple[data: string, address: string, port: Port]] = socket.recvFrom(1400)
    var resp: tuple[data: string, address: string, port: Port]
    if timeout > 0:
      if await withTimeout(respFuture, timeout):
        resp = await respFuture
      else:
        echo "TIMEOUTED QUERYING GAMESPY ... GOING TO BREAK"
        break
    else:
      resp = await respFuture

    # echo repr resp
    # echo "PACKAGE: ", repr resp.data
    var response: Response00
    response.protocolId = resp.data[0].ProtocolId #parseEnum[ProtocolId](resp[0])
    # response.timeStamp = cast[TimeStamp](resp[1..5])
    response.splitNum = resp.data[13].byte
    var lastAndMessageNum: byte = resp.data[14].byte
    var isLastMessage: bool = lastAndMessageNum.shr(7).bool
    # echo "isLastMessage: ", isLastMessage
    response.messageNumber = lastAndMessageNum.shl(1).shr(1)
    # echo "response.messageNumber: ", response.messageNumber
    response.data = resp.data[15..^1]
    # echo repr response.data
    messages[response.messageNumber.int] = response.data
    if isLastMessage:
      break
  for idx in 0 .. messages.len - 1:
    result.add messages[idx]

proc parseCstr*(msg: string, pos: var int): string =
  pos += msg.parseUntil(result, 0x00.char, pos)
  pos.inc() # skip 0x00


proc parseGSpyServer*(msg: string, pos: var int): GSpyServer =
  while true:
    var key = msg.parseCstr(pos)
    var val = msg.parseCstr(pos)

    case key:
    of "hostport":
      result.hostport = parseUInt(val).uint16
    of "gamemode":
      result.gamemode = val
    of "bf2142_spawntime":
      result.bf2142_spawntime = parseFloat(val)
    of "bf2142_pure":
      result.bf2142_pure = parseBool(val)
    of "bf2142_d_idx":
      result.bf2142_d_idx = val
    of "bf2142_team2":
      result.bf2142_team2 = val
    of "numplayers":
      result.numplayers = parseUInt(val).uint8
    of "bf2142_maxrank":
      result.bf2142_maxrank = parseUInt(val).uint16
    of "bf2142_teamratio":
      result.bf2142_teamratio = parseFloat(val)
    of "bf2142_custom_map_url":
      result.bf2142_custom_map_url = val
    of "mapname":
      result.mapname = val
    of "bf2142_globalunlocks":
      result.bf2142_globalunlocks = parseBool(val)
    of "bf2142_ticketratio":
      result.bf2142_ticketratio = parseUInt(val).uint8
    of "password":
      result.password = parseBool(val)
    of "bf2142_d_dl":
      result.bf2142_d_dl = val
    of "bf2142_sponsortext":
      result.bf2142_sponsortext = val
    of "bf2142_region":
      result.bf2142_region = val
    of "gamevariant":
      result.gamevariant = val
    of "gametype":
      result.gametype = val
    of "bf2142_ranked":
      result.bf2142_ranked = parseBool(val)
    of "bf2142_averageping":
      result.bf2142_averageping = parseUInt(val).uint16
    of "bf2142_provider":
      result.bf2142_provider = val
    of "bf2142_ranked_tournament":
      result.bf2142_ranked_tournament = parseBool(val)
    of "bf2142_anticheat":
      result.bf2142_anticheat = parseBool(val)
    of "bf2142_friendlyfire":
      result.bf2142_friendlyfire = parseBool(val)
    of "bf2142_communitylogo_url":
      result.bf2142_communitylogo_url = val
    of "maxplayers":
      result.maxplayers = parseUInt(val).uint8
    of "bf2142_voip":
      result.bf2142_voip = parseBool(val)
    of "bf2142_reservedslots":
      result.bf2142_reservedslots = parseUInt(val).uint8
    of "bf2142_type":
      result.bf2142_type = val
    of "gamename":
      result.gamename = val
    of "bf2142_mapsize":
      result.bf2142_mapsize = parseUInt(val).uint8
    of "bf2142_scorelimit":
      result.bf2142_scorelimit = parseUInt(val)
    of "bf2142_allow_spectators":
      result.bf2142_allow_spectators = parseBool(val)
    of "gamever":
      result.gamever = val
    of "bf2142_tkmode":
      result.bf2142_tkmode = val
    of "bf2142_autobalanced":
      result.bf2142_autobalanced = parseBool(val)
    of "bf2142_team1":
      result.bf2142_team1 = val
    of "bf2142_autorec":
      result.bf2142_autorec = parseBool(val)
    of "bf2142_sponsorlogo_url":
      result.bf2142_sponsorlogo_url = val
    of "timelimit":
      result.timelimit = parseUInt(val).uint16
    of "hostname":
      result.hostname = val
    of "roundtime":
      result.roundtime = parseUInt(val).uint8
    of "bf2142_startdelay":
      result.bf2142_startdelay = parseUInt(val).uint8

    if msg[pos] == 0x00.char:
      pos.inc() # skip 0x00
      pos += msg.skip($(0x01.char), pos)
      return

############# TODO: Get rid of this redundance
proc parseListUInt8(msg: string, pos: var int): seq[uint8] =
  pos.inc() # skip the byte start starts the list 0x00, 0x01 (offset?)
  while pos < msg.len:
    let linebuf = msg.parseCstr(pos)
    if pos == msg.len:
      return
    result.add(parseUInt(linebuf).uint8)
    if msg[pos] == 0x00.char:
      pos.inc() # skip 0x00
      return

proc parseListInt16(msg: string, pos: var int): seq[int16] =
  pos.inc() # skip the byte start starts the list 0x00, 0x01 (offset?)
  while pos < msg.len:
    let linebuf = msg.parseCstr(pos)
    if pos == msg.len:
      return
    result.add(parseInt(linebuf).int16)
    if msg[pos] == 0x00.char:
      pos.inc() # skip 0x00
      return

proc parseListUInt16(msg: string, pos: var int): seq[uint16] =
  pos.inc() # skip the byte start starts the list 0x00, 0x01 (offset?)
  while pos < msg.len:
    let linebuf = msg.parseCstr(pos)
    if pos == msg.len:
      return
    result.add(parseUInt(linebuf).uint16)
    if msg[pos] == 0x00.char:
      pos.inc() # skip 0x00
      return

proc parseListUInt32(msg: string, pos: var int): seq[uint32] =
  pos.inc() # skip the byte start starts the list 0x00, 0x01 (offset?)
  while pos < msg.len:
    let linebuf = msg.parseCstr(pos)
    if pos == msg.len:
      return
    result.add(parseUInt(linebuf).uint32)
    if msg[pos] == 0x00.char:
      pos.inc() # skip 0x00
      return

proc parseListStr(msg: string, pos: var int): seq[string] =
  pos.inc() # skip the byte start starts the list 0x00, 0x01 (offset?)
  while pos < msg.len:
    let linebuf = msg.parseCstr(pos)
    if pos == msg.len:
      return
    result.add(linebuf)
    if msg[pos] == 0x00.char:
      pos.inc() # skip 0x00
      return
########################

proc queryAll*(url: string, port: Port, timeout: int = 0): tuple[server: GSpyServer, player: GSpyPlayer, team: GSpyTeam] =
  var messages = waitFor recvProto00(url, port, newProtocol00B(), timeout)
  # var messages = @["\x00hostname\x00Reclamation Remaster\x00gamename\x00stella\x00gamever\x001.10.112.0\x00mapname\x00Leipzig\x00gametype\x00gpm_coop\x00gamevariant\x00project_remaster_mp\x00numplayers\x002\x00maxplayers\x0064\x00gamemode\x00openplaying\x00password\x000\x00timelimit\x000\x00roundtime\x001\x00hostport\x0017567\x00bf2142_ranked\x001\x00bf2142_anticheat\x000\x00bf2142_autorec\x000\x00bf2142_d_idx\x00http://\x00bf2142_d_dl\x00http://\x00bf2142_voip\x001\x00bf2142_autobalanced\x001\x00bf2142_friendlyfire\x001\x00bf2142_tkmode\x00Punish\x00bf2142_startdelay\x0015\x00bf2142_spawntime\x0015.000000\x00bf2142_sponsortext\x00\x00bf2142_sponsorlogo_url\x00http://lightav.com/bf2142/mixedmode.jpg\x00bf2142_communitylogo_url\x00http://lightav.com/bf2142/mixedmode.jpg\x00bf2142_scorelimit\x000\x00bf2142_ticketratio\x00100\x00bf2142_teamratio\x00100.000000\x00bf2142_team1\x00Pac\x00bf2142_team2\x00EU\x00bf2142_pure\x000\x00bf2142_mapsize\x0032\x00bf2142_globalunlocks\x001\x00bf2142_reservedslots\x000\x00bf2142_maxrank\x000\x00bf2142_provider\x00OS\x00bf2142_region\x00EU\x00bf2142_type\x000\x00bf2142_averageping\x001\x00bf2142_ranked_tournament\x000\x00bf2142_allow_spectators\x000\x00bf2142_custom_map_url\x000http://battlefield2142.co\x00\x00\x01player_\x00\x00 ddre\x00NineEleven Hijackers\x00Sir Smokealot\x00DSquarius Green\x00Guy Nutter\x00Jack Ghoff\x00DGlester Hardunkichud\x00Bang-Ding Ow\x00LORD Voldemort\x00Rick Titball\x00Michael Myers\x00Harry Palmer\x00Justin Sider\x00Hans Gruber\x00Professor Chaos\x00Nyquillus Dillwad\x00Dylan Weed\x00Ben Dover\x00Vin Diesel\x00Harry Beaver\x00Jack Mehoff\x00Jawana Die\x00Mr Slave\x00 Boomer-UK\x00X-Wing AtAliciousness\x00Bloody Glove\x00MaryJane Potman\x00Tits McGee\x00Phat Ho\x00Dee Capitated\x00T 1\x00", "\x01player_\x00\x1ET 1000\x00Quackadilly Blip\x00No Collusion\x00\x00score_\x00\x0037\x0021\x0018\x0018\x0016\x0015\x0013\x0012\x0010\x0010\x009\x009\x008\x008\x008\x007\x007\x007\x006\x006\x006\x005\x005\x004\x003\x003\x003\x003\x002\x001\x001\x001\x000\x00\x00ping_\x00\x0041\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x0023\x000\x000\x000\x000\x000\x000\x000\x000\x000\x00\x00team_\x00\x002\x002\x002\x002\x001\x001\x002\x002\x002\x002\x002\x002\x001\x002\x002\x001\x002\x001\x001\x001\x002\x001\x001\x002\x001\x001\x001\x002\x001\x001\x002\x001\x001\x00\x00deaths_\x00\x006\x004\x005\x005\x006\x0011\x004\x004\x0010\x005\x008\x006\x008\x005\x007\x006\x009\x004\x005\x007\x006\x007\x0010\x000\x007\x007\x008\x007\x007\x007\x004\x006\x006\x00\x00pid_\x00\x0030748\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x000\x0032963\x000\x000\x000\x000\x000\x000\x000\x000\x000\x00\x00skill_\x00\x0031\x006\x0011\x0010\x0014\x0015\x002\x006\x007\x005\x007\x003\x006\x004\x004\x007\x007\x004\x006\x006\x001\x004\x003\x004\x003\x002\x001\x000\x004\x003\x002\x000\x000\x00\x00\x00\x02team_t\x00\x00Pac\x00EU\x00\x00score_t\x00\x000\x000\x00\x00\x00"]
  # TODO: Crashes with following (empty lists)
  # var messages = @["\x00hostname\x00Reclamation US\x00gamename\x00stella\x00gamever\x001.10.112.0\x00mapname\x002142af_ladder_1\x00gametype\x00gpm_cq\x00gamevariant\x00bf2142\x00numplayers\x000\x00maxplayers\x0064\x00gamemode\x00openplaying\x00password\x000\x00timelimit\x000\x00roundtime\x001\x00hostport\x0017567\x00bf2142_ranked\x001\x00bf2142_anticheat\x000\x00bf2142_autorec\x000\x00bf2142_d_idx\x00http://\x00bf2142_d_dl\x00http://\x00bf2142_voip\x001\x00bf2142_autobalanced\x001\x00bf2142_friendlyfire\x001\x00bf2142_tkmode\x00Punish\x00bf2142_startdelay\x0015\x00bf2142_spawntime\x0015.000000\x00bf2142_sponsortext\x00\x00bf2142_sponsorlogo_url\x00http://lightav.com/bf2142/mixedmode.jpg\x00bf2142_communitylogo_url\x00http://lightav.com/bf2142/mixedmode.jpg\x00bf2142_scorelimit\x000\x00bf2142_ticketratio\x00100\x00bf2142_teamratio\x00100.000000\x00bf2142_team1\x00Pac\x00bf2142_team2\x00EU\x00bf2142_pure\x000\x00bf2142_mapsize\x0064\x00bf2142_globalunlocks\x001\x00bf2142_reservedslots\x000\x00bf2142_maxrank\x000\x00bf2142_provider\x00OS\x00bf2142_region\x00US\x00bf2142_type\x000\x00bf2142_averageping\x000\x00bf2142_ranked_tournament\x000\x00bf2142_allow_spectators\x000\x00bf2142_custom_map_url\x000http://battlefield2142.co\x00\x00\1player_\x00\x00\x00score_\x00\x00\x00ping_\x00\x00\x00team_\x00\x00\x00deaths_\x00\x00\x00pid_\x00\x00\x00skill_\x00\x00\x00\x00\2team_t\x00\x00Pac\x00EU\x00\x00score_t\x00\x000\x000\x00\x00\x00"]
  var lists: Table[string, seq[string]]
  for idx, message in messages:
    var pos = 1 # Skip the first byte of the message (the first byte is the typeid 0x00,0x01, 0x02/ Server, Player, Team)
    if idx == 0:
      result.server = parseGSpyServer(message, pos)
    if pos >= message.len:
      continue
    # echo messages
    while pos < message.len:
      try:
        pos += message.skipWhile({0x00.char, 0x01.char, 0x02.char}, pos)
        var nextWord: string = message.parseCstr(pos)

        case nextWord:
        of "deaths_": # Player
          result.player.deaths.add(parseListUInt16(message, pos))
        of "pid_": # Player
          result.player.pid.add(parseListUInt32(message, pos))
        of "score_": # Player
          result.player.score.add(parseListInt16(message, pos))
        of "skill_": # Player
          result.player.skill.add(parseListUInt16(message, pos))
        of "team_": # Player
          result.player.team.add(parseListUInt8(message, pos))
        of "ping_": # Player
          result.player.ping.add(parseListUInt16(message, pos))
        of "player_": # Player
          result.player.player.add(parseListStr(message, pos))
        of "team_t": # Team
          result.team.team_t.add(parseListStr(message, pos))
        of "score_t": # Team
          result.team.score_t.add(parseListUInt16(message, pos))
      except:
        continue

      # discard lists.hasKeyOrPut(nextWord, @[])
      # lists[nextWord].add(parseList(message, pos))

  # echo lists

when isMainModule:
  echo queryAll("185.189.255.6", Port(29987))

# proc parseServerSettings(raw: string) =
  # discard

### TODO: Parser crashes while parsing ping list. It returns `@["", "team_"]` instead of pings:
# 0x7fc74d6584a0"\0hostname\0Reclamation US\0gamename\0stella\0gamever\01.10.112.0\0mapname\02142af_ladder_1\0gametype\0gpm_cq\0gamevariant\0bf2142\0numplayers\00\0maxplayers\064\0gamemode\0openplaying\0password\00\0timelimit\00\0roundtime\01\0hostport\017567\0bf2142_ranked\01\0bf2142_anticheat\00\0bf2142_autorec\00\0bf2142_d_idx\0http://\0bf2142_d_dl\0http://\0bf2142_voip\01\0bf2142_autobalanced\01\0bf2142_friendlyfire\01\0bf2142_tkmode\0Punish\0bf2142_startdelay\015\0bf2142_spawntime\015.000000\0bf2142_sponsortext\0\0bf2142_sponsorlogo_url\0http://lightav.com/bf2142/mixedmode.jpg\0bf2142_communitylogo_url\0http://lightav.com/bf2142/mixedmode.jpg\0bf2142_scorelimit\00\0bf2142_ticketratio\0100\0bf2142_teamratio\0100.000000\0bf2142_team1\0Pac\0bf2142_team2\0EU\0bf2142_pure\00\0bf2142_mapsize\064\0bf2142_globalunlocks\01\0bf2142_reservedslots\00\0bf2142_maxrank\00\0bf2142_provider\0OS\0bf2142_region\0US\0bf2142_type\00\0bf2142_averageping\00\0bf2142_ranked_tournament\00\0bf2142_allow_spectators\00\0bf2142_custom_map_url\00http://battlefield2142.co\0\0\1player_\0\0\0score_\0\0\0ping_\0\0\0team_\0\0\0deaths_\0\0\0pid_\0\0\0skill_\0\0\0\0\2team_t\0\0Pac\0EU\0\0score_t\0\00\00\0\0\0"
