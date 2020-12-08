import gintro/[gtk, glib, gobject, gdk, cairo, gdkpixbuf]
import gintro/gio except ListStore
import os
import net # Requierd for ip parsing and type
import osproc # Requierd to start the process
import strutils
import strformat # Required for fmt macro
import xmlparser, xmltree # Requierd for map infos (and available modes for maps)
when defined(linux):
  import posix # Requierd for getlogin and killProcess
  import gintro/gmodule # Required to automatically bind signals on linux
elif defined(windows):
  import winim
  import docpath
  import sendmsg # Required for to write to bf2142 game server
import parsecfg # Config
import md5 # Requierd to check if the current BF2142.exe is the original BF2142.exe
import times # Requierd for rudimentary level backup with epochtime suffix
import localaddrs, checkserver # Required to get all local adresses and check if servers are reachable
import signal # Required to use the custom signal pragma (checks windowShown flag and returns if false)
import resolutions # Required to read out all possible resolutions
import patcher # Required to patch BF2142 with the login/unlock server address. Also required to patch the game server
import cdkey # Required to set an empty cd key if cd key not exists.
import checkpermission # Required to check write permission before patching client
import math # Required for runtime configuration
import gsapi # Required to parse data out of bf2142 game server # TODO: Make this work for linux too (stdoutreader for linux required)
import options # Required for error/exception handling
import sets # Required for queryServer for the optional bytes parameter from gspy module
import sequtils # Required for filter proc (filtering gamespy address port list)
import fesl_client # Required for getSoldiers proc (login and returning soldiers or error code)
import uri # Required for parseUri # TODO: REMOVE (see server.ini)
import strhider # Simple string hide functionality with xor and base64 to hide username/password saved in logins.ini
import masterserver, gspy # Required to query gamespy server and query each gamespy server (server listing)
import streams # Required to load server.ini (which has unknown sections)
import regex # Required to validate soldier name
import tables # Required to store ServerConfig temporary for faster server list quering (see threadUpdateServerProc)

when defined(linux):
  import gintro/vte # Required for terminal (linux only feature or currently only available on linux)
elif defined(windows):
  import streams # Required to read from process stream (login/unlock server)
  import getprocessbyname # Required to get pid from forked process
  import stdoutreader # Required for read stdoutput from another process
  import gethwndbypid # Required to get window handle from pid
  type
    Terminal = ref object of ScrolledWindow # Have a look at the linux only vte import above
  ## Terminal newTerminal and related helper procs
  proc newTerminal(): Terminal =
    var textView = newTextView()
    textView.wrapMode = WrapMode.wordChar
    textView.editable = false
    var scrolledWindow = newScrolledWindow(textView.getHadjustment(), textView.getVadjustment())
    scrolledWindow.propagateNaturalHeight = true
    scrolledWindow.add(textView)
    scrolledWindow.styleContext.addClass("terminal")
    result = cast[Terminal](scrolledWindow)
  proc textView(terminal: Terminal): TextView =
    return cast[TextView](terminal.getChild())
  proc buffer(terminal: Terminal): TextBuffer =
    return terminal.textView.getBuffer()
  proc `text=`(terminal: Terminal, text: string) =
    terminal.buffer.setText(text, text.len)
  proc text(terminal: Terminal): string =
    var startIter: TextIter
    var endIter: TextIter
    terminal.buffer.getStartIter(startIter)
    terminal.buffer.getEndIter(endIter)
    return terminal.buffer.getText(startIter, endIter, true)
  proc visible(terminal: Terminal): bool =
    return terminal.textView.visible
  proc `visible=`(terminal: Terminal, visible: bool) =
    cast[ScrolledWindow](terminal).visible = visible
    terminal.textView.visible = visible
  #

# Create precompiled resource file
when defined(windows):
  static:
    discard staticExec("windres.exe BF2142Unlocker.rc -O coff -o BF2142Unlocker.res")

var bf2142Path: string
var bf2142ServerPath: string
var documentsPath: string
var bf2142ProfilePath: string
var bf2142Profile0001Path: string

const VERSION: string = static:
  var raw: string = staticRead("BF2142Unlocker.nimble")
  var posVersionStart: int = raw.find("version")
  var posQuoteStart: int = raw.find('"', posVersionStart)
  var posQuoteEnd: int = raw.find('"', posQuoteStart + 1)
  raw.substr(posQuoteStart + 1, posQuoteEnd - 1)

when defined(linux):
  const BF2142_SRV_EXE_NAME: string = "bf2142"
  const BF2142_SRV_UNLOCKER_EXE_NAME: string = "bf2142Unlocker"
else:
  const BF2142_SRV_EXE_NAME: string = "BF2142_w32ded.exe"
  const BF2142_SRV_UNLOCKER_EXE_NAME: string = "BF2142_w32dedUnlocker.exe"
const BF2142_EXE_NAME: string = "BF2142.exe"
const BF2142_UNLOCKER_EXE_NAME: string = "BF2142Unlocker.exe"
const OPENSPY_DLL_NAME: string = "RendDX9.dll"
const ORIGINAL_RENDDX9_DLL_NAME: string = "RendDX9_ori.dll" # Named by reclamation hub and remaster mod
const FILE_BACKUP_SUFFIX: string = ".original"

const ORIGINAL_CLIENT_MD5_HASH: string = "6ca5c59cd1623b78191e973b3e8088bc"
const OPENSPY_MD5_HASHES: seq[string] = @["c74f5a6b4189767dd82ccfcb13fc23c4", "9c819a18af0e213447b7bb0e4ff41253"]
const ORIGINAL_RENDDX9_MD5_HASH: string = "18a7be5d8761e54d43130b8a2a3078b9"

const
  SETTING_BOT_SKILL: string = "sv.botSkill"
  SETTING_TICKET_RATIO: string = "sv.ticketRatio"
  SETTING_SPAWN_TIME: string = "sv.spawnTime"
  SETTING_ROUNDS_PER_MAP: string = "sv.roundsPerMap"
  SETTING_SOLDIER_FRIENDLY_FIRE: string = "sv.soldierFriendlyFire"
  SETTING_VEHICLE_FRIENDLY_FIRE: string = "sv.vehicleFriendlyFire"
  SETTING_SOLDIER_SPLASH_FRIENDLY_FIRE: string = "sv.soldierSplashFriendlyFire"
  SETTING_VEHICLE_SPLASH_FRIENDLY_FIRE: string = "sv.vehicleSplashFriendlyFire"
  SETTING_TEAM_RATIO: string = "sv.teamRatioPercent"
  SETTING_MAX_PLAYERS: string = "sv.maxPlayers"
  SETTING_PLAYERS_NEEDED_TO_START: string = "sv.numPlayersNeededToStart"
  SETTING_SERVER_IP: string = "sv.serverIP"
  SETTING_INTERNET: string = "sv.internet"
  SETTING_ALLOW_NOSE_CAM: string = "sv.allowNoseCam"

const
  AISETTING_BOTS: string = "aiSettings.setMaxNBots"
  AISETTING_OVERRIDE_MENU_SETTINGS: string = "aiSettings.overrideMenuSettings"
  AISETTING_BOT_SKILL: string = "aiSettings.setBotSkill"
  AISETTING_MAX_BOTS_INCLUDE_HUMANS = "aiSettings.maxBotsIncludeHumans"


var currentModSettingsPath: string
var currentServerSettingsPath: string
var currentMapListPath: string
var currentLevelFolderPath: string
var currentAiSettingsPath: string
var currentLocale: string

var lastGsStatus: GsStatus = None
var termLoginServerPid: int = 0
var termBF2142ServerPid: int = 0


type
  ServerConfig* = object of PatchConfig
    server_name*: string
    game_name*: string
    game_key*: string
    game_str*: string
  Server = object
    name: string
    currentPlayer: uint8
    maxPlayer: uint8
    map: string
    mode: string
    `mod`: string
    ip: IpAddress
    port: Port
    gspyPort: Port
    stellaName: string

var threadUpdateServer: system.Thread[seq[ServerConfig]]
var channelUpdateServer: Channel[seq[tuple[address: IpAddress, port: Port, gspyServer: GSpyServer, serverConfig: ServerConfig]]]
# TODO add a boolean that indicates if the server is refreshing to prevent reloading multiple times by pressing F5 or switching tabs

type
  FeslCommand = enum
    Create
    Login
    AddSoldier
    DelSoldier
  ThreadFeslCreateData = object of RootObj
    stella: string
    username: string
    password: string
    save: bool
  ThreadFeslLoginData = object of RootObj
    stella: string
    username: string
    password: string
    save: bool
    soldier: Option[string]
  ThreadFeslSoldierData = object of RootObj
    soldier: string
  ThreadFeslData = object
    case command: FeslCommand:
    of Create:
      create: ThreadFeslCreateData
    of Login:
      login: ThreadFeslLoginData
    of AddSoldier, DelSoldier:
      soldier: ThreadFeslSoldierData
type
  TimerFeslCreateData = object of ThreadFeslCreateData
  TimerFeslLoginData = object of ThreadFeslLoginData
    soldiers: seq[string]
  TimerFeslSoldierData = object of ThreadFeslSoldierData
    soldiers: seq[string]
  TimerFeslData = object
    case command: FeslCommand:
    of Create:
      create: TimerFeslCreateData
    of Login:
      login: TimerFeslLoginData
    of AddSoldier, DelSoldier:
      soldier: TimerFeslSoldierData
    ex: Option[FeslException]

proc getTimerFeslData(threadData: ThreadFeslData): TimerFeslData =
  case threadData.command:
  of FeslCommand.Create:
    result = TimerFeslData(command: FeslCommand.Create)
    result.create.stella = threadData.create.stella
    result.create.username = threadData.create.username
    result.create.password = threadData.create.password
    result.create.save = threadData.create.save
  of FeslCommand.Login:
    result = TimerFeslData(command: FeslCommand.Login)
    result.login.stella = threadData.login.stella
    result.login.username = threadData.login.username
    result.login.password = threadData.login.password
    result.login.save = threadData.login.save
    result.login.soldier = threadData.login.soldier
  of FeslCommand.AddSoldier:
    result = TimerFeslData(command: FeslCommand.AddSoldier)
    result.soldier.soldier = threadData.soldier.soldier
  of FeslCommand.DelSoldier:
    result = TimerFeslData(command: FeslCommand.DelSoldier)
    result.soldier.soldier = threadData.soldier.soldier

var threadFesl: system.Thread[void]
var channelFeslThread: Channel[ThreadFeslData]
var channelFeslTimer: Channel[TimerFeslData]


var threadUpdatePlayerList: system.Thread[tuple[gspyIp: IpAddress, gspyPort: Port]]
var channelUpdatePlayerList: Channel[tuple[gspy: GSpy, gspyIp: IpAddress, gspyPort: Port]]
var timerUpdatePlayerListId: int = 0

var isServerSelected: bool = false
var currentServer: Server
var currentServerConfig: ServerConfig
var serverConfigs: seq[ServerConfig] # TODO: Change this to a table and maybe remove server_name attribute from ServerConfig


const
  PROFILE_AUDIO_CON: string = staticRead("profile/Audio.con")
  PROFILE_CONTROLS_CON: string = staticRead("profile/Controls.con")
  PROFILE_GENERAL_CON: string = staticRead("profile/General.con")
  PROFILE_PROFILE_CON: string = staticRead("profile/Profile.con")
  PROFILE_SERVER_SETTINGS_CON: string = staticRead("profile/ServerSettings.con")
  PROFILE_VIDEO_CON: string = staticRead("profile/Video.con")
  GLOBAL_CON: string = staticRead("profile/Global.con")

const
  BLANK_BIK: string = staticRead("blank.bik")
  BLANK_BIK_HASH: string = static: getMd5(BLANK_BIK)

when defined(release):
  const GUI_CSS: string = staticRead("BF2142Unlocker.css")
  const GUI_GLADE: string = staticRead("BF2142Unlocker.glade")
const
  CONFIG_FILE_NAME: string = "config.ini"
  CONFIG_SECTION_GENERAL: string = "General"
  CONFIG_SECTION_SETTINGS: string = "Settings"
  CONFIG_SECTION_UNLOCKS: string = "Unlocks"
  CONFIG_KEY_BF2142_PATH: string = "bf2142_path"
  CONFIG_KEY_BF2142_SERVER_PATH: string = "bf2142_server_path"
  CONFIG_KEY_WINEPREFIX: string = "wineprefix"
  CONFIG_KEY_STARTUP_QUERY: string = "startup_query"
  CONFIG_KEY_PLAYER_NAME: string = "playername"
  CONFIG_KEY_AUTO_JOIN: string = "autojoin"
  CONFIG_KEY_WINDOW_MODE: string = "window_mode"
  CONFIG_KEY_SKIP_MOVIES: string = "skip_movies"
  CONFIG_KEY_UNLOCK_SQUAD_GADGETS: string = "unlock_squad_gadgets"
  CONFIG_KEY_RESOLUTION: string = "resolution"

const
  CONFIG_SERVER_FILE_NAME: string = "server.ini"
  CONFIG_SERVER_KEY_STELLA_PROD: string = "stella_prod"
  CONFIG_SERVER_KEY_STELLA_MS: string = "stella_ms"
  CONFIG_SERVER_KEY_MS: string = "ms"
  CONFIG_SERVER_KEY_AVAILABLE: string = "available"
  CONFIG_SERVER_KEY_MOTD: string = "motd"
  CONFIG_SERVER_KEY_MASTER: string = "master"
  CONFIG_SERVER_KEY_GAMESTATS: string = "gamestats"
  CONFIG_SERVER_KEY_GPCM: string = "gpcm"
  CONFIG_SERVER_KEY_GPSP: string = "gpsp"
  CONFIG_SERVER_KEY_GAME_NAME: string = "game_name"
  CONFIG_SERVER_KEY_GAME_KEY: string = "game_key"
  CONFIG_SERVER_KEY_GAME_STR: string = "game_str"

const
  CONFIG_LOGINS_FILE_NAME: string = "logins.ini"
  CONFIG_LOGINS_KEY_USERNAME: string = "username"
  CONFIG_LOGINS_KEY_PASSWORD: string = "password"
  CONFIG_LOGINS_KEY_SOLDIER: string = "soldier"

# Required, because config loads values into widgets after gui is created,
# but the language must be set before gui init is called.
const LANGUAGE_FILE: string = "lang.txt"
const AVAILABLE_LANGUAGES: seq[string] = @["en_US", "de_DE", "ru_RU"]

const NO_PREVIEW_IMG_PATH: string = "nopreview.png"

var config: Config

### Required vars for signal module
var windowShown: bool = false
var ignoreEvents: bool = false
##

### General controls
var application: Application
var window: ApplicationWindow
var notebook: Notebook
var lblVersion: Label
var cbxLanguages: ComboBox
##
### Join controls
var vboxJoin: Box
var vboxJustPlay: Box
var cbxJoinMods: ComboBox
var lblJoinResolutions: Label
var cbxJoinResolutions: ComboBox
var txtPlayerName: Entry
var txtIpAddress: Entry
var chbtnAutoJoin: CheckButton
var chbtnSkipMovies: CheckButton
var chbtnWindowMode: CheckButton
var btnJoin: Button # TODO: Rename to btnConnect
var btnJustPlay: Button
var btnJustPlayCancel: Button
var termJustPlayServer: Terminal
var dlgCheckServers: Dialog
var btnCheckCancel: Button
var throbberLoginServer: Spinner
var throbberGpcmServer: Spinner
var throbberUnlockServer: Spinner
var imgLoginServer: Image
var imgGpcmServer: Image
var imgUnlockServer: Image
var btnCheckServerCancel: Button
##
### Server list
var overlayServer: Overlay
var spinnerServer: Spinner
var listServer: TreeView
var btnServerListRefresh: Button
var btnServerListPlay: Button
var listPlayerInfo1: TreeView
var spinnerServerPlayerList1: Spinner
var listPlayerInfo2: TreeView
var spinnerServerPlayerList2: Spinner
var lblTeam1: Label
var lblTeam2: Label
var btnServerPlayerListRefresh: Button
var wndLogin: gtk.Window
var spinnerLogin: Spinner
var lblLoginStellaName: Label
var lblLoginGameServerName: Label
var txtLoginUsername: Entry
var txtLoginPassword: Entry
var listLoginSoldiers: TreeView
var spinnerLoginSoldiers: Spinner
var btnLoginCheck: Button
var btnLoginSoldierAdd: Button
var btnLoginSoldierDelete: Button
var chbtnLoginSave: CheckButton
var frameLoginError: Frame
var lblLoginErrorTxn: Label
var lblLoginErrorCode: Label
var lblLoginErrorMsg: Label
var btnLoginCreate: Button
var btnLoginPlay: Button  # TODO: Delete? (uses response id)
var btnLoginCancel: Button # TODO: Delete? (uses response id)
var dlgLoginAddSoldier: Dialog
var txtLoginAddSoldierName: Entry
var btnLoginAddSoldierOk: Button # TODO: Delete? (uses response id)
var btnLoginAddSoldierCancel: Button # TODO: Delete? (uses response id)
##
### Host controls
var vboxHost: Box
var tblHostSettings: Grid
var imgLevelPreview: Image
var cbxHostMods: ComboBox
var cbxGameMode: ComboBox
var sbtnBotSkill: SpinButton
var scaleBotSkill: Scale
var sbtnTicketRatio: SpinButton
var scaleTicketRatio: Scale
var sbtnSpawnTime: SpinButton
var scaleSpawnTime: Scale
var sbtnRoundsPerMap: SpinButton
var scaleRoundsPerMap: Scale
var sbtnBots: SpinButton
var scaleBots: Scale
var sbtnMaxPlayers: SpinButton
var scaleMaxPlayers: Scale
var sbtnPlayersNeededToStart: SpinButton
var scalePlayersNeededToStart: Scale
var chbtnFriendlyFire: CheckButton
var chbtnAllowNoseCam: CheckButton
  # teamratio (also for coop?)
  # autobalance (also for coop?)
var txtHostIpAddress: Entry
var hboxMaps: Box
var listSelectableMaps: TreeView
var listSelectedMaps: TreeView
var btnAddMap: Button
var btnRemoveMap: Button
var btnMapMoveUp: Button
var btnMapMoveDown: Button
var btnHostLoginServer: Button
var btnHost: Button
var btnHostCancel: Button
var hboxTerms: Box
var termLoginServer: Terminal
var termBF2142Server: Terminal
when defined(linux):
  var swinBF2142Server: ScrolledWindow
##
### Unlock controls
var vboxUnlocks: Box
var chbtnUnlockSquadGadgets: CheckButton
##
### Settings controls
var lblBF2142Path: Label
var txtBF2142Path: Entry
var btnBF2142Path: Button
var lblBF2142ServerPath: Label
var txtBF2142ServerPath: Entry
var btnBF2142ServerPath: Button
var lblWinePrefix: Label
var btnWinePrefix: Button
var txtWinePrefix: Entry
var lblStartupQuery: Label
var txtStartupQuery: Entry
var btnPatchClientMaps: Button
var btnPatchServerMaps: Button
##

### Exception procs # TODO: Replace tuple results with Option
proc onQuit()

import logging
var logger: FileLogger = newFileLogger("error.log", fmtStr = verboseFmtStr)
addHandler(logger)

proc `$`(ex: ref Exception): string =
  result.add("Exception: \n\t" & $ex.name & "\n")
  result.add("Message: \n\t" & ex.msg.strip() & "\n")
  result.add("Stacktrace: \n")
  for line in splitLines(getStackTrace()):
    result.add("\t" & line & "\n")

proc log(ex: ref Exception) =
  error($ex)

proc show(ex: ref Exception) = # TODO: gintro doesnt wraped messagedialog :/ INFO: https://github.com/StefanSalewski/gintro/issues/35
  var dialog: Dialog = newDialog()
  dialog.title = "ERROR: " & osErrorMsg(osLastError())
  var lblText: Label = newLabel($ex)
  dialog.contentArea.add(lblText)
  var vboxButtons: HBox = newHBox(true, 5)
  dialog.contentArea.add(vboxButtons)
  var btnOk: Button = newButton("Ok")
  vboxButtons.add(btnOk)
  proc onBtnOkClicked(self: Button, dialog: Dialog) =
    dialog.destroy()
  btnOk.connect("clicked", onBtnOkClicked, dialog)
  var btnCloseAll: Button = newButton("Close BF2142Unlocker")
  vboxButtons.add(btnCloseAll)
  proc onBtnCloseAllClicked(self: Button, dialog: Dialog) =
    onQuit()
    quit(0)
  btnCloseAll.connect("clicked", onBtnCloseAllClicked, dialog)
  dialog.contentArea.showAll()
  dialog.setPosition(WindowPosition.center)
  discard dialog.run()
  dialog.destroy()

proc handle(ex: ref Exception) =
  log(ex)
  show(ex)

proc writeFile(filename, content: string): bool =
  try:
    system.writeFile(filename, content)
    return true
  except system.IOError as ex:
    ex.handle()
    return false

proc readFile(filename: string): Option[TaintedString] =
  try:
    return some(system.readFile(filename))
  except system.IOError as ex:
    ex.handle()
    return none(TaintedString)

proc moveFile(source, dest: string): bool =
  try:
    os.moveFile(source, dest)
    return true
  except OSError as ex:
    ex.handle()
    return false

proc moveDir(source, dest: string): bool =
  try:
    os.moveDir(source, dest)
    return true
  except OSError as ex:
    ex.handle()
    return false

proc copyFile(source, dest: string): bool =
  try:
    os.copyFile(source, dest)
    return true
  except OSError as ex:
    ex.handle()
    return false

proc copyFileWithPermissions(source, dest: string, ignorePermissionErrors = true): bool =
  try:
    os.copyFileWithPermissions(source, dest, ignorePermissionErrors)
    return true
  except OSError as ex:
    ex.handle()
    return false

proc copyDir(source, dest: string): bool =
  try:
    os.copyDir(source, dest)
    return true
  except OSError as ex:
    ex.handle()
    return false

proc removeFile(file: string): bool =
  try:
    os.removeFile(file)
    return true
  except OSError as ex:
    ex.handle()
    return false

proc removeDir(dir: string): bool = # TODO: in newer version, theres also a "checkDir = false" param
  try:
    os.removeDir(dir)
    return true
  except OSError as ex:
    ex.handle()
    return false

proc open(filename: string; mode: FileMode = fmRead; bufSize: int = -1): tuple[opened: bool, file: system.File] =
  try:
    return (true, system.open(filename, mode, bufSize))
  except system.IOError as ex:
    ex.handle()
    return (false, nil)

proc existsOrCreateDir(dir: string): tuple[succeed: bool, exists: bool] =
  try:
    return (true, os.existsOrCreateDir(dir))
  except OSError as ex:
    ex.handle()
    return (false, false)
##

### Fix procs TODO: delete later
const AEGIS_STATION_DESC_MD5_HASH: string = "5709317f425bf7e639eb57842095852e"
const BLOODGULCH_DESC_MD5_HASH: string = "bc08f0711ba9a37a357e196e4167c2b0"
const KILIMANDSCHARO_DESC_MD5_HASH: string = "b165b81cf9949a89924b0f196d0ceec3"
const OMAHA_BEACH_DESC_MD5_HASH: string = "0e28bad9b61224f7889cfffcded81182"
const PANORAMA_DESC_MD5_HASH: string = "5288a6a0dded7df3c60341f5a20a5f0a"
const SEVERNAYA_DESC_MD5_HASH: string = "6de6b4433ecc35dd11467fff3f4e5cc4"
const STREET_DESC_MD5_HASH: string = "d36161b9b4638e315809ba2dd8bf4cdf"

proc removeLine(path: string, val: int): bool =
  var rawOpt: Option[TaintedString] = readFile(path)
  if rawOpt.isNone:
    return false
  var rawLines: seq[string] = rawOpt.get().splitLines()
  rawLines.delete(val - 1)
  return writeFile(path, rawLines.join("\n"))

proc removeChars(path: string, valFrom, valTo: int): bool =
  var rawOpt: Option[TaintedString] = readFile(path)
  if rawOpt.isNone:
    return false
  rawOpt.get().delete(valFrom - 1, valTo - 1)
  return writeFile(path, rawOpt.get())

proc fixMapDesc(path: string): bool =
  var rawOpt: Option[TaintedString] = readFile(path)
  if rawOpt.isNone:
    return false
  var raw: string = rawOpt.get()
  case extractFileName(path).toLower()
  of "aegis_station.desc":
    if getMd5(raw) == AEGIS_STATION_DESC_MD5_HASH:
      return removeChars(path, 1464, 1464) # Fix: Remove char on position 1464
  of "bloodgulch.desc":
    if getMd5(raw) == BLOODGULCH_DESC_MD5_HASH:
      return removeLine(path, 20) # Fix: Delete line 20
  of "kilimandscharo.desc":
    if getMd5(raw) == KILIMANDSCHARO_DESC_MD5_HASH:
      return removeLine(path, 7) # Fix: Delete line 7
  of "omaha_beach.desc":
    if getMd5(raw) == OMAHA_BEACH_DESC_MD5_HASH:
      return removeLine(path, 11) # Fix: Delete line 11
  of "panorama.desc":
    if getMd5(raw) == PANORAMA_DESC_MD5_HASH:
      return removeLine(path, 14) # Fix: Delete line 14
  of "severnaya.desc":
    if getMd5(raw) == SEVERNAYA_DESC_MD5_HASH:
      return removeLine(path, 16) # Fix: Delete line 16
  of "street.desc":
    if getMd5(raw) == STREET_DESC_MD5_HASH:
      return removeLine(path, 9) # Fix: Delete line 9
  return false
##

### Helper procs
proc isAlphaNumeric(str: string): bool =
  for ch in str:
    if not isAlphaNumeric(ch):
      return false
  return true

proc validateSoldier(soldier: string): bool =
  let soldierRegex: regex.Regex = re"""^([[:alnum:]\^\$%&/\(\)\{\}\[\]=\?<>_\.@]{3}[[:alnum:]\^\$%&/\(\)\{\}\[\]=\?<>_\.@\#\-+]{0,11}|[[:alnum:]\^\$%&/\(\)\{\}\[\]=\?<>_\.@]{0,14})$"""
  return match(soldier, soldierRegex)

proc updateProfilePathes() =
  bf2142ProfilePath = documentsPath / "Battlefield 2142" / "Profiles"
  bf2142Profile0001Path = bf2142ProfilePath / "0001"

proc loadConfig() =
  if not fileExists(CONFIG_FILE_NAME):
    config = newConfig()
  else:
    config = loadConfig(CONFIG_FILE_NAME)
  bf2142Path = config.getSectionValue(CONFIG_SECTION_SETTINGS, CONFIG_KEY_BF2142_PATH)
  if bf2142Path != "":
    txtBF2142Path.text = bf2142Path
  bf2142ServerPath = config.getSectionValue(CONFIG_SECTION_SETTINGS, CONFIG_KEY_BF2142_SERVER_PATH)
  if bf2142ServerPath != "":
    txtBF2142ServerPath.text = bf2142ServerPath
  txtWinePrefix.text = config.getSectionValue(CONFIG_SECTION_SETTINGS, CONFIG_KEY_WINEPREFIX)
  when defined(linux):
    if txtWinePrefix.text != "":
      documentsPath = txtWinePrefix.text / "drive_c" / "users" / $getlogin() / "My Documents"
  elif defined(windows):
    documentsPath = getDocumentsPath()
  updateProfilePathes()
  when defined(linux):
    txtStartupQuery.text = config.getSectionValue(CONFIG_SECTION_SETTINGS, CONFIG_KEY_STARTUP_QUERY)
    if txtStartupQuery.text == "":
      txtStartupQuery.text = "/usr/bin/wine"
  txtPlayerName.text = config.getSectionValue(CONFIG_SECTION_GENERAL, CONFIG_KEY_PLAYER_NAME)
  if txtPlayerName.text == "":
    txtPlayerName.text = "Player"
  let autoJoinStr = config.getSectionValue(CONFIG_SECTION_GENERAL, CONFIG_KEY_AUTO_JOIN)
  if autoJoinStr != "":
    chbtnAutoJoin.active = autoJoinStr.parseBool()
  else:
    chbtnAutoJoin.active = false
  let skipMoviesStr = config.getSectionValue(CONFIG_SECTION_GENERAL, CONFIG_KEY_SKIP_MOVIES)
  if skipMoviesStr != "":
    chbtnSkipMovies.active = skipMoviesStr.parseBool()
  else:
    chbtnSkipMovies.active = false
  let windowModeStr = config.getSectionValue(CONFIG_SECTION_GENERAL, CONFIG_KEY_WINDOW_MODE)
  if windowModeStr != "":
    chbtnWindowMode.active = windowModeStr.parseBool()
  else:
    chbtnWindowMode.active = false
  let unlockSquadGadgetsStr = config.getSectionValue(CONFIG_SECTION_UNLOCKS, CONFIG_KEY_UNLOCK_SQUAD_GADGETS)
  if unlockSquadGadgetsStr != "":
    chbtnUnlockSquadGadgets.active = unlockSquadGadgetsStr.parseBool()
  else:
    chbtnUnlockSquadGadgets.active = false
  let resolutionStr = config.getSectionValue(CONFIG_SECTION_GENERAL, CONFIG_KEY_RESOLUTION)
  if resolutionStr != "":
    discard cbxJoinResolutions.setActiveId(resolutionStr)

proc backupOpenSpyIfExists() =
  let openspyDllPath: string = bf2142Path / OPENSPY_DLL_NAME
  let originalRendDX9Path: string = bf2142Path / ORIGINAL_RENDDX9_DLL_NAME
  if not fileExists(openspyDllPath) or not fileExists(originalRendDX9Path): # TODO: Inform user if original file could not be found if openspy dll exists
    return
  let openspyDllRawOpt: Option[TaintedString] = readFile(openspyDllPath)
  if openspyDllRawOpt.isNone:
    return
  let originalRendDX9RawOpt: Option[TaintedString] = readFile(originalRendDX9Path)
  if originalRendDX9RawOpt.isNone:
    return
  let openspyMd5Hash: string = getMD5(openspyDllRawOpt.get())
  let originalRendDX9Hash: string = getMD5(originalRendDX9RawOpt.get())
  if openspyMd5Hash in OPENSPY_MD5_HASHES and originalRendDX9Hash == ORIGINAL_RENDDX9_MD5_HASH:
    echo "Found openspy dll (" & OPENSPY_DLL_NAME & "). Creating a backup and restoring original file!"
    if not copyFile(openspyDllPath, openspyDllPath & FILE_BACKUP_SUFFIX):
      return
    if not copyFile(originalRendDX9Path, openspyDllPath):
      return

proc newInfoDialog(title, text: string) = # TODO: gintro doesnt wraped messagedialog :/ INFO: https://github.com/StefanSalewski/gintro/issues/35
  var dialog: Dialog = newDialog()
  dialog.title = title
  var lblText: Label = newLabel(text)
  dialog.contentArea.add(lblText)
  var btnOk: Button = newButton("OK")
  dialog.contentArea.add(btnOk)
  btnOk.halign = Align.center
  proc onBtnOkClicked(self: Button, dialog: Dialog) =
    dialog.destroy()
  btnOk.connect("clicked", onBtnOkClicked, dialog)
  dialog.contentArea.showAll()
  dialog.setPosition(WindowPosition.center)
  discard dialog.run()
  dialog.destroy()

proc restoreOpenSpyIfExists() =
  let openspyDllBackupPath: string = bf2142Path / OPENSPY_DLL_NAME & FILE_BACKUP_SUFFIX
  let openspyDllRestorePath: string = bf2142Path / OPENSPY_DLL_NAME
  if not fileExists(openspyDllBackupPath):
    return
  let openspyMd5RawOpt: Option[TaintedString] = readFile(openspyDllBackupPath)
  if openspyMd5RawOpt.isNone:
    return
  let openspyMd5Hash: string = getMD5(openspyMd5RawOpt.get())
  if openspyMd5Hash in OPENSPY_MD5_HASHES:
    echo "Found openspy dll (" & OPENSPY_DLL_NAME & "). Restoring!"
    var tryCnt: int = 0
    while tryCnt < 8:
      try:
        os.copyFile(openspyDllBackupPath, openspyDllRestorePath)
        os.removeFile(openspyDllBackupPath)
        break
      except OSError as ex:
        tryCnt.inc()
        if tryCnt == 8:
          newInfoDialog(
            fmt"Could not restore {OPENSPY_DLL_NAME}",
            fmt"Could not restore {OPENSPY_DLL_NAME}!" & "\n\n" & $ex
          )
          return
        else:
          sleep(500)

proc typeTest(o: gobject.Object; s: string): bool =
  let gt = g_type_from_name(s)
  return g_type_check_instance_is_a(cast[ptr TypeInstance00](o.impl), gt).toBool

proc listStore(o: gobject.Object): gtk.ListStore =
  assert(typeTest(o, "GtkListStore"))
  cast[gtk.ListStore](o)

proc clear(list: TreeView) =
  ignoreEvents = true
  var
    iter: TreeIter
  let store = listStore(list.getModel())
  if not store.getIterFirst(iter):
    ignoreEvents = false
    return
  clear(store)
  ignoreEvents = false

proc appendMap(list: TreeView, mapName, mapMode: string, mapSize: int) =
  var
    valMapName: Value
    valMapMode: Value
    valMapSize: Value
    iter: TreeIter
  let store = listStore(list.getModel())
  discard valMapName.init(g_string_get_type())
  discard valMapMode.init(g_string_get_type())
  discard valMapSize.init(g_int_get_type())
  valMapName.setString(mapName)
  valMapMode.setString(mapMode)
  valMapSize.setInt(mapSize)
  store.append(iter)
  store.setValue(iter, 0, valMapName)
  store.setValue(iter, 1, valMapMode)
  store.setValue(iter, 2, valMapSize)

proc moveSelectedUpDown(list: TreeView, up: bool) =
  var
    listStore: ListStore
    iter: TreeIter
    iter2: TreeIter

  if list.selection.getSelected(listStore, iter) and list.selection.getSelected(listStore, iter2): # TODO: This is imperformant
    if up:
      if listStore.iterPrevious(iter2):
        listStore.moveBefore(iter, iter2)
    else:
      if listStore.iterNext(iter2):
        listStore.moveAfter(iter, iter2)

proc moveSelectedUp(list: TreeView) =
  list.moveSelectedUpDown(up = true)

proc moveSelectedDown(list: TreeView) =
  list.moveSelectedUpDown(up = false)

proc selectedMap(list: TreeView): tuple[mapName, mapMode: string, mapSize: int] =
  var
    valMapName: Value
    valMapMode: Value
    valMapSize: Value
    ls: ListStore
    iter: TreeIter
  let store = listStore(list.getModel())
  if getSelected(list.selection, ls, iter):
    store.getValue(iter, 0, valMapName)
    result.mapName = valMapName.getString()
    store.getValue(iter, 1, valMapMode)
    result.mapMode = valMapMode.getString()
    store.getValue(iter, 2, valMapSize)
    result.mapSize = valMapSize.getInt()

proc selectedServer(list: TreeView): Option[Server] =
  var
    valName, valCurrentPlayer, valMaxPlayer, valMap: Value
    valMode, valMod, valIp, valPort, valGSpyPort: Value
    valStellaName: Value
  let store = listStore(list.getModel())
  var iter: TreeIter
  var ls: ListStore

  if not getSelected(list.selection, ls, iter):
    return none(Server)

  store.getValue(iter, 0, valName)
  store.getValue(iter, 1, valCurrentPlayer)
  store.getValue(iter, 2, valMaxPlayer)
  store.getValue(iter, 3, valMap)
  store.getValue(iter, 4, valMode)
  store.getValue(iter, 5, valMod)
  store.getValue(iter, 6, valIp)
  store.getValue(iter, 7, valPort)
  store.getValue(iter, 9, valGSpyPort)
  store.getValue(iter, 8, valStellaName)

  var server: Server
  server.name = valName.getString()
  server.currentPlayer = uint8(valCurrentPlayer.getUint())
  server.maxPlayer = uint8(valMaxPlayer.getUint())
  server.map = valMap.getString()
  server.mode = valMode.getString()
  server.`mod` = valMod.getString()
  server.ip = parseIpAddress(valIp.getString())
  server.port = Port(valPort.getUint())
  server.gspyPort = Port(valGSpyPort.getUint())
  server.stellaName = valStellaName.getString()

  return some(server)

proc `selectServer=`(list: TreeView, server: Server) =
  var iter: TreeIter
  let store = listStore(list.getModel())
  var whileCond: bool = store.getIterFirst(iter)
  while whileCond:
    var
      valIp: Value
      valPort: Value
    store.getValue(iter, 6, valIp)
    store.getValue(iter, 7, valPort)
    if parseIpAddress(valIp.getString()) == server.ip and Port(valPort.getUint()) == server.port:
      list.selection.selectIter(iter)
      list.scrollToCell(store.getPath(iter), nil, false, 0.0, 0.0)
      return
    whileCond = store.iterNext(iter)
  # TODO: Raise exception if server doesn't exists


proc selectedSoldier(list: TreeView): Option[string] =
  var
    valSoldier: Value
    ls: ListStore
    iter: TreeIter
  let store = listStore(list.getModel())
  if getSelected(list.selection, ls, iter):
    store.getValue(iter, 0, valSoldier)
    return some(valSoldier.getString())
  none(string)

proc `selectedSoldier=`(list: TreeView, soldier: string) =
  ignoreEvents = true
  var iter: TreeIter
  let store = listStore(list.getModel())
  var whileCond: bool = store.getIterFirst(iter)
  while whileCond:
    var valSoldier: Value
    store.getValue(iter, 0, valSoldier)
    if valSoldier.getString() == soldier:
      list.selection.selectIter(iter)
      list.scrollToCell(store.getPath(iter), nil, false, 0.0, 0.0)
      ignoreEvents = false
      return
    whileCond = store.iterNext(iter)
  ignoreEvents = false
  # TODO: Raise exception if soldier doesn't exists

proc `soldiers=`(list: TreeView, soldiers: seq[string]) =
  ignoreEvents = true
  list.clear()
  var
    valSoldier: Value
    iter: TreeIter
  let store = listStore(list.getModel())
  discard valSoldier.init(g_string_get_type())
  for soldier in soldiers:
    valSoldier.setString(soldier)
    store.append(iter)
    store.setValue(iter, 0, valSoldier)
  ignoreEvents = false

proc hasEntries(treeView: TreeView): bool =
  var
    iter: TreeIter
  let store: ListStore = listStore(treeView.getModel())
  return store.getIterFirst(iter)

proc update(treeView: TreeView, gsdata: GsData) =
  var
    iter: TreeIter
  let store: ListStore = listStore(treeView.getModel())
  if not store.getIterFirst(iter):
    return
  var doIter: bool = true
  while doIter:
    var
      valMapName: Value
      valMapMode: Value
      valMapSize: Value
      valBackgroundColor: Value
    store.getValue(iter, 0, valMapName)
    store.getValue(iter, 1, valMapMode)
    store.getValue(iter, 2, valMapSize)
    store.getValue(iter, 3, valBackgroundColor)
    if valMapName.getString() ==  $gsdata.mapName and $valMapMode.getString() == $gsdata.mapMode and
    valMapSize.getInt() == gsdata.mapSize: # Current map. # TODO: This needs to be checked (get index from gs)
      var color: string
      case gsdata.status
      of Pregame:
        color = "Yellow"
      of Playing:
        color = "Green"
      of Endgame:
        color = "Red"
      else:
        discard
      valBackgroundColor.setString(color)
      store.setValue(iter, 3, valBackgroundColor)
    elif valBackgroundColor.getString() != "":
        valBackgroundColor.setString("")
        store.setValue(iter, 3, valBackgroundColor)
    doIter = store.iterNext(iter)

proc updateLevelPreview(mapName, mapMode: string, mapSize: int) =
  var imgPath: string
  imgPath = currentLevelFolderPath / mapName / "info" / mapMode & "_" & $mapSize & "_menumap.png" # TODO: Use fmt
  if fileExists(imgPath):
    var pixbuf = newPixbufFromFile(imgPath)
    pixbuf = pixbuf.scaleSimple(478, 341, InterpType.bilinear) # 478x341 is the default size of BF2142 menumap images
    imgLevelPreview.setFromPixbuf(pixbuf)
  elif fileExists(NO_PREVIEW_IMG_PATH):
    imgLevelPreview.setFromFile(NO_PREVIEW_IMG_PATH) # TODO: newPixbufFromBytes
  else:
    imgLevelPreview.clear()

proc updateLevelPreview(treeView: TreeView) =
  var mapName, mapMode: string
  var mapSize: int
  (mapName, mapMode, mapSize) = treeView.selectedMap
  updateLevelPreview(mapName, mapMode, mapSize)

proc selectNext(treeView: TreeView) =
  ignoreEvents = true
  var iter: TreeIter
  var store: ListStore = listStore(treeView.getModel())
  if not treeView.selection.getSelected(store, iter):
    ignoreEvents = false
    return
  if store.iterNext(iter):
    treeView.selection.selectIter(iter)
    treeView.scrollToCell(store.getPath(iter), nil, false, 0.0, 0.0)
  ignoreEvents = false

proc removeSelected(treeView: TreeView) =
  ignoreEvents = true
  var
    ls: ListStore
    iter: TreeIter
  let store = listStore(treeView.getModel())
  if not store.getIterFirst(iter):
      ignoreEvents = false
      return
  if getSelected(treeView.selection, ls, iter):
    discard store.remove(iter)
  ignoreEvents = false

iterator maps(list: TreeView): tuple[mapName, mapMode: string, mapSize: int] =
  var
    model: TreeModel = list.model()
    iter: TreeIter
  var whileCond: bool = model.getIterFirst(iter)
  var result: tuple[mapName, mapMode: string, mapSize: int]
  while whileCond:
    var
      valMapName: Value
      valMapMode: Value
      valMapSize: Value
    model.getValue(iter, 0, valMapName)
    result.mapName = valMapName.getString()
    model.getValue(iter, 1, valMapMode)
    result.mapMode = valMapMode.getString()
    model.getValue(iter, 2, valMapSize)
    result.mapSize = valMapSize.getInt()
    yield result
    whileCond = model.iterNext(iter)

proc loadSelectableMapList() =
  listSelectableMaps.clear()
  var gameMode: string = cbxGameMode.activeId
  var xmlMapInfo: XmlNode
  var invalidXmlFiles: seq[string]
  var descPath: string
  for folder in walkDir(currentLevelFolderPath, true):
    if folder.kind != pcDir:
      continue
    try:
      descPath = currentLevelFolderPath / folder.path / "info" / folder.path & ".desc"
      xmlMapInfo = loadXml(descPath).child("modes")
      for xmlMode in xmlMapInfo.findAll("mode"):
        if xmlMode.attr("type") == gameMode:
          for xmlMapType in xmlMode.findAll("maptype"):
            listSelectableMaps.appendMap(folder.path, gameMode, parseInt(xmlMapType.attr("players")))
          break
    except xmlparser.XmlError:
      invalidXmlFiles.add(descPath)
  var notFixableXmlFiles: seq[string]
  for path in invalidXmlFiles:
    if not fixMapDesc(path):
      notFixableXmlFiles.add(path)
  if invalidXmlFiles.len > 0:
    if notFixableXmlFiles.len == 0:
      loadSelectableMapList() # TODO: Fixed maps are only displayed if there's no non fixable map
    else:
      newInfoDialog("INVALID XML FILES", "Following xml files are invalid and could not be fixed\n" & notFixableXmlFiles.join("\n"))

proc updatePathes() =
  var currentModPath: string = bf2142ServerPath / "mods" / cbxHostMods.activeId
  currentModSettingsPath = currentModPath / "settings"
  currentServerSettingsPath = currentModSettingsPath / "serversettings.con"
  currentMapListPath = currentModSettingsPath / "maplist.con"
  currentLevelFolderPath = currentModPath / "levels"
  currentAiSettingsPath = currentModPath / "ai" / "aidefault.ai"

proc loadSaveServerSettings(save: bool): bool =
  var
    line: string
    serverConfig: string
    setting: string
    value: string
    fileTpl: tuple[opened: bool, file: system.File] = open(currentServerSettingsPath, fmRead)
  if not fileTpl.opened:
    return false

  # Server config
  while fileTpl.file.readLine(line):
    (setting, value) = line.splitWhitespace(maxsplit = 1)
    case setting:
      of SETTING_ROUNDS_PER_MAP:
        if save:
          value = $sbtnRoundsPerMap.value.toInt()
        else:
          sbtnRoundsPerMap.value = value.parseFloat()
      of SETTING_BOT_SKILL:
        if save:
          value = $sbtnBotSkill.value
        else:
          sbtnBotSkill.value = value.parseFloat()
      of SETTING_TICKET_RATIO:
        if save:
          value = $sbtnTicketRatio.value.toInt()
        else:
          sbtnTicketRatio.value = value.parseFloat()
      of SETTING_SPAWN_TIME:
        if save:
          value = $sbtnSpawnTime.value.toInt()
        else:
          sbtnSpawnTime.value = value.parseFloat()
      of SETTING_SOLDIER_FRIENDLY_FIRE,
          SETTING_VEHICLE_FRIENDLY_FIRE,
          SETTING_SOLDIER_SPLASH_FRIENDLY_FIRE,
          SETTING_VEHICLE_SPLASH_FRIENDLY_FIRE:
        if save:
          value = if chbtnFriendlyFire.active: "100" else: "0"
        else:
          chbtnFriendlyFire.active = if value == "100": true else: false
      of SETTING_ALLOW_NOSE_CAM:
        if save:
          value = $chbtnAllowNoseCam.active.int
        else:
          chbtnAllowNoseCam.active = value.parseBool()
      of SETTING_MAX_PLAYERS:
        if save:
          value = $sbtnMaxPlayers.value.toInt()
        else:
          sbtnMaxPlayers.value = value.parseFloat()
      of SETTING_PLAYERS_NEEDED_TO_START:
        if save:
          value = $sbtnPlayersNeededToStart.value.toInt()
        else:
          sbtnPlayersNeededToStart.value = value.parseFloat()
      of SETTING_SERVER_IP:
        if save:
          value = "\"" & txtHostIpAddress.text & "\""
      of SETTING_INTERNET:
        if save:
          value = "0" # TODO: Server crashes when internet is set to 1
      of SETTING_TEAM_RATIO:
        discard # TODO: Implement SETTING_TEAM_RATIO
    if save:
      serverConfig.add(setting & ' ' & value & '\n')
  fileTpl.file.close()
  if save:
    return writeFile(currentServerSettingsPath, serverConfig)
  return true


proc saveServerSettings(): bool =
  return loadSaveServerSettings(save = true)

proc loadServerSettings(): bool =
  return loadSaveServerSettings(save = false)

proc loadSaveAiSettings(save: bool): bool =
  var
    line: string
    aiConfig: string
    inComment: bool = false
    fileTpl: tuple[opened: bool, file: system.File] = open(currentAiSettingsPath, fmRead)
  if not fileTpl.opened:
    return false

  # AI config
  while fileTpl.file.readLine(line):
    if line.startsWith("beginrem"):
      inComment = true
    elif line.startsWith("endrem"):
      inComment = false
      continue
    if inComment:
      continue
    if line.startsWith(AISETTING_BOTS):
      if save:
        line = AISETTING_BOTS & " " & $sbtnBots.value.toInt()
      else:
        sbtnBots.value = line.split(' ')[1].parseFloat()
    elif line.startsWith(AISETTING_OVERRIDE_MENU_SETTINGS):
      if save:
        line = AISETTING_OVERRIDE_MENU_SETTINGS & " 1" # Necessary to change bot amount
    elif line.startsWith(AISETTING_BOT_SKILL):
      # As we added AISETTING_OVERRIDE_MENU_SETTINGS above every ai setting will override our serversettings.
      # So we need to remove every setting that can be done in gui from the ai config.
      line = ""
    elif line.startsWith(AISETTING_MAX_BOTS_INCLUDE_HUMANS):
      if save:
        line = AISETTING_MAX_BOTS_INCLUDE_HUMANS & " 0" # To prevent wrong bot amount configured in gui
    if save:
      aiConfig.add(line & '\n')
  fileTpl.file.close()

  if not aiConfig.contains(AISETTING_OVERRIDE_MENU_SETTINGS): # Requiered to override bot amount
    if save:
      aiConfig.add(AISETTING_OVERRIDE_MENU_SETTINGS & " 1")
  if not aiConfig.contains(AISETTING_MAX_BOTS_INCLUDE_HUMANS):
    if save:
      aiConfig.add(AISETTING_MAX_BOTS_INCLUDE_HUMANS & " 0")

  if save:
    return writeFile(currentAiSettingsPath, aiConfig)
  return true

proc saveAiSettings(): bool =
  return loadSaveAiSettings(save = true)

proc loadAiSettings(): bool =
  return loadSaveAiSettings(save = false)

proc saveMapList(): bool =
  var
    mapListCon: string
    line: string
    fileTpl: tuple[opened: bool, file: system.File] = open(currentMapListPath, fmRead)
  if not fileTpl.opened:
    return false
  while fileTpl.file.readLine(line):
    if line.toLower().startsWith("maplist"):
      continue
    mapListCon.add(line & "\n")
  fileTpl.file.close()
  for map in listSelectedMaps.maps:
    mapListCon.add("mapList.append " & map.mapName & ' ' & map.mapMode & ' ' & $map.mapSize & '\n')
  return writeFile(currentMapListPath, mapListCon)

proc loadMapList(): bool =
  var fileTpl: tuple[opened: bool, file: system.File] = open(currentMapListPath, fmRead)
  if not fileTpl.opened:
    return false
  var line, mapName, mapMode, mapSize: string
  listSelectedMaps.clear()
  while fileTpl.file.readLine(line):
    if not line.toLower().startsWith("maplist"):
      continue
    (mapName, mapMode, mapSize) = line.splitWhitespace()[1..3]
    listSelectedMaps.appendMap(mapName, mapMode, parseInt(mapSize))
  fileTpl.file.close()
  return true

proc checkBF2142ProfileFiles() =
  if bf2142ProfilePath == "":
    raise newException(ValueError, "checkBF2142ProfileFiles - bf2142ProfilePath == \"\"")
  discard existsOrCreateDir(documentsPath  / "Battlefield 2142")
  discard existsOrCreateDir(documentsPath  / "Battlefield 2142" / "Profiles")
  if not existsOrCreateDir(bf2142Profile0001Path).exists:
    if not writeFile(bf2142Profile0001Path / "Audio.con", PROFILE_AUDIO_CON):
      return
    if not writeFile(bf2142Profile0001Path / "Controls.con", PROFILE_CONTROLS_CON):
      return
    if not writeFile(bf2142Profile0001Path / "General.con", PROFILE_GENERAL_CON):
      return
    if not writeFile(bf2142Profile0001Path / "Profile.con", PROFILE_PROFILE_CON):
      return
    if not writeFile(bf2142Profile0001Path / "ServerSettings.con", PROFILE_SERVER_SETTINGS_CON):
      return
    if not writeFile(bf2142Profile0001Path / "Video.con", PROFILE_VIDEO_CON):
      return
  if not fileExists(bf2142ProfilePath / "Global.con"):
    if not writeFile(bf2142ProfilePath / "Global.con", GLOBAL_CON):
      return

proc saveBF2142Profile(username, profile: string) =
  checkBF2142ProfileFiles()

  var profileConPath: string = bf2142Profile0001Path / "Profile.con"
  var globalConPath: string = bf2142ProfilePath / "Global.con"
  var fileTpl: tuple[opened: bool, file: system.File]
  var line, content: string

  # Profile.con
  fileTpl = open(profileConPath, fmRead)
  if not fileTpl.opened:
    return
  while fileTpl.file.readLine(line):
    if line.startsWith("LocalProfile.setEAOnlineMasterAccount"):
      content.add("LocalProfile.setEAOnlineMasterAccount \"" & username & "\"\n")
    elif line.startsWith("LocalProfile.setEAOnlineSubAccount"):
      content.add("LocalProfile.setEAOnlineSubAccount \"" & profile & "\"\n")
    else:
      content.add(line & '\n')
  fileTpl.file.close()
  discard writeFile(profileConPath, content)

  content = ""

  # Global.con
  fileTpl = open(globalConPath, fmRead)
  if not fileTpl.opened:
    return
  while fileTpl.file.readLine(line):
    if line.startsWith("GlobalSettings.setDefaultUser"):
      content.add("GlobalSettings.setDefaultUser \"0001\"\n")
    elif line.startsWith("GlobalSettings.setLastOnlineUser"):
      content.add("GlobalSettings.setLastOnlineUser \"" & username & "\"\n")
    else:
      content.add(line & '\n')
  fileTpl.file.close()
  discard writeFile(globalConPath, content)

proc loadJoinMods() =
  var valMod: Value
  discard valMod.init(g_string_get_type())
  var iter: TreeIter
  let store = listStore(cbxJoinMods.getModel())
  store.clear()
  if bf2142Path != "":
    for folder in walkDir(bf2142Path / "mods", true):
      if folder.kind == pcDir:
        valMod.setString(folder.path)
        store.append(iter)
        store.setValue(iter, 0, valMod)
        store.setValue(iter, 1, valMod)
  discard cbxJoinMods.setActiveId("bf2142")

proc loadJoinResolutions() =
  var valResolution: Value
  var valWidth: Value
  var valHeight: Value
  discard valResolution.init(g_string_get_type())
  discard valWidth.init(g_uint_get_type())
  discard valHeight.init(g_uint_get_type())
  var iter: TreeIter
  let store = listStore(cbxJoinResolutions.getModel())
  store.clear()
  var idx: int = 0
  for resolution in getAvailableResolutions():
    valResolution.setString($resolution.width & "x" & $resolution.height)
    valWidth.setUint(cast[int](resolution.width))
    valHeight.setUint(cast[int](resolution.height))
    store.append(iter)
    store.setValue(iter, 0, valResolution)
    store.setValue(iter, 1, valResolution)
    store.setValue(iter, 2, valWidth)
    store.setValue(iter, 3, valHeight)
    idx.inc()
  cbxJoinResolutions.setActive(0)

proc getSelectedResolution(): tuple[width, height: uint16] =
  var iter: TreeIter
  let store = listStore(cbxJoinResolutions.getModel())
  discard cbxJoinResolutions.getActiveIter(iter)
  var valWidth: Value
  var valHeight: Value
  store.getValue(iter, 2, valWidth)
  store.getValue(iter, 3, valHeight)
  return (cast[uint16](valWidth.getUint()), cast[uint16](valHeight.getUint()))

proc loadHostMods() =
  var valMod: Value
  discard valMod.init(g_string_get_type())
  var iter: TreeIter
  let store = listStore(cbxHostMods.getModel())
  store.clear()
  if bf2142ServerPath != "":
    for folder in walkDir(bf2142ServerPath / "mods", true):
      if folder.kind == pcDir:
        valMod.setString(folder.path)
        store.append(iter)
        store.setValue(iter, 0, valMod)
        store.setValue(iter, 1, valMod)
  discard cbxHostMods.setActiveId("bf2142")

proc applyHostRunningSensitivity(running: bool, bf2142ServerInvisible: bool = false) =
  # tblHostSettings.sensitive = not running
  # hboxMaps.sensitive = not running
  btnHostLoginServer.visible = not running
  btnHost.visible = not running
  btnHostCancel.visible = running
  hboxTerms.visible = running
  termLoginServer.visible = running
  if bf2142ServerInvisible:
    when defined(windows):
      termBF2142Server.visible = false
    elif defined(linux):
      swinBF2142Server.visible = false
  else:
    when defined(windows):
      termBF2142Server.visible = running
    elif defined(linux):
      swinBF2142Server.visible = running

proc applyJustPlayRunningSensitivity(running: bool) =
  termJustPlayServer.visible = running
  btnJustPlay.visible = not running
  btnJustPlayCancel.visible = running

proc enableDisableIntroMovies(path: string, enable: bool): bool =
  var moviePathSplit: tuple[dir, name, ext: string]
  for moviePath in walkDir(path):
    if moviePath.kind != pcFile:
      continue
    moviePathSplit = splitFile(moviePath.path)
    if moviePathSplit.name == "titan_tutorial":
      continue
    if enable:
      if moviePathSplit.ext == ".bik":
        if moviePathSplit.name == "Dice":
          # Fixes game crashes on pressing alt+tab when playing online.
          # https://github.com/Dankr4d/BF2142Unlocker/issues/42
          var diceBikRawOpt: Option[TaintedString] = readFile(moviePath.path)
          if diceBikRawOpt.isNone:
            return false
          if getMd5(diceBikRawOpt.get()) == BLANK_BIK_HASH:
            continue
          if not moveFile(moviePath.path, moviePathSplit.dir / moviePathSplit.name & FILE_BACKUP_SUFFIX):
            return false
          if not writeFile(moviePath.path, BLANK_BIK):
            return false
        else:
          if not moveFile(moviePath.path, moviePathSplit.dir / moviePathSplit.name & FILE_BACKUP_SUFFIX):
            return false
    else:
      if moviePathSplit.ext == FILE_BACKUP_SUFFIX:
        if moviePathSplit.name == "Dice" and fileExists(moviePathSplit.dir / moviePathSplit.name & ".bik"):
          if not removeFile(moviePathSplit.dir / moviePathSplit.name & ".bik"):
            return false
        if not moveFile(moviePath.path, moviePathSplit.dir / moviePathSplit.name & ".bik"):
          return false
  return true

proc loadServerConfig() =
  var serverConfig: ServerConfig
  var isFirstSection: bool = true
  var f = newFileStream(CONFIG_SERVER_FILE_NAME, fmRead)

  if f == nil:
    return

  var p: CfgParser
  open(p, f, CONFIG_SERVER_FILE_NAME)
  while true:
    var e = next(p)
    case e.kind
    of cfgEof:
      serverConfigs.add(serverConfig)
      break
    of cfgSectionStart:   ## a ``[section]`` has been parsed
      echo("new section: " & e.section)
      if isFirstSection:
        isFirstSection = false
      else:
        serverConfigs.add(serverConfig)
        serverConfig = ServerConfig()
      serverConfig.server_name = e.section
    of cfgKeyValuePair:
      case e.key:
      of CONFIG_SERVER_KEY_STELLA_PROD:
        serverConfig.stella_prod = e.value
      of CONFIG_SERVER_KEY_STELLA_MS:
        serverConfig.stella_ms = e.value
      of CONFIG_SERVER_KEY_MS:
        serverConfig.ms = e.value
      of CONFIG_SERVER_KEY_AVAILABLE:
        serverConfig.available = e.value
      of CONFIG_SERVER_KEY_MOTD:
        serverConfig.motd = e.value
      of CONFIG_SERVER_KEY_MASTER:
        serverConfig.master = e.value
      of CONFIG_SERVER_KEY_GAMESTATS:
        serverConfig.gamestats = e.value
      of CONFIG_SERVER_KEY_GPCM:
        serverConfig.gpcm = e.value
      of CONFIG_SERVER_KEY_GPSP:
        serverConfig.gpsp = e.value
      of CONFIG_SERVER_KEY_GAME_NAME:
        serverConfig.game_name = e.value
      of CONFIG_SERVER_KEY_GAME_KEY:
        serverConfig.game_key = e.value
      of CONFIG_SERVER_KEY_GAME_STR:
        serverConfig.game_str = e.value
      # echo("key-value-pair: " & e.key & ": " & e.value)
    of cfgOption:
      echo("command: " & e.key & ": " & e.value)
    of cfgError:
      echo(e.msg)
  close(p)
  echo serverConfigs

proc getLogin(stellaName: string): Option[tuple[username, password: string, soldier: Option[string]]] =
  var config: Config
  if not fileExists(CONFIG_LOGINS_FILE_NAME):
    config = newConfig()
  else:
    config = loadConfig(CONFIG_LOGINS_FILE_NAME)
  let username = showStr(config.getSectionValue(stellaName, CONFIG_LOGINS_KEY_USERNAME))
  let password = showStr(config.getSectionValue(stellaName, CONFIG_LOGINS_KEY_PASSWORD))
  let soldier = showStr(config.getSectionValue(stellaName, CONFIG_LOGINS_KEY_SOLDIER))
  if username != "" and password != "":
    return some((username, password, if soldier.len > 0: some(soldier) else: none(string)))
  return none(tuple[username, password: string, soldier: Option[string]])

proc saveLogin(stellaName, username, password, soldier: string, saveSoldierOnly: bool = false) =
  var config: Config
  if not fileExists(CONFIG_LOGINS_FILE_NAME):
    config = newConfig()
  else:
    config = loadConfig(CONFIG_LOGINS_FILE_NAME)
  if not saveSoldierOnly:
    config.setSectionKey(stellaName, CONFIG_LOGINS_KEY_USERNAME, hideStr(username))
    config.setSectionKey(stellaName, CONFIG_LOGINS_KEY_PASSWORD, hideStr(password))
  config.setSectionKey(stellaName, CONFIG_LOGINS_KEY_SOLDIER, hideStr(soldier))
  config.writeConfig(CONFIG_LOGINS_FILE_NAME)

proc timerUpdatePlayerList(TODO: int): bool =
  if channelUpdatePlayerList.peek() <= 0:
    return SOURCE_CONTINUE

  var gspy: Gspy
  var gspyTpl: tuple[gspy: GSpy, gspyIp: IpAddress, gspyPort: Port]
  var found: bool = false
  while channelUpdatePlayerList.peek() > 0:
    gspyTpl = channelUpdatePlayerList.recv()

    if gspyTpl.gspyIp == currentServer.ip and gspyTpl.gspyPort == currentServer.gspyPort:
      gspy = gspyTpl.gspy
      found = true
  if found == false:
    return SOURCE_CONTINUE

  var
    valPID, valName, valScore, valKills, valDeaths, valPing: Value
    iter: TreeIter
  let storePlayerInfo1: ListStore = listStore(listPlayerInfo1.getModel())
  let storePlayerInfo2: ListStore = listStore(listPlayerInfo2.getModel())
  discard valPID.init(g_uint_get_type())
  discard valName.init(g_string_get_type())
  discard valScore.init(g_int_get_type())
  discard valKills.init(g_uint_get_type())
  discard valDeaths.init(g_uint_get_type())
  discard valPing.init(g_uint_get_type())

  var store: ListStore
  for idx in 0..gspy.player.pid.high:
    if gspy.player.team[idx] == 1:
      store = storePlayerInfo1
    else:
      store = storePlayerInfo2
    valPID.setUint(gspy.player.pid[idx].int) # TODO: setUInt should take an uint param, not int
    valName.setString(gspy.player.player[idx])
    valScore.setInt(gspy.player.score[idx])
    valKills.setUInt(gspy.player.skill[idx].int) # TODO: setUInt should take an uint param, not int
    valDeaths.setUInt(gspy.player.deaths[idx].int) # TODO: setUInt should take an uint param, not int
    valPing.setUInt(gspy.player.ping[idx].int) # TODO: setUInt should take an uint param, not int
    store.append(iter)
    store.setValue(iter, 0, valPID)
    # TODO: Add clan tag column and split first whitespace occurrence
    store.setValue(iter, 1, valName)
    store.setValue(iter, 2, valScore)
    store.setValue(iter, 3, valKills)
    store.setValue(iter, 4, valDeaths)
    store.setValue(iter, 5, valPing)

  lblTeam1.text = gspy.team.team_t[0].toUpper()
  lblTeam2.text = gspy.team.team_t[1].toUpper()

  btnServerPlayerListRefresh.sensitive = true
  spinnerServerPlayerList1.stop()
  spinnerServerPlayerList2.stop()
  timerUpdatePlayerListId = 0

  channelUpdatePlayerList.close()
  return SOURCE_REMOVE

proc threadUpdatePlayerListProc(gspyIpPort: tuple[gspyIp: IpAddress, gspyPort: Port]) =
  let gspy: GSpy = queryAll(gspyIpPort.gspyIP, gspyIpPort.gspyPort)

  channelUpdatePlayerList.send((gspy, gspyIpPort.gspyIp, gspyIpPort.gspyPort))

proc updatePlayerListAsync() =
  listPlayerInfo1.clear()
  listPlayerInfo2.clear()
  spinnerServerPlayerList1.start()
  spinnerServerPlayerList2.start()
  btnServerListPlay.sensitive = true
  btnServerPlayerListRefresh.sensitive = false

  channelUpdatePlayerList = Channel[tuple[gspy: GSpy, gspyIp: IpAddress, gspyPort: Port]]()
  channelUpdatePlayerList.open()

  let TODO: int = 0
  if timerUpdatePlayerListId == 0:
    timerUpdatePlayerListId = int(timeoutAdd(250, timerUpdatePlayerList, TODO))

  threadUpdatePlayerList.createThread(threadUpdatePlayerListProc, (currentServer.ip, currentServer.gspyPort))

proc timerUpdateServer(TODO: int): bool =
  var data: tuple[dataAvailable: bool, msg: seq[tuple[address: IpAddress, port: Port, gspyServer: GSpyServer, serverConfig: ServerConfig]]] = channelUpdateServer.tryRecv()
  if not data.dataAvailable:
    return SOURCE_CONTINUE

  var
    valName, valCurrentPlayer, valMaxPlayer, valMap: Value
    valMode, valMod, valIp, valPort, valGSpyPort: Value
    valStellaName: Value
    iter: TreeIter
  let store = listStore(listServer.getModel())
  discard valName.init(g_string_get_type())
  discard valCurrentPlayer.init(g_uint_get_type())
  discard valMaxPlayer.init(g_uint_get_type())
  discard valMap.init(g_string_get_type())
  discard valMode.init(g_string_get_type())
  discard valMod.init(g_string_get_type())
  discard valIp.init(g_string_get_type())
  discard valPort.init(g_uint_get_type())
  discard valGSpyPort.init(g_uint_get_type())
  discard valStellaName.init(g_string_get_type())

  for server in data.msg:
    valName.setString(server.gspyServer.hostname)
    valCurrentPlayer.setUInt(server.gspyServer.numplayers.int) # TODO: setUInt should take an uint param, not int
    valMaxPlayer.setUInt(server.gspyServer.maxplayers.int) # TODO: setUInt should take an uint param, not int
    valMap.setString(server.gspyServer.mapname)
    valMode.setString(server.gspyServer.gametype)
    valMod.setString(server.gspyServer.gamevariant)
    valIp.setString($server.address)
    valPort.setUInt(server.gspyServer.hostport.int) # TODO: setUInt should take an uint param, not int
    valGSpyPort.setUInt(server.port.int) # TODO: setUInt should take an uint param, not int
    valStellaName.setString(server.serverConfig.server_name)
    store.append(iter)
    store.setValue(iter, 0, valName)
    store.setValue(iter, 1, valCurrentPlayer)
    store.setValue(iter, 2, valMaxPlayer)
    store.setValue(iter, 3, valMap)
    store.setValue(iter, 4, valMode)
    store.setValue(iter, 5, valMod)
    store.setValue(iter, 6, valIp)
    store.setValue(iter, 7, valPort)
    store.setValue(iter, 9, valGSpyPort)
    store.setValue(iter, 8, valStellaName)

  spinnerServer.stop()
  spinnerServerPlayerList1.stop()
  spinnerServerPlayerList2.stop()
  btnServerListRefresh.sensitive = true
  if isServerSelected:
    # TODO: Maybe we can select the first server then this global var is obsolet.
    #       Options would be also a possibility but then we need to call get every currentServer access
    listServer.selectServer = currentServer
    btnServerListPlay.sensitive = true
    btnServerPlayerListRefresh.sensitive = true
    updatePlayerListAsync()

  channelUpdateServer.close()
  return SOURCE_REMOVE

proc threadUpdateServerProc(serverConfigs: seq[ServerConfig]) {.thread.} =
  var gslist: seq[tuple[address: IpAddress, port: Port]]
  var gslistTmp: seq[tuple[address: IpAddress, port: Port]]
  var serverConfigsTbl: tables.Table[string, ServerConfig] = initTable[string, ServerConfig]()
  var servers: seq[tuple[address: IpAddress, port: Port, gspyServer: GSpyServer, serverConfig: ServerConfig]]
  for idx, serverConfig in serverConfigs:
    # TODO: Querying openspy and novgames master server takes ~500ms
    #       Store game server and implement a "quick refrsh" which queries gamespy server only and not requering master server
    # TODO2: Query master servers async like in `queryServers` proc
    gslistTmp = queryGameServerList(serverConfig.stella_ms, Port(28910), serverConfig.game_name, serverConfig.game_key, serverConfig.game_str)
    gslistTmp = filter(gslistTmp, proc(gs: tuple[address: IpAddress, port: Port]): bool =
      if $gs.address == "0.0.0.0" or startsWith($gs.address, "255.255.255"):
        return false
      serverConfigsTbl[$gs.address & $gs.port] = serverConfigs[idx]
      return true
    )
    gslist.add(gslistTmp)
  let serversTmp = queryServers(gslist, 500, toOrderedSet([Hostname, Numplayers, Maxplayers, Mapname, Gametype, Gamevariant, Hostport]))
  for server in serversTmp:
    servers.add((
      address: server.address,
      port: server.port,
      gspyServer: server.gspyServer,
      serverConfig: serverConfigsTbl[$server.address & $server.port]
    ))
  channelUpdateServer.send(servers)

proc updateServerAsync() =
  listServer.clear()
  listPlayerInfo1.clear()
  listPlayerInfo2.clear()
  spinnerServer.start()
  btnServerListRefresh.sensitive = false
  btnServerListPlay.sensitive = false
  btnServerPlayerListRefresh.sensitive = false

  channelUpdateServer = Channel[seq[tuple[address: IpAddress, port: Port, gspyServer: GSpyServer, serverConfig: ServerConfig]]]()
  channelUpdateServer.open()

  let TODO: int = 0
  discard timeoutAdd(250, timerUpdateServer, TODO)
  threadUpdateServer.createThread(threadUpdateServerProc, serverConfigs)


proc timerFesl(TODO: int): bool =
  let msgAmount: int = channelFeslTimer.peek()

  if msgAmount == -1:
    return SOURCE_REMOVE # Channel closed, stop timer
  elif msgAmount == 0:
    return SOURCE_CONTINUE # No data to process

  let data: TimerFeslData = channelFeslTimer.recv()

  case data.command:
  of FeslCommand.Create:
    if data.create.save and isNone(data.ex):
      saveLogin(currentServerConfig.server_name, data.create.username, data.create.password, "")
    btnLoginSoldierAdd.sensitive = isNone(data.ex)
    btnLoginSoldierDelete.sensitive = false
    btnLoginPlay.sensitive = false
    spinnerLogin.stop()
  of FeslCommand.Login:
    if data.login.save and isNone(data.ex):
      saveLogin(currentServerConfig.server_name, data.login.username, data.login.password, get(data.login.soldier, ""))
    btnLoginSoldierAdd.sensitive = isNone(data.ex)
    if isNone(data.ex):
      listLoginSoldiers.soldiers = data.login.soldiers
      if isSome(data.login.soldier):
        listLoginSoldiers.selectedSoldier = get(data.login.soldier) # TODO: `selectedSoldier=` should raise an exception if soldier doesn't exists
      let isSoldierSelected: bool = isSome(listLoginSoldiers.selectedSoldier) # TODO: `selectedSoldier` should raise an exception if soldier doesn't exists
      btnLoginPlay.sensitive = isSoldierSelected
      btnLoginSoldierDelete.sensitive = isSoldierSelected
    else:
      btnLoginPlay.sensitive = false
      btnLoginSoldierDelete.sensitive = false
    btnLoginCheck.sensitive = true
    spinnerLogin.stop()
  of FeslCommand.AddSoldier:
    if isNone(data.ex):
      listLoginSoldiers.soldiers = data.soldier.soldiers
      listLoginSoldiers.selectedSoldier = data.soldier.soldier
      txtLoginAddSoldierName.text = ""
      btnLoginPlay.sensitive = true
    btnLoginSoldierDelete.sensitive = true
    spinnerLoginSoldiers.stop()
  of FeslCommand.DelSoldier:
    if isNone(data.ex):
      # listLoginSoldiers.selectNext()
      listLoginSoldiers.removeSelected()
    if chbtnLoginSave.active and isNone(data.ex): # TODO
      saveLogin(currentServerConfig.server_name, txtLoginUsername.text, txtLoginPassword.text, "") # TODO
    btnLoginSoldierDelete.sensitive = listLoginSoldiers.hasEntries()
    btnLoginPlay.sensitive = isSome(listLoginSoldiers.selectedSoldier)
    spinnerLoginSoldiers.stop()

  wndLogin.sensitive = true

  if isSome(data.ex):
    let ex: FeslException = get(data.ex)
    var errorMsg: string = ex.msg

    if errorMsg == "" and currentServerConfig.server_name == "OpenSpy":
      case ex.exType:
      of FeslExceptionType.AddAccount:
        if ex.code == 160:
          errorMsg = "User already taken or an other unknown error."
      of FeslExceptionType.AddSubAccount:
        if ex.code == 160:
          errorMsg = "Soldier already taken or an other unknown error."
      of FeslExceptionType.Login:
        if ex.code == 101:
          errorMsg = "Username doesn't exists."
        elif ex.code == 122:
          errorMsg = "Password is incorrect."
      else:
        discard
    if errorMsg == "":
      errorMsg = "Unknown error."

    frameLoginError.visible = true
    lblLoginErrorTxn.text = $ex.exType
    lblLoginErrorCode.text = $ex.code
    lblLoginErrorMsg.text = errorMsg

  else:
    frameLoginError.visible = false
  return SOURCE_CONTINUE


proc threadFeslProc() {.thread.} =
  var socket: net.Socket = net.newSocket()
  var isSocketConnected: bool = false
  var threadData: ThreadFeslData
  var timerData: TimerFeslData
  var msgAmount: int

  while true:
    msgAmount = channelFeslThread.peek()
    if msgAmount == -1:
      # if isSocketConnected:
      #   socket.close() # TODO: Investigate crashes when closing socket
      return # Channel closed, stop thread

    if msgAmount == 0:
      if not isSocketConnected:
        # No data and not connected, waiting for the first message send through channel
        continue
      # No commands in channel (channelFeslThread) and connected to server,
      # so we're waiting for Ping packages and respond to them,
      # to not get disconnected.
      var dataTbl: tables.Table[string, string]
      var data: string
      var id: uint8
      if not socket.recv(data, id, 500):
        continue # No package received, continue loop
      dataTbl = parseData(data)
      if dataTbl["TXN"] == "Ping":
        socket.send(newPing(), id)
        continue # Send Ping, continue loop

    threadData = channelFeslThread.recv()
    timerData = getTimerFeslData(threadData)

    # Copying ThreadFeslData object into TimerFeslData
    # copyMem(addr(timerData), addr(threadData), sizeof(threadData))

    try:
      if not isSocketConnected:
        var stella: string
        if threadData.command == FeslCommand.Create:
          stella = threadData.create.stella
        elif threadData.command == FeslCommand.Login:
          stella = threadData.login.stella
        else:
          raise # Create or Login command need to be send before sending other commands
        fesl_client.connect(socket, stella)
        isSocketConnected = true

      case threadData.command:
      of FeslCommand.Create:
        socket.createAccount(threadData.create.username, threadData.create.password)
        socket.login(threadData.create.username, threadData.create.password)
        channelFeslTimer.send(timerData)
      of FeslCommand.Login:
        socket.login(threadData.login.username, threadData.login.password)
        timerData.login.soldiers = socket.soldiers()
        channelFeslTimer.send(timerData)
      of FeslCommand.AddSoldier:
        socket.addSoldier(threadData.soldier.soldier)
        timerData.soldier.soldiers = socket.soldiers()
        channelFeslTimer.send(timerData)
      of FeslCommand.DelSoldier:
        socket.delSoldier(threadData.soldier.soldier)
        timerData.soldier.soldiers = socket.soldiers()
        channelFeslTimer.send(timerData)

    except FeslException as ex:
      timerData.ex = some(ex)
      channelFeslTimer.send(timerData)

proc createAsync(save: bool) =
  listLoginSoldiers.clear()
  spinnerLogin.start()
  wndLogin.sensitive = false
  var data: ThreadFeslData = ThreadFeslData(command: FeslCommand.Create)
  var createData: ThreadFeslCreateData
  createData.stella = parseUri(currentServerConfig.stella_prod).hostname
  createData.username = txtLoginUsername.text
  createData.password = txtLoginPassword.text
  createData.save = save
  data.create = createData
  channelFeslThread.send(data)

proc loginAsync(save: bool, soldier: Option[string] = none(string)) =
  listLoginSoldiers.clear()
  spinnerLogin.start()
  wndLogin.sensitive = false
  var data: ThreadFeslData = ThreadFeslData(command: FeslCommand.Login)
  var loginData: ThreadFeslLoginData
  loginData.stella = parseUri(currentServerConfig.stella_prod).hostname
  loginData.username = txtLoginUsername.text
  loginData.password = txtLoginPassword.text
  loginData.save = save
  loginData.soldier = soldier
  data.login = loginData
  channelFeslThread.send(data)
##

### Terminal
when defined(windows):
  # ... I know, it's ugly.
  proc addTextColorizedWorkaround(terminal: Terminal, text: string, scrollDown: bool = false) =
    var buffer: string
    var textLineSplit: seq[string] = text.splitLines()
    for idx, line in textLineSplit:
      var lineSplit: seq[string]

      if line.len < 3:
        buffer.add(glib.markupEscapeText(line.cstring, line.len))
        if idx + 1 != textLineSplit.high: # TODO: Why?
          buffer.add("\n")
        continue

      lineSplit.add(line[0..2])
      if not (lineSplit[0] in @["###", "<==", "==>"]):
        buffer.add(glib.markupEscapeText(line.cstring, line.len))
        if idx + 1 != textLineSplit.high: # TODO: Why?
          buffer.add("\n")
        continue

      lineSplit.add(line[4..^1].split(':', 1))
      var colorPrefix, colorServer: string
      const FORMATTED_COLORIZE: string = """<span foreground="$#">$#</span> <span foreground="$#">$#:</span>$#"""
      case lineSplit[0]:
        of "###":
          colorPrefix = "blue"
        of "<==", "==>":
          colorPrefix = "green"
        else:
          colorPrefix = "red"
      case lineSplit[1]:
        of "LOGIN":
          colorServer = "darkcyan"
        of "LOGIN_UDP":
          colorServer = "goldenrod"
        of "UNLOCK":
          colorServer = "darkmagenta"
        else:
          colorServer = "red"
      buffer.add(FORMATTED_COLORIZE % [
        colorPrefix,
        glib.markupEscapeText(lineSplit[0], lineSplit[0].len),
        colorServer,
        glib.markupEscapeText(lineSplit[1], lineSplit[1].len),
        glib.markupEscapeText(lineSplit[2], lineSplit[2].len)
      ])

      if idx + 1 != textLineSplit.high:
        buffer.add("\n")

    var iterEnd: TextIter
    terminal.buffer.getEndIter(iterEnd)
    terminal.buffer.insertMarkup(iterEnd, buffer, buffer.len)
    if scrollDown:
      terminal.buffer.placeCursor(iterEnd)
      var mark: TextMark = terminal.buffer.getInsert()
      terminal.textView.scrollMarkOnScreen(mark)

proc clear(terminal: Terminal) =
  when defined(linux):
    terminal.reset(true, true)
  elif defined(windows):
    var iterStart, iterEnd: TextIter
    terminal.buffer.getStartIter(iterStart)
    terminal.buffer.getEndIter(iterEnd)
    terminal.buffer.delete(iterStart, iterEnd)

when defined(windows):
  type
    TimerDataLoginUnlockServer = ref object
      terminal: Terminal
    TimerDataGameServer = ref object
      terminal: Terminal
      treeView: TreeView
    ChannelData = object
      running: bool
      data: string
  var threadLoginUnlockServer: system.Thread[Process]
  var threadGameServer: system.Thread[int]
  var channelGameServer: Channel[ChannelData]
  var channelLoginUnlockServer: Channel[ChannelData]
  channelGameServer.open() # TODO: Open before thread is spawned # See workaround in: https://github.com/nim-lang/Nim/issues/6369
  channelLoginUnlockServer.open() # TODO: Open before thread is spawned # See workaround in: https://github.com/nim-lang/Nim/issues/6369

  proc timerGameServer(timerData: TimerDataGameServer): bool =
    # TODO: Always receive the last entry from channel, because
    #       data is the whole stdout of the game server
    var (hasData, channelData) = channelGameServer.tryRecv()
    if not hasData:
      return SOURCE_CONTINUE
    if channelData.data.strip() == "":
      # Stdout of game server is at startup "empty"
      return SOURCE_CONTINUE
    timerData.terminal.text = channelData.data
    var gsdata: GsData
    if channelData.running:
      gsdata = channelData.data.parseGsData()
    if gsdata.status != lastGsStatus:
      timerData.treeView.update(gsdata)
      lastGsStatus = gsdata.status
    return channelData.running

  proc timerLoginUnlockServer(timerData: TimerDataLoginUnlockServer): bool =
    var (hasData, channelData) = channelLoginUnlockServer.tryRecv()
    if not hasData:
      return SOURCE_CONTINUE
    if not channelData.running:
      return SOURCE_REMOVE
    timerData.terminal.addTextColorizedWorkaround(channelData.data, scrollDown = true)
    return SOURCE_CONTINUE

proc killProcess*(pid: int) = # TODO: Add some error handling
  when defined(linux):
    if kill(Pid(pid), SIGKILL) < 0:
      echo "ERROR: Cannot kill process!" # TODO: Create a popup
  elif defined(windows):
    var hndlProcess = OpenProcess(PROCESS_TERMINATE, false.WINBOOL, pid.DWORD)
    discard hndlProcess.TerminateProcess(0) # TODO: Check result
    discard CloseHandle(hndlProcess)
  if pid == termBF2142ServerPid:
    termBF2142ServerPid = 0
  elif pid == termLoginServerPid:
    termLoginServerPid = 0

when defined(windows):
  proc threadGameServerProc(pid: int) {.thread.} =
    var exitCode: DWORD
    var hndl: HANDLE = OpenProcess(PROCESS_ALL_ACCESS, true, pid.DWORD)
    # Disable resizing and maximize button (this breaks readability and
    # stdoutreader fails if region rect is wrong because of resizing)
    SetWindowLongPtrA(hndl, GWL_STYLE, WS_OVERLAPPED xor WS_CAPTION xor WS_SYSMENU xor WS_MINIMIZEBOX xor WS_VISIBLE)
    var channelData: ChannelData = ChannelData(running: true, data: "")
    if hndl == 0:
      channelData.running = false
      channelData.data = "ERROR: " & $osLastError() & "\n" & osErrorMsg(osLastError())
      channelGameServer.send(channelData)
      return
    while channelData.running:
      if GetExitCodeProcess(hndl, unsafeAddr exitCode).bool == false or exitCode != STILL_ACTIVE:
        channelData.running = false
        channelData.data = dgettext("gui", "GAMESERVER_CRASHED")
        channelGameServer.send(channelData)
        continue # Continue to cleanup after while loop
      var stdoutTuple: tuple[lastError: uint32, stdout: string] = readStdOut(pid)
      if stdoutTuple.lastError == 0:
        channelData.data = stdoutTuple.stdout
        channelGameServer.send(channelData)
      elif stdoutTuple.lastError == ERROR_INVALID_HANDLE:
        # TODO: Sometimes it fails with invalid handle.
        # Maybe this happens when the process is killed while reading from stdout.
        discard
      else:
        when defined(debug):
          channelData.running = false
        channelData.data = "ERROR: " & $stdoutTuple.lastError & "\n" & osErrorMsg(stdoutTuple.lastError.OSErrorCode)
        channelGameServer.send(channelData)
      sleep(250)
    ## Cleanup
    discard CloseHandle(hndl)
    #

  proc threadLoginUnlockServerProc(process: Process) {.thread.} =
    var channelData: ChannelData = ChannelData(running: true, data: "")
    var exitCode: int
    while channelData.running:
      exitCode = process.peekExitCode()
      if exitCode == 0:
        channelData.running = false
        channelData.data = ""
        channelLoginUnlockServer.send(channelData)
        return
      elif exitCode > 0:
        channelData.running = false
        channelData.data = "" # TODO: Send error message through channel
        channelLoginUnlockServer.send(channelData)
        return
      channelData.data = process.outputStream.readAll()
      channelLoginUnlockServer.send(channelData)
      sleep(250)
elif defined(linux):
  proc onTermBF2142ServerContentsChanged(terminal: Terminal) =
    var text: string = termBF2142Server.getText(nil, nil, cast[var ptr GArray00](nil))
    if text.strip() == "":
      return
    var gsdata: GsData = text.parseGsData()
    if gsdata.status != lastGsStatus:
      listSelectedMaps.update(gsdata)
      lastGsStatus = gsdata.status
  proc onTermBF2142ServerChildExited(terminal: Terminal, exitCode: int) =
    # Clears the colorized rows.
    listSelectedMaps.update(GsData())

proc startProcess(terminal: Terminal, command: string, params: string = "",
                  workingDir: string = os.getCurrentDir(), env: string = "",
                  searchForkedProcess: bool = false): int =
  when defined(linux):
    var argv: seq[string] = command.strip().splitWhitespace()
    if params != "":
      argv.add(params)
    discard terminal.spawnSync(
      ptyFlags = {PtyFlag.noLastlog},
      workingDirectory = workingDir,
      argv = argv,
      envv = env.strip().splitWhitespace(),
      spawnFlags = {glib.SpawnFlag.doNotReapChild},
      childSetup = nil,
      childSetupData = nil,
      childPid = result
    )
  elif defined(windows):
    var process: Process
    if searchForkedProcess == true:
      process = startProcess(
        command = """cmd /c """" & workingDir / command & "\" " & params, # TODO: Use fmt
        workingDir = workingDir,
        options = {poStdErrToStdOut, poEvalCommand, poEchoCmd}
      )
    else:
      process = startProcess(
        command = workingDir / command & " " & params,
        workingDir = workingDir,
        options = {poStdErrToStdOut, poEvalCommand, poEchoCmd}
      )
    result = process.processID
    if searchForkedProcess:
      # Gameserver
      var tryCounter: int = 0
      while tryCounter < 10: # TODO: Raise an exception if proess could not be found
        result = getPidByName(command)
        if result > 0:
          break
        tryCounter.inc()
        sleep(500)
      var timerDataGameServer: TimerDataGameServer = TimerDataGameServer(terminal: terminal, treeView: listSelectedMaps)
      discard timeoutAdd(250, timerGameServer, timerDataGameServer)
      threadGameServer.createThread(threadGameServerProc, result) # result = pid
    else:
      # Login/unlock server
      var timerLoginUnlockServer: TimerDataLoginUnlockServer = TimerDataLoginUnlockServer(terminal: terminal)
      discard timeoutAdd(250, timerLoginUnlockServer, timerLoginUnlockServer)
      threadLoginUnlockServer.createThread(threadLoginUnlockServerProc, process)

proc startBF2142Server() =
  termBF2142Server.setSizeRequest(0, 300)
  var stupidPbSymlink: string = bf2142ServerPath / "pb"
  if symlinkExists(stupidPbSymlink):
    if not removeFile(stupidPbSymlink):
      return
  when defined(linux):
    var ldLibraryPath: string = bf2142ServerPath / "bin" / "amd-64"
    ldLibraryPath &= ":" & os.getCurrentDir()
    termBF2142ServerPid = termBF2142Server.startProcess(
      command = "bin" / "amd-64" / BF2142_SRV_UNLOCKER_EXE_NAME,
      params = "+modPath mods/" & cbxHostMods.activeId,
      workingDir = bf2142ServerPath,
      env = fmt"TERM=xterm LD_LIBRARY_PATH={ldLibraryPath}"
    )
  elif defined(windows):
    termBF2142ServerPid = termBF2142Server.startProcess(
      command = BF2142_SRV_UNLOCKER_EXE_NAME,
      params = "+modPath mods/" & cbxHostMods.activeId,
      workingDir = bf2142ServerPath,
      searchForkedProcess = true
    )

proc startLoginServer(term: Terminal, ipAddress: IpAddress) =
  term.setSizeRequest(0, 300)
  when defined(linux):
    # TODO: Fix this crappy code below. Did this only to get version 0.9.3 out.
    termLoginServerPid = term.startProcess(command = fmt"./server {$ipAddress} {$chbtnUnlockSquadGadgets.active}")
    var tryCnt: int = 0
    while tryCnt < 3:
      if isAddrReachable($ipAddress, Port(18300), 1_000):
        break
      else:
        tryCnt.inc()
        sleep(250)
  elif defined(windows):
    termLoginServerPid = term.startProcess(command = fmt"server.exe {$ipAddress} {$chbtnUnlockSquadGadgets.active}")
##

### Events
## Join
type
  BF2142Options* = object
    modPath*: Option[string]
    menu*: Option[bool]
    fullscreen*: Option[bool]
    szx*: Option[uint16]
    szy*: Option[uint16]
    widescreen*: Option[bool]
    eaAccountName*: Option[string]
    eaAccountPassword*: Option[string]
    soldierName*: Option[string]
    joinServer*: Option[IpAddress]
    port*: Option[Port]

proc startBF2142(options: BF2142Options): bool = # TODO: Other params and also an joinGSPort
  var command: string
  when defined(linux):
    when defined(debug):
      command.add("WINEDEBUG=fixme-all,err-winediag" & ' ') # TODO: Remove some nasty fixme's and errors for development
    if txtWinePrefix.text != "":
      command.add("WINEPREFIX=" & txtWinePrefix.text & ' ')
  # command.add("WINEARCH=win32" & ' ') # TODO: Implement this if user would like to run this in 32 bit mode (only requierd on first run)
  when defined(linux):
    if txtStartupQuery.text != "":
      command.add(txtStartupQuery.text & ' ')
  command.add(BF2142_UNLOCKER_EXE_NAME & ' ')
  if isSome(options.modPath):
    command.add("+modPath " & get(options.modPath) & ' ')
  if isSome(options.menu):
    command.add("+menu " & $get(options.menu).int & ' ') # TODO: Check if this is necessary
  if isSome(options.fullscreen):
    command.add("+fullscreen " & $get(options.fullscreen).int & ' ')
    if get(options.fullscreen) == false:
      if isSome(options.szx) and isSome(options.szy):
        command.add("+szx " & $get(options.szx) & ' ')
        command.add("+szy " & $get(options.szy) & ' ')
  if isSome(options.widescreen):
    command.add("+widescreen " & $get(options.widescreen).int & ' ') # INFO: Enables widescreen resolutions in bf2142 ingame graphic settings
  command.add("+eaAccountName " & get(options.eaAccountName) & ' ')
  command.add("+eaAccountPassword " & get(options.eaAccountPassword) & ' ')
  command.add("+soldierName " & get(options.soldierName) & ' ')
  if isSome(options.joinServer):
    command.add("+joinServer " & $get(options.joinServer) & ' ')
    if isSome(options.port):
      command.add("+port " & $get(options.port) & ' ')
  when defined(linux): # TODO: Check if bf2142Path is neccessary
    let processCommand: string = command
  elif defined(windows):
    let processCommand: string = bf2142Path & '\\' & command
  var process: Process = startProcess(command = processCommand, workingDir = bf2142Path,
    options = {poStdErrToStdOut, poParentStreams, poEvalCommand, poEchoCmd}
  )
  return true

proc patchAndStartLogic(): bool =
  let ipAddress: string = txtIpAddress.text.strip()
  txtPlayerName.text = txtPlayerName.text.strip()
  var invalidStr: string
  if chbtnAutoJoin.active and (ipAddress == "127.0.0.1" or ipAddress == "localhost"):
    invalidStr.add("\t* Auto join feature won't work if you're trying to connect to a gameserver with 127.0.0.1 or localhost.\n")
  if not ipAddress.isIpAddress():
    invalidStr.add("\t* Your IP-address is not valid.\n")
  elif ipAddress.parseIpAddress().family == IPv6:
    invalidStr.add("\t* IPv6 not testes!\n") # TODO: Add ignore?
  if txtPlayerName.text == "":
    invalidStr.add("\t* You need to specify a playername with at least one character.\n")
  if bf2142Path == "": # TODO: Some more checkes are requierd (e.g. does BF2142.exe exists)
    invalidStr.add("\t* You need to specify your Battlefield 2142 path in \"Settings\"-Tab.\n")
  when defined(linux):
    if txtWinePrefix.text == "":
      invalidStr.add("\t* You need to specify your wine prefix (in \"Settings\"-Tab).\n")
  if invalidStr.len > 0:
    newInfoDialog("Error", invalidStr)
    return false

  ## Check Logic (TODO: Cleanup and check servers in thread)
  # var canConnect: bool = true
  # throbberLoginServer.visible = true
  # throbberGpcmServer.visible = true
  # throbberUnlockServer.visible = true
  # imgLoginServer.visible = false
  # imgGpcmServer.visible = false
  # imgUnlockServer.visible = false
  # # Login server
  # if isAddrReachable(ipAddress, Port(18300), 1_000):
  #   throbberLoginServer.visible = false
  #   imgLoginServer.visible = true
  #   imgLoginServer.setFromIconName("gtk-apply", 0)
  # else:
  #   canConnect = false
  #   throbberLoginServer.visible = false
  #   imgLoginServer.visible = true
  #   imgLoginServer.setFromIconName("gtk-cancel", 0)
  # # GPCM server
  # if isAddrReachable(ipAddress, Port(29900), 1_000):
  #   throbberGpcmServer.visible = false
  #   imgGpcmServer.visible = true
  #   imgGpcmServer.setFromIconName("gtk-apply", 0)
  # else:
  #   canConnect = false
  #   throbberGpcmServer.visible = false
  #   imgGpcmServer.visible = true
  #   imgGpcmServer.setFromIconName("gtk-cancel", 0)
  # # Unlock server
  # if isAddrReachable(ipAddress, Port(8085), 1_000):
  #   throbberUnlockServer.visible = false
  #   imgUnlockServer.visible = true
  #   imgUnlockServer.setFromIconName("gtk-apply", 0)
  # else:
  #   canConnect = false
  #   throbberUnlockServer.visible = false
  #   imgUnlockServer.visible = true
  #   imgUnlockServer.setFromIconName("gtk-cancel", 0)
  # if not canConnect:
  #   dlgCheckServers.show()
  #   # TODO: When checks are done in a thread, this dialog would be always shown when connecting,
  #   #       and if every server is reachable autoamtically hidden.
  #   return
  #

  # config.setSectionKey(CONFIG_SECTION_GENERAL, CONFIG_KEY_IP_ADDRESS, ipAddress)
  config.setSectionKey(CONFIG_SECTION_GENERAL, CONFIG_KEY_PLAYER_NAME, txtPlayerName.text)
  config.setSectionKey(CONFIG_SECTION_GENERAL, CONFIG_KEY_AUTO_JOIN, $chbtnAutoJoin.active)
  config.setSectionKey(CONFIG_SECTION_GENERAL, CONFIG_KEY_SKIP_MOVIES, $chbtnSkipMovies.active)
  config.setSectionKey(CONFIG_SECTION_GENERAL, CONFIG_KEY_WINDOW_MODE, $chbtnWindowMode.active)
  config.setSectionKey(CONFIG_SECTION_GENERAL, CONFIG_KEY_RESOLUTION, cbxJoinResolutions.activeId)
  config.writeConfig(CONFIG_FILE_NAME)

  if not fileExists(bf2142Path / BF2142_UNLOCKER_EXE_NAME):
    if not copyFile(bf2142Path / BF2142_EXE_NAME, bf2142Path / BF2142_UNLOCKER_EXE_NAME):
      return
  if not hasWritePermission(bf2142Path / BF2142_UNLOCKER_EXE_NAME):
    newInfoDialog(
      dgettext("gui", "NO_WRITE_PERMISSION_TITLE"),
      dgettext("gui", "NO_WRITE_PERMISSION_MSG") % [bf2142Path / BF2142_UNLOCKER_EXE_NAME]
    )
    return

  var patchConfig: PatchConfig
  patchConfig.stella_prod = "http://" & ipAddress & ":8085/"
  patchConfig.stella_ms = ipAddress
  patchConfig.ms = ipAddress
  patchConfig.available = ipAddress
  patchConfig.motd = "http://" & ipAddress & "/"
  patchConfig.master = ipAddress
  patchConfig.gamestats = ipAddress
  patchConfig.gpcm = ipAddress
  patchConfig.gpsp = ipAddress
  patchClient(bf2142Path / BF2142_UNLOCKER_EXE_NAME, patchConfig)

  backupOpenSpyIfExists()

  saveBF2142Profile(txtPlayerName.text, txtPlayerName.text)

  when defined(windows): # TODO: Reading/setting cd key on linux
    setCdKeyIfNotExists() # Checking if cd key exists, if not an empty cd key is set

  if not enableDisableIntroMovies(bf2142Path / "mods" / cbxJoinMods.activeId / "Movies", chbtnSkipMovies.active):
    return

  var options: BF2142Options
  options.modPath = some("mods/" & cbxJoinMods.activeId)
  options.menu = some(true)
  options.fullscreen = some(not chbtnWindowMode.active)
  if chbtnWindowMode.active:
    var resolution: tuple[width, height: uint16] = getSelectedResolution()
    options.szx = some(resolution.width)
    options.szy = some(resolution.height)
  options.widescreen = some(true) # TODO
  options.eaAccountName = some(txtPlayerName.text)
  options.eaAccountPassword = some("A")
  options.soldierName = some(txtPlayerName.text)
  if chbtnAutoJoin.active:
    options.joinServer = some(ipAddress.parseIpAddress())
    options.port = some(Port(17567))
  return startBF2142(options)

proc onBtnJoinClicked(self: Button00) {.signal.} =
  discard patchAndStartLogic()

proc onChbtnWindowModeToggled(self: CheckButton00) {.signal.} =
  lblJoinResolutions.visible = chbtnWindowMode.active
  cbxJoinResolutions.visible = chbtnWindowMode.active

proc onBtnJustPlayClicked(self: Button00) {.signal.} =
  var ipAddress: IpAddress = parseIpAddress("127.0.0.1")
  txtIpAddress.text = $ipAddress
  if termLoginServerPid > 0:
    killProcess(termLoginServerPid)
  termJustPlayServer.clear()
  termJustPlayServer.startLoginServer(ipAddress)
  var prevAutoJoinVal: bool = chbtnAutoJoin.active
  chbtnAutoJoin.active = false
  if patchAndStartLogic():
    termLoginServer.visible = false
    applyJustPlayRunningSensitivity(true)
    if termBF2142ServerPid == 0:
      applyHostRunningSensitivity(false)
  else:
    chbtnAutoJoin.active = prevAutoJoinVal
    killProcess(termLoginServerPid)

proc onBtnJustPlayCancelClicked(self: Button00) {.signal.} =
  killProcess(termLoginServerPid)
  applyJustPlayRunningSensitivity(false)

proc onBtnCheckCancelClicked(self: Button00) {.signal.} =
  dlgCheckServers.hide()

proc onBtnAddMapClicked(self: Button00) {.signal.} =
  var mapName, mapMode: string
  var mapSize: int
  (mapName, mapMode, mapSize) = listSelectableMaps.selectedMap
  if mapName == "" or mapMode == "" or mapSize == 0:
    return
  listSelectedMaps.appendMap(mapName, mapMode, mapSize)
  listSelectableMaps.selectNext()
  listSelectableMaps.updateLevelPreview()

proc onBtnRemoveMapClicked(self: Button00) {.signal.} =
  var mapName, mapMode: string
  var mapSize: int
  (mapName, mapMode, mapSize) = listSelectedMaps.selectedMap
  if mapName == "" or mapMode == "" or mapSize == 0: return
  listSelectedMaps.removeSelected()
  listSelectedMaps.updateLevelPreview()

proc onBtnMapMoveUpClicked(self: Button00) {.signal.} =
  listSelectedMaps.moveSelectedUp()

proc onBtnMapMoveDownClicked(self: Button00) {.signal.} =
  listSelectedMaps.moveSelectedDown()
#
## Server list
## TODO: Ping or connection gets closed after 30 seconds
proc onListServerCursorChanged(self: TreeView00) {.signal.} =
  currentServer = get(listServer.selectedServer)
  isServerSelected = true

  for serverConfig in serverConfigs:
    if serverConfig.server_name == currentServer.stellaName:
      currentServerConfig = serverConfig

  btnServerListPlay.sensitive = true
  btnServerPlayerListRefresh.sensitive = true

  updatePlayerListAsync()

proc onWindowKeyReleaseEvent(self: gtk.Window00, event00: ptr EventKey00): bool {.signal.} =
  var event: EventKey = new EventKey
  event.impl = event00
  event.ignoreFinalizer = true
  if not notebook.currentPage == 1:
    return
  if event.getKeyval() == KEY_F5: # TODO: Add tooltip info
    updateServerAsync()
  if event.getKeyval() == KEY_F6 and isServerSelected: # TODO: Add tooltip info
    updatePlayerListAsync()

proc onNotebookSwitchPage(self: Notebook00, page: Widget00, pageNum: cint): bool {.signal.} =
  if pageNum == 1:
    updateServerAsync()

proc onTxtLoginUsernameInsertText(self: Editable00, cstr: cstring, cstrLen: cint, pos: ptr cuint) {.signal.} =
  if not isAlphaNumeric($cstr):
    txtLoginUsername.signalStopEmissionByName("insert-text")
    return
  btnLoginCheck.sensitive = (txtLoginUsername.text & $cstr).len > 0 and txtLoginPassword.text.len > 0

proc onTxtLoginUsernameDeleteText(self: Editable00, startPos, endPos: cint) {.signal.} =
  btnLoginCheck.sensitive = (txtLoginUsername.text.len - (endPos - startPos)) > 0 and txtLoginPassword.text.len > 0

proc onTxtLoginPasswordInsertText(self: Editable00, cstr: cstring, cstrLen: cint, pos: ptr cuint) {.signal.} =
  if not isAlphaNumeric($cstr):
    txtLoginPassword.signalStopEmissionByName("insert-text")
    return
  btnLoginCheck.sensitive = txtLoginUsername.text.len > 0 and (txtLoginPassword.text & $cstr).len > 0

proc onTxtLoginPasswordDeleteText(self: Editable00, startPos, endPos: cint) {.signal.} =
  btnLoginCheck.sensitive = txtLoginUsername.text.len > 0 and (txtLoginPassword.text.len - (endPos - startPos)) > 0

proc onTxtLoginAddSoldierNameInsertText(self: Editable00, cstr: cstring, cstrLen: cint, pos: ptr cuint) {.signal.} =
  var soldier: string
  soldier = txtLoginAddSoldierName.text
  soldier.insert($cstr, int(pos[]))
  if not validateSoldier(soldier):
    txtLoginAddSoldierName.signalStopEmissionByName("insert-text")

proc onTxtLoginAddSoldierNameDeleteText(self: Editable00, startPos, endPos: cint) {.signal.} =
  var soldier: string = txtLoginAddSoldierName.text
  soldier.delete(int(startPos), int(endPos) - 1)
  if not validateSoldier(soldier):
    txtLoginAddSoldierName.signalStopEmissionByName("delete-text")

proc onTxtLoginAddSoldierNameChanged(self: Editable00) {.signal.} =
  btnLoginAddSoldierOk.sensitive = txtLoginAddSoldierName.text.len >= 3

proc onBtnLoginCheckClicked(self: Button00) {.signal.} =
  frameLoginError.visible = false
  loginAsync(chbtnLoginSave.active)

proc onBtnLoginCreateClicked(self: Button00) {.signal.} =
  frameLoginError.visible = false
  createAsync(chbtnLoginSave.active)

proc onBtnLoginPlayClicked(self: Button00) {.signal.} =
  frameLoginError.visible = false

  let username: string = txtLoginUsername.text
  let soldier: string = get(listLoginSoldiers.selectedSoldier)

  backupOpenSpyIfExists()
  patchClient(bf2142Path / BF2142_UNLOCKER_EXE_NAME, PatchConfig(currentServerConfig))
  saveBF2142Profile(username, soldier)

  var options: BF2142Options
  options.modPath = some("mods/" & currentServer.`mod`)
  options.menu = some(true)
  options.fullscreen = some(false) # TODO
  options.szx = some(800.uint16) # TODO
  options.szy = some(600.uint16) # TODO
  options.widescreen = some(true) # TODO
  options.eaAccountName = some(username)
  options.eaAccountPassword = some(txtLoginPassword.text)
  options.soldierName = some(soldier)
  options.joinServer = some(currentServer.ip)
  options.port = some(currentServer.port)
  discard startBF2142(options)

proc onBtnLoginCancelClicked(self: Button) {.signal.} =
  wndLogin.hide()

proc onBtnLoginSoldierAddClicked(self: Button00) {.signal.} =
  frameLoginError.visible = false
  txtLoginAddSoldierName.grabFocus()
  let dlgLoginAddSoldierCode: int = dlgLoginAddSoldier.run()
  if dlgLoginAddSoldierCode != 1:
    dlgLoginAddSoldier.hide()
    return # User closed dialog
  dlgLoginAddSoldier.hide()
  spinnerLoginSoldiers.start()
  wndLogin.sensitive = false
  var data: ThreadFeslData = ThreadFeslData(command: FeslCommand.AddSoldier)
  var dataSoldier: ThreadFeslSoldierData
  dataSoldier.soldier = txtLoginAddSoldierName.text
  data.soldier = dataSoldier
  channelFeslThread.send(data)


proc onBtnLoginSoldierDeleteClicked(self: Button00) {.signal.} =
  spinnerLoginSoldiers.start()
  wndLogin.sensitive = false
  var data: ThreadFeslData = ThreadFeslData(command: FeslCommand.DelSoldier)
  var dataSoldier: ThreadFeslSoldierData
  dataSoldier.soldier = get(listLoginSoldiers.selectedSoldier)
  data.soldier = dataSoldier
  channelFeslThread.send(data)

proc onChbtnLoginSaveToggled(self: ToggleButton00) {.signal.} =
  var username, password, soldier: string
  if chbtnLoginSave.active:
    username = txtLoginUsername.text
    password = txtLoginPassword.text
    soldier = get(listLoginSoldiers.selectedSoldier, "")
  saveLogin(currentServerConfig.server_name, username, password, soldier)

proc onListLoginSoldiersCursorChanged(self: TreeView00): bool {.signal.} =
  if chbtnLoginSave.active:
    saveLogin(currentServerConfig.server_name, "", "", get(listLoginSoldiers.selectedSoldier), true)
  btnLoginPlay.sensitive = true
  btnLoginSoldierDelete.sensitive = true
  return EVENT_PROPAGATE

proc onWndLoginShow(self: gtk.Window00) {.signal.} =
  notebook.sensitive = false

  channelFeslThread = Channel[ThreadFeslData]()
  channelFeslThread.open()
  channelFeslTimer = Channel[TimerFeslData]()
  channelFeslTimer.open()
  let TODO: int = 0
  discard timeoutAdd(250, timerFesl, TODO)
  threadFesl.createThread(threadFeslProc)

  lblLoginStellaName.text = currentServer.stellaName
  lblLoginGameServerName.text = currentServer.name

  let loginTplOpt: Option[tuple[username, password: string, soldier: Option[string]]] = getLogin(currentServerConfig.server_name)
  if loginTplOpt.isSome:
    let loginTpl: tuple[username, password: string, soldier: Option[string]] = get(loginTplOpt)
    ignoreEvents = true
    txtLoginUsername.text = loginTpl.username
    txtLoginPassword.text = loginTpl.password
    chbtnLoginSave.active = true
    ignoreEvents = false
    loginAsync(false, loginTpl.soldier)
    return

  listLoginSoldiers.clear()
  ignoreEvents = true
  chbtnLoginSave.active = false
  ignoreEvents = false

  btnLoginCheck.sensitive = false
  btnLoginSoldierAdd.sensitive = false
  btnLoginSoldierDelete.sensitive = false
  btnLoginPlay.sensitive = false

proc onWndLoginDeleteEvent(self: gtk.Window00): bool {.signal.} =
  wndLogin.hide()
  return EVENT_STOP

proc onWndLoginHide(self: gtk.Window00) {.signal.} =
  notebook.sensitive = true
  frameLoginError.visible = false

  txtLoginUsername.text = ""
  txtLoginPassword.text = ""
  channelFeslThread.close() # Closes thread (see threadFeslProc)
  channelFeslTimer.close() # Closes timer (see timerFesl)

proc onListServerButtonPressEvent(self: TreeView00, event00: ptr EventButton00): bool {.signal.} =
  var event: EventButton = new EventButton
  event.impl = event00
  event.ignoreFinalizer = true
  if event.eventType != EventType.doubleButtonPress:
    return

  wndLogin.show()
  return EVENT_PROPAGATE

proc onBtnServerListRefreshClicked(self: Button00) {.signal.} =
  updateServerAsync()

proc onBtnServerListPlayClicked(self: Button00) {.signal.} =
  wndLogin.show()

proc onBtnServerPlayerRefreshClicked(self: Button00) {.signal.} =
  updatePlayerListAsync()
#
## Host
proc onBtnHostClicked(self: Button00) {.signal.} =
  if not txtHostIpAddress.text.strip().isIpAddress() or
  txtHostIpAddress.text.strip().parseIpAddress().family != IPv4:
    newInfoDialog(dgettext("gui", "NO_VALID_IP_ADDRESS_TITLE"), dgettext("gui", "NO_VALID_IP_ADDRESS_MSG"))
    return
  var ipAddress: IpAddress = txtHostIpAddress.text.strip().parseIpAddress()
  if not saveMapList():
    return
  if not saveServerSettings():
    return
  if not saveAiSettings():
    return
  var serverExePath = bf2142ServerPath
  when defined(linux):
    serverExePath = serverExePath / "bin" / "amd-64"
  if not fileExists(serverExePath / BF2142_SRV_UNLOCKER_EXE_NAME):
    if not copyFileWithPermissions(serverExePath / BF2142_SRV_EXE_NAME,
    serverExePath / BF2142_SRV_UNLOCKER_EXE_NAME, false):
      return
  if not hasWritePermission(serverExePath / BF2142_SRV_UNLOCKER_EXE_NAME):
    newInfoDialog(
      dgettext("gui", "NO_WRITE_PERMISSION_TITLE"),
      dgettext("gui", "NO_WRITE_PERMISSION_MSG") % [serverExePath / BF2142_SRV_UNLOCKER_EXE_NAME]
    )
    return
  serverExePath = serverExePath / BF2142_SRV_UNLOCKER_EXE_NAME
  echo "Patching Battlefield 2142 server!"
  patchServer(serverExePath, parseIpAddress("127.0.0.1"), Port(8085))
  applyJustPlayRunningSensitivity(false)
  applyHostRunningSensitivity(true)
  if $ipAddress == "0.0.0.0":
     # When setting to 127.0.0.1 game doesn't connect to game server (doesn't load map)
    txtIpAddress.text = getPrivateAddrs()[0]
  else:
    txtIpAddress.text = $ipAddress
  chbtnAutoJoin.active = true
  if termLoginServerPid > 0:
    killProcess(termLoginServerPid)
  termLoginServer.clear()
  termLoginServer.startLoginServer(ipAddress)
  startBF2142Server()
  discard cbxJoinMods.setActiveId(cbxHostMods.activeId)

proc onBtnHostLoginServerClicked(self: Button00) {.signal.} =
  if not txtHostIpAddress.text.strip().isIpAddress() or
  txtHostIpAddress.text.strip().parseIpAddress().family != IPv4:
    newInfoDialog(dgettext("gui", "NO_VALID_IP_ADDRESS_TITLE"), dgettext("gui", "NO_VALID_IP_ADDRESS_MSG"))
    return
  var ipAddress: IpAddress = txtHostIpAddress.text.strip().parseIpAddress()
  applyJustPlayRunningSensitivity(false)
  applyHostRunningSensitivity(true, bf2142ServerInvisible = true)
  if $ipAddress == "0.0.0.0":
    txtIpAddress.text = "127.0.0.1"
  else:
    txtIpAddress.text = $ipAddress
  chbtnAutoJoin.active = false
  if termLoginServerPid > 0:
    killProcess(termLoginServerPid)
  termLoginServer.clear()
  termLoginServer.startLoginServer(ipAddress)

proc onBtnHostCancelClicked(self: Button00) {.signal.} =
  applyHostRunningSensitivity(false)
  applyJustPlayRunningSensitivity(false)
  killProcess(termLoginServerPid)
  txtIpAddress.text = ""
  if termBF2142ServerPid > 0:
    killProcess(termBF2142ServerPid)

proc onCbxHostModsChanged(self: ComboBox00) {.signal.} =
  updatePathes()
  loadSelectableMapList()
  if not loadMapList():
    return
  if not loadServerSettings():
    return
  if not loadAiSettings():
    return

proc onCbxGameModeChanged(self: ComboBox00) {.signal.} =
  updatePathes()
  loadSelectableMapList()

proc onListSelectableMapsCursorChanged(self: TreeView00) {.signal.} =
  listSelectableMaps.updateLevelPreview()

proc onListSelectedMapsRowActivated(self: TreeView00, path: TreePath00, column: TreeViewColumn00) {.signal.} =
  listSelectedMaps.updateLevelPreview()
#
## Settings
proc selectFolderDialog(title: string): tuple[responseType: ResponseType, path: string] =
  var dialog: FileChooserDialog = newFileChooserDialog(title, window, FileChooserAction.selectFolder)
  discard dialog.addButton("OK", ResponseType.ok.ord)
  discard dialog.addButton("Cancel", ResponseType.cancel.ord)
  let responseId: int = dialog.run()
  let path: string = dialog.getFilename()
  dialog.destroy()
  return (cast[ResponseType](responseId), path)

proc setBF2142Path(path: string) =
  if bf2142Path == path:
    return
  if not fileExists(path / BF2142_EXE_NAME):
    newInfoDialog(
      dgettext("gui", "COULD_NOT_FIND_TITLE") % [BF2142_EXE_NAME],
      dgettext("gui", "COULD_NOT_FIND_MSG") % [BF2142_EXE_NAME],
    )
    txtBF2142Path.text = bf2142Path
    return
  vboxJoin.visible = true
  vboxHost.visible = true
  vboxUnlocks.visible = true
  bf2142Path = path
  if txtBF2142Path.text != path:
    txtBF2142Path.text = path
  loadJoinMods()
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_BF2142_PATH, bf2142Path)
  when defined(linux):
    let wineStartPos: int = bf2142Path.find(".wine")
    var wineEndPos: int
    if wineStartPos > -1:
      wineEndPos = bf2142Path.find(DirSep, wineStartPos) - 1
      if txtWinePrefix.text == "": # TODO: Ask with Dialog if the read out wineprefix should be assigned to txtWinePrefix's text
        txtWinePrefix.text = bf2142Path.substr(0, wineEndPos)
        config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_WINEPREFIX, txtWinePrefix.text) # TODO: Create a saveWinePrefix proc
  config.writeConfig(CONFIG_FILE_NAME)

proc onBtnBF2142PathClicked(self: Button00) {.signal.} = # TODO: Add checks
  var (responseType, path) = selectFolderDialog(lblBF2142Path.text[0..^2])
  if responseType != ResponseType.ok:
    return
  setBF2142Path(path)

proc onTxtBF2142PathFocusOut(self: Entry00) {.signal.} =
  setBF2142Path(txtBF2142Path.text.strip())

proc setBF2142ServerPath(path: string) =
  if bf2142ServerPath == path:
    return
  when defined(windows):
    let serverExePath: string = path / BF2142_SRV_EXE_NAME
  elif defined(linux):
    let serverExePath: string = path / "bin" / "amd-64" / BF2142_SRV_EXE_NAME
  if not fileExists(serverExePath):
    newInfoDialog(
      dgettext("gui", "COULD_NOT_FIND_TITLE") % [BF2142_SRV_EXE_NAME],
      dgettext("gui", "COULD_NOT_FIND_MSG") % [BF2142_SRV_EXE_NAME],
    )
    txtBF2142ServerPath.text = bf2142ServerPath
    return
  bf2142ServerPath = path
  if txtBF2142ServerPath.text != path:
    txtBF2142ServerPath.text = path
  btnHost.sensitive = bf2142ServerPath != ""
  ignoreEvents = true
  loadHostMods()
  updatePathes()
  loadSelectableMapList()
  if not loadMapList():
    ignoreEvents = false
    return
  if not loadServerSettings():
    ignoreEvents = false
    return
  if not loadAiSettings():
    ignoreEvents = false
    return
  ignoreEvents = false
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_BF2142_SERVER_PATH, bf2142ServerPath)
  config.writeConfig(CONFIG_FILE_NAME)

proc onBtnBF2142ServerPathClicked(self: Button00) {.signal.} = # TODO: Add Checks
  var (responseType, path) = selectFolderDialog(lblBF2142ServerPath.text[0..^2])
  if responseType != ResponseType.ok:
    return
  setBF2142ServerPath(path)

proc onTxtBF2142ServerPathFocusOut(self: Entry00) {.signal.} =
  setBF2142ServerPath(txtBF2142ServerPath.text.strip())

proc onBtnWinePrefixClicked(self: Button00) {.signal.} = # TODO: Add checks
  var (responseType, path) = selectFolderDialog(lblWinePrefix.text[0..^2])
  if responseType != ResponseType.ok:
    return
  if bf2142ServerPath == path:
    return
  txtWinePrefix.text = path
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_WINEPREFIX, txtWinePrefix.text)
  config.writeConfig(CONFIG_FILE_NAME)
  when defined(linux): # Getlogin is only available for linux
    documentsPath = txtWinePrefix.text / "drive_c" / "users" / $getlogin() / "My Documents"
  updateProfilePathes()

proc onTxtStartupQueryFocusOut(self: Entry00, event: EventFocus00): bool {.signal.} =
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_STARTUP_QUERY, txtStartupQuery.text)
  config.writeConfig(CONFIG_FILE_NAME)

proc copyLevels(srcLevelPath, dstLevelPath: string, isServer: bool = false): bool =
  result = true
  var srcPath, dstPath, dstArchiveMd5Path, levelName: string
  for levelFolder in walkDir(srcLevelPath, true):
    levelName = levelFolder.path
    when defined(linux):
      if isServer:
        levelName = levelFolder.path.toLower()
    if not existsOrCreateDir(dstLevelPath / levelName).succeed:
      return false
    echo "Copying level: ", levelName
    for levelFiles in walkDir(srcLevelPath / levelFolder.path, true):
      dstPath = dstLevelPath / levelName
      when defined(linux):
        if isServer and levelFiles.kind == pcDir and levelFiles.path == "Info":
          dstPath = dstPath / levelFiles.path.toLower()
        else:
          dstPath = dstPath / levelFiles.path
      else:
        dstPath = dstPath / levelFiles.path
      srcPath = srcLevelPath / levelFolder.path / levelFiles.path
      if levelFiles.kind == pcDir:
        if not copyDir(srcPath, dstPath):
          return
      elif levelFiles.kind == pcFile:
        if not copyFile(srcPath, dstPath):
          return
    when defined(linux):
      if isServer: # Moving all files in levels info folder to lowercase names
        let infoPath = dstLevelPath / levelName / "info"
        for fileName in walkDir(infoPath, true):
          if fileName.kind == pcFile:
            let srcDescPath = infoPath / fileName.path
            let dstDescPath = infoPath / fileName.path.toLower()
            if srcDescPath != dstDescPath:
              if not moveFile(srcDescPath, dstDescPath):
                return


proc onBtnPatchClientMapsClickedResponse(dialog: FileChooserDialog; responseId: int) =
  let
    response = ResponseType(responseId)
    srcLevelPath: string = dialog.getFilename()
    dstLevelPath: string = bf2142Path / "mods" / "bf2142" / "Levels"
  if response == ResponseType.ok:
    var writeSucceed: bool = copyLevels(srcLevelPath, dstLevelPath)
    dialog.destroy()
    if writeSucceed:
      newInfoDialog(dgettext("gui", "COPIED_MAPS"), dgettext("gui", "COPIED_MAPS_CLIENT"))
  else:
    dialog.destroy()

proc onBtnPatchClientMapsClicked(self: Button00) {.signal.} =
  let chooser = newFileChooserDialog(dgettext("gui", "SELECT_MAPS_FOLDER_CLIENT"), nil, FileChooserAction.selectFolder)
  discard chooser.addButton("Ok", ResponseType.ok.ord)
  discard chooser.addButton("Cancel", ResponseType.cancel.ord)
  chooser.connect("response", onBtnPatchClientMapsClickedResponse)
  chooser.show()

proc onBtnPatchServerMapsClickedResponse(dialog: FileChooserDialog; responseId: int) =
  let
    response = ResponseType(responseId)
    srcLevelPath: string = dialog.getFilename()
    dstLevelPath: string = bf2142ServerPath / "mods" / "bf2142" / "levels" # TODO: Set mod when selecting src folder
  if response == ResponseType.ok:
    var writeSucceed: bool = copyLevels(srcLevelPath = srcLevelPath, dstLevelPath = dstLevelPath, isServer = true)
    dialog.destroy()
    if writeSucceed:
      loadSelectableMapList()
      newInfoDialog(dgettext("gui", "COPIED_MAPS"), dgettext("gui", "COPIED_MAPS_SERVER"))
  else:
    dialog.destroy()

proc onBtnPatchServerMapsClicked(self: Button00) {.signal.} =
  let chooser = newFileChooserDialog(dgettext("gui", "SELECT_MAPS_FOLDER_SERVER"), nil, FileChooserAction.selectFolder)
  discard chooser.addButton("Ok", ResponseType.ok.ord)
  discard chooser.addButton("Cancel", ResponseType.cancel.ord)
  chooser.connect("response", onBtnPatchServerMapsClickedResponse)
  chooser.show()

proc execBF2142ServerCommand(command: string) =
  when defined(windows):
    sendMsg(termBF2142ServerPid, command)
  elif defined(linux):
    termBF2142Server.feedChild(command)

proc onBotSkillChanged(self: pointer) {.signal.} =
  if termBF2142ServerPid > 0:
    execBF2142ServerCommand(SETTING_BOT_SKILL & " " & $round(sbtnBotSkill.value, 1) & "\r")

proc onTicketRatioChanged(self: pointer) {.signal.} =
  if termBF2142ServerPid > 0:
    execBF2142ServerCommand(SETTING_TICKET_RATIO & " " & $sbtnTicketRatio.value.int & "\r")

proc onSpawnTimeChanged(self: pointer) {.signal.} =
  if termBF2142ServerPid > 0:
    execBF2142ServerCommand(SETTING_SPAWN_TIME & " " & $sbtnSpawnTime.value.int & "\r")

proc onRoundsPerMapChanged(self: pointer) {.signal.} =
  if termBF2142ServerPid > 0:
    execBF2142ServerCommand(SETTING_ROUNDS_PER_MAP & " " & $sbtnRoundsPerMap.value.int & "\r")

proc onPlayersNeededToStartChanged(self: pointer) {.signal.} =
  if termBF2142ServerPid > 0:
    execBF2142ServerCommand(SETTING_PLAYERS_NEEDED_TO_START & " " & $sbtnPlayersNeededToStart.value.int & "\r")

proc onFriendlyFireToggled(self: CheckButton00) {.signal.} =
  var val: string = if chbtnFriendlyFire.active: "100" else: "0"
  if termBF2142ServerPid > 0:
    execBF2142ServerCommand(SETTING_SOLDIER_FRIENDLY_FIRE & " " & val & "\r")
    execBF2142ServerCommand(SETTING_VEHICLE_FRIENDLY_FIRE & " " & val & "\r")
    execBF2142ServerCommand(SETTING_SOLDIER_SPLASH_FRIENDLY_FIRE & " " & val & "\r")
    execBF2142ServerCommand(SETTING_VEHICLE_SPLASH_FRIENDLY_FIRE & " " & val & "\r")

proc onAllowNoseCamToggled(self: CheckButton00) {.signal.} =
  if termBF2142ServerPid > 0:
    execBF2142ServerCommand(SETTING_ALLOW_NOSE_CAM & " " & $chbtnAllowNoseCam.active.int & "\r")
#
## Unlocks
proc onChbtnUnlockSquadGadgetsToggled(self: CheckButton00) {.signal.} =
  config.setSectionKey(CONFIG_SECTION_UNLOCKS, CONFIG_KEY_UNLOCK_SQUAD_GADGETS, $chbtnUnlockSquadGadgets.active)
  config.writeConfig(CONFIG_FILE_NAME)
#
##

proc onApplicationWindowDraw(self: ApplicationWindow00, context: cairo.Context00): bool {.signalNoCheck.} =
  if not windowShown:
    windowShown = true

proc onQuit() =
  if termBF2142ServerPid > 0:
    echo "KILLING BF2142 GAME SERVER"
    killProcess(termBF2142ServerPid)
  if termLoginServerPid > 0:
    echo "KILLING BF2142 LOGIN/UNLOCK SERVER"
    killProcess(termLoginServerPid)
  restoreOpenSpyIfExists()

proc onApplicationWindowDestroy(self: ApplicationWindow00) {.signal.} =
  onQuit()

proc onCbxLanguagesChanged(self: ComboBox00) {.signal.} =
  if writeFile(LANGUAGE_FILE, cbxLanguages.activeId):
    newInfoDialog("Info: Restart BF2142Unlocker", "To apply language changes, you need to restart BF2142Unlocker.")

proc onApplicationActivate(application: Application) =
  let builder = newBuilder()
  builder.translationDomain = "gui" # Autotranslate all "translatable" enabled widgets
  when defined(release):
    discard builder.addFromString(GUI_GLADE, GUI_GLADE.len)
  else:
    discard builder.addFromFile("BF2142Unlocker.glade")
  window = builder.getApplicationWindow("window")
  notebook = builder.getNotebook("notebook")
  lblVersion = builder.getLabel("lblVersion")
  cbxLanguages = builder.getComboBox("cbxLanguages")
  vboxJoin = builder.getBox("vboxJoin")
  vboxJustPlay = builder.getBox("vboxJustPlay")
  cbxJoinMods = builder.getComboBox("cbxJoinMods")
  lblJoinResolutions = builder.getLabel("lblJoinResolutions")
  cbxJoinResolutions = builder.getComboBox("cbxJoinResolutions")
  txtPlayerName = builder.getEntry("txtPlayerName")
  txtIpAddress = builder.getEntry("txtIpAddress")
  chbtnAutoJoin = builder.getCheckButton("chbtnAutoJoin")
  chbtnSkipMovies = builder.getCheckButton("chbtnSkipMovies")
  chbtnWindowMode = builder.getCheckButton("chbtnWindowMode")
  btnJoin = builder.getButton("btnJoin")
  btnJustPlay = builder.getButton("btnJustPlay")
  btnJustPlayCancel = builder.getButton("btnJustPlayCancel")
  dlgCheckServers = builder.getDialog("dlgCheckServers")
  btnCheckCancel = builder.getButton("btnCheckCancel")
  throbberLoginServer = builder.getSpinner("throbberLoginServer")
  throbberGpcmServer = builder.getSpinner("throbberGpcmServer")
  throbberUnlockServer = builder.getSpinner("throbberUnlockServer")
  imgLoginServer = builder.getImage("imgLoginServer")
  imgGpcmServer = builder.getImage("imgGpcmServer")
  imgUnlockServer = builder.getImage("imgUnlockServer")
  vboxHost = builder.getBox("vboxHost")
  tblHostSettings = builder.getGrid("tblHostSettings")
  imgLevelPreview = builder.getImage("imgLevelPreview")
  cbxHostMods = builder.getComboBox("cbxHostMods")
  cbxGameMode = builder.getComboBox("cbxGameMode")
  sbtnBotSkill = builder.getSpinButton("sbtnBotSkill")
  scaleBotSkill = builder.getScale("scaleBotSkill")
  sbtnTicketRatio = builder.getSpinButton("sbtnTicketRatio")
  scaleTicketRatio = builder.getScale("scaleTicketRatio")
  sbtnSpawnTime = builder.getSpinButton("sbtnSpawnTime")
  scaleSpawnTime = builder.getScale("scaleSpawnTime")
  sbtnRoundsPerMap = builder.getSpinButton("sbtnRoundsPerMap")
  scaleRoundsPerMap = builder.getScale("scaleRoundsPerMap")
  sbtnBots = builder.getSpinButton("sbtnBots")
  scaleBots = builder.getScale("scaleBots")
  sbtnMaxPlayers = builder.getSpinButton("sbtnMaxPlayers")
  scaleMaxPlayers = builder.getScale("scaleMaxPlayers")
  sbtnPlayersNeededToStart = builder.getSpinButton("sbtnPlayersNeededToStart")
  scalePlayersNeededToStart = builder.getScale("scalePlayersNeededToStart")
  chbtnFriendlyFire = builder.getCheckButton("chbtnFriendlyFire")
  chbtnAllowNoseCam = builder.getCheckButton("chbtnAllowNoseCam")
  txtHostIpAddress = builder.getEntry("txtHostIpAddress")
  hboxMaps = builder.getBox("hboxMaps")
  listSelectableMaps = builder.getTreeView("listSelectableMaps")
  listSelectedMaps = builder.getTreeView("listSelectedMaps")
  btnAddMap = builder.getButton("btnAddMap")
  btnRemoveMap = builder.getButton("btnRemoveMap")
  btnMapMoveUp = builder.getButton("btnMapMoveUp")
  btnMapMoveDown = builder.getButton("btnMapMoveDown")
  btnHostLoginServer = builder.getButton("btnHostLoginServer")
  btnHost = builder.getButton("btnHost")
  btnHostCancel = builder.getButton("btnHostCancel")
  hboxTerms = builder.getBox("hboxTerms")
  vboxUnlocks = builder.getBox("vboxUnlocks")
  chbtnUnlockSquadGadgets = builder.getCheckButton("chbtnUnlockSquadGadgets")
  lblBF2142Path = builder.getLabel("lblBF2142Path")
  txtBF2142Path = builder.getEntry("txtBF2142Path")
  btnBF2142Path = builder.getButton("btnBF2142Path")
  lblBF2142ServerPath = builder.getLabel("lblBF2142ServerPath")
  txtBF2142ServerPath = builder.getEntry("txtBF2142ServerPath")
  btnBF2142ServerPath = builder.getButton("btnBF2142ServerPath")
  lblWinePrefix = builder.getLabel("lblWinePrefix")
  btnWinePrefix = builder.getButton("btnWinePrefix")
  txtWinePrefix = builder.getEntry("txtWinePrefix")
  lblStartupQuery = builder.getLabel("lblStartupQuery")
  txtStartupQuery = builder.getEntry("txtStartupQuery")
  btnPatchClientMaps = builder.getButton("btnPatchClientMaps")
  btnPatchServerMaps = builder.getButton("btnPatchServerMaps")

  overlayServer = builder.getOverlay("overlayServer")
  spinnerServer = builder.getSpinner("spinnerServer")
  listServer = builder.getTreeView("listServer")
  btnServerListRefresh = builder.getButton("btnServerListRefresh")
  btnServerListPlay = builder.getButton("btnServerListPlay")
  listPlayerInfo1 = builder.getTreeView("listPlayerInfo1")
  spinnerServerPlayerList1 = builder.getSpinner("spinnerServerPlayerList1")
  listPlayerInfo2 = builder.getTreeView("listPlayerInfo2")
  spinnerServerPlayerList2 = builder.getSpinner("spinnerServerPlayerList2")
  lblTeam1 = builder.getLabel("lblTeam1")
  lblTeam2 = builder.getLabel("lblTeam2")
  btnServerPlayerListRefresh = builder.getButton("btnServerPlayerListRefresh")
  wndLogin = builder.getWindow("wndLogin")
  spinnerLogin = builder.getSpinner("spinnerLogin")
  lblLoginStellaName = builder.getLabel("lblLoginStellaName")
  lblLoginGameServerName = builder.getLabel("lblLoginGameServerName")
  txtLoginUsername = builder.getEntry("txtLoginUsername")
  txtLoginPassword = builder.getEntry("txtLoginPassword")
  listLoginSoldiers = builder.getTreeView("listLoginSoldiers")
  spinnerLoginSoldiers = builder.getSpinner("spinnerLoginSoldiers")
  btnLoginCheck = builder.getButton("btnLoginCheck")
  btnLoginSoldierAdd = builder.getButton("btnLoginSoldierAdd")
  btnLoginSoldierDelete = builder.getButton("btnLoginSoldierDelete")
  chbtnLoginSave = builder.getCheckButton("chbtnLoginSave")
  frameLoginError = builder.getFrame("frameLoginError")
  lblLoginErrorTxn = builder.getLabel("lblLoginErrorTxn")
  lblLoginErrorCode = builder.getLabel("lblLoginErrorCode")
  lblLoginErrorMsg = builder.getLabel("lblLoginErrorMsg")
  btnLoginCreate = builder.getButton("btnLoginCreate")
  btnLoginPlay = builder.getButton("btnLoginPlay")
  btnLoginCancel = builder.getButton("btnLoginCancel")
  dlgLoginAddSoldier = builder.getDialog("dlgLoginAddSoldier")
  txtLoginAddSoldierName = builder.getEntry("txtLoginAddSoldierName")
  btnLoginAddSoldierOk = builder.getButton("btnLoginAddSoldierOk")
  btnLoginAddSoldierCancel = builder.getButton("btnLoginAddSoldierCancel")

  ## Set version (statically) read out from nimble file
  lblVersion.label = VERSION
  #

  ## Terminals # TODO: Create a custom widget for glade
  termJustPlayServer = newTerminal()
  termJustPlayServer.vexpand = true
  vboxJustPlay.add(termJustPlayServer)
  vboxJustPlay.reorderChild(termJustPlayServer, 0)
  termLoginServer = newTerminal()
  termLoginServer.hexpand = true
  termBF2142Server = newTerminal()
  termBF2142Server.hexpand = true
  hboxTerms.add(termLoginServer)
  when defined(windows):
    hboxTerms.add(termBF2142Server)
  elif defined(linux):
    # Adding a horizontal scrollbar to display the whole server output.
    # This is required to parse the content otherwise the content is cutted.
    termBF2142Server.connect("contents-changed", onTermBF2142ServerContentsChanged)
    termBF2142Server.connect("child-exited", onTermBF2142ServerChildExited)
    termBF2142Server.visible = true
    var box: Box = newHBox(false, 0)
    box.visible = true
    box.setSizeRequest(termBF2142Server.getCharWidth().int * 80, -1)
    box.add(termBF2142Server)
    swinBF2142Server = newScrolledWindow(nil, nil)
    swinBF2142Server.setSizeRequest(0, 300)
    swinBF2142Server.hexpand = true
    swinBF2142Server.add(box)
    hboxTerms.add(swinBF2142Server)
  #
  ## Setting current language
  discard cbxLanguages.setActiveId(currentLocale)
  #
  ## Setting styles
  var cssProvider: CssProvider = newCssProvider()
  when defined(release):
    discard cssProvider.loadFromData(GUI_CSS)
  else:
    discard cssProvider.loadFromPath("BF2142Unlocker.css")
  getDefaultScreen().addProviderForScreen(cssProvider, STYLE_PROVIDER_PRIORITY_USER)
  #
  ## Set Adwaita dark mode
  when defined(windows):
    var settings: gtk.Settings = getDefaultSettings()
    var preferDarkTheme: Value
    settings.getProperty("gtk-application-prefer-dark-theme", preferDarkTheme)
    if not preferDarkTheme.getBoolean():
      preferDarkTheme.setBoolean(true)
      settings.setProperty("gtk-application-prefer-dark-theme", preferDarkTheme)
  #
  window.setApplication(application)
  builder.connectSignals(cast[pointer](nil))
  window.show()
  loadJoinResolutions()
  loadConfig()
  loadJoinMods()
  lblJoinResolutions.visible = chbtnWindowMode.active
  cbxJoinResolutions.visible = chbtnWindowMode.active
  loadHostMods()
  if bf2142ServerPath != "":
    updatePathes()
    loadSelectableMapList()
    if loadMapList() and loadServerSettings() and loadAiSettings():
       # This if statments exists, because if any of this proc calls above fails it wont continue with the next proc call
       # TODO: Maybe create a loadAll proc because those procs are always called together
      discard # Do not return, otherwise the following visibility logic will not be executed
  when defined(windows):
    lblWinePrefix.visible = false
    txtWinePrefix.visible = false
    btnWinePrefix.visible = false
    lblStartupQuery.visible = false
    txtStartupQuery.visible = false
  if bf2142Path == "":
    notebook.currentPage = 2 # Switch to settings tab when no Battlefield 2142 path is set
    vboxJoin.visible = false
    vboxHost.visible = false
    vboxUnlocks.visible = false
  if bf2142ServerPath == "":
    btnHost.sensitive = false

  loadServerConfig()
  # updateServer()

when defined(windows): # TODO: Cleanup
  proc setlocale(category: int, other: cstring): cstring {.header: "<locale.h>", importc.}
  var LC_ALL {.header: "<locale.h>", importc.}: int
  proc bindtextdomain(domainname: cstring, dirname: cstring): cstring {.dynlib: "libintl-8.dll", importc.}
  proc bind_textdomain_codeset(domainname: cstring, codeset: cstring): cstring {.dynlib: "libintl-8.dll", importc.}
else:
  proc bindtextdomain(domainname: cstring, dirname: cstring): cstring {.header: "<libintl.h>", importc.}
  proc bind_textdomain_codeset(domainname: cstring, codeset: cstring): cstring {.header: "<libintl.h>", importc.}

proc languageLogic() =
  if fileExists(LANGUAGE_FILE):
    var currentLocaleRawOpt: Option[TaintedString] = readFile(LANGUAGE_FILE)
    if currentLocaleRawOpt.isSome:
      currentLocale = currentLocaleRawOpt.get().strip()
  discard bindtextdomain("gui", os.getCurrentDir() / "locale")
  disableSetlocale()
  if currentLocale in AVAILABLE_LANGUAGES:
    when defined(windows):
      var lcid: LCID =  LocaleNameToLCID(currentLocale.replace("_", "-"), LOCALE_ALLOW_NEUTRAL_NAMES)
      discard SetThreadLocale(lcid)
      if currentLocale == "ru_RU":
        discard bind_textdomain_codeset("gui", "KOI8-R")
      else:
        discard bind_textdomain_codeset("gui", "ISO-8859-1")
    else:
      discard setlocale(LC_ALL, currentLocale)
  else:
    # locale in lang.txt is empty or locale.txt does not exists or is not available
    currentLocale = "en_US" # Set currentLocale to "auto" if not already set
    when defined(windows):
      var lcid: LCID = LocaleNameToLCID("en-US", LOCALE_ALLOW_NEUTRAL_NAMES)
      discard SetThreadLocale(lcid)
      discard bind_textdomain_codeset("gui", "ISO-8859-1")
    else:
      discard setlocale(LC_ALL, "en_US")

proc main =
  languageLogic()
  application = newApplication()
  application.connect("activate", onApplicationActivate)
  when defined(windows) and defined(release):
    # Hiding cmd, because I could not compile it as gui.
    # Warning: Do not start gui from cmd (it becomes invisible and need to be killed via taskmanager)
    # TODO: This is a workaround.
    ShowWindow(GetConsoleWindow(), SW_HIDE)
  discard run(application)

main()