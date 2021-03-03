import asyncnet, asyncdispatch, net
# import times
import parseutils
import strutils
import sets
import options

type
  Magic* = array[2, byte]
  ProtocolId* = enum
    Protocol00 = 0x00.byte
  TimeStamp* = uint32  # array[4, byte]

const MAGIC_VALUE*: Magic = [0xFE.byte, 0xFD.byte]


type
  Protocol00CByte* = enum
    # Missing: Mapsize, Ping, Ranked .. Maybe not supported in Protocol00C
    Hostname = byte(0x01)
    Gamename = byte(0x02)
    Gamever = byte(0x03)
    Hostport = byte(0x04)
    Mapname = byte(0x05)
    Gametype = byte(0x06)
    Gamevariant = byte(0x07)
    Numplayers = byte(0x08)
    UnknownByte09 = byte(0x09)
    Maxplayers = byte(0x0A)
    Gamemode = byte(0x0B)
    UnknownByte0C = byte(0x0C)
    UnknownByte0D = byte(0x0D)
    UnknownByte0E = byte(0x0E)
    UnknownByte0F = byte(0x0F)
    Timelimit = byte(0x10)
    Roundtime = byte(0x11)
    UnknownByte12 = byte(0x12)
    UnknownByte13 = byte(0x13)
  Protocol00CBytes* = OrderedSet[Protocol00CByte]

const Protocol00CBytesAll*: Protocol00CBytes = toOrderedSet([Hostname, Gamename, Gamever, Hostport, Mapname, Gametype, Gamevariant, Numplayers, Maxplayers, Gamemode, Timelimit, Roundtime])

type # Protcol 00
  Header00* {.packed.} = object
    magic*: Magic
    protocolId*: ProtocolId
    timeStamp*: TimeStamp
  Protocol00B* {.packed.} = object
    header*: Header00
    # INFO: I've implemented Protocol00A, which allows to query header, player and or team information
    #       by setting a flag. The response is limmited to 1400 bytes and is not multipart.
    #       As I finished with Protocol00A I realizeed, that server only respond to me when player flag
    #       is set. Also the data is in another format and not the same as in Protocol00B,
    #       Therefore I reverted Protocol00A.
  Protocol00C* = object
    header*: Header00
    bytes*: Protocol00CBytes
  Response00B* {.packed.} = object
    protocolId*: ProtocolId
    timeStamp*: TimeStamp
    splitNum*: byte
    messageNumber*: byte
    data*: string
  Response00C* {.packed.} = object
    protocolId*: ProtocolId
    timeStamp*: TimeStamp
    data*: string

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
  GSpy* = object
    server*: GSpyServer
    player*: GSpyPlayer
    team*: GSpyTeam


proc newHeader00*(protocolId: ProtocolId = Protocol00, timeStamp: TimeStamp = TimeStamp.high): Header00 =
  result.magic = MAGIC_VALUE
  result.protocolId = protocolId
  result.timeStamp = timeStamp


proc newProtocol00B*(): Protocol00B =
  result.header = newHeader00()


proc newProtocol00C*(bytes: Protocol00CBytes): Protocol00C =
  result.header = newHeader00()
  result.bytes = bytes


proc serialize*(header00: Header00): string =
  result = newString(sizeof(Header00))
  copyMem(addr result[0], unsafeAddr header00, sizeof(Protocol00B))


proc serialize*(protocol00B: Protocol00B): string =
  result = newString(sizeof(Protocol00B))
  copyMem(addr result[0], unsafeAddr protocol00B, sizeof(Protocol00B))
  # Server, Player and Team query bytes (are ignored in Protocol00B). In Protocol00A 0x00 disables and 0xFF enables querying
  # those informations. E.g. 0x00 0xFF 0x00 will query player information.
  result.add("\x00\x00\x00")
  result.add("\x01")


proc serialize*(protocol00C: Protocol00C): string =
  result.add(protocol00C.header.serialize())
  result.add(char(byte(protocol00C.bytes.len)))
  for b in protocol00C.bytes:
    result.add(char(b))
  result.add("\x00\x00")


proc sendProtocol00B*(address: IpAddress, port: Port, protocol00B: Protocol00B, timeout: int = -1): Future[seq[Response00B]] {.async.} =
  var socket = newAsyncSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  var resp: tuple[data: string, address: string, port: Port]
  var response00B: Response00B

  try:
    await socket.sendTo($address, port, protocol00B.serialize())

    while true: ## todo read up to a max limit to not stall the client when server fucks up
      var respFuture: Future[tuple[data: string, address: string, port: Port]] = socket.recvFrom(1400)
      if timeout > -1:
        if await withTimeout(respFuture, timeout):
          resp = await respFuture
        else:
          # echo "TIMEOUT QUERYING GAMESPY SERVER (", address, ":", $port, ") ... BREAKING OUT"
          break
      else:
        resp = await respFuture

      response00B = Response00B()
      response00B.protocolId = resp.data[0].ProtocolId #parseEnum[ProtocolId](resp[0])
      # response00B.timeStamp = cast[TimeStamp](resp[1..5])
      response00B.splitNum = resp.data[13].byte
      let lastAndMessageNum: byte = resp.data[14].byte
      let isLastMessage: bool = lastAndMessageNum.shr(7).bool
      response00B.messageNumber = lastAndMessageNum.shl(1).shr(1)
      response00B.data = resp.data[15..^1]
      result.add(response00B)
      if isLastMessage:
        break
    socket.close()
  except OSError:
    socket.close()
    return


proc sendProtocol00C*(address: IpAddress, port: Port, protocol00C: Protocol00C, timeout: int = -1): Future[Option[Response00C]] {.async.} =
  var socket = newAsyncSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  var resp: tuple[data: string, address: string, port: Port]

  try:
    await socket.sendTo($address, port, protocol00C.serialize())

    var respFuture: Future[tuple[data: string, address: string, port: Port]] = socket.recvFrom(1400)

    if timeout > -1:
      if await withTimeout(respFuture, timeout):
        resp = await respFuture
      else:
        # echo "TIMEOUT QUERYING GAMESPY SERVER (", address, ":", $port, ") ... BREAKING OUT"
        break
    else:
      resp = await respFuture
    socket.close()
  except OSError:
    socket.close()
    return none(Response00C) # Server not reachable

  var response: Response00C
  response.protocolId = resp.data[0].ProtocolId #parseEnum[ProtocolId](resp[0])
  # response.timeStamp = cast[TimeStamp](resp[1..5])
  response.data = resp.data[5..^1]
  return some(response)


proc parseCStr(str: string, pos: var int): string =
  pos += str.parseUntil(result, char(0x0), pos)
  pos.inc()


proc parseGSpyServer*(data: string, server: var GSpyServer, pos: var int) =
  while true:
    var key: string = data.parseCStr(pos)
    var val: string = data.parseCStr(pos)

    case key:
    of "hostport":
      server.hostport = parseUInt(val).uint16
    of "gamemode":
      server.gamemode = val
    of "bf2142_spawntime":
      server.bf2142_spawntime = parseFloat(val)
    of "bf2142_pure":
      server.bf2142_pure = parseBool(val)
    of "bf2142_d_idx":
      server.bf2142_d_idx = val
    of "bf2142_team2":
      server.bf2142_team2 = val
    of "numplayers":
      server.numplayers = parseUInt(val).uint8
    of "bf2142_maxrank":
      server.bf2142_maxrank = parseUInt(val).uint16
    of "bf2142_teamratio":
      server.bf2142_teamratio = parseFloat(val)
    of "bf2142_custom_map_url":
      server.bf2142_custom_map_url = val
    of "mapname":
      server.mapname = val
    of "bf2142_globalunlocks":
      server.bf2142_globalunlocks = parseBool(val)
    of "bf2142_ticketratio":
      server.bf2142_ticketratio = parseUInt(val).uint8
    of "password":
      server.password = parseBool(val)
    of "bf2142_d_dl":
      server.bf2142_d_dl = val
    of "bf2142_sponsortext":
      server.bf2142_sponsortext = val
    of "bf2142_region":
      server.bf2142_region = val
    of "gamevariant":
      server.gamevariant = val
    of "gametype":
      server.gametype = val
    of "bf2142_ranked":
      server.bf2142_ranked = parseBool(val)
    of "bf2142_averageping":
      server.bf2142_averageping = parseUInt(val).uint16
    of "bf2142_provider":
      server.bf2142_provider = val
    of "bf2142_ranked_tournament":
      server.bf2142_ranked_tournament = parseBool(val)
    of "bf2142_anticheat":
      server.bf2142_anticheat = parseBool(val)
    of "bf2142_friendlyfire":
      server.bf2142_friendlyfire = parseBool(val)
    of "bf2142_communitylogo_url":
      server.bf2142_communitylogo_url = val
    of "maxplayers":
      server.maxplayers = parseUInt(val).uint8
    of "bf2142_voip":
      server.bf2142_voip = parseBool(val)
    of "bf2142_reservedslots":
      server.bf2142_reservedslots = parseUInt(val).uint8
    of "bf2142_type":
      server.bf2142_type = val
    of "gamename":
      server.gamename = val
    of "bf2142_mapsize":
      server.bf2142_mapsize = parseUInt(val).uint8
    of "bf2142_scorelimit":
      server.bf2142_scorelimit = parseUInt(val)
    of "bf2142_allow_spectators":
      server.bf2142_allow_spectators = parseBool(val)
    of "gamever":
      server.gamever = val
    of "bf2142_tkmode":
      server.bf2142_tkmode = val
    of "bf2142_autobalanced":
      server.bf2142_autobalanced = parseBool(val)
    of "bf2142_team1":
      server.bf2142_team1 = val
    of "bf2142_autorec":
      server.bf2142_autorec = parseBool(val)
    of "bf2142_sponsorlogo_url":
      server.bf2142_sponsorlogo_url = val
    of "timelimit":
      server.timelimit = parseUInt(val).uint16
    of "hostname":
      server.hostname = val
    of "roundtime":
      server.roundtime = parseUInt(val).uint8
    of "bf2142_startdelay":
      server.bf2142_startdelay = parseUInt(val).uint8

    if data[pos - 1 .. pos] == "\0\0": # pos - 1 because parseCStr skips the first 0x0 byte
      pos.inc(1)
      return


proc parseList[T](data: string, pos: var int): seq[T] =
  if pos + 2 > data.high: # Invalid data, the sserver just cutted of after 1400 bytes (packet end)
    pos = data.len
    return
  if data[pos .. pos + 2] == "\0\0\0": # Empty list
    pos.inc(3)
    return
  pos.inc(2) # Skip 00 byte and offset # TODO: offset (currently ignored because the last entry isn't added)
  while true:
    let val: string = data.parseCstr(pos)
    if pos == data.len:
      return

    when T is string:
      result.add(val)
    elif T is int8 or T is int16 or T is int32:
      result.add(T(parseInt(val)))
    elif T is uint8 or T is uint16 or T is uint32:
      result.add(T(parseUInt(val)))

    if data[pos - 1 .. pos] == "\0\0":
      pos.inc()
      return


proc parseGSpyPlayer*(data: string, player: var GSpyPlayer, pos: var int) =
  while true:
    var key: string = data.parseCStr(pos)
    pos.dec() # Because parseCStr skips the 0x0 byte
    if data.len == pos:
      return
    case key:
    of "deaths_":
      player.deaths.add(parseList[uint16](data, pos))
    of "pid_":
      player.pid.add(parseList[uint32](data, pos))
    of "score_":
      player.score.add(parseList[int16](data, pos))
    of "skill_":
      player.skill.add(parseList[uint16](data, pos))
    of "team_":
      player.team.add(parseList[uint8](data, pos))
    of "ping_":
      player.ping.add(parseList[uint16](data, pos))
    of "player_":
      player.player.add(parseList[string](data, pos))
    # of "AIBot_": # Battlefield 2
    else:
      discard parseList[string](data, pos) # Parse list if the key is not known

    if data.len == pos: # TODO: This check is done twice. Before parseList and here
      return
    if data[pos - 2 .. pos] == "\0\0\0":
      pos.inc()
      return


proc parseGSpyTeam*(data: string, team: var GSpyTeam, pos: var int) =
  while true:
    var key: string = data.parseCStr(pos)
    pos.dec() # Because parseCStr skips the 0x0 byte
    if data.len == pos:
      return
    case key:
    of "team_t":
      team.team_t.add(parseList[string](data, pos))
    of "score_t":
      team.score_t.add(parseList[uint16](data, pos))
    else:
      discard parseList[string](data, pos) # Parse list if the key is not known
    if data.len == pos: # TODO: This check is done twice. Before parseList and here
      return
    if data[pos - 2 .. pos] == "\0\0\0":
      pos.inc()
      return


proc parseProtocol00B*(data: string, gspy: var GSpy, pos: var int) =
  if pos >= data.len:
    return

  case data[pos]:
  of char(0x0): # Server
    # echo "SERVER"
    pos.inc() # Skip server identifier byte (0x0)
    parseGSpyServer(data, gspy.server, pos)
  of char(0x1): # Player
    # echo "PLAYER"
    pos.inc() # Skip player identifier byte (0x1)
    parseGSpyPlayer(data, gspy.player, pos)
  of char(0x2): # Team
    # echo "TEAM"
    pos.inc() # Skip team identifier byte (0x2)
    parseGSpyTeam(data, gspy.team, pos)
  else:
    discard

  parseProtocol00B(data, gspy, pos)


proc parseProtocol00C*(data: string, gspyServer: var GSpyServer, bytes: Protocol00CBytes) =
  var pos: int = 0
  for b in bytes:
    let val: string = data.parseCstr(pos)

    case b:
    of Hostname:
      gspyServer.hostname = val
    of Gamename:
      gspyServer.gamename = val
    of Gamever:
      gspyServer.gamever = val
    of Hostport:
      gspyServer.hostport = parseUInt(val).uint16
    of Mapname:
      gspyServer.mapname = val
    of Gametype:
      gspyServer.gametype = val
    of Gamevariant:
      gspyServer.gamevariant = val
    of Numplayers:
      gspyServer.numplayers = parseUInt(val).uint8
    of Maxplayers:
      gspyServer.maxplayers = parseUInt(val).uint8
    of Gamemode:
      gspyServer.gamemode = val
    of Timelimit:
      gspyServer.timelimit = parseUInt(val).uint16
    of Roundtime:
      gspyServer.roundtime = parseUInt(val).uint8
    else:
      discard # Other bytes are unknown

