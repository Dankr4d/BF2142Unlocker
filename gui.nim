import gintro/[gtk, glib, gobject, gdk, cairo, gdkpixbuf]
import gintro/gio except ListStore

import os
import net # Requierd for ip parsing and type
import osproc # Requierd for process starting
import strutils
import strformat # Required for fmt macro
import xmlparser, xmltree # Requierd for map infos (and available modes for maps)
when defined(linux):
  import posix # Requierd for getlogin and killProcess
elif defined(windows):
  import winim
  import docpath
import terminal # Terminal wrapper (uses vte on linux and textview on windows)
import parsecfg # Config
import md5 # Requierd to check if the current BF2142.exe is the original BF2142.exe
import times # Requierd for rudimentary level backup with epochtime suffix
import checkpermission # Requierd to check if file has write permissions
import nimBF2142IpPatcher
import elevatedio # Requierd to write, copy and delete data elevated
import localaddrs, checkserver # Required to get all local adresses and check if servers are reachable
import options

# Set icon (windres.exe .\icon.rc -O coff -o icon.res)
when defined(gcc) and defined(windows):
  {.link: "icon.res".}

const TEMP_FILES_DIR*: string = "tempfiles" # TODO

var bf2142Path: string
var bf2142ServerPath: string
var documentsPath: string
var bf2142ProfilesPath: string
var bf2142Profile0001Path: string

const VERSION: string = "0.9.1"

const BF2142_EXE_NAME: string = "BF2142.exe"
const OPENSPY_DLL_NAME: string = "RendDX9.dll"
const ORIGINAL_RENDDX9_DLL_NAME: string = "RendDX9_ori.dll" # Named by reclamation hub and remaster mod
const FILE_BACKUP_SUFFIX: string = ".original"

const ORIGINAL_CLIENT_MD5_HASH: string = "6ca5c59cd1623b78191e973b3e8088bc"
const OPENSPY_MD5_HASH: string = "c74f5a6b4189767dd82ccfcb13fc23c4"
const ORIGINAL_RENDDX9_MD5_HASH: string = "18a7be5d8761e54d43130b8a2a3078b9"
when defined(linux):
  const
    ORIGINAL_SERVER_MD5_HASH_32: string = "9e9368e3ee5ffc0a533048685456cb8c"
    ORIGINAL_SERVER_MD5_HASH_64: string = "ce720cbf34cf11460a69eaaae50dc917"
elif defined(windows):
  const
    ORIGINAL_SERVER_MD5_HASH_32: string = "2380c7bc967f96aff1fbf83ce1b9390d"
    ORIGINAL_SERVER_MD5_HASH_64: string = "2380c7bc967f96aff1fbf83ce1b9390d"


const GAME_MODES: seq[tuple[id: string, name: string]] = @[
  (id: "gpm_cq", name: "Conquest"),
  (id: "gpm_ti", name: "Titan"),
  (id: "gpm_coop", name: "Coop"),
  (id: "gpm_sl", name: "SupplyLine"),
  (id: "gpm_nv", name: "NoVehicles"),
  (id: "gpm_ca", name: "ConquestAssault")
]

const
  SETTING_BOT_SKILL: string = "sv.botSkill"
  SETTING_TICKET_RATIO: string = "sv.ticketRatio"
  SETTING_SPAWN_TIME: string = "sv.spawnTime"
  SETTING_ROUNDS_PER_MINUTE: string = "sv.roundsPerMap"
  SETTING_SOLDIER_FRIENDLY_FIRE: string = "sv.soldierFriendlyFire"
  SETTING_VEHICLE_FRIENDLY_FIRE: string = "sv.vehicleFriendlyFire"
  SETTING_SOLDIER_SPLASH_FRIENDLY_FIRE: string = "sv.soldierSplashFriendlyFire"
  SETTING_VEHICLE_SPLASH_FRIENDLY_FIRE: string = "sv.vehicleSplashFriendlyFire"
  SETTING_TEAM_RATIO: string = "sv.teamRatioPercent"
  SETTING_MAX_PLAYERS: string = "sv.maxPlayers"
  SETTING_PLAYERS_NEEDED_TO_START: string = "sv.numPlayersNeededToStart"
  SETTING_SERVER_IP: string = "sv.serverIP"

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

var termLoginServerPid: int = 0
var termBF2142ServerPid: int = 0

const
  PROFILE_AUDIO_CON: string = staticRead("profile/Audio.con")
  PROFILE_CONTROLS_CON: string = staticRead("profile/Controls.con")
  PROFILE_GENERAL_CON: string = staticRead("profile/General.con")
  PROFILE_PROFILE_CON: string = staticRead("profile/Profile.con")
  PROFILE_SERVER_SETTINGS_CON: string = staticRead("profile/ServerSettings.con")
  PROFILE_VIDEO_CON: string = staticRead("profile/Video.con")

const GUI_CSS: string = staticRead("gui.css")
const
  CONFIG_FILE_NAME: string = "config.ini"
  CONFIG_SECTION_GENERAL: string = "General"
  CONFIG_SECTION_SETTINGS: string = "Settings"
  CONFIG_KEY_BF2142_PATH: string = "bf2142_path"
  CONFIG_KEY_BF2142_SERVER_PATH: string = "bf2142_server_path"
  CONFIG_KEY_WINEPREFIX: string = "wineprefix"
  CONFIG_KEY_STARTUP_QUERY: string = "startup_query"
  CONFIG_KEY_PLAYER_NAME: string = "playername"
  CONFIG_KEY_AUTO_JOIN: string = "autojoin"
  CONFIG_KEY_WINDOW_MODE: string = "window_mode"

const NO_PREVIEW_IMG_PATH: string = "nopreview.png"

var config: Config

### General controls
var application: Application
var window: ApplicationWindow
var vboxMain: Box
var notebook: Notebook
var actionBar: ActionBar
##
### Join controls
var vboxJoin: Box
var hboxJoinSettings: Box
var vboxJustPlay: Box
var frameJoinConnect: Frame
var frameJoinSettings: Frame
var tblJoinConnect: Table
var tblJoinSettings: Table
var lblJoinMods: Label
var cbxJoinMods: ComboBoxText
var lblPlayerName: Label
var txtPlayerName: Entry
var lblIpAddress: Label
var txtIpAddress: Entry
var lblAutoJoin: Label
var chbtnAutoJoin: CheckButton
var lblWindowMode: Label
var chbtnWindowMode: CheckButton
var btnJoin: Button # TODO: Rename to btnConnect
var btnJustPlay: Button
var btnJustPlayCancel: Button
# var panedJustPlay: Paned
var termJustPlayServer: Terminal
##
### Host controls
var tblHostSettings: Table
var vboxHost: Box
var hboxHostLevelPreview: Box
var imgLevelPreview: Image
var lblHostMods: Label
var cbxHostMods: ComboBoxText
var lblGameMode: Label
var cbxGameMode: ComboBoxText
var lblBotSkill: Label
var sbtnBotSkill: SpinButton
var scaleBotSkill: HScale
var lblTicketRatio: Label
var sbtnTicketRatio: SpinButton
var scaleTicketRatio: HScale
var lblSpawnTime: Label
var sbtnSpawnTime: SpinButton
var scaleSpawnTime: HScale
var lblRoundsPerMap: Label
var sbtnRoundsPerMap: SpinButton
var scaleRoundsPerMap: HScale
var lblBots: Label
var sbtnBots: SpinButton
var scaleBots: HScale
var lblMaxPlayers: Label
var sbtnMaxPlayers: SpinButton
var scaleMaxPlayers: HScale
var lblPlayersNeededToStart: Label
var sbtnPlayersNeededToStart: SpinButton
var scalePlayersNeededToStart: HScale
var lblFriendlyFire: Label
var chbtnFriendlyFire: CheckButton
  # teamratio (also for coop?)
  # autobalance (also for coop?)
var lblHostIpAddress: Label
var txtHostIpAddress: Entry
var hboxMaps: Box
var listSelectableMaps: TreeView
var sWindowSelectableMaps: ScrolledWindow
var listSelectedMaps: TreeView
var sWindowSelectedMaps: ScrolledWindow
var vboxAddRemoveMap: Box
var btnAddMap: Button
var btnRemoveMap: Button
var vboxMoveMap: Box
var btnMapMoveUp: Button
var btnMapMoveDown: Button
var hboxHostButtons: Box
var btnHostLoginServer: Button
var btnHost: Button
var btnHostCancel: Button
var hboxTerms: Box
var termLoginServer: Terminal
var termBF2142Server: Terminal
##
### Settings controls
var vboxSettings: Box
var tblSettings: Table
var lblBF2142Path: Label
var btnBF2142Path: Button
var txtBF2142Path: Entry
var lblBF2142ServerPath: Label
var btnBF2142ServerPath: Button
var txtBF2142ServerPath: Entry
var lblWinePrefix: Label
var btnWinePrefix: Button
var txtWinePrefix: Entry
var lblStartupQuery: Label
var txtStartupQuery: Entry
var btnRemoveMovies: Button
var btnPatchClientMaps: Button
var btnPatchServerMaps: Button
var btnRestore: Button
##

### Helper procs
proc areServerReachable(address: string): bool =
  if not isAddrReachable(address, Port(8080)):
    return false
  if not isAddrReachable(address, Port(18300)):
    return false
  if not isAddrReachable(address, Port(29900)):
    return false
  return true

proc fillHostIpAddress() =
  var addrs: seq[string] = getLocalAddrs()
  if addrs.len > 0:
    txtHostIpAddress.text = addrs[0] # TODO: Validate interface and choose lan interfaces first
  else:
    txtHostIpAddress.text = ""

proc killProcess*(pid: int) = # TODO: Add some error handling; TODO: pid should be stored in startProcess and not passed
  when defined(linux):
    if kill(Pid(pid), SIGKILL) < 0:
      echo "ERROR: Cannot kill process!" # TODO: Create a popup
  elif defined(windows):
    if pid == termBF2142ServerPid:
      terminateForkedThread() # TODO
    elif pid == termLoginServerPid:
      terminateThread() # TODO
    var hndlProcess = OpenProcess(PROCESS_TERMINATE, false.WINBOOL, pid.DWORD)
    discard hndlProcess.TerminateProcess(0) # TODO: Check result
  if pid == termBF2142ServerPid:
    termBF2142ServerPid = 0
  elif pid == termLoginServerPid:
    termLoginServerPid = 0

proc onWidgetFakeHoverEnterNotifyEvent(self: Entry | SpinButton, event: EventCrossing): bool =
  self.styleContext.addClass("fake-hover")
proc onWidgetFakeHoverLeaveNotifyEvent(self: Entry | SpinButton, event: EventCrossing): bool =
  self.styleContext.removeClass("fake-hover")

proc updateProfilePathes() =
  bf2142ProfilesPath = documentsPath / "Battlefield 2142" / "Profiles"
  bf2142Profile0001Path = bf2142ProfilesPath / "0001"

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
  let windowModeStr = config.getSectionValue(CONFIG_SECTION_GENERAL, CONFIG_KEY_WINDOW_MODE)
  if windowModeStr != "":
    chbtnWindowMode.active = windowModeStr.parseBool()
  else:
    chbtnWindowMode.active = false

proc preClientPatchCheck() =
  let clientExePath: string = bf2142Path / BF2142_EXE_NAME
  if bf2142Path == "":
    return
  if fileExists(clientExePath):
    let clientMd5Hash: string = getMD5(clientExePath.readFile()) # TODO: In a thread (slow gui startup) OR!! read file until first ground patched byte OR Create a check byte at the begining of the file
    if clientMd5Hash == ORIGINAL_CLIENT_MD5_HASH:
      echo fmt"Found original client binary ({BF2142_EXE_NAME}). Creating a backup and prepatching!"
      if hasWritePermission(clientExePath):
        copyFile(clientExePath, clientExePath & FILE_BACKUP_SUFFIX)
        preClientPatch(clientExePath)
      else:
        var writeSucceed: bool = false
        let tmpExePath: string = TEMP_FILES_DIR / BF2142_EXE_NAME
        if not copyFileElevated(clientExePath, clientExePath & FILE_BACKUP_SUFFIX):
          return
        copyFile(clientExePath, tmpExePath)
        preClientPatch(tmpExePath)
        writeSucceed = copyFileElevated(tmpExePath, clientExePath)
        removeFile(tmpExePath)
        if not writeSucceed:
          return
      btnRestore.sensitive = true

proc openspyBackupCheck() =
  let openspyDllPath: string = bf2142Path / OPENSPY_DLL_NAME
  let originalRendDX9Path: string = bf2142Path / ORIGINAL_RENDDX9_DLL_NAME
  if fileExists(openspyDllPath) and fileExists(originalRendDX9Path):
    let openspyMd5Hash: string = getMD5(openspyDllPath.readFile())
    let originalRendDX9Hash: string = getMD5(originalRendDX9Path.readFile())
    if openspyMd5Hash == OPENSPY_MD5_HASH and originalRendDX9Hash == ORIGINAL_RENDDX9_MD5_HASH:
      echo "Found openspy dll (" & OPENSPY_DLL_NAME & "). Creating a backup and restoring original file!"
      if hasWritePermission(openspyDllPath):
        copyFile(openspyDllPath, openspyDllPath & FILE_BACKUP_SUFFIX)
        copyFile(originalRendDX9Path, openspyDllPath)
      else:
        if not copyFileElevated(openspyDllPath, openspyDllPath & FILE_BACKUP_SUFFIX):
          return
        if not copyFileElevated(originalRendDX9Path, openspyDllPath):
          return
      btnRestore.sensitive = true

proc restoreCheck() =
  let clientExeBackupPath: string = bf2142Path / BF2142_EXE_NAME & FILE_BACKUP_SUFFIX
  let openspyDllBackupPath: string = bf2142Path / OPENSPY_DLL_NAME & FILE_BACKUP_SUFFIX
  if fileExists(clientExeBackupPath) or fileExists(openspyDllBackupPath):
    btnRestore.sensitive = true
  else:
    btnRestore.sensitive = false

proc preServerPatchCheck(ipAddress: IpAddress) =
  # when defined(windows):
  #   raise newException(ValueError, "Windows server precheck not implemented")
  #   return
  var serverExePath = bf2142ServerPath
  when defined(linux):
    serverExePath = serverExePath / "bin"
    when defined(cpu32):
      serverExePath = serverExePath / "ia-32"
    else:
      serverExePath = serverExePath / "amd-64"
    serverExePath = serverExePath / "bf2142"
  elif defined(windows):
    serverExePath = serverExePath / "BF2142_w32ded.exe"
  if serverExePath != "" and fileExists(serverExePath):
    var serverMd5Hash: string = getMD5(serverExePath.readFile()) # TODO: In a thread (slow gui startup) OR!! read file until first ground patched byte OR Create a check byte at the begining of the file
    var createBackup: bool = false
    if serverMd5Hash in [ORIGINAL_SERVER_MD5_HASH_32, ORIGINAL_SERVER_MD5_HASH_64]:
      echo "Found original server binary. Creating a backup and prepatching!"
      createBackup = true
    echo "Patching Battlefield 2142 server!"
    if hasWritePermission(serverExePath):
      if createBackup:
        copyFile(serverExePath, serverExePath & FILE_BACKUP_SUFFIX)
      preServerPatch(serverExePath, ipAddress, Port(8080))
    else:
      var fileSplit = splitFile(serverExePath)
      let tmpExePath: string = TEMP_FILES_DIR / fileSplit.name & fileSplit.ext
      if createBackup:
        if not copyFileElevated(serverExePath, serverExePath & FILE_BACKUP_SUFFIX):
          return
      copyFile(serverExePath, tmpExePath)
      preServerPatch(tmpExePath, ipAddress, Port(8080))
      discard copyFileElevated(tmpExePath, serverExePath)
      removeFile(tmpExePath)

proc newRangeEntry(min, max, step, value: float): tuple[spinButton: SpinButton, hScale: HScale] = # TODO: Handle values with bindProperty
  proc onValueChanged(self: SpinButton | HScale, other: SpinButton | HScale) =
    other.value = self.value
  result = (spinButton: newSpinButtonWithRange(min, max, step), hScale: newHScaleWithRange(min, max, step))
  result.spinButton.connect("enter-notify-event", onWidgetFakeHoverEnterNotifyEvent)
  result.spinButton.connect("leave-notify-event", onWidgetFakeHoverLeaveNotifyEvent)
  result.hScale.value = value
  result.spinButton.value = value
  result.hScale.connect("value-changed", onValueChanged, result.spinButton)
  result.spinButton.connect("value-changed", onValueChanged, result.hScale)

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
  discard dialog.run()
  dialog.destroy()

proc typeTest(o: gobject.Object; s: string): bool =
  let gt = g_type_from_name(s)
  return g_type_check_instance_is_a(cast[ptr TypeInstance00](o.impl), gt).toBool

proc listStore(o: gobject.Object): gtk.ListStore =
  assert(typeTest(o, "GtkListStore"))
  cast[gtk.ListStore](o)

proc appendMap(list: TreeView, mapName, mapMode, mapSize: string) =
  var
    valMapName: Value
    valMapMode: Value
    valMapSize: Value
    iter: TreeIter
  let store = listStore(list.getModel())
  store.append(iter)
  let gtype = typeFromName("gchararray")
  discard valMapName.init(gtype)
  valMapName.setString(mapName)
  store.setValue(iter, 0, valMapName)
  discard valMapMode.init(gtype)
  valMapMode.setString(mapMode)
  store.setValue(iter, 1, valMapMode)
  discard valMapSize.init(gtype)
  valMapSize.setString(mapSize)
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

proc removeSelected(list: TreeView) =
  var
    ls: ListStore
    iter: TreeIter
  let store = listStore(list.getModel())
  if not store.getIterFirst(iter):
      return
  if getSelected(list.selection, ls, iter):
    discard store.remove(iter)

proc selectedMap(list: TreeView): tuple[mapName: string, mapMode: string, mapSize: string] =
  var
    val: Value
    ls: ListStore
    iter: TreeIter
  let store = listStore(list.getModel())
  if not store.getIterFirst(iter):
      return ("", "", "")
  if getSelected(list.selection, ls, iter):
    store.getValue(iter, 0, val)
    result.mapName = $val.getString()
    store.getValue(iter, 1, val)
    result.mapMode = $val.getString()
    store.getValue(iter, 2, val)
    result.mapSize = $val.getString() # TODO: Should be int

iterator maps(list: TreeView): tuple[mapName: string, mapMode: string, mapSize: string] =
  var
    model: TreeModel = list.model()
    iter: TreeIter
    val: Value
    mapName: string
    mapMode: string
    mapSize: string
  var whileCond: bool = model.iterFirst(iter)
  while whileCond:
    model.getValue(iter, 0, val)
    mapName = $val.getString()
    model.getValue(iter, 1, val)
    mapMode = $val.getString()
    model.getValue(iter, 2, val)
    mapSize = $val.getString()
    yield((mapName, mapMode, mapSize))
    whileCond = model.iterNext(iter)

proc clear(list: TreeView) =
  var
    iter: TreeIter
  let store = listStore(list.getModel())
  if not store.iterFirst(iter):
    return
  clear(store)

proc fillListSelectableMaps() =
  listSelectableMaps.clear()
  var gameMode: string = cbxGameMode.activeId
  var xmlMapInfo: XmlNode
  for folder in walkDir(currentLevelFolderPath, true):
    if folder.kind != pcDir:
      continue
    xmlMapInfo = loadXml(currentLevelFolderPath / folder.path / "info" / folder.path & ".desc").child("modes")
    for xmlMode in xmlMapInfo.findAll("mode"):
      if xmlMode.attr("type") == gameMode:
        for xmlMapType in xmlMode.findAll("maptype"):
          listSelectableMaps.appendMap(folder.path, gameMode, xmlMapType.attr("players"))
        break

proc initMapList(list: TreeView, titleMap: string, titleMapMode: string = "Mode", titleMapSize: string = "Size") =
  var renderer: CellRendererText
  var column: TreeViewColumn
  # Map column
  renderer = newCellRendererText()
  column = newTreeViewColumn()
  column.title = titleMap
  column.packStart(renderer, true)
  column.addAttribute(renderer, "text", 0)
  discard list.appendColumn(column)
  # Mapmode column
  renderer = newCellRendererText()
  column = newTreeViewColumn()
  column.title = titleMapMode
  column.packStart(renderer, true)
  column.addAttribute(renderer, "text", 1)
  discard list.appendColumn(column)
  # Mapsize column
  renderer = newCellRendererText()
  column = newTreeViewColumn()
  column.title = titleMapSize
  column.packStart(renderer, true)
  column.addAttribute(renderer, "text", 2)
  discard list.appendColumn(column)

  let gtypes = [typeFromName("gchararray"), typeFromName("gchararray"), typeFromName("gchararray")]
  let store: ListStore = newListStore(3, unsafeAddr gtypes)
  list.setModel(store)

proc updatePathes() =
  var currentModPath: string = bf2142ServerPath / "mods" / cbxHostMods.activeText
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
    file = open(currentServerSettingsPath, fmRead)

  # Server config
  while file.readLine(line):
    (setting, value) = line.splitWhitespace(maxsplit = 1)
    case setting:
      of SETTING_ROUNDS_PER_MINUTE:
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
      of SETTING_TEAM_RATIO:
        discard # TODO: Implement SETTING_TEAM_RATIO
    if save:
      serverConfig.add(setting & ' ' & value & '\n')
  file.close()
  if save:
    if hasWritePermission(currentServerSettingsPath):
      writeFile(currentServerSettingsPath, serverConfig)
    else:
      return writeFileElevated(currentServerSettingsPath, serverConfig)
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
    file = open(currentAiSettingsPath, fmRead)

  # AI config
  while file.readLine(line):
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
  file.close()

  if not aiConfig.contains(AISETTING_OVERRIDE_MENU_SETTINGS): # Requiered to override bot amount
    if save:
      aiConfig.add(AISETTING_OVERRIDE_MENU_SETTINGS & " 1")
  if not aiConfig.contains(AISETTING_MAX_BOTS_INCLUDE_HUMANS):
    if save:
      aiConfig.add(AISETTING_MAX_BOTS_INCLUDE_HUMANS & " 0")

  if save:
    if hasWritePermission(currentAiSettingsPath):
      writeFile(currentAiSettingsPath, aiConfig)
    else:
      return writeFileElevated(currentAiSettingsPath, aiConfig)
  return true

proc saveAiSettings(): bool =
  return loadSaveAiSettings(save = true)

proc loadAiSettings(): bool =
  return loadSaveAiSettings(save = false)

proc saveMapList(): bool =
  var mapListContent: string
  for map in listSelectedMaps.maps:
    mapListContent.add("mapList.append " & map.mapName & ' ' & map.mapMode & ' ' & map.mapSize & '\n')
  if hasWritePermission(currentMapListPath):
    writeFile(currentMapListPath, mapListContent)
  else:
    return writeFileElevated(currentMapListPath, mapListContent)
  return true

proc loadMapList(): bool =
  var file = open(currentMapListPath, fmRead)
  var line, mapName, mapMode, mapSize: string
  while file.readLine(line):
    (mapName, mapMode, mapSize) = line.splitWhitespace()[1..3]
    listSelectedMaps.appendMap(mapName, mapMode, mapSize)
  file.close()
  return true

proc checkProfileFiles() =
  if bf2142ProfilesPath == "":
    raise newException(ValueError, "checkProfileFiles - bf2142ProfilesPath == \"\"")
  discard existsOrCreateDir(documentsPath  / "Battlefield 2142")
  discard existsOrCreateDir(documentsPath  / "Battlefield 2142" / "Profiles")
  if not existsOrCreateDir(bf2142Profile0001Path):
    writeFile(bf2142Profile0001Path / "Audio.con", PROFILE_AUDIO_CON)
    writeFile(bf2142Profile0001Path / "Controls.con", PROFILE_CONTROLS_CON)
    writeFile(bf2142Profile0001Path / "General.con", PROFILE_GENERAL_CON)
    writeFile(bf2142Profile0001Path / "Profile.con", PROFILE_PROFILE_CON)
    writeFile(bf2142Profile0001Path / "ServerSettings.con", PROFILE_SERVER_SETTINGS_CON)
    writeFile(bf2142Profile0001Path / "Video.con", PROFILE_VIDEO_CON)

proc saveProfileAccountName() =
  checkProfileFiles()
  var profileConPath: string = bf2142Profile0001Path / "Profile.con"
  var file = open(profileConPath, fmRead)
  var line, profileContent: string
  while file.readLine(line):
    if line.startsWith("LocalProfile.setEAOnlineMasterAccount"):
      profileContent.add("LocalProfile.setEAOnlineMasterAccount \"" & txtPlayerName.text & "\"\n" )
    elif line.startsWith("LocalProfile.setEAOnlineSubAccount"):
      profileContent.add("LocalProfile.setEAOnlineSubAccount \"" & txtPlayerName.text & "\"\n" )
    else:
      profileContent.add(line & '\n')
  file.close()
  writeFile(profileConPath, profileContent)

proc startLoginServer(term: Terminal, ipAddress: IpAddress) =
  term.setSizeRequest(0, 300)
  when defined(linux):
    termLoginServerPid = term.startProcess(command = fmt"./server {$ipAddress}")
  elif defined(windows):
    termLoginServerPid = term.startProcess(command = fmt"server.exe {$ipAddress}")

proc startBF2142Server() =
  termBF2142Server.setSizeRequest(0, 300)
  var stupidPbSymlink: string = bf2142ServerPath / "pb"
  if symlinkExists(stupidPbSymlink):
    removeFile(stupidPbSymlink)
  when defined(linux):
    termBF2142ServerPid = termBF2142Server.startProcess(command = "/bin/bash start.sh", workingDir = bf2142ServerPath, env = "TERM=xterm")
  elif defined(windows):
    termBF2142ServerPid = termBF2142Server.startProcess(command = "BF2142_w32ded.exe", workingDir = bf2142ServerPath, searchForkedProcess = true)

proc loadJoinMods() =
  cbxJoinMods.removeAll()
  if bf2142Path.len > 0:
    for folder in walkDir(bf2142Path / "mods", true):
      if folder.kind == pcDir:
        cbxJoinMods.appendText(folder.path)
  cbxJoinMods.active = 0

proc loadHostMods() =
  cbxHostMods.removeAll()
  if bf2142ServerPath.len > 0:
    for folder in walkDir(bf2142ServerPath / "mods", true):
      if folder.kind == pcDir:
        cbxHostMods.appendText(folder.path)
  cbxHostMods.active = 0

proc applyHostRunningSensitivity(running: bool, bf2142ServerInvisible: bool = false) =
  tblHostSettings.sensitive = not running
  hboxMaps.sensitive = not running
  btnHostLoginServer.visible = not running
  btnHost.visible = not running
  btnHostCancel.visible = running
  hboxTerms.visible = running
  termLoginServer.visible = running
  if bf2142ServerInvisible:
    termBF2142Server.visible = false
  else:
    termBF2142Server.visible = running

proc applyJustPlayRunningSensitivity(running: bool) =
  termJustPlayServer.visible = running
  btnJustPlay.visible = not running
  btnJustPlayCancel.visible = running
##


### Events
## Join
proc patchAndStartLogic(): bool =
  let ipAddress: string = txtIpAddress.text.strip()
  txtPlayerName.text = txtPlayerName.text.strip()
  var invalidStr: string
  if ipAddress.startsWith("127") or ipAddress == "localhost": # TODO: Check if ip is also an valid ipv4 address
    invalidStr.add("\t* Localhost addresses are currently not supported. Battlefield 2142 starts with a black screen if you're trying to connect to a localhost address.\n")
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
  # config.setSectionKey(CONFIG_SECTION_GENERAL, CONFIG_KEY_IP_ADDRESS, ipAddress)
  config.setSectionKey(CONFIG_SECTION_GENERAL, CONFIG_KEY_PLAYER_NAME, txtPlayerName.text)
  config.setSectionKey(CONFIG_SECTION_GENERAL, CONFIG_KEY_AUTO_JOIN, $chbtnAutoJoin.active)
  config.setSectionKey(CONFIG_SECTION_GENERAL, CONFIG_KEY_WINDOW_MODE, $chbtnWindowMode.active)
  config.writeConfig(CONFIG_FILE_NAME)

  preClientPatchCheck()
  var writeSucceed: bool = true
  if hasWritePermission(bf2142Path / BF2142_EXE_NAME):
    patchClient(bf2142Path / BF2142_EXE_NAME, ipAddress.parseIpAddress(), Port(8080))
  else:
    copyFile(bf2142Path / BF2142_EXE_NAME, TEMP_FILES_DIR / BF2142_EXE_NAME)
    patchClient(TEMP_FILES_DIR / BF2142_EXE_NAME, ipAddress.parseIpAddress(), Port(8080))
    writeSucceed = copyFileElevated(TEMP_FILES_DIR / BF2142_EXE_NAME, bf2142Path / BF2142_EXE_NAME)
    removeFile(TEMP_FILES_DIR / BF2142_EXE_NAME)
  if not writeSucceed:
    return

  openspyBackupCheck()

  saveProfileAccountName()
  # TODO: Check if server is reachable before starting BF2142 (try out all 3 port)
  var command: string
  when defined(linux):
    when not defined(release):
      command.add("WINEDEBUG=fixme-all,err-winediag" & ' ') # TODO: Remove some nasty fixme's and errors for development
    if txtWinePrefix.text != "":
      command.add("WINEPREFIX=" & txtWinePrefix.text & ' ')
  # command.add("WINEARCH=win32" & ' ') # TODO: Implement this if user would like to run this in 32 bit mode (only requierd on first run)
  when defined(linux):
    if txtStartupQuery.text != "":
      command.add(txtStartupQuery.text & ' ')
  command.add(BF2142_EXE_NAME & ' ')
  command.add("+modPath mods/" &  cbxJoinMods.activeText & ' ')
  command.add("+menu 1" & ' ') # TODO: Check if this is necessary
  if chbtnWindowMode.active:
    command.add("+fullscreen 0" & ' ')
  command.add("+widescreen 1" & ' ') # INFO: Enables widescreen resolutions in bf2142 ingame graphic settings
  command.add("+eaAccountName " & txtPlayerName.text & ' ')
  command.add("+eaAccountPassword A" & ' ')
  command.add("+soldierName " & txtPlayerName.text & ' ')
  if chbtnAutoJoin.active:
    command.add("+joinServer " & ipAddress)
  when defined(linux): # TODO: Check if bf2142Path is neccessary
    let processCommand: string = command
  elif defined(windows):
    let processCommand: string = bf2142Path & '\\' & command
  var process: Process = startProcess(command = processCommand, workingDir = bf2142Path,
    options = {poStdErrToStdOut, poParentStreams, poEvalCommand, poEchoCmd}
  )
  return true

proc onBtnJoinClicked(self: Button) =
  discard patchAndStartLogic()

proc onBtnJustPlayClicked(self: Button) =
  var ipAddress: IpAddress = getLocalAddrs()[0].parseIpAddress() # TODO: Add checks and warnings
  txtIpAddress.text = $ipAddress
  if termLoginServerPid > 0:
    killProcess(termLoginServerPid)
  termJustPlayServer.clear()
  termJustPlayServer.startLoginServer(ipAddress)
  termLoginServer.visible = false
  chbtnAutoJoin.active = false
  if patchAndStartLogic():
    applyJustPlayRunningSensitivity(true)
    if termBF2142ServerPid == 0:
      applyHostRunningSensitivity(false)

proc onBtnJustPlayCancelClicked(self: Button) =
  killProcess(termLoginServerPid)
  applyJustPlayRunningSensitivity(false)

proc onBtnAddMapClicked(self: Button) =
  var mapName, mapMode, mapSize: string
  (mapName, mapMode, mapSize) = listSelectableMaps.selectedMap
  if mapName == "" or mapMode == "" or mapSize == "": return
  listSelectedMaps.appendMap(mapName, mapMode, mapSize)
  listSelectableMaps.removeSelected()

proc onBtnRemoveMapClicked(self: Button) =
  var mapName, mapMode, mapSize: string
  (mapName, mapMode, mapSize) = listSelectedMaps.selectedMap
  if mapName == "" or mapMode == "" or mapSize == "": return
  if cbxGameMode.activeId == mapMode:
    listSelectableMaps.appendMap(mapName, mapMode, mapSize)
  listSelectedMaps.removeSelected()

proc onBtnMapMoveUpClicked(self: Button) =
  listSelectedMaps.moveSelectedUp()

proc onBtnMapMoveDownClicked(self: Button) =
  listSelectedMaps.moveSelectedDown()
#
## Host
proc onBtnHostClicked(self: Button) =
  if not saveMapList():
    return
  if not saveServerSettings():
    return
  if not saveAiSettings():
    return
  applyJustPlayRunningSensitivity(false)
  applyHostRunningSensitivity(true)
  preServerPatchCheck(txtHostIpAddress.text.parseIpAddress()) # TODO
  txtIpAddress.text = txtHostIpAddress.text
  if termLoginServerPid > 0:
    killProcess(termLoginServerPid)
  termLoginServer.clear()
  termLoginServer.startLoginServer(txtHostIpAddress.text.parseIpAddress()) # TODO
  startBF2142Server()

proc onBtnHostLoginServerClicked(self: Button) =
  applyJustPlayRunningSensitivity(false)
  applyHostRunningSensitivity(true, bf2142ServerInvisible = true)
  txtIpAddress.text = txtHostIpAddress.text
  if termLoginServerPid > 0:
    killProcess(termLoginServerPid)
  termLoginServer.clear()
  termLoginServer.startLoginServer(txtHostIpAddress.text.parseIpAddress()) # TODO

proc onBtnHostCancelClicked(self: Button) =
  applyHostRunningSensitivity(false)
  applyJustPlayRunningSensitivity(false)
  killProcess(termLoginServerPid)
  txtIpAddress.text = ""
  if termBF2142ServerPid > 0:
    killProcess(termBF2142ServerPid)

proc onCbxHostModsChanged(self: ComboBoxText) =
  updatePathes()
  fillListSelectableMaps()
  discard loadMapList()
  discard loadServerSettings()
  discard loadAiSettings()

proc onCbxGameModeChanged(self: ComboBoxText) =
  updatePathes()
  fillListSelectableMaps()

proc updateLevelPreview(mapName, mapMode, mapSize: string) =
  var imgPath: string
  imgPath = currentLevelFolderPath / mapName / "info" / mapMode & "_" & mapSize & "_menumap.png"
  if fileExists(imgPath):
    var pixbuf = newPixbufFromFile(imgPath)
    pixbuf = pixbuf.scaleSimple(478, 341, InterpType.bilinear) # 478x341 is the default size of BF2142 menumap images
    imgLevelPreview.setFromPixbuf(pixbuf)
  elif fileExists(NO_PREVIEW_IMG_PATH):
    imgLevelPreview.setFromFile(NO_PREVIEW_IMG_PATH) # TODO: newPixbufFromBytes
  else:
    imgLevelPreview.clear()

proc onListSelectableMapsCursorChanged(self: TreeView) =
  var mapName, mapMode, mapSize: string
  (mapName, mapMode, mapSize) = listSelectableMaps.selectedMap
  updateLevelPreview(mapName, mapMode, mapSize)

proc onListSelectedMapsRowActivated(self: TreeView, path: TreePath, column: TreeViewColumn) =
  var mapName, mapMode, mapSize: string
  (mapName, mapMode, mapSize) = listSelectedMaps.selectedMap
  updateLevelPreview(mapName, mapMode, mapSize)
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

proc onBtnBF2142PathClicked(self: Button) = # TODO: Add checks
  var (responseType, path) = selectFolderDialog(lblBF2142Path.text[0..^2])
  if responseType != ResponseType.ok:
    return
  if not fileExists(path / BF2142_EXE_NAME):
    newInfoDialog("Could not find BF2142.exe", "Could not find BF2142.exe. The path is invalid!")
    return
  vboxJoin.visible = true
  vboxHost.visible = true
  bf2142Path = path
  txtBF2142Path.text = path
  if btnRestore.sensitive == false:
    restoreCheck()
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

proc onBtnBF2142ServerPathClicked(self: Button) = # TODO: Add Checks
  var (responseType, path) = selectFolderDialog(lblBF2142ServerPath.text[0..^2])
  if responseType != ResponseType.ok:
    return
  if bf2142ServerPath == path:
    return
  bf2142ServerPath = path
  txtBF2142ServerPath.text = path
  updatePathes()
  loadHostMods()
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_BF2142_SERVER_PATH, bf2142ServerPath)
  config.writeConfig(CONFIG_FILE_NAME)

proc onBtnWinePrefixClicked(self: Button) = # TODO: Add checks
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

proc onTxtStartupQueryFocusOut(self: Entry, event: EventFocus): bool =
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_STARTUP_QUERY, txtStartupQuery.text)
  config.writeConfig(CONFIG_FILE_NAME)

proc onBtnRemoveMoviesClicked(self: Button) =
  for movie in walkDir(bf2142Path / "mods" / "bf2142" / "Movies"): # TODO: Hacky, make it cleaner
    if movie.kind == pcFile and not movie.path.endsWith("titan_tutorial.bik"):
      echo "Removing movie: ", movie.path
      if hasWritePermission(movie.path):
        removeFile(movie.path)
      else:
        discard removeFileElevated(movie.path)

proc copyLevels(srcLevelPath, dstLevelPath: string, createBackup: bool = false, isServer: bool = false): bool =
  result = true
  var srcPath, dstPath, dstArchiveMd5Path, levelName: string
  if createBackup:
    echo "Creating a Levels folder backup!"
    if not copyDirElevated(dstLevelPath, dstLevelPath & "_backup_" & $epochTime().toInt()): # TODO: Check if dir could be copied as normal user
      return false
  for levelFolder in walkDir(srcLevelPath, true):
    levelName = levelFolder.path
    when defined(linux):
      if isServer:
        levelName = levelFolder.path.toLower()
    if not existsOrCreateDirElevated(dstLevelPath / levelName)[0]: # TODO: Check for write permission
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
        if not copyDirElevated(srcPath, dstPath): # TODO: Check for write permission
          return false
      elif levelFiles.kind == pcFile:
        if hasWritePermission(dstPath):
          copyFile(srcPath, dstPath)
        else:
          if not copyFileElevated(srcPath, dstPath):
            return false
    ## Move desc file # TODO: Create a recursive function that walks every file in each folder
    # if isServer: # Linux only # TODO: Refactor copyLevels
    if isServer: # Moving all files in levels info folder with lowercase namens
      let infoPath = dstLevelPath / levelName / "info"
      for fileName in walkDir(infoPath, true):
        if fileName.kind == pcFile:
          when defined(linux):
            let srcDescPath = infoPath / fileName.path
            let dstDescPath = infoPath / fileName.path.toLower()
            if srcDescPath != dstDescPath:
              moveFile(srcDescPath, dstDescPath) # TODO: Move elevated on windows

          block FIX_INVALID_XML_FILES: # Fixes invalid xml files, should be deleted later
            const AEGIS_STATION_DESC_MD5_HASH: string = "5709317f425bf7e639eb57842095852e"
            const BLOODGULCH_DESC_MD5_HASH: string = "bc08f0711ba9a37a357e196e4167c2b0"
            const KILIMANDSCHARO_DESC_MD5_HASH: string = "b165b81cf9949a89924b0f196d0ceec3"
            const OMAHA_BEACH_DESC_MD5_HASH: string = "0e28bad9b61224f7889cfffcded81182"
            const PANORAMA_DESC_MD5_HASH: string = "5288a6a0dded7df3c60341f5a20a5f0a"
            const SEVERNAYA_DESC_MD5_HASH: string = "6de6b4433ecc35dd11467fff3f4e5cc4"
            const STREET_DESC_MD5_HASH: string = "d36161b9b4638e315809ba2dd8bf4cdf"
            proc removeLine(path, fileName: string, val: int): bool =
              var raw: string = readFile(path / fileName.toLower())
              var rawLines: seq[string] = raw.splitLines()
              rawLines.delete(val - 1)
              when defined(windows):
                if hasWritePermission(path / fileName):
                  writeFile(path / fileName, rawLines.join("\n"))
                else:
                  if not writeFileElevated(path / fileName, rawLines.join("\n")):
                    return false
              else:
                writeFile(path / fileName.toLower(), rawLines.join("\n"))
              return true
            proc removeChars(path: string, fileName: string, valFrom, valTo: int): bool =
              var raw: string = readFile(path / fileName.toLower())
              raw.delete(valFrom - 1, valTo - 1)
              when defined(windows):
                if hasWritePermission(path / fileName):
                  writeFile(path / fileName, raw)
                else:
                  if not writeFileElevated(path / fileName, raw):
                    return false
              else:
                writeFile(path / fileName.toLower(), raw)
              return true
            if fileName.path.endsWith(".desc"):
              if fileName.path.toLower() == "aegis_station.desc" and getMd5(readFile(infoPath / fileName.path.toLower())) == AEGIS_STATION_DESC_MD5_HASH:
                if not removeChars(infoPath, fileName.path, 1464, 1464): # Fix: Remove char on position 1464
                  return false
              if fileName.path.toLower() == "bloodgulch.desc" and getMd5(readFile(infoPath / fileName.path.toLower())) == BLOODGULCH_DESC_MD5_HASH:
                if not removeLine(infoPath, fileName.path, 20): # Fix: Delete line 20
                  return false
              if fileName.path.toLower() == "kilimandscharo.desc" and getMd5(readFile(infoPath / fileName.path.toLower())) == KILIMANDSCHARO_DESC_MD5_HASH:
                if not removeLine(infoPath, fileName.path, 7): # Fix: Delete line 7
                  return false
              if fileName.path.toLower() == "omaha_beach.desc" and getMd5(readFile(infoPath / fileName.path.toLower())) == OMAHA_BEACH_DESC_MD5_HASH:
                if not removeLine(infoPath, fileName.path, 11): # Fix: Delete line 11
                  return false
              if fileName.path.toLower() == "panorama.desc" and getMd5(readFile(infoPath / fileName.path.toLower())) == PANORAMA_DESC_MD5_HASH:
                if not removeLine(infoPath, fileName.path, 14): # Fix: Delete line 14
                  return false
              if fileName.path.toLower() == "severnaya.desc" and getMd5(readFile(infoPath / fileName.path.toLower())) == SEVERNAYA_DESC_MD5_HASH:
                if not removeLine(infoPath, fileName.path, 16): # Fix: Delete line 16
                  return false
              if fileName.path.toLower() == "street.desc" and getMd5(readFile(infoPath / fileName.path.toLower())) == STREET_DESC_MD5_HASH:
                if not removeLine(infoPath, fileName.path, 9): # Fix: Delete line 9
                  return false


proc onBtnPatchClientMapsClickedResponse(dialog: FileChooserDialog; responseId: int) =
  let
    response = ResponseType(responseId)
    srcLevelPath: string = dialog.getFilename()
    dstLevelPath: string = bf2142Path / "mods" / "bf2142" / "Levels"
  if response == ResponseType.ok:
    var writeSucceed: bool = copyLevels(srcLevelPath, dstLevelPath)
    dialog.destroy()
    if writeSucceed:
      newInfoDialog("Done", "Copied 64 coop maps (client)!")
  else:
    dialog.destroy()

proc onBtnPatchClientMapsClicked(self: Button) =
  let chooser = newFileChooserDialog("Select levels folder to copy from (client)", nil, FileChooserAction.selectFolder)
  discard chooser.addButton("Ok", ResponseType.ok.ord)
  discard chooser.addButton("Cancel", ResponseType.cancel.ord)
  chooser.connect("response", onBtnPatchClientMapsClickedResponse)
  chooser.show()

proc onBtnPatchServerMapsClickedResponse(dialog: FileChooserDialog; responseId: int) =
  let
    response = ResponseType(responseId)
    srcLevelPath: string = dialog.getFilename()
    dstLevelPath: string = bf2142ServerPath / "mods" / "bf2142" / "levels"
  if response == ResponseType.ok:
    var writeSucceed: bool = copyLevels(srcLevelPath = srcLevelPath, dstLevelPath = dstLevelPath, isServer = true)
    dialog.destroy()
    if writeSucceed:
      fillListSelectableMaps()
      newInfoDialog("Done", "Copied 64 coop maps (server)!")
  else:
    dialog.destroy()

proc onBtnPatchServerMapsClicked(self: Button) =
  let chooser = newFileChooserDialog("Select levels folder to copy from (server)", nil, FileChooserAction.selectFolder)
  discard chooser.addButton("Ok", ResponseType.ok.ord)
  discard chooser.addButton("Cancel", ResponseType.cancel.ord)
  chooser.connect("response", onBtnPatchServerMapsClickedResponse)
  chooser.show()

proc onBtnRestoreClicked(self: Button) =
  let clientExeBackupPath: string = bf2142Path / BF2142_EXE_NAME & FILE_BACKUP_SUFFIX
  let clientExeRestorePath: string = bf2142Path / BF2142_EXE_NAME
  let openspyDllBackupPath: string = bf2142Path / OPENSPY_DLL_NAME & FILE_BACKUP_SUFFIX
  let openspyDllRestorePath: string = bf2142Path / OPENSPY_DLL_NAME
  var restoredFiles: bool = false
  if bf2142Path == "":
    return
  if fileExists(clientExeBackupPath):
    let clientMd5Hash: string = getMD5(clientExeBackupPath.readFile()) # TODO: In a thread (slow gui startup) OR!! read file until first ground patched byte OR Create a check byte at the begining of the file
    if clientMd5Hash == ORIGINAL_CLIENT_MD5_HASH:
      echo "Found original client binary (" & BF2142_EXE_NAME & "). Restoring!"
      if hasWritePermission(clientExeBackupPath):
        copyFile(clientExeBackupPath, clientExeRestorePath)
        removeFile(clientExeBackupPath)
      else:
        if not copyFileElevated(clientExeBackupPath, clientExeRestorePath):
          return
        if not removeFileElevated(clientExeBackupPath):
          return
      restoredFiles = true
  if fileExists(openspyDllBackupPath):
    let openspyMd5Hash: string = getMD5(openspyDllBackupPath.readFile())
    if openspyMd5Hash == OPENSPY_MD5_HASH:
      echo "Found openspy dll (" & OPENSPY_DLL_NAME & "). Restoring!"
      if hasWritePermission(openspyDllBackupPath):
        copyFile(openspyDllBackupPath, openspyDllRestorePath)
        removeFile(openspyDllBackupPath)
      else:
        if not copyFileElevated(openspyDllBackupPath, openspyDllRestorePath):
          return
        if not removeFileElevated(openspyDllBackupPath):
          return
      restoredFiles = true
  if restoredFiles:
    btnRestore.sensitive = false
#
##
proc createNotebook(window: gtk.Window): Notebook =
  result = newNotebook()
  ### Join
  lblJoinMods = newLabel("Mods:")
  lblJoinMods.styleContext.addClass("label")
  lblJoinMods.setAlignment(0.0, 0.5)
  cbxJoinMods = newComboBoxText()
  lblPlayerName = newLabel("Player name: ")
  lblPlayerName.styleContext.addClass("label")
  lblPlayerName.setAlignment(0.0, 0.5)
  txtPlayerName = newEntry()
  txtPlayerName.styleContext.addClass("entry")
  lblIpAddress = newLabel("IP-Address:")
  lblIpAddress.styleContext.addClass("label")
  lblIpAddress.setAlignment(0.0, 0.5)
  txtIpAddress = newEntry()
  txtIpAddress.styleContext.addClass("entry")
  lblAutoJoin = newLabel("Auto join server:")
  lblAutoJoin.styleContext.addClass("label")
  chbtnAutoJoin = newCheckButton()
  lblWindowMode = newLabel("Window mode:")
  lblWindowMode.styleContext.addClass("label")
  lblWindowMode.setAlignment(0.0, 0.5)
  chbtnWindowMode = newCheckButton()
  btnJoin = newButton("Connect")
  btnJoin.styleContext.addClass("button")
  btnJustPlay = newButton("Just play")
  btnJustPlay.styleContext.addClass("button")
  btnJustPlay.styleContext.addClass("justPlay")
  btnJustPlay.setSizeRequest(0, 50)
  btnJustPlayCancel = newButton("Cancel")
  btnJustPlayCancel.styleContext.addClass("button")
  btnJustPlayCancel.styleContext.addClass("justPlay")
  btnJustPlayCancel.setSizeRequest(0, 50)

  tblJoinConnect = newTable(3, 2, false)
  tblJoinConnect.halign = Align.start
  tblJoinConnect.hexpand = true
  tblJoinConnect.rowSpacings = 2
  tblJoinConnect.attach(lblIpAddress, 0, 1, 0, 1, {AttachFlag.expand, AttachFlag.fill}, {}, 5, 3)
  tblJoinConnect.attach(txtIpAddress, 1, 2, 0, 1, {AttachFlag.expand, AttachFlag.fill}, {}, 5, 3)
  tblJoinConnect.attach(lblAutoJoin, 0, 1, 1, 2, {AttachFlag.expand, AttachFlag.fill}, {}, 5, 3)
  tblJoinConnect.attach(chbtnAutoJoin, 1, 2, 1, 2, {AttachFlag.expand, AttachFlag.fill}, {}, 5, 3)
  tblJoinConnect.attach(btnJoin, 0, 2, 2, 3, {AttachFlag.expand, AttachFlag.fill}, {}, 5, 3)
  frameJoinConnect = newFrame("Connect")
  frameJoinConnect.add(tblJoinConnect)

  tblJoinSettings = newTable(3, 2, false)
  tblJoinSettings.halign = Align.start
  tblJoinSettings.hexpand = true
  tblJoinSettings.rowSpacings = 2
  tblJoinSettings.attach(lblJoinMods, 0, 1, 0, 1, {AttachFlag.expand, AttachFlag.fill}, {}, 5, 3)
  tblJoinSettings.attach(cbxJoinMods, 1, 2, 0, 1, {AttachFlag.expand, AttachFlag.fill}, {}, 5, 3)
  tblJoinSettings.attach(lblPlayerName, 0, 1, 1, 2, {AttachFlag.expand, AttachFlag.fill}, {}, 5, 3)
  tblJoinSettings.attach(txtPlayerName, 1, 2, 1, 2, {AttachFlag.expand, AttachFlag.fill}, {}, 5, 3)
  tblJoinSettings.attach(lblWindowMode, 0, 1, 2, 3, {AttachFlag.expand, AttachFlag.fill}, {}, 5, 3)
  tblJoinSettings.attach(chbtnWindowMode, 1, 2, 2, 3, {AttachFlag.expand, AttachFlag.fill}, {}, 5, 3)
  frameJoinSettings = newFrame("Game settings")
  frameJoinSettings.add(tblJoinSettings)

  hboxJoinSettings = newBox(Orientation.horizontal, 5)
  hboxJoinSettings.vexpand = true
  hboxJoinSettings.styleContext.addClass("box")
  hboxJoinSettings.add(frameJoinConnect)
  hboxJoinSettings.add(frameJoinSettings)
  vboxJoin = newBox(Orientation.vertical, 5)
  vboxJoin.vexpand = true
  vboxJoin.styleContext.addClass("box")
  vboxJoin.add(hboxJoinSettings)
  # vboxJoin.add(btnJustPlay)
  termJustPlayServer = newTerminal()
  termJustPlayServer.vexpand = true

  vboxJustPlay = newBox(Orientation.vertical, 0)
  vboxJustPlay.hexpand = true
  vboxJustPlay.add(btnJustPlay)
  vboxJustPlay.add(termJustPlayServer)
  vboxJustPlay.add(btnJustPlayCancel)

  # panedJustPlay = newPaned(Orientation.vertical)
  # panedJustPlay.pack1(hboxJoinSettings, true, false)
  # panedJustPlay.pack2(vboxJustPlay, true, true)

  # vboxJoin.add(panedJustPlay)
  vboxJoin.add(vboxJustPlay)
  ##
  ### Host
  vboxHost = newBox(Orientation.vertical, 10)
  vboxHost.styleContext.addClass("box")
  lblHostMods = newLabel("Mods:")
  lblHostMods.styleContext.addClass("label")
  lblHostMods.setAlignment(0.0, 0.5)
  cbxHostMods = newComboBoxText()
  lblGameMode = newLabel("Game mode:")
  lblGameMode.styleContext.addClass("label")
  lblGameMode.setAlignment(0.0, 0.5)
  cbxGameMode = newComboBoxText()
  for mode in GAME_MODES:
    cbxGameMode.append(mode.id, mode.name)
  cbxGameMode.active = 2 # Coop
  lblBotSkill = newLabel("Bot skill:")
  lblBotSkill.styleContext.addClass("label")
  lblBotSkill.setAlignment(0.0, 0.5)
  (sbtnBotSkill, scaleBotSkill) = newRangeEntry(0, 1, 0.1, 0.5)
  lblTicketRatio = newLabel("Ticket ratio: ")
  lblTicketRatio.styleContext.addClass("label")
  lblTicketRatio.setAlignment(0.0, 0.5)
  (sbtnTicketRatio, scaleTicketRatio) = newRangeEntry(10, 999, 1, 100)
  lblSpawnTime = newLabel("Spawn time: ")
  lblSpawnTime.styleContext.addClass("label")
  lblSpawnTime.setAlignment(0.0, 0.5)
  (sbtnSpawnTime, scaleSpawnTime) = newRangeEntry(0, 60, 1, 15)
  lblRoundsPerMap = newLabel("Rounds per map: ")
  lblRoundsPerMap.styleContext.addClass("label")
  lblRoundsPerMap.setAlignment(0.0, 0.5)
  (sbtnRoundsPerMap, scaleRoundsPerMap) = newRangeEntry(1, 5, 1, 1)
  lblBots = newLabel("Bots: ")
  lblBots.styleContext.addClass("label")
  lblBots.setAlignment(0.0, 0.5)
  (sbtnBots, scaleBots) = newRangeEntry(0, 255, 1, 63)
  lblMaxPlayers = newLabel("Max players: ")
  lblMaxPlayers.styleContext.addClass("label")
  lblMaxPlayers.setAlignment(0.0, 0.5)
  (sbtnMaxPlayers, scaleMaxPlayers) = newRangeEntry(1, 64, 1, 64)
  lblPlayersNeededToStart = newLabel("Players needed to start: ")
  lblPlayersNeededToStart.styleContext.addClass("label")
  lblPlayersNeededToStart.setAlignment(0.0, 0.5)
  (sbtnPlayersNeededToStart, scalePlayersNeededToStart) = newRangeEntry(1, 64, 1, 1)
  lblFriendlyFire = newLabel("Friendly fire: ")
  lblFriendlyFire.styleContext.addClass("label")
  lblFriendlyFire.setAlignment(0.0, 0.5)
  chbtnFriendlyFire = newCheckButton()
  chbtnFriendlyFire.active = true
  lblHostIpAddress = newLabel("Server IP-Address: ")
  lblHostIpAddress.styleContext.addClass("label")
  lblHostIpAddress.setAlignment(0.0, 0.5)
  txtHostIpAddress = newEntry()
  txtHostIpAddress.styleContext.addClass("entry")
  tblHostSettings = newTable(11, 3, true)
  tblHostSettings.rowSpacings = 3
  tblHostSettings.attachDefaults(lblHostMods, 0, 1, 0, 1)
  tblHostSettings.attachDefaults(cbxHostMods, 1, 2, 0, 1)
  tblHostSettings.attachDefaults(lblGameMode, 0, 1, 1, 2)
  tblHostSettings.attachDefaults(cbxGameMode, 1, 2, 1, 2)
  tblHostSettings.attachDefaults(lblBotSkill, 0, 1, 2, 3)
  tblHostSettings.attachDefaults(sbtnBotSkill, 1, 2, 2, 3)
  tblHostSettings.attachDefaults(scaleBotSkill, 2, 3, 2, 3)
  tblHostSettings.attachDefaults(lblTicketRatio, 0, 1, 3, 4)
  tblHostSettings.attachDefaults(sbtnTicketRatio, 1, 2, 3, 4)
  tblHostSettings.attachDefaults(scaleTicketRatio, 2, 3, 3, 4)
  tblHostSettings.attachDefaults(lblSpawnTime, 0, 1, 4, 5)
  tblHostSettings.attachDefaults(sbtnSpawnTime, 1, 2, 4, 5)
  tblHostSettings.attachDefaults(scaleSpawnTime, 2, 3, 4, 5)
  tblHostSettings.attachDefaults(lblRoundsPerMap, 0, 1, 5, 6)
  tblHostSettings.attachDefaults(sbtnRoundsPerMap, 1, 2, 5, 6)
  tblHostSettings.attachDefaults(scaleRoundsPerMap, 2, 3, 5, 6)
  tblHostSettings.attachDefaults(lblBots, 0, 1, 6, 7)
  tblHostSettings.attachDefaults(sbtnBots, 1, 2, 6, 7)
  tblHostSettings.attachDefaults(scaleBots, 2, 3, 6, 7)
  tblHostSettings.attachDefaults(lblMaxPlayers, 0, 1, 7, 8)
  tblHostSettings.attachDefaults(sbtnMaxPlayers, 1, 2, 7, 8)
  tblHostSettings.attachDefaults(scaleMaxPlayers, 2, 3, 7, 8)
  tblHostSettings.attachDefaults(lblPlayersNeededToStart, 0, 1, 8, 9)
  tblHostSettings.attachDefaults(sbtnPlayersNeededToStart, 1, 2, 8, 9)
  tblHostSettings.attachDefaults(scalePlayersNeededToStart, 2, 3, 8, 9)
  tblHostSettings.attachDefaults(lblFriendlyFire, 0, 1, 9, 10)
  tblHostSettings.attachDefaults(chbtnFriendlyFire, 1, 2, 9, 10)
  tblHostSettings.attachDefaults(lblHostIpAddress, 0, 1, 10, 11)
  tblHostSettings.attachDefaults(txtHostIpAddress, 1, 2, 10, 11)
  tblHostSettings.halign = Align.start
  hboxHostLevelPreview = newBox(Orientation.horizontal, 0)
  hboxHostLevelPreview.add(tblHostSettings)
  imgLevelPreview = newImage()
  hboxHostLevelPreview.add(imgLevelPreview)
  vboxHost.add(hboxHostLevelPreview)
  listSelectableMaps = newTreeView()
  # listSelectableMaps.rulesHint = true # Sets a hint to the theme to draw rows in alternating colors. TODO: Cannot set even/odd row colors -.-
  listSelectableMaps.activateOnSingleClick = true
  listSelectableMaps.hexpand = true
  listSelectableMaps.initMapList("Maps")
  sWindowSelectableMaps = newScrolledWindow(listSelectableMaps.getHadjustment(), listSelectableMaps.getVadjustment())
  sWindowSelectableMaps.add(listSelectableMaps)
  listSelectedMaps = newTreeView()
  # listSelectedMaps.rulesHint = true # Sets a hint to the theme to draw rows in alternating colors. TODO: Cannot set even/odd row colors -.-
  listSelectedMaps.activateOnSingleClick = true
  listSelectedMaps.hexpand = true
  listSelectedMaps.initMapList("Selected maps")
  sWindowSelectedMaps = newScrolledWindow(listSelectedMaps.getHadjustment(), listSelectedMaps.getVadjustment())
  sWindowSelectedMaps.add(listSelectedMaps)
  vboxAddRemoveMap = newBox(Orientation.vertical, 10)
  vboxAddRemoveMap.valign = Align.center
  btnAddMap = newButton("→")
  btnAddMap.styleContext.addClass("button")
  vboxAddRemoveMap.add(btnAddMap)
  btnRemoveMap = newButton("←")
  btnRemoveMap.styleContext.addClass("button")
  vboxAddRemoveMap.add(btnRemoveMap)
  vboxMoveMap = newBox(Orientation.vertical, 10)
  vboxMoveMap.valign = Align.center
  btnMapMoveUp = newButton("↑")
  btnMapMoveUp.styleContext.addClass("button")
  vboxMoveMap.add(btnMapMoveUp)
  btnMapMoveDown = newButton("↓")
  btnMapMoveDown.styleContext.addClass("button")
  vboxMoveMap.add(btnMapMoveDown)
  hboxMaps = newBox(Orientation.horizontal, 5)
  hboxMaps.vexpand = true
  hboxMaps.add(sWindowSelectableMaps)
  hboxMaps.add(vboxAddRemoveMap)
  hboxMaps.add(sWindowSelectedMaps)
  hboxMaps.add(vboxMoveMap)
  vboxHost.add(hboxMaps)
  hboxHostButtons = newBox(Orientation.horizontal, 15)
  btnHostLoginServer = newButton("Host login server only")
  btnHostLoginServer.styleContext.addClass("button")
  btnHostLoginServer.hexpand = true
  btnHost = newButton("Host")
  btnHost.styleContext.addClass("button")
  btnHost.hexpand = true
  btnHostCancel = newButton("Cancel")
  btnHostCancel.styleContext.addClass("button")
  btnHostCancel.hexpand = true
  hboxHostButtons.add(btnHostLoginServer)
  hboxHostButtons.add(btnHost)
  hboxHostButtons.add(btnHostCancel)
  vboxHost.add(hboxHostButtons)
  termLoginServer = newTerminal()
  termLoginServer.hexpand = true
  hboxTerms = newBox(Orientation.horizontal, 1)
  # hboxTerms.hexpand = true
  hboxTerms.add(termLoginServer)
  termBF2142Server = newTerminal()
  termBF2142Server.hexpand = true
  hboxTerms.add(termBF2142Server)
  vboxHost.add(hboxTerms)
  ##
  ### Settings
  lblBF2142Path = newLabel("Battlefield 2142 path:")
  lblBF2142Path.styleContext.addClass("label")
  lblBF2142Path.setAlignment(0.0, 0.5)
  btnBF2142Path = newButton("Select")
  btnBF2142Path.styleContext.addClass("button")
  txtBF2142Path = newEntry()
  txtBF2142Path.styleContext.addClass("entry")
  txtBF2142Path.editable = false
  lblBF2142ServerPath = newLabel("Battlefield 2142 Server path:")
  lblBF2142ServerPath.styleContext.addClass("label")
  lblBF2142ServerPath.setAlignment(0.0, 0.5)
  btnBf2142ServerPath = newButton("Select")
  btnBf2142ServerPath.styleContext.addClass("button")
  txtBF2142ServerPath = newEntry()
  txtBF2142ServerPath.styleContext.addClass("entry")
  txtBF2142ServerPath.editable = false
  lblWinePrefix = newLabel("Wine prefix:") # Linux only
  lblWinePrefix.styleContext.addClass("label")
  lblWinePrefix.setAlignment(0.0, 0.5)
  btnWinePrefix = newButton("Select")
  btnWinePrefix.styleContext.addClass("button")
  txtWinePrefix = newEntry()
  txtWinePrefix.styleContext.addClass("entry")
  txtWinePrefix.editable = false
  lblStartupQuery = newLabel("Startup query:")
  lblStartupQuery.styleContext.addClass("label")
  lblStartupQuery.setAlignment(0.0, 0.5)
  txtStartupQuery = newEntry()
  txtStartupQuery.styleContext.addClass("entry")
  btnRemoveMovies = newButton("Remove movies")
  btnRemoveMovies.styleContext.addClass("button")
  btnPatchClientMaps = newButton("Copy 64 coop maps (client)")
  btnPatchClientMaps.styleContext.addClass("button")
  btnPatchServerMaps = newButton("Copy 64 coop maps (server)")
  btnPatchServerMaps.styleContext.addClass("button")
  btnRestore = newButton("Restore original files")
  btnRestore.styleContext.addClass("button")
  btnRestore.sensitive = false
  tblSettings = newTable(8, 3, false)
  tblSettings.rowSpacings = 5
  tblSettings.attach(lblBF2142Path, 0, 1, 0, 1, {AttachFlag.fill}, {}, 10, 0)
  tblSettings.attach(txtBF2142Path, 1, 2, 0, 1, {AttachFlag.expand, AttachFlag.fill}, {}, 0, 0)
  tblSettings.attach(btnBF2142Path, 2, 3, 0, 1, {AttachFlag.shrink}, {}, 0, 0)
  tblSettings.attach(lblBF2142ServerPath, 0, 1, 1, 2, {AttachFlag.fill}, {}, 10, 0)
  tblSettings.attach(txtBF2142ServerPath, 1, 2, 1, 2, {AttachFlag.expand, AttachFlag.fill}, {}, 0, 0)
  tblSettings.attach(btnBF2142ServerPath, 2, 3, 1, 2, {AttachFlag.shrink}, {}, 0, 0)
  tblSettings.attach(lblWinePrefix, 0, 1, 2, 3, {AttachFlag.fill}, {}, 10, 0)
  tblSettings.attach(txtWinePrefix, 1, 2, 2, 3, {AttachFlag.expand, AttachFlag.fill}, {}, 0, 0)
  tblSettings.attach(btnWinePrefix, 2, 3, 2, 3, {AttachFlag.shrink}, {}, 0, 0)
  tblSettings.attach(lblStartupQuery, 0, 1, 3, 4, {AttachFlag.fill}, {}, 10, 0)
  tblSettings.attach(txtStartupQuery, 1, 2, 3, 4, {AttachFlag.expand, AttachFlag.fill}, {}, 0, 0)
  tblSettings.attach(btnRemoveMovies, 1, 2, 4, 5, {AttachFlag.expand, AttachFlag.fill}, {}, 0, 0)
  tblSettings.attach(btnPatchClientMaps, 1, 2, 5, 6, {AttachFlag.expand, AttachFlag.fill}, {}, 0, 0)
  tblSettings.attach(btnPatchServerMaps, 1, 2, 6, 7, {AttachFlag.expand, AttachFlag.fill}, {}, 0, 0)
  tblSettings.attach(btnRestore, 1, 2, 7, 8, {AttachFlag.expand, AttachFlag.fill}, {}, 0, 0)
  vboxSettings = newBox(Orientation.vertical, 0)
  vboxSettings.styleContext.addClass("box")
  vboxSettings.add(tblSettings)
  ##
  ##
  ### Terminal sending data: vte_terminal_feed_child (For later admin.runNextRound button or something else)
  ##  cbxHostMods.connect("changed", onCbxHostModsChanged)
  discard result.appendPage(vboxJoin, newLabel("Join")) # returns page index?
  discard result.appendPage(vboxHost, newLabel("Host")) # returns page index?
  discard result.appendPage(vboxSettings, newLabel("Settings")) # returns page index?

proc onNotebookSwitchPage(self: Notebook, page: Widget, pageNum: int) =
  if pageNum == 1:
    if txtHostIpAddress.text == "":
      fillHostIpAddress()

proc connectSignals() =
  ### Bind signals
  ## General
  notebook.connect("switch-page", onNotebookSwitchPage)
  #
  ## Join
  txtPlayerName.connect("enter-notify-event", onWidgetFakeHoverEnterNotifyEvent)
  txtPlayerName.connect("leave-notify-event", onWidgetFakeHoverLeaveNotifyEvent)
  txtIpAddress.connect("enter-notify-event", onWidgetFakeHoverEnterNotifyEvent)
  txtIpAddress.connect("leave-notify-event", onWidgetFakeHoverLeaveNotifyEvent)
  btnJoin.connect("clicked", onBtnJoinClicked)
  btnJustPlay.connect("clicked", onBtnJustPlayClicked)
  btnJustPlayCancel.connect("clicked", onBtnJustPlayCancelClicked)
  #
  ## Host
  btnAddMap.connect("clicked", onBtnAddMapClicked)
  btnRemoveMap.connect("clicked", onBtnRemoveMapClicked)
  btnMapMoveUp.connect("clicked", onBtnMapMoveUpClicked)
  btnMapMoveDown.connect("clicked", onBtnMapMoveDownClicked)
  btnHostLoginServer.connect("clicked", onBtnHostLoginServerClicked)
  btnHost.connect("clicked", onBtnHostClicked)
  btnHostCancel.connect("clicked", onBtnHostCancelClicked)
  cbxHostMods.connect("changed", onCbxHostModsChanged)
  cbxGameMode.connect("changed", onCbxGameModeChanged)
  listSelectableMaps.connect("cursor-changed", onListSelectableMapsCursorChanged)
  listSelectedMaps.connect("row-activated", onListSelectedMapsRowActivated)
  #
  ## Settings
  btnBF2142Path.connect("clicked", onBtnBF2142PathClicked)
  btnBF2142ServerPath.connect("clicked", onBtnBF2142ServerPathClicked)
  btnWinePrefix.connect("clicked", onBtnWinePrefixClicked)
  txtStartupQuery.connect("focus-out-event", onTxtStartupQueryFocusOut)
  txtStartupQuery.connect("enter-notify-event", onWidgetFakeHoverEnterNotifyEvent)
  txtStartupQuery.connect("leave-notify-event", onWidgetFakeHoverLeaveNotifyEvent)
  btnRemoveMovies.connect("clicked", onBtnRemoveMoviesClicked)
  btnPatchClientMaps.connect("clicked", onBtnPatchClientMapsClicked)
  btnPatchServerMaps.connect("clicked", onBtnPatchServerMapsClicked)
  btnRestore.connect("clicked", onBtnRestoreClicked)
  #

var signalsConnected: bool = false # TODO: Workaround, because gintro does not implement the disconnect template/macro in gimpl.nim
proc onApplicationWindowDraw(window: ApplicationWindow, context: cairo.Context): bool =
  if not signalsConnected:
    connectSignals()
    signalsConnected = true

proc onApplicationWindowDestroy(window: ApplicationWindow) =
  if termBF2142ServerPid > 0:
    echo "KILLING BF2142 GAME SERVER"
    killProcess(termBF2142ServerPid)
  if termLoginServerPid > 0:
    echo "KILLING BF2142 LOGIN/UNLOCK SERVER"
    killProcess(termLoginServerPid)
  when defined(windows):
    if elevatedio.isServerRunning():
      echo "KILLING ELEVATEDIO SERVER"
      killElevatedIo()

proc onApplicationActivate(application: Application) =
  window = newApplicationWindow(application)
  window.connect("draw", onApplicationWindowDraw)
  window.connect("destroy", onApplicationWindowDestroy)
  # discard window.setIconFromFile(os.getCurrentDir() / "bf2142unlocker.icon")
  var cssProvider: CssProvider = newCssProvider()
  when defined(release):
    discard cssProvider.loadFromData(GUI_CSS)
  else:
    discard cssProvider.loadFromPath("gui.css")
  getDefaultScreen().addProviderForScreen(cssProvider, STYLE_PROVIDER_PRIORITY_USER)
  window.title = "BF2142Unlocker"
  window.defaultSize = (800, 600)
  window.position = WindowPosition.center
  vboxMain = newBox(Orientation.vertical, 0)
  vboxMain.styleContext.addClass("box")
  notebook = window.createNotebook()
  notebook.vexpand = true
  vboxMain.add(notebook)
  actionBar = newActionBar()
  actionBar.packEnd(newLinkButtonWithLabel("https://battlefield2142.co/", "Play online"))
  actionBar.packEnd(newLabel("|"))
  actionBar.packEnd(newLinkButtonWithLabel("https://www.moddb.com/mods/project-remaster", "Project Remaster Mod"))
  actionBar.packEnd(newLabel("|"))
  actionBar.packEnd(newLinkButtonWithLabel("https://www.moddb.com/mods/bf2142unlocker", "Moddb"))
  actionBar.packEnd(newLabel("|"))
  actionBar.packEnd(newLinkButtonWithLabel("https://github.com/Dankr4d/BF2142Unlocker", "Github"))
  actionBar.packStart(newLabel("Version: " & VERSION))
  vboxMain.add(actionBar)
  window.add(vboxMain)
  window.showAll()
  loadConfig()
  loadJoinMods()
  loadHostMods()
  if bf2142ServerPath != "":
    updatePathes()
    fillListSelectableMaps()
    discard loadMapList()
    discard loadServerSettings()
    discard loadAiSettings()
  hboxTerms.visible = false
  termJustPlayServer.visible = false
  termBF2142Server.visible = false
  termLoginServer.visible = false
  btnHostCancel.visible = false
  btnJustPlayCancel.visible = false
  when defined(windows):
    lblWinePrefix.visible = false
    txtWinePrefix.visible = false
    btnWinePrefix.visible = false
    lblStartupQuery.visible = false
    txtStartupQuery.visible = false
    if not dirExists(TEMP_FILES_DIR):
      createDir(TEMP_FILES_DIR)
  if bf2142Path == "":
    notebook.currentPage = 2 # Switch to settings tab when no Battlefield 2142 path is set
    vboxJoin.visible = false
    vboxHost.visible = false
  restoreCheck()

proc main =
  application = newApplication()
  application.connect("activate", onApplicationActivate)
  when defined(windows) and defined(release):
    # Hiding cmd, because I could not compile it as gui.
    # Warning: Do not start gui from cmd (it becomes invisible and need to be killed via taskmanager)
    # TODO: This is a workaround.
    ShowWindow(GetConsoleWindow(), SW_HIDE)
  discard run(application)

main()