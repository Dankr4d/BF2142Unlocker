import ../protocol/gspy
import asyncdispatch, net
import options
export gspy


proc queryAll*(address: IpAddress, port: Port, timeout: int = -1): GSpy =
  var responses: seq[Response00B]
  responses = waitFor sendProtocol00B(address, port, newProtocol00B(), timeout)
  if responses.len == 0:
    return

  var pos: int
  for idx, response00B in responses:
    pos = 0
    try:
      parseProtocol00B(response00B.data, result, pos)
    except:
      continue # TODO: Parser shouldn't fail


proc queryServer*(address: IpAddress, port: Port, timeout: int = -1, bytes: Protocol00CBytes = Protocol00CBytesAll): Option[GSpyServer] =
  # WARNING: `queryServer` queries server information via Protocol00C which is missing some
  #          some informations/data. Therefore the GSpyServer object is holey.
  var response00COpt: Option[Response00C]
  var protocol00C: Protocol00C = newProtocol00C(bytes)
  response00COpt = waitFor sendProtocol00C(address, port, protocol00C, timeout)
  if isNone(response00COpt):
    return none(GSpyServer)
  var gspyServer: GSpyServer
  try:
    parseProtocol00C(get(response00COpt).data, gspyServer, bytes)
  except:
    return none(GSpyServer) # TODO: Parser shouldn't fail
  return some(gspyServer)


iterator queryServers*(servers: seq[tuple[address: IpAddress, port: Port]], timeout: int = -1, bytes: Protocol00CBytes = Protocol00CBytesAll): tuple[address: IpAddress, port: Port, gspyServer: GSpyServer] =
  # WARNING: `queryServers` queries server information via Protocol00C which is missing some
  #          some informations/data. Therefore the GSpyServer object is holey.
  var responsesOpt: seq[Option[Response00C]]
  var responsesFuture: seq[tuple[server: tuple[address: IpAddress, port: Port], future: Future[Option[Response00C]]]]

  var protocol00C: Protocol00C
  for server in servers:
    protocol00C = newProtocol00C(bytes)
    responsesFuture.add((server, sendProtocol00C(server.address, server.port, protocol00C, timeout)))

  while responsesFuture.len > 0:
    var responsesToDelete: seq[int]
    for idx, (server, responseFuture) in responsesFuture:
      if not responseFuture.finished:
        continue
      responsesToDelete.add(idx)

      var gspyServer: GSpyServer
      var response00COpt: Option[Response00C] = waitFor responseFuture
      var response00C: Response00C
      if response00COpt.isNone:
        when not defined(release):
          echo "Server (GSPY) not responding: ", server.address, ":", server.port
        continue # Server was not reachable
      response00C = get(response00COpt)
      try:
        parseProtocol00C(response00C.data, gspyServer, bytes)
      except:
        continue # TODO: Parser shouldn't fail
      when not defined(release):
        echo "Server (GSPY): ", gspyServer.hostname
      yield (
        address: server.address,
        port: server.port,
        gspyServer: gspyServer
      )

    for idx, idxToRemove in responsesToDelete:
      responsesFuture.delete(idxToRemove - idx)

    waitFor sleepAsync 50



when isMainModule:
  # echo queryAll(parseIpAddress("185.189.255.6"), Port(29987))
  # echo queryAll(parseIpAddress("95.172.92.116"), Port(29900))
  # echo queryAll(parseIpAddress("162.248.88.201"), Port(29900))
  # echo queryAll(parseIpAddress("185.107.96.106"), Port(29900))
  # echo queryAll(parseIpAddress("138.197.130.124"), Port(29900))

  # echo queryServer(parseIpAddress("185.189.255.6"), Port(29987))
  # echo queryServer(parseIpAddress("185.189.255.6"), Port(29987), 0, toOrderedSet([Hostname, Numplayers, Maxplayers, Mapname, Gametype, Gamevariant, Hostport]))

  var addresses = @[
    (parseIpAddress("185.189.255.6"), Port(29987)),
    (parseIpAddress("95.172.92.116"), Port(29900)),
    (parseIpAddress("162.248.88.201"), Port(29900)),
    (parseIpAddress("185.107.96.106"), Port(29900)),
    (parseIpAddress("138.197.130.124"), Port(29900)),
  ]
  echo queryServers(addresses, 500)

# TODO: Following Battlefield 2 server added a t char in the end sequence.
#       Instead of \0\0\0 it is \0\0t\0. In the next message it starts with \1team_ (maybe it depends to team, but then it ignores the player byte)
# 0x7f060c19f060"\0hostname\0=F&F= Best Maps !!!\0gamename\0battlefield2\0gamever\01.5.3153-802.0\0mapname\0Strike At Karkand\0gametype\0gpm_cq\0gamevariant\0bf2\0numplayers\020\0maxplayers\064\0gamemode\0openplaying\0password\00\0timelimit\00\0roundtime\09999\0hostport\016567\0bf2_dedicated\01\0bf2_ranked\01\0bf2_anticheat\01\0bf2_os\0linux-64\0bf2_autorec\00\0bf2_d_idx\0http://\0bf2_d_dl\0http://\0bf2_voip\01\0bf2_autobalanced\01\0bf2_friendlyfire\00\0bf2_tkmode\0No Punish\0bf2_startdelay\015\0bf2_spawntime\015.000000\0bf2_sponsortext\0\0bf2_sponsorlogo_url\0https://shutterstock.7eer.net/c/2204609/560528/1305?u=https%3A%2F%2Fwww.shutterstock.com%2Fimage-photo%2F1056664877\0bf2_communitylogo_url\0https://shutterstock.7eer.net/c/2204609/560528/1305?u=https%3A%2F%2Fwww.shutterstock.com%2Fimage-photo%2F1056664877\0bf2_scorelimit\00\0bf2_ticketratio\0100\0bf2_teamratio\0100.000000\0bf2_team1\0MEC\0bf2_team2\0US\0bf2_bots\00\0bf2_pure\01\0bf2_mapsize\064\0bf2_globalunlocks\01\0bf2_fps\036.000000\0bf2_plasma\00\0bf2_reservedslots\00\0bf2_coopbotratio\0\0bf2_coopbotcount\0\0bf2_coopbotdiff\0\0bf2_novehicles\00\0\0\1player_\0\0 Happy Hero\0 Pistol Perfection\0 King Killer\0 Collateral Damage\0 The Rifleman\0 Ace Aim\0 KnifeYou1ce\0 Miami Master\0 Digital Warrior\0 Steel Soldier\0 Defrib Devil\0 Sick Skillz\0 Master Medic\0 WatchYour6\0 Head-Hunter\0 TopDog\0 The Camper\0 Pathfinder\0 Peaceful Terrorist\0\0score_\0\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\0\0ping_\0\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\0\0t\0"
# 0x7f060c19e1c0"\1team_\0\01\02\01\02\01\02\01\01\02\02\02\01\02\01\02\02\01\02\01\0\0deaths_\0\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\0\0pid_\0\0114\0115\0111\0136\0117\0139\0112\0134\0109\0137\0110\0135\0116\0141\0150\0118\0140\0154\0113\0\0skill_\0\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\0\0AIBot_\0\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\0\0\0\2team_t\0\0MEC\0US\0\0score_t\0\00\00\0\0\0"
