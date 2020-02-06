import gintro/[gtk, glib, gobject, gdk, cairo]
import gintro/gio except ListStore

import os
import net # Requierd for ip parsing and type
import osproc # Requierd for process starting
import strutils
import xmlparser, xmltree # Requierd for map infos (and available modes for maps)
when defined(linux):
  import posix # Requierd for getlogin
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

# Set icon (windres.exe .\icon.rc -O coff -o icon.res)
when defined(gcc) and defined(windows):
  {.link: "icon.res".}

const TEMP_FILES_DIR*: string = "tempfiles" # TODO

var bf2142Path: string
var bf2142ServerPath: string
var documentsPath: string
var bf2142ProfilesPath: string
var bf2142Profile0001Path: string
var winePrefix: string
var startupQuery: string
var ipAddress: string
var playerName: string
var autoJoin: bool

const VERSION: string = "0.9.0"

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
var termBf2142ServerPid: int = 0

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
  CONFIG_KEY_IP_ADDRESS: string = "ip_address"
  CONFIG_KEY_AUTO_JOIN: string = "autojoin"

const NO_PREVIEW_IMG_PATH = "nopreview.png"

var config: Config

### General controls
var application: Application
var window: ApplicationWindow
var vboxMain: Box
var notebook: gtk.Notebook
##
### Join controls
var vboxJoin: Box
var actionBar: ActionBar
var tblJoin: Table
var lblJoinMods: Label
var cbxJoinMods: ComboBoxText
var lblPlayerName: Label
var txtPlayerName: Entry
var lblIpAddress: Label
var txtIpAddress: Entry
var lblAutoJoin: Label
var chbtnAutoJoin: CheckButton
var btnJoin: Button
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
var fchsrBtnBF2142Path: FileChooserButton
var lblBF2142ServerPath: Label
var fchsrBtnBF2142ServerPath: FileChooserButton
var lblWinePrefix: Label
var fchsrBtnWinePrefix: FileChooserButton
var lblStartupQuery: Label
var txtStartupQuery: Entry
var btnRemoveMovies: Button
var btnPatchClientMaps: Button
var btnPatchServerMaps: Button
var btnRestore: Button
##

### Helper procs
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
    discard fchsrBtnBF2142Path.setFilename(bf2142Path)
  bf2142ServerPath = config.getSectionValue(CONFIG_SECTION_SETTINGS, CONFIG_KEY_BF2142_SERVER_PATH)
  if bf2142ServerPath != "":
    discard fchsrBtnBF2142ServerPath.setFilename(bf2142ServerPath)
  winePrefix = config.getSectionValue(CONFIG_SECTION_SETTINGS, CONFIG_KEY_WINEPREFIX)
  when defined(linux):
    if winePrefix != "":
      discard fchsrBtnWinePrefix.setFilename(winePrefix)
      documentsPath = winePrefix / "drive_c" / "users" / $getlogin() / "My Documents"
  elif defined(windows):
    documentsPath = getDocumentsPath()
  updateProfilePathes()
  startupQuery = config.getSectionValue(CONFIG_SECTION_SETTINGS, CONFIG_KEY_STARTUP_QUERY)
  if startupQuery == "":
    when defined(linux):
      txtStartupQuery.text = "/usr/bin/wine"
    elif defined(windows):
      txtStartupQuery.text = "start"
  else:
    txtStartupQuery.text = startupQuery
  ipAddress = config.getSectionValue(CONFIG_SECTION_GENERAL, CONFIG_KEY_IP_ADDRESS)
  txtIpAddress.text = ipAddress
  playerName = config.getSectionValue(CONFIG_SECTION_GENERAL, CONFIG_KEY_PLAYER_NAME)
  txtPlayerName.text = playerName
  var autoJoinStr = config.getSectionValue(CONFIG_SECTION_GENERAL, CONFIG_KEY_AUTO_JOIN)
  if autoJoinStr != "":
    autoJoin = autoJoinStr.parseBool()
  else:
    autojoin = true
  chbtnAutoJoin.active = autoJoin

proc preClientPatchCheck() =
  let clientExePath: string = bf2142Path / BF2142_EXE_NAME
  if bf2142Path == "":
    return
  if fileExists(clientExePath):
    let clientMd5Hash: string = getMD5(clientExePath.readFile()) # TODO: In a thread (slow gui startup) OR!! read file until first ground patched byte OR Create a check byte at the begining of the file
    if clientMd5Hash == ORIGINAL_CLIENT_MD5_HASH:
      echo "Found original client binary (" & BF2142_EXE_NAME & "). Creating a backup and prepatching!"
      if hasWritePermission(clientExePath):
        copyFile(clientExePath, clientExePath & FILE_BACKUP_SUFFIX)
        preClientPatch(clientExePath)
      else:
        let tmpExePath: string = TEMP_FILES_DIR / BF2142_EXE_NAME
        copyFileElevated(clientExePath, clientExePath & FILE_BACKUP_SUFFIX)
        copyFile(clientExePath, tmpExePath)
        preClientPatch(tmpExePath)
        copyFileElevated(tmpExePath, clientExePath)
        removeFile(tmpExePath)
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
        copyFileElevated(openspyDllPath, openspyDllPath & FILE_BACKUP_SUFFIX)
        copyFileElevated(originalRendDX9Path, openspyDllPath)
      btnRestore.sensitive = true

proc restoreCheck() =
  let clientExeBackupPath: string = bf2142Path / BF2142_EXE_NAME & FILE_BACKUP_SUFFIX
  let openspyDllBackupPath: string = bf2142Path / OPENSPY_DLL_NAME & FILE_BACKUP_SUFFIX
  if fileExists(clientExeBackupPath) or fileExists(openspyDllBackupPath):
    btnRestore.sensitive = true
  else:
    btnRestore.sensitive = false

proc preServerPatchCheck() =
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
    if serverMd5Hash in [ORIGINAL_SERVER_MD5_HASH_32, ORIGINAL_SERVER_MD5_HASH_64]:
      echo "Found original server binary. Creating a backup and prepatching!"
      if hasWritePermission(serverExePath):
        copyFile(serverExePath, serverExePath & FILE_BACKUP_SUFFIX)
        preServerPatch(serverExePath, parseIpAddress("127.0.0.1"), Port(8080))
      else:
        var fileSplit = splitFile(serverExePath)
        let tmpExePath: string = TEMP_FILES_DIR / fileSplit.name & fileSplit.ext
        copyFileElevated(serverExePath, serverExePath & FILE_BACKUP_SUFFIX)
        copyFile(serverExePath, tmpExePath)
        preServerPatch(tmpExePath, parseIpAddress("127.0.0.1"), Port(8080))
        copyFileElevated(tmpExePath, serverExePath)
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

proc loadSaveServerSettings(save: bool) =
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
      of SETTING_TEAM_RATIO:
        discard # TODO: Implement SETTING_TEAM_RATIO
    if save:
      serverConfig.add(setting & ' ' & value & '\n')
  file.close()
  if save:
    if hasWritePermission(currentServerSettingsPath):
      writeFile(currentServerSettingsPath, serverConfig)
    else:
      writeFileElevated(currentServerSettingsPath, serverConfig)

proc saveServerSettings() =
  loadSaveServerSettings(save = true)

proc loadServerSettings() =
  loadSaveServerSettings(save = false)

proc loadSaveAiSettings(save: bool) =
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
      writeFileElevated(currentAiSettingsPath, aiConfig)

proc saveAiSettings() =
  loadSaveAiSettings(save = true)

proc loadAiSettings() =
  loadSaveAiSettings(save = false)

proc saveMapList() =
  var mapListContent: string
  for map in listSelectedMaps.maps:
    mapListContent.add("mapList.append " & map.mapName & ' ' & map.mapMode & ' ' & map.mapSize & '\n')
  if hasWritePermission(currentMapListPath):
    writeFile(currentMapListPath, mapListContent)
  else:
    writeFileElevated(currentMapListPath, mapListContent)

proc loadMapList() =
  var file = open(currentMapListPath, fmRead)
  var line, mapName, mapMode, mapSize: string
  while file.readLine(line):
    (mapName, mapMode, mapSize) = line.splitWhitespace()[1..3]
    listSelectedMaps.appendMap(mapName, mapMode, mapSize)
  file.close()

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
      profileContent.add("LocalProfile.setEAOnlineMasterAccount \"" & playerName & "\"\n" )
    elif line.startsWith("LocalProfile.setEAOnlineSubAccount"):
      profileContent.add("LocalProfile.setEAOnlineSubAccount \"" & playerName & "\"\n" )
    else:
      profileContent.add(line & '\n')
  file.close()
  writeFile(profileConPath, profileContent)

proc startLoginServer() =
  termLoginServer.setSizeRequest(0, 300)
  when defined(linux):
    termLoginServerPid = termLoginServer.startProcess(command = "./server")
  elif defined(windows):
    termLoginServerPid = termLoginServer.startProcess(command = "server.exe")

proc startBF2142Server() =
  termBF2142Server.setSizeRequest(0, 300)
  var stupidPbSymlink: string = bf2142ServerPath / "pb"
  if symlinkExists(stupidPbSymlink):
    removeFile(stupidPbSymlink)
  when defined(linux):
    termBf2142ServerPid = termBF2142Server.startProcess(command = "/bin/bash start.sh", workingDir = bf2142ServerPath, env = "TERM=xterm")
  elif defined(windows):
    termBf2142ServerPid = termBF2142Server.startProcess(command = "BF2142_w32ded.exe", workingDir = bf2142ServerPath, searchForkedProcess = true)

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
##


### Events
## Join
proc onBtnJoinClicked(self: Button) =
  playerName = txtPlayerName.text.strip()
  ipAddress = txtIpAddress.text.strip()
  autoJoin = chbtnAutoJoin.active
  var invalidStr: string
  if ipAddress.startsWith("127") or ipAddress == "localhost": # TODO: Check if ip is also an valid ipv4 address
    invalidStr.add("\t* Localhost addresses are currently not supported. Battlefield 2142 starts with a black screen if you're trying to connect to a localhost address.\n")
  if not ipAddress.isIpAddress():
    invalidStr.add("\t* Your IP-address is not valid.\n")
  elif ipAddress.parseIpAddress().family == IPv6:
    invalidStr.add("\t* IPv6 not testes!\n") # TODO: Add ignore?
  if playerName.len == 0:
    invalidStr.add("\t* You need to specify a playername with at least one character.\n")
  if bf2142Path == "": # TODO: Some more checkes are requierd (e.g. does BF2142.exe exists)
    invalidStr.add("\t* You need to specify your Battlefield 2142 path in \"Settings\"-Tab.\n")
  when defined(linux):
    if winePrefix == "":
      invalidStr.add("\t* You need to specify your wine path (in \"Settings\"-Tab).\n")
  if invalidStr.len > 0:
    newInfoDialog("Error", invalidStr)
    return
  config.setSectionKey(CONFIG_SECTION_GENERAL, CONFIG_KEY_IP_ADDRESS, ipAddress)
  config.setSectionKey(CONFIG_SECTION_GENERAL, CONFIG_KEY_PLAYER_NAME, playerName)
  config.setSectionKey(CONFIG_SECTION_GENERAL, CONFIG_KEY_AUTO_JOIN, $autoJoin)
  config.writeConfig(CONFIG_FILE_NAME)

  preClientPatchCheck()
  if hasWritePermission(bf2142Path / BF2142_EXE_NAME):
    patchClient(bf2142Path / BF2142_EXE_NAME, ipAddress.parseIpAddress(), Port(8080))
  else:
    copyFile(bf2142Path / BF2142_EXE_NAME, TEMP_FILES_DIR / BF2142_EXE_NAME)
    patchClient(TEMP_FILES_DIR / BF2142_EXE_NAME, ipAddress.parseIpAddress(), Port(8080))
    copyFileElevated(TEMP_FILES_DIR / BF2142_EXE_NAME, bf2142Path / BF2142_EXE_NAME)
    removeFile(TEMP_FILES_DIR / BF2142_EXE_NAME)

  openspyBackupCheck()

  saveProfileAccountName()
  # TODO: Check if server is reachable before starting BF2142 (try out all 3 port)
  var command: string
  when defined(linux):
    when defined(debug):
      command.add("WINEDEBUG=fixme-all,err-winediag" & ' ') # TODO: Remove some nasty fixme's and errors for development
    if winePrefix != "":
      command.add("WINEPREFIX=" & wineprefix & ' ')
  # command.add("WINEARCH=win32" & ' ') # TODO: Implement this if user would like to run this in 32 bit mode (only requierd on first run)
  if startupQuery != "":
    command.add(startupQuery & ' ')
  command.add(BF2142_EXE_NAME & ' ')
  command.add("+modPath mods/" &  cbxJoinMods.activeText & ' ')
  command.add("+menu 1" & ' ') # TODO: Check if this is necessary
  # command.add("+fullscreen 0" & ' ') # TODO: Implement this as settings option
  command.add("+widescreen 1" & ' ') # INFO: Enables widescreen resolutions in bf2142 ingame graphic settings
  command.add("+eaAccountName " & playerName & ' ')
  command.add("+eaAccountPassword A" & ' ')
  command.add("+soldierName " & playerName & ' ')
  if autoJoin:
    command.add("+joinServer " & ipAddress)
  when defined(linux): # TODO: Check if bf2142Path is neccessary
    let processCommand: string = command
  elif defined(windows):
    let processCommand: string = bf2142Path & '\\' & command
  var process: Process = startProcess(command = processCommand, workingDir = bf2142Path,
    options = {poStdErrToStdOut, poParentStreams, poEvalCommand, poEchoCmd}
  )


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
  # var thread: system.Thread[void]
  # thread.createThread(server.run)
  tblHostSettings.sensitive = false
  hboxMaps.sensitive = false
  btnHostLoginServer.visible = false
  btnHost.visible = false
  btnHostCancel.visible = true
  saveMapList()
  saveServerSettings()
  saveAiSettings()
  hboxTerms.visible = true
  termLoginServer.visible = true
  termBF2142Server.visible = true
  startLoginServer()
  startBF2142Server()

proc onBtnHostLoginServerClicked(self: Button) =
  tblHostSettings.sensitive = false
  hboxMaps.sensitive = false
  btnHostLoginServer.visible = false
  btnHost.visible = false
  btnHostCancel.visible = true
  hboxTerms.visible = true
  termLoginServer.visible = true
  startLoginServer()

proc onBtnHostCancelClicked(self: Button) =
  tblHostSettings.sensitive = true
  hboxMaps.sensitive = true
  btnHostLoginServer.visible = true
  btnHost.visible = true
  btnHostCancel.visible = false
  hboxTerms.visible = false
  termBF2142Server.visible = false
  termLoginServer.visible = false
  if termLoginServerPid > 0:
    termLoginServer.killProcess(termLoginServerPid)
    termLoginServer.clear()
    termLoginServerPid = 0
  if termBf2142ServerPid > 0:
    termBF2142Server.killProcess(termBf2142ServerPid)
    termLoginServer.clear()
    termBf2142ServerPid = 0

proc onCbxHostModsChanged(self: ComboBoxText) =
  updatePathes()
  fillListSelectableMaps()
  loadMapList()
  loadServerSettings()
  loadAiSettings()

proc onCbxGameModeChanged(self: ComboBoxText) =
  updatePathes()
  fillListSelectableMaps()

proc updateLevelPreview(mapName, mapMode, mapSize: string) =
  var imgPath: string
  imgPath = currentLevelFolderPath / mapName / "info" / mapMode & "_" & mapSize & "_menuMap.png"
  if fileExists(imgPath):
    imgLevelPreview.setFromFile(imgPath)
  elif fileExists(NO_PREVIEW_IMG_PATH):
    imgLevelPreview.setFromFile(NO_PREVIEW_IMG_PATH)
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
proc onFchsrBtnBF2142PathSelectionChanged(self: FileChooserButton) = # TODO: Add checks
  bf2142Path = self.getFilename()
  if btnRestore.sensitive == false:
    restoreCheck()
  loadJoinMods()
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_BF2142_PATH, bf2142Path)
  when defined(linux):
    var wineStartPos: int = bf2142Path.find(".wine")
    var wineEndPos: int
    if wineStartPos > -1:
      wineEndPos = bf2142Path.find(DirSep, wineStartPos) - 1
      if fchsrBtnWinePrefix.getFilename() == "": # TODO: Ask with Dialog if the read out wineprefix should be assigned to txtWinePrefix's text
        winePrefix = bf2142Path.substr(0, wineEndPos)
        discard fchsrBtnWinePrefix.setFilename(winePrefix)
        config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_WINEPREFIX, winePrefix) # TODO: Create a saveWinePrefix proc
  config.writeConfig(CONFIG_FILE_NAME)

proc onFchsrBtnBF2142ServerPathSelectionChanged(self: FileChooserButton) = # TODO: Add checks
  bf2142ServerPath = self.getFilename()
  preServerPatchCheck()
  updatePathes()
  loadHostMods()
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_BF2142_SERVER_PATH, bf2142ServerPath)
  config.writeConfig(CONFIG_FILE_NAME)

proc onFchsrBtnWinePrefixSelectionChanged(self: FileChooserButton) = # TODO: Add checks
  winePrefix = self.getFilename()
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_WINEPREFIX, winePrefix)
  config.writeConfig(CONFIG_FILE_NAME)
  when defined(linux): # Getlogin is only available for linux
    documentsPath = winePrefix / "drive_c" / "users" / $getlogin() / "My Documents"
  updateProfilePathes()

proc onTxtStartupQueryFocusOut(self: Entry, event: EventFocus): bool =
  startupQuery = self.text
  config.setSectionKey(CONFIG_SECTION_SETTINGS, CONFIG_KEY_STARTUP_QUERY, startupQuery)
  config.writeConfig(CONFIG_FILE_NAME)

proc onBtnRemoveMoviesClicked(self: Button) =
  for movie in walkDir(bf2142Path / "mods" / "bf2142" / "Movies"): # TODO: Hacky, make it cleaner
    if movie.kind == pcFile and not movie.path.endsWith("titan_tutorial.bik"):
      echo "Removing movie: ", movie.path
      if hasWritePermission(movie.path):
        removeFile(movie.path)
      else:
        removeFileElevated(movie.path)

proc copyLevels(srcLevelPath, dstLevelPath: string, excludeFiles: seq[string] = @[], createBackup: bool = true, copyLevelsLowerCase: bool = false) =
  var srcPath, dstPath, dstArchiveMd5Path, levelName: string
  echo "Creating a Levels folder backup!"
  if createBackup:
    copyDirElevated(dstLevelPath, dstLevelPath & "_backup_" & $epochTime().toInt()) # TODO: Check if dir could be copied as normal user
  for levelFolder in walkDir(srcLevelPath, true):
    levelName = levelFolder.path
    if copyLevelsLowerCase:
      levelName = levelFolder.path.toLower()
    discard existsOrCreateDirElevated(dstLevelPath / levelName) # TODO: Check for write permission
    echo "Copying level: ", levelName
    for levelFiles in walkDir(srcLevelPath / levelName, true):
      dstPath = dstLevelPath / levelName / levelFiles.path
      srcPath = srcLevelPath / levelName / levelFiles.path
      if levelFiles.path in excludeFiles:
        continue
      if levelFiles.kind == pcDir:
        copyDirElevated(srcPath, dstPath) # TODO: Check for write permission
      elif levelFiles.kind == pcFile:
        if hasWritePermission(dstPath):
          copyFile(srcPath, dstPath)
        else:
          copyFileElevated(srcPath, dstPath)
  for levelPath in walkDir(dstLevelPath): # We need to rewalk levels to delete all archive.md5 files
    dstArchiveMd5Path = levelPath.path / "archive.md5"
    if fileExists(dstArchiveMd5Path):
      echo "Removing checksum file: ", dstArchiveMd5Path
      if hasWritePermission(dstArchiveMd5Path):
        removeFile(dstArchiveMd5Path)
      else:
        removeFileElevated(dstArchiveMd5Path)

proc onBtnPatchClientMapsClickedResponse(dialog: FileChooserDialog; responseId: int) =
  let
    response = ResponseType(responseId)
    srcLevelPath: string = dialog.getFilename()
    dstLevelPath: string = bf2142Path / "mods" / "bf2142" / "Levels"
  if response == ResponseType.ok:
    copyLevels(srcLevelPath, dstLevelPath)
    dialog.destroy()
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
    dstLevelPath: string = bf2142ServerPath / "mods" / "bf2142" / "Levels" # TODO: Check if "Levels" is in linux lowercase (i think so)
    copyLevelsLowerCase: bool = defined(linux)
  if response == ResponseType.ok:
    copyLevels(srcLevelPath = srcLevelPath, dstLevelPath = dstLevelPath, excludeFiles = @["client.zip"], copyLevelsLowerCase = copyLevelsLowerCase)
    fillListSelectableMaps()
    dialog.destroy()
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
        copyFileElevated(clientExeBackupPath, clientExeRestorePath)
        removeFileElevated(clientExeBackupPath)
      restoredFiles = true
  if fileExists(openspyDllBackupPath):
    let openspyMd5Hash: string = getMD5(openspyDllBackupPath.readFile())
    if openspyMd5Hash == OPENSPY_MD5_HASH:
      echo "Found openspy dll (" & OPENSPY_DLL_NAME & "). Restoring!"
      if hasWritePermission(openspyDllBackupPath):
        copyFile(openspyDllBackupPath, openspyDllRestorePath)
        removeFile(openspyDllBackupPath)
      else:
        copyFileElevated(openspyDllBackupPath, openspyDllRestorePath)
        removeFileElevated(openspyDllBackupPath)
      restoredFiles = true
  if restoredFiles:
    btnRestore.sensitive = false
#
##
proc createNotebook(): NoteBook =
  result = newNotebook()
  ### Join
  lblJoinMods = newLabel("Mods:")
  lblJoinMods.styleContext.addClass("label")
  lblJoinMods.setAlignment(0.0, 0.5)
  cbxJoinMods = newComboBoxText()
  lblPlayerName = newLabel("Player name: ")
  lblPlayerName.styleContext.addClass("label")
  txtPlayerName = newEntry()
  txtPlayerName.styleContext.addClass("entry")
  lblIpAddress = newLabel("IP-Address:")
  lblIpAddress.styleContext.addClass("label")
  txtIpAddress = newEntry()
  txtIpAddress.styleContext.addClass("entry")
  lblAutoJoin = newLabel("Auto join server:")
  lblAutoJoin.styleContext.addClass("label")
  chbtnAutoJoin = newCheckButton()
  btnJoin = newButton("Join")
  btnJoin.styleContext.addClass("button")
  tblJoin = newTable(5, 2, false)
  tblJoin.halign = Align.center
  tblJoin.attach(lblJoinMods, 0, 1, 0, 1, {AttachFlag.shrink}, {}, 0, 3)
  tblJoin.attach(cbxJoinMods, 1, 2, 0, 1, {AttachFlag.fill}, {}, 0, 3)
  tblJoin.attach(lblPlayerName, 0, 1, 1, 2, {AttachFlag.shrink}, {}, 0, 3)
  tblJoin.attach(txtPlayerName, 1, 2, 1, 2, {AttachFlag.shrink}, {}, 0, 3)
  tblJoin.attach(lblIpAddress, 0, 1, 2, 3, {AttachFlag.shrink}, {}, 0, 3)
  tblJoin.attach(txtIpAddress, 1, 2, 2, 3, {AttachFlag.shrink}, {}, 0, 3)
  tblJoin.attach(lblAutoJoin, 0, 1, 3, 4, {AttachFlag.shrink}, {}, 0, 3)
  tblJoin.attach(chbtnAutoJoin, 1, 2, 3, 4, {AttachFlag.shrink}, {}, 0, 3)
  tblJoin.attach(btnJoin, 0, 2, 4, 5, {AttachFlag.fill}, {}, 0, 3)
  vboxJoin = newBox(Orientation.vertical, 0)
  vboxJoin.styleContext.addClass("box")
  vboxJoin.add(tblJoin)
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
  tblHostSettings = newTable(10, 3, true)
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
  fchsrBtnBF2142Path = newFileChooserButton(lblBF2142Path.text, FileChooserAction.selectFolder)
  lblBF2142ServerPath = newLabel("Battlefield 2142 Server path:")
  lblBF2142ServerPath.styleContext.addClass("label")
  fchsrBtnBF2142ServerPath = newFileChooserButton(lblBF2142ServerPath.text, FileChooserAction.selectFolder)
  lblWinePrefix = newLabel("Wine prefix:") # Linux only
  lblWinePrefix.styleContext.addClass("label")
  fchsrBtnWinePrefix = newFileChooserButton(lblWinePrefix.text, FileChooserAction.selectFolder)
  lblStartupQuery = newLabel("Startup query:")
  lblStartupQuery.styleContext.addClass("label")
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
  tblSettings = newTable(8, 2, false)
  tblSettings.rowSpacings = 5
  tblSettings.attach(lblBF2142Path, 0, 1, 0, 1, {}, {}, 10, 0)
  tblSettings.attach(fchsrBtnBF2142Path, 1, 2, 0, 1, {AttachFlag.expand, AttachFlag.fill}, {}, 0, 0)
  tblSettings.attach(lblBF2142ServerPath, 0, 1, 1, 2, {}, {}, 10, 0)
  tblSettings.attach(fchsrBtnBF2142ServerPath, 1, 2, 1, 2, {AttachFlag.expand, AttachFlag.fill}, {}, 0, 0)
  tblSettings.attach(lblWinePrefix, 0, 1, 2, 3, {}, {}, 10, 0)
  tblSettings.attach(fchsrBtnWinePrefix, 1, 2, 2, 3, {AttachFlag.expand, AttachFlag.fill}, {}, 0, 0)
  tblSettings.attach(lblStartupQuery, 0, 1, 3, 4, {}, {}, 10, 0)
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

proc connectSignals() =
  ### Bind signals
  ## Join
  txtPlayerName.connect("enter-notify-event", onWidgetFakeHoverEnterNotifyEvent)
  txtPlayerName.connect("leave-notify-event", onWidgetFakeHoverLeaveNotifyEvent)
  txtIpAddress.connect("enter-notify-event", onWidgetFakeHoverEnterNotifyEvent)
  txtIpAddress.connect("leave-notify-event", onWidgetFakeHoverLeaveNotifyEvent)
  btnJoin.connect("clicked", onBtnJoinClicked)
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
  fchsrBtnBF2142Path.connect("selection-changed", onFchsrBtnBF2142PathSelectionChanged)
  fchsrBtnBF2142ServerPath.connect("selection-changed", onFchsrBtnBF2142ServerPathSelectionChanged)
  fchsrBtnWinePrefix.connect("selection-changed", onFchsrBtnWinePrefixSelectionChanged)
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
  if termBf2142ServerPid > 0:
    echo "KILLING BF2142 GAME SERVER"
    termBF2142Server.killProcess(termBf2142ServerPid)
  if termLoginServerPid > 0:
    echo "KILLING BF2142 LOGIN/UNLOCK SERVER"
    termLoginServer.killProcess(termLoginServerPid)

proc onApplicationActivate(application: Application) =
  window = newApplicationWindow(application)
  window.connect("draw", onApplicationWindowDraw)
  window.connect("destroy", onApplicationWindowDestroy)
  # discard window.setIconFromFile(os.getCurrentDir() / "bf2142unlocker.icon")
  var cssProvider: CssProvider = newCssProvider()
  discard cssProvider.loadFromData(GUI_CSS)
  # discard cssProvider.loadFromPath("gui.css")
  getDefaultScreen().addProviderForScreen(cssProvider, STYLE_PROVIDER_PRIORITY_USER)
  window.title = "BF2142Unlocker - Launcher"
  window.defaultSize = (957, 600)
  window.position = WindowPosition.center
  vboxMain = newBox(Orientation.vertical, 0)
  vboxMain.styleContext.addClass("box")
  notebook = createNotebook()
  notebook.vexpand = true
  vboxMain.add(notebook)
  actionBar = newActionBar()
  actionbar.packEnd(newLinkButtonWithLabel("https://www.moddb.com/mods/project-remaster", "Project Remaster Mod"))
  actionbar.packEnd(newLinkButtonWithLabel("https://www.moddb.com/mods/bf2142unlocker", "Moddb"))
  actionbar.packEnd(newLinkButtonWithLabel("https://github.com/Dankr4d/BF2142Unlocker", "Github"))
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
    loadMapList()
    loadServerSettings()
    loadAiSettings()
  hboxTerms.visible = false
  termBF2142Server.visible = false
  termLoginServer.visible = false
  btnHostCancel.visible = false
  when defined(windows):
    lblWinePrefix.visible = false
    fchsrBtnWinePrefix.visible = false
    if not dirExists(TEMP_FILES_DIR):
      createDir(TEMP_FILES_DIR)
  if bf2142Path == "":
    notebook.currentPage = 2 # Switch to settings tab when no Battlefield 2142 path is set
  restoreCheck()
  preServerPatchCheck()

proc main =
  application = newApplication()
  application.connect("activate", onApplicationActivate)
  discard run(application)

main()