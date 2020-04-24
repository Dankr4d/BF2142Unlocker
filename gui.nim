import gintro/[gtk, glib, gobject, gdk, cairo, gdkpixbuf]
import gintro/gio except ListStore
when defined(linux):
  import gintro/gmodule # Required to automatically bind signals on linux

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
  import cdkey # Required to set the cd key if it's not set (on startup)
import terminal # Terminal wrapper (uses vte on linux and textview on windows)
import parsecfg # Config
import md5 # Requierd to check if the current BF2142.exe is the original BF2142.exe
import times # Requierd for rudimentary level backup with epochtime suffix
import elevatedio # Requierd to write, copy and delete data elevated
import localaddrs, checkserver # Required to get all local adresses and check if servers are reachable
import signal # Required to use the custom signal pragma (checks windowShown flag and returns if false)
import resolutions # Required to read out all possible resolutions

# Set icon (windres.exe .\icon.rc -O coff -o icon.res)
when defined(gcc) and defined(windows):
  {.link: "icon.res".}

when defined(linux):
  {.passC:"-Wl,--export-dynamic".}
  {.passL:"-lgmodule-2.0 -rdynamic".}

var bf2142Path: string
var bf2142ServerPath: string
var documentsPath: string
var bf2142ProfilesPath: string
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
const OPENSPY_MD5_HASH: string = "c74f5a6b4189767dd82ccfcb13fc23c4"
const ORIGINAL_RENDDX9_MD5_HASH: string = "18a7be5d8761e54d43130b8a2a3078b9"

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
  SETTING_INTERNET: string = "sv.internet"

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

var termLoginServerPid: int = 0
var termBF2142ServerPid: int = 0

const
  PROFILE_AUDIO_CON: string = staticRead("profile/Audio.con")
  PROFILE_CONTROLS_CON: string = staticRead("profile/Controls.con")
  PROFILE_GENERAL_CON: string = staticRead("profile/General.con")
  PROFILE_PROFILE_CON: string = staticRead("profile/Profile.con")
  PROFILE_SERVER_SETTINGS_CON: string = staticRead("profile/ServerSettings.con")
  PROFILE_VIDEO_CON: string = staticRead("profile/Video.con")

when defined(release):
  const GUI_CSS: string = staticRead("gui.css")
  const GUI_GLADE: string = staticRead("gui.glade")
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
  CONFIG_KEY_UNLOCK_SQUAD_GADGETS: string = "unlock_squad_gadgets"
  CONFIG_KEY_RESOLUTION: string = "resolution"

# Required, because config loads values into widgets after gui is created,
# but the language must be set before gui init is called.
const LANGUAGE_FILE: string = "lang.txt"

const NO_PREVIEW_IMG_PATH: string = "nopreview.png"

var config: Config
var windowShown: bool = false

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
##
### Unlock controls
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
var btnRemoveMovies: Button
var btnPatchClientMaps: Button
var btnPatchServerMaps: Button
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
  let openspyMd5Hash: string = getMD5(openspyDllPath.readFile())
  let originalRendDX9Hash: string = getMD5(originalRendDX9Path.readFile())
  if openspyMd5Hash == OPENSPY_MD5_HASH and originalRendDX9Hash == ORIGINAL_RENDDX9_MD5_HASH:
    echo "Found openspy dll (" & OPENSPY_DLL_NAME & "). Creating a backup and restoring original file!"
    if not copyFileElevated(openspyDllPath, openspyDllPath & FILE_BACKUP_SUFFIX):
      return
    if not copyFileElevated(originalRendDX9Path, openspyDllPath):
      return

proc restoreOpenSpyIfExists() =
  let openspyDllBackupPath: string = bf2142Path / OPENSPY_DLL_NAME & FILE_BACKUP_SUFFIX
  let openspyDllRestorePath: string = bf2142Path / OPENSPY_DLL_NAME
  if not fileExists(openspyDllBackupPath):
    return
  let openspyMd5Hash: string = getMD5(openspyDllBackupPath.readFile())
  if openspyMd5Hash == OPENSPY_MD5_HASH:
    echo "Found openspy dll (" & OPENSPY_DLL_NAME & "). Restoring!"
    if not copyFileElevated(openspyDllBackupPath, openspyDllRestorePath):
      return
    if not removeFileElevated(openspyDllBackupPath):
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

proc updateLevelPreview(treeView: TreeView) =
  var mapName, mapMode, mapSize: string
  (mapName, mapMode, mapSize) = treeView.selectedMap
  updateLevelPreview(mapName, mapMode, mapSize)

proc selectNext(treeView: TreeView) =
  var iter: TreeIter
  var store: ListStore = listStore(treeView.getModel())
  if not treeView.selection.getSelected(store, iter):
    return
  if store.iterNext(iter):
    treeView.selection.selectIter(iter)
    treeView.scrollToCell(store.getPath(iter), nil, false, 0.0, 0.0)
    treeView.updateLevelPreview()

proc removeSelected(treeView: TreeView) =
  var
    ls: ListStore
    iter: TreeIter
  let store = listStore(treeView.getModel())
  if not store.getIterFirst(iter):
      return
  if getSelected(treeView.selection, ls, iter):
    discard store.remove(iter)
    treeView.updateLevelPreview()

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
      of SETTING_INTERNET:
        if save:
          value = "0" # TODO: Server crashes when internet is set to 1
      of SETTING_TEAM_RATIO:
        discard # TODO: Implement SETTING_TEAM_RATIO
    if save:
      serverConfig.add(setting & ' ' & value & '\n')
  file.close()
  if save:
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
  return writeFileElevated(currentMapListPath, mapListContent)

proc loadMapList(): bool =
  var file = open(currentMapListPath, fmRead)
  var line, mapName, mapMode, mapSize: string
  listSelectedMaps.clear()
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
    termLoginServerPid = term.startProcess(command = fmt"./server {$ipAddress} {$chbtnUnlockSquadGadgets.active}")
  elif defined(windows):
    termLoginServerPid = term.startProcess(command = fmt"server.exe {$ipAddress} {$chbtnUnlockSquadGadgets.active}")

proc startBF2142Server() =
  termBF2142Server.setSizeRequest(0, 300)
  var stupidPbSymlink: string = bf2142ServerPath / "pb"
  if symlinkExists(stupidPbSymlink):
    removeFile(stupidPbSymlink)
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

proc loadJoinMods() =
  var iter: TreeIter
  let store = listStore(cbxJoinMods.getModel())
  store.clear()
  if bf2142Path != "":
    for folder in walkDir(bf2142Path / "mods", true):
      if folder.kind == pcDir:
        var valMod: Value
        discard valMod.init(typeFromName("gchararray"))
        valMod.setString(folder.path)
        store.append(iter)
        store.setValue(iter, 0, valMod)
        store.setValue(iter, 1, valMod)
  discard cbxJoinMods.setActiveId("bf2142")

proc loadJoinResolutions() =
  var iter: TreeIter
  let store = listStore(cbxJoinResolutions.getModel())
  store.clear()
  var idx: int = 0
  for resolution in getAvailableResolutions():
    var valResolution: Value
    var valWidth: Value
    var valHeight: Value
    discard valResolution.init(typeFromName("gchararray"))
    discard valWidth.init(typeFromName("guint"))
    discard valHeight.init(typeFromName("guint"))
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

proc getSelectedResolution(): tuple[width, height: uint] =
  var iter: TreeIter
  let store = listStore(cbxJoinResolutions.getModel())
  discard cbxJoinResolutions.getActiveIter(iter)
  var valWidth: Value
  var valHeight: Value
  discard valWidth.init(typeFromName("guint"))
  discard valHeight.init(typeFromName("guint"))
  store.getValue(iter, 2, valWidth)
  store.getValue(iter, 3, valHeight)
  return (cast[uint](valWidth.getUint()), cast[uint](valHeight.getUint()))

proc loadHostMods() =
  var iter: TreeIter
  let store = listStore(cbxHostMods.getModel())
  store.clear()
  if bf2142ServerPath != "":
    for folder in walkDir(bf2142ServerPath / "mods", true):
      if folder.kind == pcDir:
        var valMod: Value
        discard valMod.init(typeFromName("gchararray"))
        valMod.setString(folder.path)
        store.append(iter)
        store.setValue(iter, 0, valMod)
        store.setValue(iter, 1, valMod)
  discard cbxHostMods.setActiveId("bf2142")

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
  config.setSectionKey(CONFIG_SECTION_GENERAL, CONFIG_KEY_RESOLUTION, cbxJoinResolutions.activeId)
  config.writeConfig(CONFIG_FILE_NAME)

  if not fileExists(bf2142Path / BF2142_UNLOCKER_EXE_NAME):
    if not copyFileElevated(bf2142Path / BF2142_EXE_NAME, bf2142Path / BF2142_UNLOCKER_EXE_NAME):
      return false
  if not patchClientElevated(bf2142Path / BF2142_UNLOCKER_EXE_NAME, ipAddress.parseIpAddress(), Port(8080)):
    return false

  backupOpenSpyIfExists()

  saveProfileAccountName()

  ## Check Logic (TODO: Cleanup and check servers in thread)
  var canConnect: bool = true
  throbberLoginServer.visible = true
  throbberGpcmServer.visible = true
  throbberUnlockServer.visible = true
  imgLoginServer.visible = false
  imgGpcmServer.visible = false
  imgUnlockServer.visible = false
  # Login server
  if isAddrReachable(ipAddress, Port(18300)):
    throbberLoginServer.visible = false
    imgLoginServer.visible = true
    imgLoginServer.setFromIconName("gtk-apply", 0)
  else:
    canConnect = false
    throbberLoginServer.visible = false
    imgLoginServer.visible = true
    imgLoginServer.setFromIconName("gtk-cancel", 0)
  # GPCM server
  if isAddrReachable(ipAddress, Port(29900)):
    throbberGpcmServer.visible = false
    imgGpcmServer.visible = true
    imgGpcmServer.setFromIconName("gtk-apply", 0)
  else:
    canConnect = false
    throbberGpcmServer.visible = false
    imgGpcmServer.visible = true
    imgGpcmServer.setFromIconName("gtk-cancel", 0)
  # Unlock server
  if isAddrReachable(ipAddress, Port(8080)):
    throbberUnlockServer.visible = false
    imgUnlockServer.visible = true
    imgUnlockServer.setFromIconName("gtk-apply", 0)
  else:
    canConnect = false
    throbberUnlockServer.visible = false
    imgUnlockServer.visible = true
    imgUnlockServer.setFromIconName("gtk-cancel", 0)
  if not canConnect:
    dlgCheckServers.show()
    # TODO: When checks are done in a thread, this dialog would be always shown when connecting,
    #       and if every server is reachable autoamtically hidden.
    return
  #

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
  command.add(BF2142_UNLOCKER_EXE_NAME & ' ')
  command.add("+modPath mods/" & cbxJoinMods.activeId & ' ')
  command.add("+menu 1" & ' ') # TODO: Check if this is necessary
  if chbtnWindowMode.active:
    command.add("+fullscreen 0" & ' ')
    var resolution: tuple[width, height: uint] = getSelectedResolution()
    command.add("+szx " & $resolution.width & ' ')
    command.add("+szy " & $resolution.height & ' ')
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

proc onBtnJoinClicked(self: Button00) {.signal.} =
  discard patchAndStartLogic()

proc onChbtnWindowModeToggled(self: CheckButton00) {.signal.} =
  lblJoinResolutions.visible = chbtnWindowMode.active
  cbxJoinResolutions.visible = chbtnWindowMode.active

proc onBtnJustPlayClicked(self: Button00) {.signal.} =
  var ipAddress: IpAddress = getLocalAddrs()[0].parseIpAddress() # TODO: Add checks and warnings
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
  var mapName, mapMode, mapSize: string
  (mapName, mapMode, mapSize) = listSelectableMaps.selectedMap
  if mapName == "" or mapMode == "" or mapSize == "": return
  listSelectedMaps.appendMap(mapName, mapMode, mapSize)
  listSelectableMaps.selectNext()

proc onBtnRemoveMapClicked(self: Button00) {.signal.} =
  var mapName, mapMode, mapSize: string
  (mapName, mapMode, mapSize) = listSelectedMaps.selectedMap
  if mapName == "" or mapMode == "" or mapSize == "": return
  listSelectedMaps.removeSelected()

proc onBtnMapMoveUpClicked(self: Button00) {.signal.} =
  listSelectedMaps.moveSelectedUp()

proc onBtnMapMoveDownClicked(self: Button00) {.signal.} =
  listSelectedMaps.moveSelectedDown()
#
## Host
proc onBtnHostClicked(self: Button00) {.signal.} =
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
    if not copyFileElevated(serverExePath / BF2142_SRV_EXE_NAME, serverExePath / BF2142_SRV_UNLOCKER_EXE_NAME):
      return
  serverExePath = serverExePath / BF2142_SRV_UNLOCKER_EXE_NAME
  echo "Patching Battlefield 2142 server!"
  if not patchServerElevated(serverExePath, txtHostIpAddress.text.parseIpAddress(), Port(8080)):
    return
  applyJustPlayRunningSensitivity(false)
  applyHostRunningSensitivity(true)
  txtIpAddress.text = txtHostIpAddress.text
  if termLoginServerPid > 0:
    killProcess(termLoginServerPid)
  termLoginServer.clear()
  termLoginServer.startLoginServer(txtHostIpAddress.text.parseIpAddress()) # TODO
  startBF2142Server()

proc onBtnHostLoginServerClicked(self: Button00) {.signal.} =
  applyJustPlayRunningSensitivity(false)
  applyHostRunningSensitivity(true, bf2142ServerInvisible = true)
  txtIpAddress.text = txtHostIpAddress.text
  if termLoginServerPid > 0:
    killProcess(termLoginServerPid)
  termLoginServer.clear()
  termLoginServer.startLoginServer(txtHostIpAddress.text.parseIpAddress()) # TODO

proc onBtnHostCancelClicked(self: Button00) {.signal.} =
  applyHostRunningSensitivity(false)
  applyJustPlayRunningSensitivity(false)
  killProcess(termLoginServerPid)
  txtIpAddress.text = ""
  if termBF2142ServerPid > 0:
    killProcess(termBF2142ServerPid)

proc onCbxHostModsChanged(self: ComboBox00) {.signal.} =
  updatePathes()
  fillListSelectableMaps()
  discard loadMapList()
  discard loadServerSettings()
  discard loadAiSettings()

proc onCbxGameModeChanged(self: ComboBox00) {.signal.} =
  updatePathes()
  fillListSelectableMaps()

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

proc onBtnBF2142PathClicked(self: Button00) {.signal.} = # TODO: Add checks
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

proc onBtnBF2142ServerPathClicked(self: Button00) {.signal.} = # TODO: Add Checks
  var (responseType, path) = selectFolderDialog(lblBF2142ServerPath.text[0..^2])
  if responseType != ResponseType.ok:
    return
  if bf2142ServerPath == path:
    return
  bf2142ServerPath = path
  txtBF2142ServerPath.text = path
  updatePathes()
  loadHostMods()
  fillListSelectableMaps()
  discard loadMapList()
  discard loadServerSettings()
  discard loadAiSettings()
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_BF2142_SERVER_PATH, bf2142ServerPath)
  config.writeConfig(CONFIG_FILE_NAME)

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

proc onBtnRemoveMoviesClicked(self: Button00) {.signal.} =
  for movie in walkDir(bf2142Path / "mods" / "bf2142" / "Movies"): # TODO: Hacky, make it cleaner
    if movie.kind == pcFile and not movie.path.endsWith("titan_tutorial.bik"):
      echo "Removing movie: ", movie.path
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
                if not writeFileElevated(path / fileName, rawLines.join("\n")):
                  return false
              else:
                writeFile(path / fileName.toLower(), rawLines.join("\n"))
              return true
            proc removeChars(path: string, fileName: string, valFrom, valTo: int): bool =
              var raw: string = readFile(path / fileName.toLower())
              raw.delete(valFrom - 1, valTo - 1)
              when defined(windows):
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

proc onBtnPatchClientMapsClicked(self: Button00) {.signal.} =
  let chooser = newFileChooserDialog("Select levels folder to copy from (client)", nil, FileChooserAction.selectFolder)
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
      fillListSelectableMaps()
      newInfoDialog("Done", "Copied 64 coop maps (server)!")
  else:
    dialog.destroy()

proc onBtnPatchServerMapsClicked(self: Button00) {.signal.} =
  let chooser = newFileChooserDialog("Select levels folder to copy from (server)", nil, FileChooserAction.selectFolder)
  discard chooser.addButton("Ok", ResponseType.ok.ord)
  discard chooser.addButton("Cancel", ResponseType.cancel.ord)
  chooser.connect("response", onBtnPatchServerMapsClickedResponse)
  chooser.show()
#
##

proc onNotebookSwitchPage(self: Notebook00, page: Widget00, pageNum: int) {.signal.} =
  if pageNum == 1:
    if txtHostIpAddress.text == "":
      fillHostIpAddress()

proc onApplicationWindowDraw(self: ApplicationWindow00, context: cairo.Context00): bool {.signalNoCheck.} =
  if not windowShown:
    windowShown = true

proc onApplicationWindowDestroy(self: ApplicationWindow00) {.signal.} =
  if termBF2142ServerPid > 0:
    echo "KILLING BF2142 GAME SERVER"
    killProcess(termBF2142ServerPid)
  if termLoginServerPid > 0:
    echo "KILLING BF2142 LOGIN/UNLOCK SERVER"
    killProcess(termLoginServerPid)
  restoreOpenSpyIfExists()
  when defined(windows):
    if elevatedio.isServerRunning():
      echo "KILLING ELEVATEDIO SERVER"
      killElevatedIo()

proc onCbxLanguagesChanged(self: ComboBox00) {.signal.} =
  if cbxLanguages.active == 0:
    removeFile(LANGUAGE_FILE)
    return
  writeFile(LANGUAGE_FILE, cbxLanguages.activeId)
  newInfoDialog("Info: Restart BF2142Unlocker", "To apply language changes, you need to restart BF2142Unlocker.")

proc onChbtnUnlockSquadGadgetsToggled(self: CheckButton00) {.signal.} =
  config.setSectionKey(CONFIG_SECTION_UNLOCKS, CONFIG_KEY_UNLOCK_SQUAD_GADGETS, $chbtnUnlockSquadGadgets.active)
  config.writeConfig(CONFIG_FILE_NAME)

proc onApplicationActivate(application: Application) =
  let builder = newBuilder()
  builder.translationDomain = "gui" # Autotranslate all "translatable" enabled widgets
  when defined(release):
    discard builder.addFromString(GUI_GLADE, GUI_GLADE.len)
  else:
    discard builder.addFromFile("gui.glade")
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
  btnRemoveMovies = builder.getButton("btnRemoveMovies")
  btnPatchClientMaps = builder.getButton("btnPatchClientMaps")
  btnPatchServerMaps = builder.getButton("btnPatchServerMaps")

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
  hboxTerms.add(termBF2142Server)
  #
  ## Setting current language (or "Auto detect")
  discard cbxLanguages.setActiveId(currentLocale)
  #
  ## Setting styles
  var cssProvider: CssProvider = newCssProvider()
  when defined(release):
    discard cssProvider.loadFromData(GUI_CSS)
  else:
    discard cssProvider.loadFromPath("gui.css")
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
    fillListSelectableMaps()
    discard loadMapList()
    discard loadServerSettings()
    discard loadAiSettings()
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
  when defined(windows): # TODO: Reading/setting cd key on linux
    setCdKeyIfNotExists() # Checking if cd key exists, if not an empty cd key is set

when defined(windows): # TODO: Cleanup
  proc setlocale(category: int, other: cstring): cstring {.header: "<locale.h>", importc.}
  var LC_ALL {.header: "<locale.h>", importc: "LC_ALL".}: int
  proc bindtextdomain(domainname: cstring, dirname: cstring): cstring {.dynlib: "libintl-8.dll", importc.}
  proc bind_textdomain_codeset(domainname: cstring, codeset: cstring): cstring {.dynlib: "libintl-8.dll", importc.}
else:
  proc bindtextdomain(domainname: cstring, dirname: cstring): cstring {.header: "<libintl.h>", importc.}

proc languageLogic() =
  if fileExists(LANGUAGE_FILE):
    currentLocale = readFile(LANGUAGE_FILE)
  discard bindtextdomain("gui", os.getCurrentDir() / "locale")
  if currentLocale == "": # Is empty if no LANGUAGE_FILE file was found
    currentLocale = $setlocale(LC_ALL, "");
    when defined(windows):
      # Required because of umlauts (Pango-WARNING **: 20:41:14.325: Invalid UTF-8 string passed to pango_layout_set_text())
      discard bind_textdomain_codeset("gui", "UTF-8")
    if currentLocale == "":
      disableSetlocale() # Required to set locale manually (in following line)
      # Setting language to en_US.utf8 when locale is not supported
      # TODO: Note, that this is not working if en_US.utf8 is not installed
      discard setlocale(LC_ALL, "en_US.utf8")
  else:
      # Setting manually selected langauge
      disableSetlocale() # Required to set locale manually (in following line)
      discard setlocale(LC_ALL, currentLocale)

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