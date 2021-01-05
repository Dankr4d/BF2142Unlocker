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
  import module/windows/docpath # Required to read out My Documents path
  import module/windows/sendmsg # Required to send messages bf2142 game server
import parsecfg # Config
import md5 # Requierd to check if the current BF2142.exe is the original BF2142.exe
import times # Requierd for rudimentary level backup with epochtime suffix
import module/localaddr # Required to get all local adresses
import module/checkserver # Required to check if servers are reachable
import "macro/signal" # Required to use the custom signal pragma (checks windowShown flag and returns if false)
import module/resolution # Required to read out all possible resolutions
import patcher/bf2142 as patcherBf2142 # Required to patch BF2142 with the login/unlock server address. Also required to patch the game server
import registry/bf2142 as registryBf2142 # Required to set an empty cd key if cd key not exists.
import module/checkpermission # Required to check write permission before patching client
import math # Required for runtime configuration
import gamesrv/parser # Required to parse data out of bf2142 game server
import options # Required for error/exception handling
import sets # Required for queryServer for the optional bytes parameter from gspy module
import sequtils # Required for filter proc (filtering gamespy address port list)
import client/fesl # Required for getSoldiers proc (login and returning soldiers or error code)
import uri # Required for parseUri # TODO: REMOVE (see server.ini)
import module/strhider # Simple string hide functionality with xor and base64 to hide username/password saved in login.ini
import client/master # Required to query master server
import client/gspy # Required to query each gamespy server for game server information
import streams # Required to load server.ini (which has unknown sections)
import regex # Required to validate soldier name
import tables # Required to store ServerConfig temporary for faster server list quering (see threadUpdateServerProc)

when defined(linux):
  import gintro/vte # Required for terminal (linux only feature or currently only available on linux)
elif defined(windows):
  import streams # Required to read from process stream (login/unlock server)
  import module/windows/getprocessbyname # Required to get pid from forked process
  import module/windows/stdoutreader # Required for read stdoutput from another process
  import module/windows/gethwndbypid # Required to get window handle from pid
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

type
  BF2142UnlockerConfigQuick = object
    `mod`: string
    playername: string
    autojoin: bool
  BF2142UnlockerConfigHost = object
    `mod`: string
  BF2142UnlockerConfigUnlocks = object
    unlockSquadGadgets: bool
  BF2142UnlockerConfigSettings = object
    bf2142ClientPath: string
    when defined(linux):
      wineprefix: string
      startupQuery: string
    bf2142ServerPath: string
    windowMode: bool
    resolution: string
    skipMovies: bool
  BF2142UnlockerConfig = object
    quick: BF2142UnlockerConfigQuick
    host: BF2142UnlockerConfigHost
    unlocks: BF2142UnlockerConfigUnlocks
    settings: BF2142UnlockerConfigSettings

var bf2142UnlockerConfig: BF2142UnlockerConfig # TODO: Rename var name to config and rename var config: Config to var cfgUnlocker or something other
var documentsPath: string
var bf2142ProfilePath: string
var bf2142Profile0001Path: string

const RC {.intdefine.}: int = 0
const VERSION: string = static:
  let raw: string = staticRead("BF2142Unlocker.nimble")
  let posVersionStart: int = raw.find("version")
  let posQuoteStart: int = raw.find('"', posVersionStart)
  let posQuoteEnd: int = raw.find('"', posQuoteStart + 1)
  let ver: string = raw.substr(posQuoteStart + 1, posQuoteEnd - 1)
  if RC != 0:
    ver & " (RC: " & $RC & ")"
  else:
    ver

when defined(linux):
  const BF2142_SRV_EXE_NAME: string = "bf2142"
  const BF2142_SRV_PATCHED_EXE_NAME: string = "bf2142Patched"
else:
  const BF2142_SRV_EXE_NAME: string = "BF2142_w32ded.exe"
  const BF2142_SRV_PATCHED_EXE_NAME: string = "BF2142_w32dedPatched.exe"
const BF2142_EXE_NAME: string = "BF2142.exe"
const BF2142_PATCHED_EXE_NAME: string = "BF2142Patched.exe"
const OPENSPY_DLL_NAME: string = "RendDX9.dll"
const ORIGINAL_RENDDX9_DLL_NAME: string = "RendDX9_ori.dll" # Named by reclamation hub and remaster mod
const FILE_BACKUP_SUFFIX: string = ".original"

const ORIGINAL_CLIENT_MD5_HASH: string = "6ca5c59cd1623b78191e973b3e8088bc"
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
  SETTING_NUMERICS: seq[string] = @[
    SETTING_BOT_SKILL, SETTING_TICKET_RATIO, SETTING_SPAWN_TIME,
    SETTING_ROUNDS_PER_MAP, SETTING_SOLDIER_FRIENDLY_FIRE,
    SETTING_VEHICLE_FRIENDLY_FIRE, SETTING_SOLDIER_SPLASH_FRIENDLY_FIRE,
    SETTING_VEHICLE_SPLASH_FRIENDLY_FIRE, SETTING_TEAM_RATIO,
    SETTING_MAX_PLAYERS, SETTING_PLAYERS_NEEDED_TO_START,
    SETTING_INTERNET, SETTING_ALLOW_NOSE_CAM
  ]

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
var termHostLoginServerPid: int = 0
var termHostGameServerPid: int = 0

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
    joinServer*: Option[net.IpAddress]
    port*: Option[Port]

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
var isMultiplayerServerLoadedOnce: bool = false
var isMultiplayerServerUpdating: bool = false

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
  BLANK_BIK: string = staticRead("asset/blank.bik")
  BLANK_BIK_HASH: string = static: getMd5(BLANK_BIK)

when defined(release):
  const GUI_CSS: string = staticRead("BF2142Unlocker.css")
  const GUI_GLADE: string = staticRead("BF2142Unlocker.glade")
const
  CONFIG_FILE_NAME: string = "config/config.ini"
  CONFIG_SECTION_QUICK: string = "Quick"
  CONFIG_SECTION_HOST: string = "Host"
  CONFIG_SECTION_UNLOCKS: string = "Unlocks"
  CONFIG_SECTION_SETTINGS: string = "Settings"
  # Quick
  CONFIG_KEY_QUICK_AUTO_JOIN: string = "autojoin"
  CONFIG_KEY_QUICK_MOD: string = "mod"
  CONFIG_KEY_QUICK_PLAYER_NAME: string = "playername"
  # Host
  CONFIG_KEY_HOST_MOD: string = "mod"
  # Unlocks
  CONFIG_KEY_UNLOCKS_UNLOCK_SQUAD_GADGETS: string = "unlock_squad_gadgets"
  # Settings
  CONFIG_KEY_SETTINGS_BF2142_PATH: string = "bf2142_path"
  CONFIG_KEY_SETTINGS_BF2142_SERVER_PATH: string = "bf2142_server_path"
  CONFIG_KEY_SETTINGS_WINEPREFIX: string = "wineprefix"
  CONFIG_KEY_SETTINGS_STARTUP_QUERY: string = "startup_query"
  CONFIG_KEY_SETTINGS_SKIP_MOVIES: string = "skip_movies"
  CONFIG_KEY_SETTINGS_WINDOW_MODE: string = "window_mode"
  CONFIG_KEY_SETTINGS_RESOLUTION: string = "resolution"

const
  CONFIG_SERVER_FILE_NAME: string = "config/server.ini"
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
  CONFIG_LOGINS_FILE_NAME: string = "config/login.ini"
  CONFIG_LOGINS_KEY_USERNAME: string = "username"
  CONFIG_LOGINS_KEY_PASSWORD: string = "password"
  CONFIG_LOGINS_KEY_SOLDIER: string = "soldier"

# Required, because config loads values into widgets after gui is created,
# but the language must be set before gui init is called.
const LANGUAGE_FILE: string = "lang.txt"
const AVAILABLE_LANGUAGES: seq[string] = @["en_US", "de_DE", "ru_RU"]

const NO_PREVIEW_IMG_PATH: string = "asset/nopreview.png"

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
### Quick controls
var vboxQuick: Box
var cbxQuickMod: ComboBox
var txtQuickPlayerName: Entry
var txtQuickIpAddress: Entry
var cbtnQuickAutoJoin: CheckButton
var btnQuickConnect: Button
var btnQuickHost: Button
var btnQuickHostCancel: Button
var btnQuickSingleplayer: Button
var btnQuickSingleplayerCancel: Button
var frameQuickTerminal: Frame
var termQuickServer: Terminal
var dlgQuickCheckServer: Dialog
var spinnerQuickCheckServerLoginServer: Spinner # Rename to FeslServer
var spinnerQuickCheckServerGpcmServer: Spinner
var spinnerQuickCheckServerUnlockServer: Spinner # Rename to StatsServer?
var imgQuickCheckServerLoginServer: Image
var imgQuickCheckServerGpcmServer: Image
var imgQuickCheckServerUnlockServer: Image
var btnQuickCheckServerCancel: Button
##
### Multiplayer controls
var vboxMultiplayer: Box
var spinnerMultiplayerServers: Spinner
var trvMultiplayerServers: TreeView
var btnMultiplayerServersRefresh: Button
var btnMultiplayerServersPlay: Button
var trvMultiplayerPlayers1: TreeView
var spinnerMultiplayerPlayers1: Spinner
var trvMultiplayerPlayers2: TreeView
var spinnerMultiplayerPlayers2: Spinner
var lblMultiplayerTeam1: Label
var lblMultiplayerTeam2: Label
var btnMultiplayerPlayersRefresh: Button
var wndMultiplayerAccount: gtk.Window
var spinnerMultiplayerAccount: Spinner
var lblMultiplayerAccountStellaName: Label
var lblMultiplayerAccountGameServerName: Label
var txtMultiplayerAccountUsername: Entry
var txtMultiplayerAccountPassword: Entry
var trvMultiplayerAccountSoldiers: TreeView
var spinnerMultiplayerAccountSoldiers: Spinner
var btnMultiplayerAccountLogin: Button
var btnMultiplayerAccountSoldierAdd: Button
var btnMutliplayerAccountSoldierDel: Button
var chbtnMultiplayerAccountSave: CheckButton
var frameMultiplayerAccountError: Frame
var lblMultiplayerAccountErrorTxn: Label
var lblMultiplayerAccountErrorCode: Label
var lblMultiplayerAccountErrorMsg: Label
var btnMultiplayerAccountCreate: Button
var btnMultiplayerAccountPlay: Button
var btnMultiplayerAccountCancel: Button
var dlgMultiplayerAccountSoldier: Dialog
var txtMultiplayerAccountSoldierName: Entry
var btnMultiplayerAccountSoldierOk: Button
var dlgMultiplayerModMissing: Dialog
var lblMultiplayerModMissingLink: Label
var lbtnMultiplayerModMissing: LinkButton
var dlgMultiplayerMapMissing: Dialog
var lblMultiplayerMapMissing: Label
var bboxMultiplayerServers: ButtonBox
##
### Host controls
var vboxHost: Box
var imgHostLevelPreview: Image
var cbxHostMods: ComboBox
var cbxHostGameMode: ComboBox
var sbtnHostBotSkill: SpinButton
var scaleHostBotSkill: Scale
var sbtnHostTicketRatio: SpinButton
var scaleHostTicketRatio: Scale
var sbtnHostSpawnTime: SpinButton
var scaleHostSpawnTime: Scale
var sbtnHostRoundsPerMap: SpinButton
var scaleHostRoundsPerMap: Scale
var sbtnHostBots: SpinButton
var scaleHostBots: Scale
var sbtnHostMaxPlayers: SpinButton
var scaleHostMaxPlayers: Scale
var sbtnHostPlayersNeededToStart: SpinButton
var scaleHostPlayersNeededToStart: Scale
var chbtnHostFriendlyFire: CheckButton
var chbtnHostAllowNoseCam: CheckButton
  # teamratio (also for coop?)
  # autobalance (also for coop?)
var txtHostIpAddress: Entry
var trvHostSelectableMap: TreeView
var trvHostSelectedMap: TreeView
var btnHostMapAdd: Button
var btnHostMapDel: Button
var btnHostMapMoveUp: Button
var btnHostMapMoveDown: Button
var btnHostGameServer: Button
var btnHostCancel: Button
var hboxHostTerms: Box
var termHostLoginServer: Terminal
var termHostGameServer: Terminal
when defined(linux):
  var swinHostGameServer: ScrolledWindow
##
### Unlock controls
var vboxUnlocks: Box
var chbtnUnlocksUnlockSquadGadgets: CheckButton
##
### Settings controls
var vboxSettings: Box
var lblSettingsBF2142ClientPath: Label
var txtSettingsBF2142ClientPath: Entry
var btnSettingsBF2142ClientPath: Button
var lblSettingsBF2142ServerPath: Label
var txtSettingsBF2142ServerPath: Entry
var btnSettingsBF2142ServerPath: Button
var lblSettingsWinePrefix: Label
var txtSettingsWinePrefix: Entry
var btnSettingsWinePrefix: Button
var lblSettingsStartupQuery: Label
var txtSettingsStartupQuery: Entry
var chbtnSettingsSkipMovies: CheckButton
var chbtnSettingsWindowMode: CheckButton
var lblSettingsResolution: Label
var cbxSettingsResolution: ComboBox
var dlgSettingsBF2142ClientPathDetected: Dialog
var lblSettingsBF2142ClientPathDetected: Label
##

### Exception procs # TODO: Replace tuple results with Option
proc onQuit()

import logging
var logger: FileLogger = newFileLogger("log/error.log", fmtStr = verboseFmtStr)
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
# TODO: Check if this counts as modified content when trying to join a server. If yes, fix invalid xml on the fly.
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


proc getBF2142UnlockerConfig(path: string = CONFIG_FILE_NAME): BF2142UnlockerConfig =
  # TODO: Try'n catch because we parse booleans
  if not fileExists(CONFIG_FILE_NAME):
    config = newConfig()
  else:
    config = loadConfig(CONFIG_FILE_NAME)

  # Quick
  result.quick.autoJoin = parseBool(config.getSectionValue(CONFIG_SECTION_QUICK, CONFIG_KEY_QUICK_AUTO_JOIN, "false"))
  result.quick.`mod` = config.getSectionValue(CONFIG_SECTION_QUICK, CONFIG_KEY_QUICK_MOD, "bf2142")
  result.quick.playername = config.getSectionValue(CONFIG_SECTION_QUICK, CONFIG_KEY_QUICK_PLAYER_NAME, "Player")

  # Host
  result.host.`mod` = config.getSectionValue(CONFIG_SECTION_HOST, CONFIG_KEY_HOST_MOD, "bf2142")

  # Unlocks
  result.unlocks.unlockSquadGadgets = parseBool(config.getSectionValue(CONFIG_SECTION_UNLOCKS, CONFIG_KEY_UNLOCKS_UNLOCK_SQUAD_GADGETS, "false"))

  # Settings
  result.settings.bf2142ClientPath = config.getSectionValue(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_BF2142_PATH)
  result.settings.bf2142ServerPath = config.getSectionValue(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_BF2142_SERVER_PATH)
  when defined(linux):
    result.settings.winePrefix = config.getSectionValue(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_WINEPREFIX)
    result.settings.startupQuery = config.getSectionValue(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_STARTUP_QUERY, "/usr/bin/wine")
  result.settings.skipMovies = parseBool(config.getSectionValue(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_SKIP_MOVIES, "false"))
  result.settings.windowMode = parseBool(config.getSectionValue(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_WINDOW_MODE, "false"))
  result.settings.resolution = config.getSectionValue(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_RESOLUTION, "800x600") # TODO: Rename to windowResolution


proc applyBF2142UnlockerConfig(config: BF2142UnlockerConfig) =
  # Quick
  if not cbxQuickMod.setActiveId(config.quick.`mod`):
    # When mod is removed or renamed set bf2142 as fallback
    discard cbxQuickMod.setActiveId("bf2142")
  txtQuickPlayerName.text = config.quick.playername
  cbtnQuickAutoJoin.active = config.quick.autoJoin

  # Host
  if not cbxHostMods.setActiveId(config.host.`mod`):
    # When mod is removed or renamed set bf2142 as fallback
    discard cbxHostMods.setActiveId("bf2142")

  # Unlocks
  chbtnUnlocksUnlockSquadGadgets.active = config.unlocks.unlockSquadGadgets

  # Settings
  txtSettingsBF2142ClientPath.text = config.settings.bf2142ClientPath
  txtSettingsBF2142ServerPath.text = config.settings.bf2142ServerPath
  when defined(linux): # TODO: Should we really do this in applyBF2142UnlockerConfig?
    txtSettingsWinePrefix.text = config.settings.winePrefix
    if config.settings.winePrefix != "":
      documentsPath = txtSettingsWinePrefix.text / "drive_c" / "users" / $getlogin() / "My Documents"
  elif defined(windows):
    documentsPath = getDocumentsPath()
  updateProfilePathes()
  when defined(linux):
    txtSettingsStartupQuery.text = config.settings.startupQuery
  chbtnSettingsSkipMovies.active = config.settings.skipMovies
  chbtnSettingsWindowMode.active = config.settings.windowMode
  if not cbxSettingsResolution.setActiveId(config.settings.resolution):
    cbxSettingsResolution.setActive(0)


proc backupOpenSpyIfExists() =
  let openspyDllPath: string = bf2142UnlockerConfig.settings.bf2142ClientPath / OPENSPY_DLL_NAME
  let originalRendDX9Path: string = bf2142UnlockerConfig.settings.bf2142ClientPath / ORIGINAL_RENDDX9_DLL_NAME
  if not fileExists(openspyDllPath) or not fileExists(originalRendDX9Path): # TODO: Inform user if original file could not be found if openspy dll exists
    return
  let originalRendDX9RawOpt: Option[TaintedString] = readFile(originalRendDX9Path)
  if originalRendDX9RawOpt.isNone:
    return
  let originalRendDX9Hash: string = getMD5(originalRendDX9RawOpt.get())
  if originalRendDX9Hash == ORIGINAL_RENDDX9_MD5_HASH:
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
  let openspyDllBackupPath: string = bf2142UnlockerConfig.settings.bf2142ClientPath / OPENSPY_DLL_NAME & FILE_BACKUP_SUFFIX
  let openspyDllRestorePath: string = bf2142UnlockerConfig.settings.bf2142ClientPath / OPENSPY_DLL_NAME
  if not fileExists(openspyDllBackupPath):
    return
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
    if valMapName.getString() == gsdata.mapName and valMapMode.getString() == gsdata.mapMode and
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
    imgHostLevelPreview.setFromPixbuf(pixbuf)
  elif fileExists(NO_PREVIEW_IMG_PATH):
    imgHostLevelPreview.setFromFile(NO_PREVIEW_IMG_PATH) # TODO: newPixbufFromBytes
  else:
    imgHostLevelPreview.clear()

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
  trvHostSelectableMap.clear()
  var gameMode: string = cbxHostGameMode.activeId
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
            trvHostSelectableMap.appendMap(folder.path, gameMode, parseInt(xmlMapType.attr("players")))
          break
    except xmlparser.XmlError:
      invalidXmlFiles.add(descPath)
    except system.IOError:
      continue # Maybe desc file does not exists or is named wrong.
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
  var currentModPath: string = bf2142UnlockerConfig.settings.bf2142ServerPath / "mods" / cbxHostMods.activeId
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

    if setting in SETTING_NUMERICS:
      value = value.replace("\"", "")

    case setting:
      of SETTING_ROUNDS_PER_MAP:
        if save:
          value = $sbtnHostRoundsPerMap.value.toInt()
        else:
          sbtnHostRoundsPerMap.value = value.parseFloat()
      of SETTING_BOT_SKILL:
        if save:
          value = $sbtnHostBotSkill.value
        else:
          sbtnHostBotSkill.value = value.parseFloat()
      of SETTING_TICKET_RATIO:
        if save:
          value = $sbtnHostTicketRatio.value.toInt()
        else:
          sbtnHostTicketRatio.value = value.parseFloat()
      of SETTING_SPAWN_TIME:
        if save:
          value = $sbtnHostSpawnTime.value.toInt()
        else:
          sbtnHostSpawnTime.value = value.parseFloat()
      of SETTING_SOLDIER_FRIENDLY_FIRE,
          SETTING_VEHICLE_FRIENDLY_FIRE,
          SETTING_SOLDIER_SPLASH_FRIENDLY_FIRE,
          SETTING_VEHICLE_SPLASH_FRIENDLY_FIRE:
        if save:
          value = if chbtnHostFriendlyFire.active: "100" else: "0"
        else:
          chbtnHostFriendlyFire.active = if value == "100": true else: false
      of SETTING_ALLOW_NOSE_CAM:
        if save:
          value = $chbtnHostAllowNoseCam.active.int
        else:
          chbtnHostAllowNoseCam.active = value.parseBool()
      of SETTING_MAX_PLAYERS:
        if save:
          value = $sbtnHostMaxPlayers.value.toInt()
        else:
          sbtnHostMaxPlayers.value = value.parseFloat()
      of SETTING_PLAYERS_NEEDED_TO_START:
        if save:
          value = $sbtnHostPlayersNeededToStart.value.toInt()
        else:
          sbtnHostPlayersNeededToStart.value = value.parseFloat()
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
        line = AISETTING_BOTS & " " & $sbtnHostBots.value.toInt()
      else:
        sbtnHostBots.value = line.split(' ')[1].parseFloat()
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
  for map in trvHostSelectedMap.maps:
    mapListCon.add("mapList.append " & map.mapName & ' ' & map.mapMode & ' ' & $map.mapSize & '\n')
  return writeFile(currentMapListPath, mapListCon)

proc loadMapList(): bool =
  var fileTpl: tuple[opened: bool, file: system.File] = open(currentMapListPath, fmRead)
  if not fileTpl.opened:
    return false
  var line, mapName, mapMode, mapSize: string
  trvHostSelectedMap.clear()
  while fileTpl.file.readLine(line):
    if not line.toLower().startsWith("maplist"):
      continue
    (mapName, mapMode, mapSize) = line.splitWhitespace()[1..3]
    trvHostSelectedMap.appendMap(mapName, mapMode, parseInt(mapSize))
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
  let store = listStore(cbxQuickMod.getModel())
  store.clear()
  if bf2142UnlockerConfig.settings.bf2142ClientPath != "":
    for folder in walkDir(bf2142UnlockerConfig.settings.bf2142ClientPath / "mods", true):
      if folder.kind != pcDir:
        continue
      if folder.path.toLower() == "project_remaster_sp":
        continue
      valMod.setString(folder.path.toLower())
      store.append(iter)
      store.setValue(iter, 0, valMod)
      store.setValue(iter, 1, valMod)

proc loadJoinResolutions() =
  var valResolution: Value
  var valWidth: Value
  var valHeight: Value
  discard valResolution.init(g_string_get_type())
  discard valWidth.init(g_uint_get_type())
  discard valHeight.init(g_uint_get_type())
  var iter: TreeIter
  let store = listStore(cbxSettingsResolution.getModel())
  store.clear()
  for resolution in getAvailableResolutions():
    valResolution.setString($resolution.width & "x" & $resolution.height)
    valWidth.setUint(cast[int](resolution.width))
    valHeight.setUint(cast[int](resolution.height))
    store.append(iter)
    store.setValue(iter, 0, valResolution)
    store.setValue(iter, 1, valResolution)
    store.setValue(iter, 2, valWidth)
    store.setValue(iter, 3, valHeight)

proc getSelectedResolution(): tuple[width, height: uint16] =
  var iter: TreeIter
  let store = listStore(cbxSettingsResolution.getModel())
  discard cbxSettingsResolution.getActiveIter(iter)
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
  if bf2142UnlockerConfig.settings.bf2142ServerPath != "":
    for folder in walkDir(bf2142UnlockerConfig.settings.bf2142ServerPath / "mods", true):
      if folder.kind != pcDir:
        continue
      if folder.path.toLower() == "project_remaster_sp":
        continue
      valMod.setString(folder.path)
      store.append(iter)
      store.setValue(iter, 0, valMod)
      store.setValue(iter, 1, valMod)

proc applyHostRunningSensitivity(running: bool) =
  btnHostGameServer.visible = not running
  btnHostCancel.visible = running
  hboxHostTerms.visible = running
  termHostLoginServer.visible = running
  when defined(windows):
    termHostGameServer.visible = running
  elif defined(linux):
    swinHostGameServer.visible = running
  btnQuickHost.sensitive = not running
  btnQuickSingleplayer.sensitive = not running

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

proc startBF2142(options: BF2142Options): bool = # TODO: Other params and also an joinGSPort
  var command: string
  when defined(linux):
    when defined(debug):
      command.add("WINEDEBUG=fixme-all,err-winediag" & ' ') # TODO: Remove some nasty fixme's and errors for development
    if txtSettingsWinePrefix.text != "":
      command.add("WINEPREFIX=" & txtSettingsWinePrefix.text & ' ')
  # command.add("WINEARCH=win32" & ' ') # TODO: Implement this if user would like to run this in 32 bit mode (only requierd on first run)
  when defined(linux):
    if txtSettingsStartupQuery.text != "":
      command.add(txtSettingsStartupQuery.text & ' ')
  command.add(BF2142_PATCHED_EXE_NAME & ' ')
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
  if isSome(options.eaAccountName):
    command.add("+eaAccountName " & get(options.eaAccountName) & ' ')
  if isSome(options.eaAccountPassword):
    command.add("+eaAccountPassword " & get(options.eaAccountPassword) & ' ')
  if isSome(options.soldierName):
    command.add("+soldierName " & get(options.soldierName) & ' ')
  if isSome(options.joinServer):
    command.add("+joinServer " & $get(options.joinServer) & ' ')
    if isSome(options.port):
      command.add("+port " & $get(options.port) & ' ')
  when defined(linux): # TODO: Check if bf2142Path is neccessary
    let processCommand: string = command
  elif defined(windows):
    let processCommand: string = bf2142UnlockerConfig.settings.bf2142ClientPath & '\\' & command
  var process: Process = startProcess(command = processCommand, workingDir = bf2142UnlockerConfig.settings.bf2142ClientPath,
    options = {poStdErrToStdOut, poParentStreams, poEvalCommand, poEchoCmd}
  )
  return true

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
  let storePlayerInfo1: ListStore = listStore(trvMultiplayerPlayers1.getModel())
  let storePlayerInfo2: ListStore = listStore(trvMultiplayerPlayers2.getModel())
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

  lblMultiplayerTeam1.text = gspy.team.team_t[0].toUpper()
  lblMultiplayerTeam2.text = gspy.team.team_t[1].toUpper()

  btnMultiplayerPlayersRefresh.sensitive = true
  spinnerMultiplayerPlayers1.stop()
  spinnerMultiplayerPlayers2.stop()
  timerUpdatePlayerListId = 0

  channelUpdatePlayerList.close()
  return SOURCE_REMOVE

proc threadUpdatePlayerListProc(gspyIpPort: tuple[gspyIp: IpAddress, gspyPort: Port]) =
  let gspy: GSpy = queryAll(gspyIpPort.gspyIP, gspyIpPort.gspyPort)

  channelUpdatePlayerList.send((gspy, gspyIpPort.gspyIp, gspyIpPort.gspyPort))

proc updatePlayerListAsync() =
  trvMultiplayerPlayers1.clear()
  trvMultiplayerPlayers2.clear()
  spinnerMultiplayerPlayers1.start()
  spinnerMultiplayerPlayers2.start()
  btnMultiplayerServersPlay.sensitive = true
  btnMultiplayerPlayersRefresh.sensitive = false

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
  let store = listStore(trvMultiplayerServers.getModel())
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

  spinnerMultiplayerServers.stop()
  spinnerMultiplayerPlayers1.stop()
  spinnerMultiplayerPlayers2.stop()
  btnMultiplayerServersRefresh.sensitive = true
  if isServerSelected:
    # TODO: Maybe we can select the first server then this global var is obsolet.
    #       Options would be also a possibility but then we need to call get every currentServer access
    trvMultiplayerServers.selectServer = currentServer
    btnMultiplayerServersPlay.sensitive = true
    btnMultiplayerPlayersRefresh.sensitive = true
    updatePlayerListAsync()

  channelUpdateServer.close()
  isMultiplayerServerUpdating = false
  isMultiplayerServerLoadedOnce = true
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
    gslistTmp = queryGameServerList(serverConfig.stella_ms, Port(28910), serverConfig.game_name, serverConfig.game_key, serverConfig.game_str, 500)
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
  isMultiplayerServerUpdating = true

  trvMultiplayerServers.clear()
  trvMultiplayerPlayers1.clear()
  trvMultiplayerPlayers2.clear()
  spinnerMultiplayerServers.start()
  btnMultiplayerServersRefresh.sensitive = false
  btnMultiplayerServersPlay.sensitive = false
  btnMultiplayerPlayersRefresh.sensitive = false

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
    btnMultiplayerAccountSoldierAdd.sensitive = isNone(data.ex)
    btnMutliplayerAccountSoldierDel.sensitive = false
    btnMultiplayerAccountPlay.sensitive = false
    spinnerMultiplayerAccount.stop()
  of FeslCommand.Login:
    if data.login.save and isNone(data.ex):
      saveLogin(currentServerConfig.server_name, data.login.username, data.login.password, get(data.login.soldier, ""))
    btnMultiplayerAccountSoldierAdd.sensitive = isNone(data.ex)
    if isNone(data.ex):
      trvMultiplayerAccountSoldiers.soldiers = data.login.soldiers
      if isSome(data.login.soldier):
        trvMultiplayerAccountSoldiers.selectedSoldier = get(data.login.soldier) # TODO: `selectedSoldier=` should raise an exception if soldier doesn't exists
      let isSoldierSelected: bool = isSome(trvMultiplayerAccountSoldiers.selectedSoldier) # TODO: `selectedSoldier` should raise an exception if soldier doesn't exists
      btnMultiplayerAccountPlay.sensitive = isSoldierSelected
      btnMutliplayerAccountSoldierDel.sensitive = isSoldierSelected
    else:
      btnMultiplayerAccountPlay.sensitive = false
      btnMutliplayerAccountSoldierDel.sensitive = false
    btnMultiplayerAccountLogin.sensitive = true
    btnMultiplayerAccountCreate.sensitive = true
    spinnerMultiplayerAccount.stop()
  of FeslCommand.AddSoldier:
    if isNone(data.ex):
      trvMultiplayerAccountSoldiers.soldiers = data.soldier.soldiers
      trvMultiplayerAccountSoldiers.selectedSoldier = data.soldier.soldier
      ignoreEvents = true
      txtMultiplayerAccountSoldierName.text = ""
      ignoreEvents = false
      btnMultiplayerAccountPlay.sensitive = true
    btnMutliplayerAccountSoldierDel.sensitive = true
    spinnerMultiplayerAccountSoldiers.stop()
  of FeslCommand.DelSoldier:
    if isNone(data.ex):
      # trvMultiplayerAccountSoldiers.selectNext()
      trvMultiplayerAccountSoldiers.removeSelected()
    if chbtnMultiplayerAccountSave.active and isNone(data.ex): # TODO
      saveLogin(currentServerConfig.server_name, txtMultiplayerAccountUsername.text, txtMultiplayerAccountPassword.text, "") # TODO
    btnMutliplayerAccountSoldierDel.sensitive = trvMultiplayerAccountSoldiers.hasEntries()
    btnMultiplayerAccountPlay.sensitive = isSome(trvMultiplayerAccountSoldiers.selectedSoldier)
    spinnerMultiplayerAccountSoldiers.stop()
  wndMultiplayerAccount.sensitive = true

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

    frameMultiplayerAccountError.visible = true
    lblMultiplayerAccountErrorTxn.text = $ex.exType
    lblMultiplayerAccountErrorCode.text = $ex.code
    lblMultiplayerAccountErrorMsg.text = errorMsg

  else:
    frameMultiplayerAccountError.visible = false
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
        sleep(100)
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
        fesl.connect(socket, stella)
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
  trvMultiplayerAccountSoldiers.clear()
  spinnerMultiplayerAccount.start()
  wndMultiplayerAccount.sensitive = false
  var data: ThreadFeslData = ThreadFeslData(command: FeslCommand.Create)
  var createData: ThreadFeslCreateData
  createData.stella = parseUri(currentServerConfig.stella_prod).hostname
  createData.username = txtMultiplayerAccountUsername.text
  createData.password = txtMultiplayerAccountPassword.text
  createData.save = save
  data.create = createData
  channelFeslThread.send(data)

proc loginAsync(save: bool, soldier: Option[string] = none(string)) =
  trvMultiplayerAccountSoldiers.clear()
  spinnerMultiplayerAccount.start()
  wndMultiplayerAccount.sensitive = false
  var data: ThreadFeslData = ThreadFeslData(command: FeslCommand.Login)
  var loginData: ThreadFeslLoginData
  loginData.stella = parseUri(currentServerConfig.stella_prod).hostname
  loginData.username = txtMultiplayerAccountUsername.text
  loginData.password = txtMultiplayerAccountPassword.text
  loginData.save = save
  loginData.soldier = soldier
  data.login = loginData
  channelFeslThread.send(data)

proc onMultiplayerPatchAndStartButtonClicked(self: Button, serverConfig: ServerConfig) =
  patchClient(bf2142UnlockerConfig.settings.bf2142ClientPath / BF2142_PATCHED_EXE_NAME, PatchConfig(serverConfig))
  backupOpenSpyIfExists()
  when defined(windows): # TODO: Reading/setting cd key on linux
    setCdKeyIfNotExists() # Checking if cd key exists, if not an empty cd key is set
  discard enableDisableIntroMovies(bf2142UnlockerConfig.settings.bf2142ClientPath / "mods" / "bf2142" / "Movies", chbtnSettingsSkipMovies.active)

  var options: BF2142Options
  options.modPath = some("mods/bf2142")
  options.menu = some(true)
  options.fullscreen = some(not chbtnSettingsWindowMode.active)
  if chbtnSettingsWindowMode.active:
    var resolution: tuple[width, height: uint16] = getSelectedResolution()
    options.szx = some(resolution.width)
    options.szy = some(resolution.height)
  options.widescreen = some(true)
  discard startBF2142(options)

proc fillMultiplayerPatchAndStartBox() =
  var button: Button
  for serverConfig in serverConfigs:
    button = newButton(serverConfig.server_name)
    button.visible = true
    button.connect("clicked", onMultiplayerPatchAndStartButtonClicked, serverConfig)
    bboxMultiplayerServers.add(button)
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
  if pid == termHostGameServerPid:
    termHostGameServerPid = 0
  elif pid == termHostLoginServerPid:
    termHostLoginServerPid = 0

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
  proc ontermHostGameServerContentsChanged(terminal: Terminal) =
    var text: string = termHostGameServer.getText(nil, nil, cast[var ptr GArray00](nil))
    if text.strip() == "":
      return
    var gsdata: GsData = text.parseGsData()
    if gsdata.status != lastGsStatus:
      trvHostSelectedMap.update(gsdata)
      lastGsStatus = gsdata.status
  proc ontermHostGameServerChildExited(terminal: Terminal, exitCode: int) =
    # Clears the colorized rows.
    trvHostSelectedMap.update(GsData())

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
      var timerDataGameServer: TimerDataGameServer = TimerDataGameServer(terminal: terminal, treeView: trvHostSelectedMap)
      discard timeoutAdd(250, timerGameServer, timerDataGameServer)
      threadGameServer.createThread(threadGameServerProc, result) # result = pid
    else:
      # Login/unlock server
      var timerLoginUnlockServer: TimerDataLoginUnlockServer = TimerDataLoginUnlockServer(terminal: terminal)
      discard timeoutAdd(250, timerLoginUnlockServer, timerLoginUnlockServer)
      threadLoginUnlockServer.createThread(threadLoginUnlockServerProc, process)

proc startBF2142Server() =
  termHostGameServer.setSizeRequest(0, 300)
  var stupidPbSymlink: string = bf2142UnlockerConfig.settings.bf2142ServerPath / "pb"
  if symlinkExists(stupidPbSymlink):
    if not removeFile(stupidPbSymlink):
      return
  when defined(linux):
    var ldLibraryPath: string = bf2142UnlockerConfig.settings.bf2142ServerPath / "bin" / "amd-64"
    ldLibraryPath &= ":" & os.getCurrentDir()
    termHostGameServerPid = termHostGameServer.startProcess(
      command = "bin" / "amd-64" / BF2142_SRV_PATCHED_EXE_NAME,
      params = "+modPath mods/" & cbxHostMods.activeId,
      workingDir = bf2142UnlockerConfig.settings.bf2142ServerPath,
      env = fmt"TERM=xterm LD_LIBRARY_PATH={ldLibraryPath}"
    )
  elif defined(windows):
    termHostGameServerPid = termHostGameServer.startProcess(
      command = BF2142_SRV_PATCHED_EXE_NAME,
      params = "+modPath mods/" & cbxHostMods.activeId,
      workingDir = bf2142UnlockerConfig.settings.bf2142ServerPath,
      searchForkedProcess = true
    )

proc startLoginServer(term: Terminal, ipAddress: IpAddress) =
  term.setSizeRequest(0, 300)
  when defined(linux):
    # TODO: Fix this crappy code below. Did this only to get version 0.9.3 out.
    termHostLoginServerPid = term.startProcess(command = fmt"./BF2142UnlockerSrv {$ipAddress} {$chbtnUnlocksUnlockSquadGadgets.active}")
    var tryCnt: int = 0
    while tryCnt < 3:
      if isAddrReachable($ipAddress, Port(18300), 1_000):
        break
      else:
        tryCnt.inc()
        sleep(250)
  elif defined(windows):
    termHostLoginServerPid = term.startProcess(command = fmt"BF2142UnlockerSrv.exe {$ipAddress} {$chbtnUnlocksUnlockSquadGadgets.active}")
##

### Events
## Quick
proc patchAndStartLogic(): bool =
  let ipAddress: string = txtQuickIpAddress.text.strip()
  txtQuickPlayerName.text = txtQuickPlayerName.text.strip()
  var invalidStr: string
  if cbtnQuickAutoJoin.active and (ipAddress == "127.0.0.1" or ipAddress == "localhost"):
    invalidStr.add("\t* Auto join feature won't work if you're trying to connect to a gameserver with 127.0.0.1 or localhost.\n")
  if not ipAddress.isIpAddress():
    invalidStr.add("\t* Your IP-address is not valid.\n")
  elif ipAddress.parseIpAddress().family == IPv6:
    invalidStr.add("\t* IPv6 not testes!\n") # TODO: Add ignore?
  if txtQuickPlayerName.text == "":
    invalidStr.add("\t* You need to specify a playername with at least one character.\n")
  if bf2142UnlockerConfig.settings.bf2142ClientPath == "": # TODO: Some more checkes are requierd (e.g. does BF2142.exe exists)
    invalidStr.add("\t* You need to specify your Battlefield 2142 path in \"Settings\"-Tab.\n")
  when defined(linux):
    if txtSettingsWinePrefix.text == "":
      invalidStr.add("\t* You need to specify your wine prefix (in \"Settings\"-Tab).\n")
  if invalidStr.len > 0:
    newInfoDialog("Error", invalidStr)
    return false

  ## Check Logic (TODO: Cleanup and check servers in thread)
  # var canConnect: bool = true
  # spinnerQuickCheckServerLoginServer.visible = true
  # spinnerQuickCheckServerGpcmServer.visible = true
  # spinnerQuickCheckServerUnlockServer.visible = true
  # imgQuickCheckServerLoginServer.visible = false
  # imgQuickCheckServerGpcmServer.visible = false
  # imgQuickCheckServerUnlockServer.visible = false
  # # Login server
  # if isAddrReachable(ipAddress, Port(18300), 1_000):
  #   spinnerQuickCheckServerLoginServer.visible = false
  #   imgQuickCheckServerLoginServer.visible = true
  #   imgQuickCheckServerLoginServer.setFromIconName("gtk-apply", 0)
  # else:
  #   canConnect = false
  #   spinnerQuickCheckServerLoginServer.visible = false
  #   imgQuickCheckServerLoginServer.visible = true
  #   imgQuickCheckServerLoginServer.setFromIconName("gtk-cancel", 0)
  # # GPCM server
  # if isAddrReachable(ipAddress, Port(29900), 1_000):
  #   spinnerQuickCheckServerGpcmServer.visible = false
  #   imgQuickCheckServerGpcmServer.visible = true
  #   imgQuickCheckServerGpcmServer.setFromIconName("gtk-apply", 0)
  # else:
  #   canConnect = false
  #   spinnerQuickCheckServerGpcmServer.visible = false
  #   imgQuickCheckServerGpcmServer.visible = true
  #   imgQuickCheckServerGpcmServer.setFromIconName("gtk-cancel", 0)
  # # Unlock server
  # if isAddrReachable(ipAddress, Port(8085), 1_000):
  #   spinnerQuickCheckServerUnlockServer.visible = false
  #   imgQuickCheckServerUnlockServer.visible = true
  #   imgQuickCheckServerUnlockServer.setFromIconName("gtk-apply", 0)
  # else:
  #   canConnect = false
  #   spinnerQuickCheckServerUnlockServer.visible = false
  #   imgQuickCheckServerUnlockServer.visible = true
  #   imgQuickCheckServerUnlockServer.setFromIconName("gtk-cancel", 0)
  # if not canConnect:
  #   dlgQuickCheckServer.show()
  #   # TODO: When checks are done in a thread, this dialog would be always shown when connecting,
  #   #       and if every server is reachable autoamtically hidden.
  #   return
  #

  # config.setSectionKey(CONFIG_SECTION_QUICK, CONFIG_KEY_IP_ADDRESS, ipAddress)
  config.setSectionKey(CONFIG_SECTION_QUICK, CONFIG_KEY_QUICK_MOD, cbxQuickMod.activeId)
  config.setSectionKey(CONFIG_SECTION_QUICK, CONFIG_KEY_QUICK_PLAYER_NAME, txtQuickPlayerName.text)
  config.setSectionKey(CONFIG_SECTION_QUICK, CONFIG_KEY_QUICK_AUTO_JOIN, $cbtnQuickAutoJoin.active)
  config.writeConfig(CONFIG_FILE_NAME)

  if not fileExists(bf2142UnlockerConfig.settings.bf2142ClientPath / BF2142_PATCHED_EXE_NAME):
    if not copyFile(bf2142UnlockerConfig.settings.bf2142ClientPath / BF2142_EXE_NAME, bf2142UnlockerConfig.settings.bf2142ClientPath / BF2142_PATCHED_EXE_NAME):
      return
  if not hasWritePermission(bf2142UnlockerConfig.settings.bf2142ClientPath / BF2142_PATCHED_EXE_NAME):
    newInfoDialog(
      dgettext("gui", "NO_WRITE_PERMISSION_TITLE"),
      dgettext("gui", "NO_WRITE_PERMISSION_MSG") % [bf2142UnlockerConfig.settings.bf2142ClientPath / BF2142_PATCHED_EXE_NAME]
    )
    return

  var patchConfig: PatchConfig
  patchConfig.stella_prod = "http://" & ipAddress & ":8085/"
  patchConfig.stella_ms = ipAddress
  patchConfig.ms = ipAddress
  patchConfig.available = "%s.available.gamespy.com" # TODO: Slows BF2142 on startup when set to 127.0.0.1
  patchConfig.motd = "http://" & ipAddress & "/"
  patchConfig.master = ipAddress
  patchConfig.gamestats = ipAddress
  patchConfig.gpcm = ipAddress
  patchConfig.gpsp = ipAddress
  patchClient(bf2142UnlockerConfig.settings.bf2142ClientPath / BF2142_PATCHED_EXE_NAME, patchConfig)

  backupOpenSpyIfExists()

  saveBF2142Profile(txtQuickPlayerName.text, txtQuickPlayerName.text)

  when defined(windows): # TODO: Reading/setting cd key on linux
    setCdKeyIfNotExists() # Checking if cd key exists, if not an empty cd key is set

  if not enableDisableIntroMovies(bf2142UnlockerConfig.settings.bf2142ClientPath / "mods" / cbxQuickMod.activeId / "Movies", chbtnSettingsSkipMovies.active):
    return

  var options: BF2142Options
  options.modPath = some("mods/" & cbxQuickMod.activeId)
  options.menu = some(true)
  options.fullscreen = some(not chbtnSettingsWindowMode.active)
  if chbtnSettingsWindowMode.active:
    var resolution: tuple[width, height: uint16] = getSelectedResolution()
    options.szx = some(resolution.width)
    options.szy = some(resolution.height)
  options.widescreen = some(true)
  options.eaAccountName = some(txtQuickPlayerName.text)
  options.eaAccountPassword = some("A")
  options.soldierName = some(txtQuickPlayerName.text)
  if cbtnQuickAutoJoin.active:
    options.joinServer = some(ipAddress.parseIpAddress())
    options.port = some(Port(17567))
  return startBF2142(options)

proc onBtnQuickConnectClicked(self: Button00) {.signal.} =
  discard patchAndStartLogic()

proc startQuickServer(singleplayer: bool) =
  var ipAddress: IpAddress
  if singleplayer:
    ipAddress = parseIpAddress("127.0.0.1")
  else:
    ipAddress = parseIpAddress("0.0.0.0")
  txtQuickIpAddress.text = "127.0.0.1"
  termQuickServer.startLoginServer(ipAddress)
  termQuickServer.visible = true
  var prevAutoJoinVal: bool = cbtnQuickAutoJoin.active
  cbtnQuickAutoJoin.active = false
  if patchAndStartLogic():
    if singleplayer:
      btnQuickSingleplayer.visible = false
      btnQuickSingleplayerCancel.visible = true
      btnQuickHost.sensitive = false
    else:
      btnQuickHost.visible = false
      btnQuickHostCancel.visible = true
      btnQuickSingleplayer.sensitive = false
    btnHostGameServer.sensitive = false
  else:
    cbtnQuickAutoJoin.active = prevAutoJoinVal
    killProcess(termHostLoginServerPid)

proc stopQuickSever(singleplayer: bool) =
  killProcess(termHostLoginServerPid)
  txtQuickIpAddress.text = ""
  termQuickServer.clear()
  termQuickServer.visible = false
  if singleplayer:
    btnQuickSingleplayer.visible = true
    btnQuickSingleplayerCancel.visible = false
    btnQuickHost.sensitive = true
  else:
    btnQuickHost.visible = true
    btnQuickHostCancel.visible = false
    btnQuickSingleplayer.sensitive = true
  btnHostGameServer.sensitive = true

proc onBtnQuickHostClicked(self: Button00) {.signal.} =
  startQuickServer(false)

proc onBtnQuickHostCancelClicked(self: Button00) {.signal.} =
  stopQuickSever(false)

proc onBtnQuickSingleplayerClicked(self: Button00) {.signal.} =
  startQuickServer(true)

proc onBtnQuickSingleplayerCancelClicked(self: Button00) {.signal.} =
  stopQuickSever(true)

proc onBtnQuickCheckServerCancelClicked(self: Button00) {.signal.} =
  dlgQuickCheckServer.hide()

proc onBtnHostMapAddClicked(self: Button00) {.signal.} =
  var mapName, mapMode: string
  var mapSize: int
  (mapName, mapMode, mapSize) = trvHostSelectableMap.selectedMap
  if mapName == "" or mapMode == "" or mapSize == 0:
    return
  trvHostSelectedMap.appendMap(mapName, mapMode, mapSize)
  trvHostSelectableMap.selectNext()
  trvHostSelectableMap.updateLevelPreview()

proc onBtnHostMapDelClicked(self: Button00) {.signal.} =
  var mapName, mapMode: string
  var mapSize: int
  (mapName, mapMode, mapSize) = trvHostSelectedMap.selectedMap
  if mapName == "" or mapMode == "" or mapSize == 0: return
  trvHostSelectedMap.removeSelected()
  trvHostSelectedMap.updateLevelPreview()

proc onBtnHostMapMoveUpClicked(self: Button00) {.signal.} =
  trvHostSelectedMap.moveSelectedUp()

proc onBtnHostMapMoveDownClicked(self: Button00) {.signal.} =
  trvHostSelectedMap.moveSelectedDown()
#
## Server list
## TODO: Ping or connection gets closed after 30 seconds
proc onTrvMultiplayerServersCursorChanged(self: TreeView00) {.signal.} =
  var previousServer: Server = currentServer

  currentServer = get(trvMultiplayerServers.selectedServer)

  if previousServer.ip == currentServer.ip and previousServer.port == currentServer.port:
    return

  isServerSelected = true

  for serverConfig in serverConfigs:
    if serverConfig.server_name == currentServer.stellaName:
      currentServerConfig = serverConfig

  btnMultiplayerServersPlay.sensitive = true
  btnMultiplayerPlayersRefresh.sensitive = true

  updatePlayerListAsync()

proc onWindowKeyReleaseEvent(self: gtk.Window00, event00: ptr EventKey00): bool {.signal.} =
  var event: EventKey = new EventKey
  event.impl = event00
  event.ignoreFinalizer = true
  if not notebook.currentPage == 1:
    return
  if not isMultiplayerServerUpdating and event.getKeyval() == KEY_F5: # TODO: Add tooltip info
    updateServerAsync()
  if event.getKeyval() == KEY_F6 and isServerSelected: # TODO: Add tooltip info
    updatePlayerListAsync()

proc onNotebookSwitchPage(self: Notebook00, page: Widget00, pageNum: cint): bool {.signal.} =
  if not isMultiplayerServerUpdating and not isMultiplayerServerLoadedOnce and pageNum == 1:
    updateServerAsync()

proc onTxtMultiplayerAccountUsernameInsertText(self: Editable00, cstr: cstring, cstrLen: cint, pos: ptr cuint) {.signal.} =
  if not isAlphaNumeric($cstr):
    txtMultiplayerAccountUsername.signalStopEmissionByName("insert-text")
    return
  btnMultiplayerAccountLogin.sensitive = (txtMultiplayerAccountUsername.text & $cstr).len > 0 and txtMultiplayerAccountPassword.text.len > 0
  btnMultiplayerAccountCreate.sensitive = btnMultiplayerAccountLogin.sensitive

proc onTxtMultiplayerAccountUsernameDeleteText(self: Editable00, startPos, endPos: cint) {.signal.} =
  btnMultiplayerAccountLogin.sensitive = (txtMultiplayerAccountUsername.text.len - (endPos - startPos)) > 0 and txtMultiplayerAccountPassword.text.len > 0
  btnMultiplayerAccountCreate.sensitive = btnMultiplayerAccountLogin.sensitive

proc onTxtMultiplayerAccountPasswordInsertText(self: Editable00, cstr: cstring, cstrLen: cint, pos: ptr cuint) {.signal.} =
  if not isAlphaNumeric($cstr):
    txtMultiplayerAccountPassword.signalStopEmissionByName("insert-text")
    return
  btnMultiplayerAccountLogin.sensitive = txtMultiplayerAccountUsername.text.len > 0 and (txtMultiplayerAccountPassword.text & $cstr).len > 0
  btnMultiplayerAccountCreate.sensitive = btnMultiplayerAccountLogin.sensitive

proc onTxtMultiplayerAccountPasswordDeleteText(self: Editable00, startPos, endPos: cint) {.signal.} =
  btnMultiplayerAccountLogin.sensitive = txtMultiplayerAccountUsername.text.len > 0 and (txtMultiplayerAccountPassword.text.len - (endPos - startPos)) > 0
  btnMultiplayerAccountCreate.sensitive = btnMultiplayerAccountLogin.sensitive

proc onMultiplayerAccountUsernamePasswordActivate(self: Entry00) {.signal.} =
  if btnMultiplayerAccountLogin.sensitive: # TODO: create a isUsernamePasswordValid proc
    frameMultiplayerAccountError.visible = false
    loginAsync(chbtnMultiplayerAccountSave.active)

proc onTxtMultiplayerAccountSoldierNameInsertText(self: Editable00, cstr: cstring, cstrLen: cint, pos: ptr cuint) {.signal.} =
  var soldier: string
  soldier = txtMultiplayerAccountSoldierName.text
  soldier.insert($cstr, int(pos[]))
  if not validateSoldier(soldier):
    txtMultiplayerAccountSoldierName.signalStopEmissionByName("insert-text")

proc onTxtMultiplayerAccountSoldierNameDeleteText(self: Editable00, startPos, endPos: cint) {.signal.} =
  var soldier: string = txtMultiplayerAccountSoldierName.text
  soldier.delete(int(startPos), int(endPos) - 1)
  if not validateSoldier(soldier):
    txtMultiplayerAccountSoldierName.signalStopEmissionByName("delete-text")

proc onTxtMultiplayerAccountSoldierNameChanged(self: Editable00) {.signal.} =
  btnMultiplayerAccountSoldierOk.sensitive = txtMultiplayerAccountSoldierName.text.len >= 3

proc onBtnMultiplayerAccountLoginClicked(self: Button00) {.signal.} =
  frameMultiplayerAccountError.visible = false
  loginAsync(chbtnMultiplayerAccountSave.active)

proc onBtnMultiplayerAccountCreateClicked(self: Button00) {.signal.} =
  frameMultiplayerAccountError.visible = false
  createAsync(chbtnMultiplayerAccountSave.active)

proc onBtnMultiplayerAccountPlayClicked(self: Button00) {.signal.} =
  frameMultiplayerAccountError.visible = false

  var modDir: string

  var modDirExists: bool = false
  when defined(windows):
    modDirExists = dirExists(bf2142UnlockerConfig.settings.bf2142ClientPath / "mods" / currentServer.`mod`)
    modDir = currentServer.`mod`
  elif defined(linux):
    # Case sensitive
    for kind, path in walkDir(bf2142UnlockerConfig.settings.bf2142ClientPath / "mods", true):
      echo "path: ", path
      if kind != pcDir:
        continue
      if path.toLower() == currentServer.`mod`:
        modDirExists = true
        modDir = path
        break

  if not modDirExists:
    var uri: string

    if currentServer.`mod`.toLower() == "project_remaster_mp":
      uri = "https://www.moddb.com/mods/project-remaster"
    elif currentServer.`mod`.toLower() == "firststrike":
      uri = "https://www.moddb.com/mods/first-strike"

    if uri != "":
      lblMultiplayerModMissingLink.visible = true
      lbtnMultiplayerModMissing.visible = true
      lbtnMultiplayerModMissing.label = uri
      lbtnMultiplayerModMissing.uri = uri
    else:
      lblMultiplayerModMissingLink.visible = false
      lbtnMultiplayerModMissing.visible = false

    discard dlgMultiplayerModMissing.run()
    dlgMultiplayerModMissing.hide()
    return

  var mapDirExists: bool = false
  when defined(windows):
    mapDirExists = dirExists(bf2142UnlockerConfig.settings.bf2142ClientPath / "mods" / currentServer.`mod` / "levels" / currentServer.map)
  elif defined(linux):
    # Case sensitive
    var levelDir: string
    for kind, path in walkDir(bf2142UnlockerConfig.settings.bf2142ClientPath / "mods" / modDir, true):
      if kind != pcDir:
        continue
      if path.toLower() == "levels":
        levelDir = path
        break
    mapDirExists = dirExists(bf2142UnlockerConfig.settings.bf2142ClientPath / "mods" / modDir / levelDir / currentServer.map)

  if not mapDirExists:
    lblMultiplayerMapMissing.text = dgettext("gui", "LOGIN_MAP_MISSING_MSG") % [currentServer.map]

    discard dlgMultiplayerMapMissing.run()
    dlgMultiplayerMapMissing.hide()
    return


  let username: string = txtMultiplayerAccountUsername.text
  let soldier: string = get(trvMultiplayerAccountSoldiers.selectedSoldier)


  if not fileExists(bf2142UnlockerConfig.settings.bf2142ClientPath / BF2142_PATCHED_EXE_NAME):
    if not copyFile(bf2142UnlockerConfig.settings.bf2142ClientPath / BF2142_EXE_NAME, bf2142UnlockerConfig.settings.bf2142ClientPath / BF2142_PATCHED_EXE_NAME):
      return
  if not hasWritePermission(bf2142UnlockerConfig.settings.bf2142ClientPath / BF2142_PATCHED_EXE_NAME):
    newInfoDialog(
      dgettext("gui", "NO_WRITE_PERMISSION_TITLE"),
      dgettext("gui", "NO_WRITE_PERMISSION_MSG") % [bf2142UnlockerConfig.settings.bf2142ClientPath / BF2142_PATCHED_EXE_NAME]
    )
    return

  patchClient(bf2142UnlockerConfig.settings.bf2142ClientPath / BF2142_PATCHED_EXE_NAME, PatchConfig(currentServerConfig))
  backupOpenSpyIfExists()
  saveBF2142Profile(username, soldier)
  when defined(windows): # TODO: Reading/setting cd key on linux
    setCdKeyIfNotExists() # Checking if cd key exists, if not an empty cd key is set
  discard enableDisableIntroMovies(bf2142UnlockerConfig.settings.bf2142ClientPath / "mods" / currentServer.`mod` / "Movies", chbtnSettingsSkipMovies.active)

  var options: BF2142Options
  options.modPath = some("mods/" & currentServer.`mod`)
  options.menu = some(true)
  options.fullscreen = some(not chbtnSettingsWindowMode.active)
  if chbtnSettingsWindowMode.active:
    var resolution: tuple[width, height: uint16] = getSelectedResolution()
    options.szx = some(resolution.width)
    options.szy = some(resolution.height)
  options.widescreen = some(true)
  options.eaAccountName = some(username)
  options.eaAccountPassword = some(txtMultiplayerAccountPassword.text)
  options.soldierName = some(soldier)
  options.joinServer = some(currentServer.ip)
  options.port = some(currentServer.port)
  discard startBF2142(options)
  wndMultiplayerAccount.hide()

proc onBtnMultiplayerAccountCancelClicked(self: Button) {.signal.} =
  wndMultiplayerAccount.hide()

proc onBtnMultiplayerAccountSoldierAddClicked(self: Button00) {.signal.} =
  frameMultiplayerAccountError.visible = false
  txtMultiplayerAccountSoldierName.grabFocus()
  let dlgMultiplayerAccountSoldierCode: int = dlgMultiplayerAccountSoldier.run()
  dlgMultiplayerAccountSoldier.hide()
  if dlgMultiplayerAccountSoldierCode != 1:
    return # User closed dialog
  spinnerMultiplayerAccountSoldiers.start()
  wndMultiplayerAccount.sensitive = false
  var data: ThreadFeslData = ThreadFeslData(command: FeslCommand.AddSoldier)
  var dataSoldier: ThreadFeslSoldierData
  dataSoldier.soldier = txtMultiplayerAccountSoldierName.text
  data.soldier = dataSoldier
  channelFeslThread.send(data)


proc onBtnMutliplayerAccountSoldierDelClicked(self: Button00) {.signal.} =
  spinnerMultiplayerAccountSoldiers.start()
  wndMultiplayerAccount.sensitive = false
  var data: ThreadFeslData = ThreadFeslData(command: FeslCommand.DelSoldier)
  var dataSoldier: ThreadFeslSoldierData
  dataSoldier.soldier = get(trvMultiplayerAccountSoldiers.selectedSoldier)
  data.soldier = dataSoldier
  channelFeslThread.send(data)

proc onChbtnMultiplayerAccountSaveToggled(self: ToggleButton00) {.signal.} =
  var username, password, soldier: string
  if chbtnMultiplayerAccountSave.active:
    username = txtMultiplayerAccountUsername.text
    password = txtMultiplayerAccountPassword.text
    soldier = get(trvMultiplayerAccountSoldiers.selectedSoldier, "")
  saveLogin(currentServerConfig.server_name, username, password, soldier)

proc onTrvMultiplayerAccountSoldiersCursorChanged(self: TreeView00): bool {.signal.} =
  if chbtnMultiplayerAccountSave.active:
    saveLogin(currentServerConfig.server_name, "", "", get(trvMultiplayerAccountSoldiers.selectedSoldier), true)
  btnMultiplayerAccountPlay.sensitive = true
  btnMutliplayerAccountSoldierDel.sensitive = true
  return EVENT_PROPAGATE

proc onWndMultiplayerAccountShow(self: gtk.Window00) {.signal.} =
  notebook.sensitive = false

  channelFeslThread = Channel[ThreadFeslData]()
  channelFeslThread.open()
  channelFeslTimer = Channel[TimerFeslData]()
  channelFeslTimer.open()
  let TODO: int = 0
  discard timeoutAdd(250, timerFesl, TODO)
  threadFesl.createThread(threadFeslProc)

  lblMultiplayerAccountStellaName.text = currentServer.stellaName
  lblMultiplayerAccountGameServerName.text = currentServer.name

  let loginTplOpt: Option[tuple[username, password: string, soldier: Option[string]]] = getLogin(currentServerConfig.server_name)
  if loginTplOpt.isSome:
    let loginTpl: tuple[username, password: string, soldier: Option[string]] = get(loginTplOpt)
    ignoreEvents = true
    txtMultiplayerAccountUsername.text = loginTpl.username
    txtMultiplayerAccountPassword.text = loginTpl.password
    chbtnMultiplayerAccountSave.active = true
    ignoreEvents = false
    loginAsync(false, loginTpl.soldier)
    return

  trvMultiplayerAccountSoldiers.clear()
  ignoreEvents = true
  chbtnMultiplayerAccountSave.active = false
  ignoreEvents = false

  btnMultiplayerAccountLogin.sensitive = false
  btnMultiplayerAccountCreate.sensitive = false
  btnMultiplayerAccountSoldierAdd.sensitive = false
  btnMutliplayerAccountSoldierDel.sensitive = false
  btnMultiplayerAccountPlay.sensitive = false
  txtMultiplayerAccountUsername.grabFocus()

proc onWndMultiplayerAccountDeleteEvent(self: gtk.Window00): bool {.signal.} =
  wndMultiplayerAccount.hide()
  return EVENT_STOP

proc onWndMultiplayerAccountHide(self: gtk.Window00) {.signal.} =
  notebook.sensitive = true
  frameMultiplayerAccountError.visible = false

  txtMultiplayerAccountUsername.text = ""
  txtMultiplayerAccountPassword.text = ""
  channelFeslThread.close() # Closes thread (see threadFeslProc)
  channelFeslTimer.close() # Closes timer (see timerFesl)


proc onTrvMultiplayerServersButtonPressEvent(self: TreeView00, event00: ptr EventButton00): bool {.signal.} =
  var event: EventButton = new EventButton
  event.impl = event00
  event.ignoreFinalizer = true
  if event.eventType != gdk.EventType.doubleButtonPress:
    return

  wndMultiplayerAccount.show()
  return EVENT_PROPAGATE

proc onBtnMultiplayerServersRefreshClicked(self: Button00) {.signal.} =
  updateServerAsync()

proc onBtnMultiplayerServersPlayClicked(self: Button00) {.signal.} =
  wndMultiplayerAccount.show()

proc onBtnMultiplayerPlayersRefreshClicked(self: Button00) {.signal.} =
  updatePlayerListAsync()
#
## Host
proc onBtnHostGameServerClicked(self: Button00) {.signal.} =
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
  config.setSectionKey(CONFIG_SECTION_HOST, CONFIG_KEY_HOST_MOD, cbxHostMods.activeId)
  config.writeConfig(CONFIG_FILE_NAME)
  var serverExePath = bf2142UnlockerConfig.settings.bf2142ServerPath
  when defined(linux):
    serverExePath = serverExePath / "bin" / "amd-64"
  if not fileExists(serverExePath / BF2142_SRV_PATCHED_EXE_NAME):
    if not copyFileWithPermissions(serverExePath / BF2142_SRV_EXE_NAME,
    serverExePath / BF2142_SRV_PATCHED_EXE_NAME, false):
      return
  if not hasWritePermission(serverExePath / BF2142_SRV_PATCHED_EXE_NAME):
    newInfoDialog(
      dgettext("gui", "NO_WRITE_PERMISSION_TITLE"),
      dgettext("gui", "NO_WRITE_PERMISSION_MSG") % [serverExePath / BF2142_SRV_PATCHED_EXE_NAME]
    )
    return
  serverExePath = serverExePath / BF2142_SRV_PATCHED_EXE_NAME
  echo "Patching Battlefield 2142 server!"
  patchServer(serverExePath, parseIpAddress("127.0.0.1"), Port(8085))
  applyHostRunningSensitivity(true)
  if $ipAddress == "0.0.0.0":
     # When setting to 127.0.0.1 game doesn't connect to game server (doesn't load map)
    txtQuickIpAddress.text = getPrivateAddrs()[0]
  else:
    txtQuickIpAddress.text = $ipAddress
  cbtnQuickAutoJoin.active = true
  if termHostLoginServerPid > 0:
    killProcess(termHostLoginServerPid)
  termHostLoginServer.clear()
  termHostLoginServer.startLoginServer(ipAddress)
  startBF2142Server()
  discard cbxQuickMod.setActiveId(cbxHostMods.activeId)

proc onBtnHostCancelClicked(self: Button00) {.signal.} =
  applyHostRunningSensitivity(false)
  killProcess(termHostLoginServerPid)
  txtQuickIpAddress.text = ""
  if termHostGameServerPid > 0:
    killProcess(termHostGameServerPid)

proc onCbxHostModsChanged(self: ComboBox00) {.signal.} =
  updatePathes()
  loadSelectableMapList()
  if not loadMapList():
    return
  if not loadServerSettings():
    return
  if not loadAiSettings():
    return

proc onCbxHostGameModeChanged(self: ComboBox00) {.signal.} =
  updatePathes()
  loadSelectableMapList()

proc onTrvHostSelectableMapCursorChanged(self: TreeView00) {.signal.} =
  trvHostSelectableMap.updateLevelPreview()

proc onTrvHostSelectedMapRowActivated(self: TreeView00, path: TreePath00, column: TreeViewColumn00) {.signal.} =
  trvHostSelectedMap.updateLevelPreview()
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
  if bf2142UnlockerConfig.settings.bf2142ClientPath == path:
    return
  if not fileExists(path / BF2142_EXE_NAME):
    newInfoDialog(
      dgettext("gui", "COULD_NOT_FIND_TITLE") % [BF2142_EXE_NAME],
      dgettext("gui", "COULD_NOT_FIND_MSG") % [BF2142_EXE_NAME],
    )
    txtSettingsBF2142ClientPath.text = bf2142UnlockerConfig.settings.bf2142ClientPath
    return
  vboxQuick.visible = true
  vboxMultiplayer.visible = true
  vboxUnlocks.visible = true
  bf2142UnlockerConfig.settings.bf2142ClientPath = path
  if txtSettingsBF2142ClientPath.text != path:
    txtSettingsBF2142ClientPath.text = path
  loadJoinMods()
  if not cbxQuickMod.setActiveId(bf2142UnlockerConfig.quick.`mod`): # TODO: Redundant (applyBF2142UnlockerConfig)
    # When mod is removed or renamed set bf2142 as fallback
    discard cbxQuickMod.setActiveId("bf2142")
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_BF2142_PATH, bf2142UnlockerConfig.settings.bf2142ClientPath)
  when defined(linux):
    let wineStartPos: int = bf2142UnlockerConfig.settings.bf2142ClientPath.find(".wine")
    var wineEndPos: int
    if wineStartPos > -1:
      wineEndPos = bf2142UnlockerConfig.settings.bf2142ClientPath.find(DirSep, wineStartPos) - 1
      if txtSettingsWinePrefix.text == "": # TODO: Ask with Dialog if the read out wineprefix should be assigned to txtSettingsWinePrefix's text
        txtSettingsWinePrefix.text = bf2142UnlockerConfig.settings.bf2142ClientPath.substr(0, wineEndPos)
        config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_WINEPREFIX, txtSettingsWinePrefix.text) # TODO: Create a saveWinePrefix proc
  config.writeConfig(CONFIG_FILE_NAME)

proc onBtnSettingsBF2142ClientPathClicked(self: Button00) {.signal.} = # TODO: Add checks
  var (responseType, path) = selectFolderDialog(lblSettingsBF2142ClientPath.text[0..^2])
  if responseType != ResponseType.ok:
    return
  setBF2142Path(path)

proc onTxtSettingsBF2142ClientPathFocusOutEvent(self: Entry00) {.signal.} =
  setBF2142Path(txtSettingsBF2142ClientPath.text.strip())

proc setBF2142ServerPath(path: string) =
  if bf2142UnlockerConfig.settings.bf2142ServerPath == path:
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
    txtSettingsBF2142ServerPath.text = bf2142UnlockerConfig.settings.bf2142ServerPath
    return
  bf2142UnlockerConfig.settings.bf2142ServerPath = path
  if txtSettingsBF2142ServerPath.text != path:
    txtSettingsBF2142ServerPath.text = path
  vboxHost.visible = true
  ignoreEvents = true
  loadHostMods()
  if not cbxHostMods.setActiveId(bf2142UnlockerConfig.host.`mod`): # TODO: Redundant (applyBF2142UnlockerConfig)
    # When mod is removed or renamed set bf2142 as fallback
    discard cbxHostMods.setActiveId("bf2142")
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
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_BF2142_SERVER_PATH, bf2142UnlockerConfig.settings.bf2142ServerPath)
  config.writeConfig(CONFIG_FILE_NAME)

proc onBtnSettingsBF2142ServerPathClicked(self: Button00) {.signal.} = # TODO: Add Checks
  var (responseType, path) = selectFolderDialog(lblSettingsBF2142ServerPath.text[0..^2])
  if responseType != ResponseType.ok:
    return
  setBF2142ServerPath(path)

proc onTxtSettingsBF2142ServerPathFocusOutEvent(self: Entry00) {.signal.} =
  setBF2142ServerPath(txtSettingsBF2142ServerPath.text.strip())

proc onBtnSettingsWinePrefixClicked(self: Button00) {.signal.} = # TODO: Add checks
  var (responseType, path) = selectFolderDialog(lblSettingsWinePrefix.text[0..^2])
  if responseType != ResponseType.ok:
    return
  if bf2142UnlockerConfig.settings.bf2142ServerPath == path:
    return
  txtSettingsWinePrefix.text = path
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_WINEPREFIX, txtSettingsWinePrefix.text)
  config.writeConfig(CONFIG_FILE_NAME)
  when defined(linux): # Getlogin is only available for linux
    documentsPath = txtSettingsWinePrefix.text / "drive_c" / "users" / $getlogin() / "My Documents"
  updateProfilePathes()

proc onTxtSettingsStartupQueryFocusOutEvent(self: Entry00, event: EventFocus00): bool {.signal.} =
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_STARTUP_QUERY, txtSettingsStartupQuery.text)
  config.writeConfig(CONFIG_FILE_NAME)

proc onChbtnSettingsSkipMoviesToggled(self: CheckButton00) {.signal.} =
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_SKIP_MOVIES, $chbtnSettingsSkipMovies.active)
  config.writeConfig(CONFIG_FILE_NAME)

proc onChbtnSettingsWindowModeToggled(self: CheckButton00) {.signal.} =
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_WINDOW_MODE, $chbtnSettingsWindowMode.active)
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_RESOLUTION, cbxSettingsResolution.activeId)
  config.writeConfig(CONFIG_FILE_NAME)
  lblSettingsResolution.visible = chbtnSettingsWindowMode.active
  cbxSettingsResolution.visible = chbtnSettingsWindowMode.active

proc onCbxSettingsResolutionChanged(self: ComboBox00) {.signal.} =
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_SETTINGS_RESOLUTION, cbxSettingsResolution.activeId)
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

proc execBF2142ServerCommand(command: string) =
  when defined(windows):
    sendMsg(termHostGameServerPid, command)
  elif defined(linux):
    termHostGameServer.feedChild(command)

proc onHostBotSkillChanged(self: pointer) {.signal.} =
  if termHostGameServerPid > 0:
    execBF2142ServerCommand(SETTING_BOT_SKILL & " " & $round(sbtnHostBotSkill.value, 1) & "\r")

proc onHostTicketRatioChanged(self: pointer) {.signal.} =
  if termHostGameServerPid > 0:
    execBF2142ServerCommand(SETTING_TICKET_RATIO & " " & $sbtnHostTicketRatio.value.int & "\r")

proc onHostSpawnTimeChanged(self: pointer) {.signal.} =
  if termHostGameServerPid > 0:
    execBF2142ServerCommand(SETTING_SPAWN_TIME & " " & $sbtnHostSpawnTime.value.int & "\r")

proc onHostRoundsPerMapChanged(self: pointer) {.signal.} =
  if termHostGameServerPid > 0:
    execBF2142ServerCommand(SETTING_ROUNDS_PER_MAP & " " & $sbtnHostRoundsPerMap.value.int & "\r")

proc onHostPlayersNeededToStartChanged(self: pointer) {.signal.} =
  if termHostGameServerPid > 0:
    execBF2142ServerCommand(SETTING_PLAYERS_NEEDED_TO_START & " " & $sbtnHostPlayersNeededToStart.value.int & "\r")

proc onHostFriendlyFireToggled(self: CheckButton00) {.signal.} =
  var val: string = if chbtnHostFriendlyFire.active: "100" else: "0"
  if termHostGameServerPid > 0:
    execBF2142ServerCommand(SETTING_SOLDIER_FRIENDLY_FIRE & " " & val & "\r")
    execBF2142ServerCommand(SETTING_VEHICLE_FRIENDLY_FIRE & " " & val & "\r")
    execBF2142ServerCommand(SETTING_SOLDIER_SPLASH_FRIENDLY_FIRE & " " & val & "\r")
    execBF2142ServerCommand(SETTING_VEHICLE_SPLASH_FRIENDLY_FIRE & " " & val & "\r")

proc onHostAllowNoseCamToggled(self: CheckButton00) {.signal.} =
  if termHostGameServerPid > 0:
    execBF2142ServerCommand(SETTING_ALLOW_NOSE_CAM & " " & $chbtnHostAllowNoseCam.active.int & "\r")
#
## Unlocks
proc onChbtnUnlocksUnlockSquadGadgetsToggled(self: CheckButton00) {.signal.} =
  config.setSectionKey(CONFIG_SECTION_UNLOCKS, CONFIG_KEY_UNLOCKS_UNLOCK_SQUAD_GADGETS, $chbtnUnlocksUnlockSquadGadgets.active)
  config.writeConfig(CONFIG_FILE_NAME)
#
##

proc onApplicationWindowDraw(self: ApplicationWindow00, context: cairo.Context00): bool {.signalNoCheck.} =
  if not windowShown:
    windowShown = true

proc onQuit() =
  if termHostGameServerPid > 0:
    echo "KILLING BF2142 GAME SERVER"
    killProcess(termHostGameServerPid)
  if termHostLoginServerPid > 0:
    echo "KILLING BF2142 LOGIN/UNLOCK SERVER"
    killProcess(termHostLoginServerPid)
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

  vboxQuick = builder.getBox("vboxQuick")
  cbxQuickMod = builder.getComboBox("cbxQuickMod")
  txtQuickPlayerName = builder.getEntry("txtQuickPlayerName")
  txtQuickIpAddress = builder.getEntry("txtQuickIpAddress")
  cbtnQuickAutoJoin = builder.getCheckButton("cbtnQuickAutoJoin")
  btnQuickConnect = builder.getButton("btnQuickConnect")
  btnQuickHost = builder.getButton("btnQuickHost")
  btnQuickHostCancel = builder.getButton("btnQuickHostCancel")
  btnQuickSingleplayer = builder.getButton("btnQuickSingleplayer")
  btnQuickSingleplayerCancel = builder.getButton("btnQuickSingleplayerCancel")
  frameQuickTerminal = builder.getFrame("frameQuickTerminal")
  dlgQuickCheckServer = builder.getDialog("dlgQuickCheckServer")
  btnQuickCheckServerCancel = builder.getButton("btnQuickCheckServerCancel")
  spinnerQuickCheckServerLoginServer = builder.getSpinner("spinnerQuickCheckServerLoginServer")
  spinnerQuickCheckServerGpcmServer = builder.getSpinner("spinnerQuickCheckServerGpcmServer")
  spinnerQuickCheckServerUnlockServer = builder.getSpinner("spinnerQuickCheckServerUnlockServer")
  imgQuickCheckServerLoginServer = builder.getImage("imgQuickCheckServerLoginServer")
  imgQuickCheckServerGpcmServer = builder.getImage("imgQuickCheckServerGpcmServer")
  imgQuickCheckServerUnlockServer = builder.getImage("imgQuickCheckServerUnlockServer")

  vboxMultiplayer = builder.getBox("vboxMultiplayer")
  spinnerMultiplayerServers = builder.getSpinner("spinnerMultiplayerServers")
  trvMultiplayerServers = builder.getTreeView("trvMultiplayerServers")
  btnMultiplayerServersRefresh = builder.getButton("btnMultiplayerServersRefresh")
  btnMultiplayerServersPlay = builder.getButton("btnMultiplayerServersPlay")
  trvMultiplayerPlayers1 = builder.getTreeView("trvMultiplayerPlayers1")
  spinnerMultiplayerPlayers1 = builder.getSpinner("spinnerMultiplayerPlayers1")
  trvMultiplayerPlayers2 = builder.getTreeView("trvMultiplayerPlayers2")
  spinnerMultiplayerPlayers2 = builder.getSpinner("spinnerMultiplayerPlayers2")
  lblMultiplayerTeam1 = builder.getLabel("lblMultiplayerTeam1")
  lblMultiplayerTeam2 = builder.getLabel("lblMultiplayerTeam2")
  btnMultiplayerPlayersRefresh = builder.getButton("btnMultiplayerPlayersRefresh")
  wndMultiplayerAccount = builder.getWindow("wndMultiplayerAccount")
  spinnerMultiplayerAccount = builder.getSpinner("spinnerMultiplayerAccount")
  lblMultiplayerAccountStellaName = builder.getLabel("lblMultiplayerAccountStellaName")
  lblMultiplayerAccountGameServerName = builder.getLabel("lblMultiplayerAccountGameServerName")
  txtMultiplayerAccountUsername = builder.getEntry("txtMultiplayerAccountUsername")
  txtMultiplayerAccountPassword = builder.getEntry("txtMultiplayerAccountPassword")
  trvMultiplayerAccountSoldiers = builder.getTreeView("trvMultiplayerAccountSoldiers")
  spinnerMultiplayerAccountSoldiers = builder.getSpinner("spinnerMultiplayerAccountSoldiers")
  btnMultiplayerAccountLogin = builder.getButton("btnMultiplayerAccountLogin")
  btnMultiplayerAccountSoldierAdd = builder.getButton("btnMultiplayerAccountSoldierAdd")
  btnMutliplayerAccountSoldierDel = builder.getButton("btnMutliplayerAccountSoldierDel")
  chbtnMultiplayerAccountSave = builder.getCheckButton("chbtnMultiplayerAccountSave")
  frameMultiplayerAccountError = builder.getFrame("frameMultiplayerAccountError")
  lblMultiplayerAccountErrorTxn = builder.getLabel("lblMultiplayerAccountErrorTxn")
  lblMultiplayerAccountErrorCode = builder.getLabel("lblMultiplayerAccountErrorCode")
  lblMultiplayerAccountErrorMsg = builder.getLabel("lblMultiplayerAccountErrorMsg")
  btnMultiplayerAccountCreate = builder.getButton("btnMultiplayerAccountCreate")
  btnMultiplayerAccountPlay = builder.getButton("btnMultiplayerAccountPlay")
  btnMultiplayerAccountCancel = builder.getButton("btnMultiplayerAccountCancel")
  dlgMultiplayerAccountSoldier = builder.getDialog("dlgMultiplayerAccountSoldier")
  txtMultiplayerAccountSoldierName = builder.getEntry("txtMultiplayerAccountSoldierName")
  btnMultiplayerAccountSoldierOk = builder.getButton("btnMultiplayerAccountSoldierOk")
  dlgMultiplayerModMissing = builder.getDialog("dlgMultiplayerModMissing")
  lblMultiplayerModMissingLink = builder.getLabel("lblMultiplayerModMissingLink")
  lbtnMultiplayerModMissing = builder.getLinkButton("lbtnMultiplayerModMissing")
  dlgMultiplayerMapMissing = builder.getDialog("dlgMultiplayerMapMissing")
  lblMultiplayerMapMissing = builder.getLabel("lblMultiplayerMapMissing")
  bboxMultiplayerServers = builder.getButtonBox("bboxMultiplayerServers")

  vboxHost = builder.getBox("vboxHost")
  imgHostLevelPreview = builder.getImage("imgHostLevelPreview")
  cbxHostMods = builder.getComboBox("cbxHostMods")
  cbxHostGameMode = builder.getComboBox("cbxHostGameMode")
  sbtnHostBotSkill = builder.getSpinButton("sbtnHostBotSkill")
  scaleHostBotSkill = builder.getScale("scaleHostBotSkill")
  sbtnHostTicketRatio = builder.getSpinButton("sbtnHostTicketRatio")
  scaleHostTicketRatio = builder.getScale("scaleHostTicketRatio")
  sbtnHostSpawnTime = builder.getSpinButton("sbtnHostSpawnTime")
  scaleHostSpawnTime = builder.getScale("scaleHostSpawnTime")
  sbtnHostRoundsPerMap = builder.getSpinButton("sbtnHostRoundsPerMap")
  scaleHostRoundsPerMap = builder.getScale("scaleHostRoundsPerMap")
  sbtnHostBots = builder.getSpinButton("sbtnHostBots")
  scaleHostBots = builder.getScale("scaleHostBots")
  sbtnHostMaxPlayers = builder.getSpinButton("sbtnHostMaxPlayers")
  scaleHostMaxPlayers = builder.getScale("scaleHostMaxPlayers")
  sbtnHostPlayersNeededToStart = builder.getSpinButton("sbtnHostPlayersNeededToStart")
  scaleHostPlayersNeededToStart = builder.getScale("scaleHostPlayersNeededToStart")
  chbtnHostFriendlyFire = builder.getCheckButton("chbtnHostFriendlyFire")
  chbtnHostAllowNoseCam = builder.getCheckButton("chbtnHostAllowNoseCam")
  txtHostIpAddress = builder.getEntry("txtHostIpAddress")
  trvHostSelectableMap = builder.getTreeView("trvHostSelectableMap")
  trvHostSelectedMap = builder.getTreeView("trvHostSelectedMap")
  btnHostMapAdd = builder.getButton("btnHostMapAdd")
  btnHostMapDel = builder.getButton("btnHostMapDel")
  btnHostMapMoveUp = builder.getButton("btnHostMapMoveUp")
  btnHostMapMoveDown = builder.getButton("btnHostMapMoveDown")
  btnHostGameServer = builder.getButton("btnHostGameServer")
  btnHostCancel = builder.getButton("btnHostCancel")
  hboxHostTerms = builder.getBox("hboxHostTerms")

  vboxUnlocks = builder.getBox("vboxUnlocks")
  chbtnUnlocksUnlockSquadGadgets = builder.getCheckButton("chbtnUnlocksUnlockSquadGadgets")

  vboxSettings = builder.getBox("vboxSettings")
  lblSettingsBF2142ClientPath = builder.getLabel("lblSettingsBF2142ClientPath")
  txtSettingsBF2142ClientPath = builder.getEntry("txtSettingsBF2142ClientPath")
  btnSettingsBF2142ClientPath = builder.getButton("btnSettingsBF2142ClientPath")
  lblSettingsBF2142ServerPath = builder.getLabel("lblSettingsBF2142ServerPath")
  txtSettingsBF2142ServerPath = builder.getEntry("txtSettingsBF2142ServerPath")
  btnSettingsBF2142ServerPath = builder.getButton("btnSettingsBF2142ServerPath")
  lblSettingsWinePrefix = builder.getLabel("lblSettingsWinePrefix")
  btnSettingsWinePrefix = builder.getButton("btnSettingsWinePrefix")
  txtSettingsWinePrefix = builder.getEntry("txtSettingsWinePrefix")
  lblSettingsStartupQuery = builder.getLabel("lblSettingsStartupQuery")
  txtSettingsStartupQuery = builder.getEntry("txtSettingsStartupQuery")
  chbtnSettingsSkipMovies = builder.getCheckButton("chbtnSettingsSkipMovies")
  chbtnSettingsWindowMode = builder.getCheckButton("chbtnSettingsWindowMode")
  lblSettingsResolution = builder.getLabel("lblSettingsResolution")
  cbxSettingsResolution = builder.getComboBox("cbxSettingsResolution")
  dlgSettingsBF2142ClientPathDetected = builder.getDialog("dlgSettingsBF2142ClientPathDetected")
  lblSettingsBF2142ClientPathDetected = builder.getLabel("lblSettingsBF2142ClientPathDetected")

  ## Set version (statically) read out from nimble file
  lblVersion.label = VERSION
  #

  ## Terminals # TODO: Create a custom widget for glade
  termQuickServer = newTerminal()
  termQuickServer.vexpand = true
  termQuickServer.marginBottom = 3
  termQuickServer.marginStart = 3
  termQuickServer.marginEnd = 3
  frameQuickTerminal.add(termQuickServer)
  termHostLoginServer = newTerminal()
  termHostLoginServer.hexpand = true
  termHostGameServer = newTerminal()
  termHostGameServer.hexpand = true
  hboxHostTerms.add(termHostLoginServer)
  when defined(windows):
    hboxHostTerms.add(termHostGameServer)
  elif defined(linux):
    # Adding a horizontal scrollbar to display the whole server output.
    # This is required to parse the content otherwise the content is cutted.
    termHostGameServer.connect("contents-changed", ontermHostGameServerContentsChanged)
    termHostGameServer.connect("child-exited", ontermHostGameServerChildExited)
    termHostGameServer.visible = true
    var box: Box = newHBox(false, 0)
    box.visible = true
    box.setSizeRequest(termHostGameServer.getCharWidth().int * 80, -1)
    box.add(termHostGameServer)
    swinHostGameServer = newScrolledWindow(nil, nil)
    swinHostGameServer.setSizeRequest(0, 300)
    swinHostGameServer.hexpand = true
    swinHostGameServer.add(box)
    hboxHostTerms.add(swinHostGameServer)
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
  bf2142UnlockerConfig = getBF2142UnlockerConfig()
  loadJoinMods()
  loadHostMods()
  loadJoinResolutions()
  applyBF2142UnlockerConfig(bf2142UnlockerConfig)
  lblSettingsResolution.visible = bf2142UnlockerConfig.settings.windowMode
  cbxSettingsResolution.visible = bf2142UnlockerConfig.settings.windowMode
  if bf2142UnlockerConfig.settings.bf2142ServerPath != "":
    updatePathes()
    loadSelectableMapList()
    if loadMapList() and loadServerSettings() and loadAiSettings():
       # This if statments exists, because if any of this proc calls above fails it wont continue with the next proc call
       # TODO: Maybe create a loadAll proc because those procs are always called together
      discard # Do not return, otherwise the following visibility logic will not be executed
  when defined(windows):
    lblSettingsWinePrefix.visible = false
    txtSettingsWinePrefix.visible = false
    btnSettingsWinePrefix.visible = false
    lblSettingsStartupQuery.visible = false
    txtSettingsStartupQuery.visible = false
  if bf2142UnlockerConfig.settings.bf2142ClientPath == "":
    vboxQuick.visible = false
    vboxMultiplayer.visible = false
    vboxUnlocks.visible = false
  if bf2142UnlockerConfig.settings.bf2142ServerPath == "":
    vboxHost.visible = false
  loadServerConfig()
  fillMultiplayerPatchAndStartBox()

  when defined(windows):
    if bf2142UnlockerConfig.settings.bf2142ClientPath == "":
      let bf2142ClientPath: string = getBF2142ClientPath()
      if bf2142ClientPath != "" and fileExists(bf2142ClientPath / BF2142_EXE_NAME):
        vboxSettings.sensitive = false
        lblSettingsBF2142ClientPathDetected.text = bf2142ClientPath
        let responseId: int = dlgSettingsBF2142ClientPathDetected.run()
        dlgSettingsBF2142ClientPathDetected.destroy()
        if responseId == 0:
          setBF2142Path(bf2142ClientPath)
          notebook.currentPage = 0
        elif responseId == 1:
          let (responseType, path) = selectFolderDialog(lblSettingsBF2142ClientPath.text[0..^2])
          if responseType == ResponseType.ok:
            setBF2142Path(path)
            notebook.currentPage = 0
        vboxSettings.sensitive = true

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