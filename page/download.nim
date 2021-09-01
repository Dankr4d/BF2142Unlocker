import gintro/[gtk, glib, gobject, gdk]
import json
import httpclient
import tables
import uri
import strutils
import httpclient
import streams
import times
import ../type/download
import "../macro/signal" # Required to use the custom signal pragma (checks windowShown flag and returns if false)
import ../module/gintro/[liststore, treestore]
import options
import os

const
  COLUMN_GAME: int = 0
  COLUMN_MOD: int = 1
  COLUMN_MAP: int = 2
  COLUMN_SIZE: int = 3
  COLUMN_URL: int = 4
  COLUMN_PROGRESS: int = 5
  COLUMN_PROGRESS_VISIBLE: int = 6
  COLUMN_MAP_HORIZONTAL_PADDING: int = 7
  COLUMN_ICON_NAME: int = 8
  COLUMN_SPINNER_PULSE: int = 9
  COLUMN_SPINNER_VISIBLE: int = 10
  COLUMN_ICON_VISIBLE: int = 11
  COLUMN_SIZE_IN_BYTES: int = 12
  COLUMN_STATUS: int = 13
  COLUMN_DOWNLOAD: int = 14
  COLUMN_IS_RADIOBUTTON: int = 15
  COLUMN_VERSION: int = 16
  COLUMN_BACKGROUND_COLOR: int = 17
  COLUMN_SIZE_IN_BYTES_NET: int = 18
  COLUMN_SIZE_NET: int = 19
  COLUMN_MAP_FORMATTED: int = 20
  COLUMN_IS_CHECKBUTTON_SENSITIVE: int = 21
  COLUMN_STATUS_ACTION: int = 22
  COLUMN_GAME_VISIBLE: int = 23
  COLUMN_MOD_VISIBLE: int = 24

type
  Status {.pure.} = enum
    None # up to date (already downloaded)
    MissingGame
    MissingMod
    MissingLevel
    Update # update available
    # TODO: Downgrade
  StatusAction {.pure.} = enum
    None
    Download
    Remove
type
  ThreadData = object of RootObj
    gameName: string
    modName: string
    levelName: string
    versionFl: float
    source: string
    files: seq[PathHashSize]
    bytesSkipped: int64 # Size of files which aren't downloaded (already exists on client)
    # TODO: Remove sizeSkipped and add a column with (bytesToDownload)
    size: int64
    pathBf2142Client: string
  ChannelData = object of ThreadData
    bytesDownloaded: int64
    done: bool


const URL: uri.Uri = parseUri("http://127.0.0.1:8080/")

var windowShown: ptr bool
var ignoreEvents: ptr bool

var trvDownloadsMaps: TreeView
var trvcDownloads: TreeViewColumn
var cbxStatus: ComboBox
var cbxStatusAction: ComboBox
var cbxGame: ComboBox
var cbxMod: ComboBox
var stxtLevel: SearchEntry
var treeFilterMaps: TreeModelFilter

var gamesClient: Games
var gamesServer: Games

var pathBf2142Client: string

var threads: seq[system.Thread[ThreadData]]
var channel: Channel[ChannelData]
channel.open()

proc threadDownloadProc(data: ThreadData) {.thread.} =
  var client = newHttpClient()
  let len: uint = 32 #1024 #* 1024
  var buffer: string = newString(len)

  var lastEpochTime, currentEpochTime: float = epochTime()

  # Creating levle dir, just in case if info is not in download/files list

  var path: string = data.pathBf2142Client / "mods" / data.modName #/ "LEVELS_TODO" / data.levelName
  var levelDirName: string = "Levels"
  when defined(linux):
    # TODO: Check if levelDirName exists, before itering
    for modDirTpl in walkDir(path, true):
      if modDirTpl.kind != pcDir:
        continue
      if modDirTpl.path.toLower() == "levels":
        levelDirName = modDirTpl.path
        break
  path = path / levelDirName / data.levelName

  discard existsOrCreateDir(path)

  var channelData: ChannelData
  channelData.gameName = data.gameName
  channelData.modName = data.modName
  channelData.levelName = data.levelName
  channelData.versionFl = data.versionFl
  channelData.source = data.source
  channelData.bytesSkipped = data.bytesSkipped
  channelData.done = false

  var totalReceived: int = 0
  for file in data.files:
    # Creating sub dirs
    # createDir("/home/dankrad/Desktop/downloadtest/" / data.levelName / file.path.split("/")[0..^2].join($os.DirSep))
    createDir(path / file.path.split("/")[0..^2].join($os.DirSep))

    # Downloading files
    var response = client.get(data.source & "/" & file.path)
    # TODO: CRITICAL: Prevent changeing dir ("../" or "..\\" is not allowed)
    # let path: string = "/home/dankrad/Desktop/downloadtest/" / data.levelName / file.path
    var fstream: FileStream = newFileStream(path / file.path, fmWrite)

    while not response.bodyStream.atEnd():
      buffer.setLen(len)
      let nrecv = response.bodyStream.readDataStr(buffer, 0..len.int - 1)
      totalReceived += nrecv
      buffer.setLen(nrecv)

      if not isNil(fstream):
        fstream.write(buffer)

      currentEpochTime = epochTime()

      if (
        currentEpochTime - lastEpochTime >= 25 / 1000 or # Send to channel each milliseconds
        response.bodyStream.atEnd()
      ):
        lastEpochTime = currentEpochTime
        channelData.bytesDownloaded = totalReceived
        channel.send(channelData)
    if not isNil(fstream):
      fstream.close()
  channelData.done = true
  channel.send(channelData)

proc threadRemoveProc(data: ThreadData) {.thread.} =
  var lastEpochTime, currentEpochTime: float = epochTime()

  var path: string = data.pathBf2142Client / "mods" / data.modName #/ "LEVELS_TODO" / data.levelName
  var levelDirName: string = "Levels"
  when defined(linux):
    # TODO: Check if levelDirName exists, before itering
    for modDirTpl in walkDir(path, true):
      if modDirTpl.kind != pcDir:
        continue
      if modDirTpl.path.toLower() == "levels":
        levelDirName = modDirTpl.path
        break
  path = path / levelDirName / data.levelName

  removeDir(path)

  var channelData: ChannelData
  channelData.gameName = data.gameName
  channelData.modName = data.modName
  channelData.levelName = data.levelName
  channelData.versionFl = data.versionFl
  # channelData.source = data.source
  # channelData.bytesSkipped = data.bytesSkipped
  channelData.done = true
  channel.send(channelData)


proc getIconName(status: Status): string =
  case status:
  of Status.None:
    return "gtk-apply"
  of Status.MissingGame, Status.MissingMod:
    return "dialog-error"
  of Status.MissingLevel:
    return "media-floppy"
  of Status.Update:
    return "software-update-available"


proc getLevelVersion(iter: TreeIter): Version =
  let store: TreeStore = treeStore(treeFilterMaps.model)
  var valGame, valMod, valLevel, valVersion: Value
  var game, `mod`, level: string
  var version: float

  store.getValue(iter, COLUMN_GAME, valGame)
  store.getValue(iter, COLUMN_MOD, valMod)
  store.getValue(iter, COLUMN_MAP, valLevel)
  store.getValue(iter, COLUMN_VERSION, valVersion)
  game = valGame.getString()
  `mod` = valMod.getString()
  level = valLevel.getString()
  version = valVersion.getFloat()

  for gameServer in gamesServer:
    if gameServer.name != game:
      continue
    for modServer in gameServer.mods:
      if modServer.name != `mod`:
        continue
      for levelServer in modServer.levels:
        if levelServer.name != level:
          continue
        for versionServer in levelServer.versions:
          if versionServer.version != version:
            continue
          return versionServer

proc getLevelVersionServer(gameName, modName, levelName: string, versionFl: float): Version =
  for game in gamesServer:
    if game.name != gameName:
      continue
    for `mod` in game.mods:
      if `mod`.name != modName:
        continue
      for level in `mod`.levels:
        if level.name != levelName:
          continue
        for version in level.versions:
          if version.version != versionFl:
            continue
          return version

proc getLevelVersionClient(game, `mod`, level: string): Option[Version] =
  for gameClient in gamesClient:
    if gameClient.name != game:
      continue
    for modClient in gameClient.mods:
      if modClient.name != `mod`:
        continue
      for levelClient in modClient.levels:
        if levelClient.name != level:
          continue
        return some(levelClient.versions[0])
  return none(Version)


proc updateLevelClient(iter: var TreeIter, version: Version) = # TODO: Pass game, mod, level?
  let store: TreeStore = treeStore(treeFilterMaps.model)
  var valGame, valMod, valLevel, valVersion: Value
  var game, `mod`, level: string

  store.getValue(iter, COLUMN_GAME, valGame)
  store.getValue(iter, COLUMN_MOD, valMod)
  store.getValue(iter, COLUMN_MAP, valLevel)
  game = valGame.getString()
  `mod` = valMod.getString()
  level = valLevel.getString()

  for gameClient in gamesClient.mitems:
    if gameClient.name != game:
      continue
    for modClient in gameClient.mods.mitems:
      if modClient.name != `mod`:
        continue
      for levelClient in modClient.levels.mitems:
        if levelClient.name != level:
          continue
        levelClient.versions[0] = version
        return

proc addLevelClient(iter: var TreeIter, version: Version) = # TODO: Pass game, mod, level?
  let store: TreeStore = treeStore(treeFilterMaps.model)
  var valGame, valMod, valLevel, valVersion: Value
  var gameName, modName, levelName: string

  store.getValue(iter, COLUMN_GAME, valGame)
  store.getValue(iter, COLUMN_MOD, valMod)
  store.getValue(iter, COLUMN_MAP, valLevel)
  gameName = valGame.getString()
  modName = valMod.getString()
  levelName = valLevel.getString()

  for gameClient in gamesClient.mitems:
    if gameClient.name != gameName:
      continue
    for modClient in gameClient.mods.mitems:
      if modClient.name != modName:
        continue
      var level: Level
      level.name = levelName
      level.versions.add(version)
      modClient.levels.add(level)

proc delLevelClient(iter: var TreeIter) = # TODO: Pass game, mod, level?
  let store: TreeStore = treeStore(treeFilterMaps.model)
  var valGame, valMod, valLevel, valVersion: Value
  var gameName, modName, levelName: string

  store.getValue(iter, COLUMN_GAME, valGame)
  store.getValue(iter, COLUMN_MOD, valMod)
  store.getValue(iter, COLUMN_MAP, valLevel)
  gameName = valGame.getString()
  modName = valMod.getString()
  levelName = valLevel.getString()

  for gameClient in gamesClient.mitems:
    if gameClient.name != gameName:
      continue
    for modClient in gameClient.mods.mitems:
      if modClient.name != modName:
        continue
      for idx, levelClient in modClient.levels:
        if levelClient.name != valLevel.getString():
          continue
        modClient.levels.delete(idx)
        return

proc saveGamesClient() =
  when defined(release):
    writeFile("config" / "download.json",  $(%*gamesClient))
  else:
    writeFile("config" / "download.json",  pretty(%*gamesClient))


################################ EVENTS

var isLastIterValid: bool = false
var lastIter: TreeIter
proc onTrvDownloadsMapsMotionNotifyEvent(self: ptr TreeView00, event00: ptr EventMotion00): bool {.signal.} =
  var event: EventMotion = new EventMotion
  event.impl = event00
  event.ignoreFinalizer = true

  var x, y: float
  if not event.getCoords(x, y):
    return

  var treePath: TreePath
  var column: TreeViewColumn
  var cellX, cellY: int
  if not trvDownloadsMaps.getPathAtPos(x.int, y.int, treePath, column, cellX, cellY):
    return
  treePath = treeFilterMaps.convertPathToChildPath(treePath)

  # var depth: int = treePath.getDepth()
  # var indices: seq[int32] = treePath.getIndices(depth)

  var valXOffset: Value
  var valWidth: Value
  trvcDownloads.getProperty("x-offset", valXOffset)
  trvcDownloads.getProperty("width", valWidth)

  var iter: TreeIter
  let store: TreeStore = treeStore(treeFilterMaps.model)
  discard store.getIter(iter, treePath)
  var valIconName: Value
  discard valIconName.init(g_string_get_type())

  var valStatus, valStatusLastIter: Value
  store.getValue(iter, COLUMN_STATUS, valStatus)
  let status: Status = cast[Status](valStatus.getInt())
  var statusLastIter: Status
  if isLastIterValid:
    store.getValue(lastIter, COLUMN_STATUS, valStatusLastIter)
    statusLastIter = cast[Status](valStatusLastIter.getInt())

  if x.int >= valXOffset.getInt() and x.int <= valXOffset.getInt() + valWidth.getInt() and status in {Status.MissingLevel, Status.Update, Status.None}:
    if status == Status.None:
      valIconName.setString("user-trash") # Alternatives: edit-delete, user-trash-full
    else:
      valIconName.setString("emblem-downloads")
    store.setValue(iter, COLUMN_ICON_NAME, valIconName)

    if isLastIterValid and iter != lastIter and statusLastIter in {Status.MissingLevel, Status.Update, Status.None}:
      valIconName.setString(getIconName(statusLastIter))
      store.setValue(lastIter, COLUMN_ICON_NAME, valIconName)

    lastIter = iter
    isLastIterValid = true

    trvDownloadsMaps.getWindow().cursor = newCursorForDisplay(trvDownloadsMaps.getDisplay(), CursorType.hand2)
  else:
    if isLastIterValid and statusLastIter in {Status.MissingLevel, Status.Update, Status.None}:
      valIconName.setString(getIconName(statusLastIter)) #"document-save")
      store.setValue(lastIter, COLUMN_ICON_NAME, valIconName)

    isLastIterValid = false
    trvDownloadsMaps.getWindow().setCursor()
  return EVENT_PROPAGATE


proc onTrvDownloadsMapsLeaveNotifyEvent(self: ptr TreeView00, event00: ptr Event00): bool {.signal.} =
  var event: EventMotion = new EventMotion
  event.impl = event00
  event.ignoreFinalizer = true

  if isLastIterValid:
    let store: TreeStore = treeStore(treeFilterMaps.model)
    var valStatusLastIter, valIconName: Value
    discard valIconName.init(g_string_get_type())
    store.getValue(lastIter, COLUMN_STATUS, valStatusLastIter)
    var statusLastIter: Status
    statusLastIter = cast[Status](valStatusLastIter.getInt())

    valIconName.setString(getIconName(statusLastIter)) #"document-save")
    store.setValue(lastIter, COLUMN_ICON_NAME, valIconName)
  return EVENT_PROPAGATE

proc setStatusAction(store: TreeStore, iter: var TreeIter, statusAction: StatusAction) =
  var valSpinnerVisible, valIconVisible, valStatusAction: Value
  discard valSpinnerVisible.init(g_boolean_get_type())
  discard valIconVisible.init(g_boolean_get_type())
  discard valStatusAction.init(g_int_get_type())

  valSpinnerVisible.setBoolean(true)
  valIconVisible.setBoolean(false)
  valStatusAction.setInt(statusAction.int)

  store.setValue(iter, COLUMN_SPINNER_VISIBLE, valSpinnerVisible)
  store.setValue(iter, COLUMN_ICON_VISIBLE, valIconVisible)
  store.setValue(iter, COLUMN_STATUS_ACTION, valStatusAction)

  var valGame, valMod, valMap, valVersion: Value
  var gameName, modName, levelName: string
  var versionFl: float

  store.getValue(iter, COLUMN_GAME, valGame)
  store.getValue(iter, COLUMN_MOD, valMod)
  store.getValue(iter, COLUMN_MAP, valMap)
  store.getValue(iter, COLUMN_VERSION, valVersion)

  gameName = valGame.getString()
  modName = valMod.getString()
  levelName = valMap.getString()
  versionFl = valVersion.getFloat()

  var depth: int = store.getPath(iter).getDepth()

  if depth == 1:
    var childIter: TreeIter
    var whileCond: bool = store.iterChildren(childIter, iter)
    while whileCond:
      var valGame, valMod, valMap, valVersion: Value
      store.getValue(childIter, COLUMN_GAME, valGame)
      store.getValue(childIter, COLUMN_MOD, valMod)
      store.getValue(childIter, COLUMN_MAP, valMap)
      store.getValue(childIter, COLUMN_VERSION, valVersion)
      if gameName != valGame.getString() or modName != valMod.getString() or levelName != valMap.getString() or versionFl != valVersion.getFloat():
        whileCond = store.iterNext(childIter)
        continue
      store.setValue(childIter, COLUMN_SPINNER_VISIBLE, valSpinnerVisible)
      store.setValue(childIter, COLUMN_ICON_VISIBLE, valIconVisible)
      store.setValue(childIter, COLUMN_STATUS_ACTION, valStatusAction)
      whileCond = store.iterNext(childIter)
  elif depth == 2:
    var parentIter: TreeIter
    if store.iterParent(parentIter, iter):
      store.setValue(parentIter, COLUMN_SPINNER_VISIBLE, valSpinnerVisible)
      store.setValue(parentIter, COLUMN_ICON_VISIBLE, valIconVisible)
      store.setValue(parentIter, COLUMN_STATUS_ACTION, valStatusAction)


proc onTrvDownloadsMapsButtonReleaseEvent(self: ptr TreeView00, event00: ptr EventButton00): bool {.signal.} =
  var event: EventButton = new EventButton
  event.impl = event00
  event.ignoreFinalizer = true

  if event.getButton() != 1: # Only left click
    return

  var x, y: cdouble
  discard event.getCoords(x, y)

  var treePath: TreePath
  var column: TreeViewColumn
  var cellX, cellY: int
  if not trvDownloadsMaps.getPathAtPos(x.int, y.int, treePath, column, cellX, cellY):
    return
  treePath = treeFilterMaps.convertPathToChildPath(treePath)

  # var depth: int = treePath.getDepth()
  # var indices: seq[int32] = treePath.getIndices(depth)

  var valXOffset: Value
  var valWidth: Value
  trvcDownloads.getProperty("x-offset", valXOffset)
  trvcDownloads.getProperty("width", valWidth)

  var iter: TreeIter
  let store: TreeStore = treeStore(treeFilterMaps.model)
  discard store.getIter(iter, treePath)
  var valIconName: Value
  discard valIconName.init(g_string_get_type())

  var valStatus, valStatusAction: Value
  store.getValue(iter, COLUMN_STATUS, valStatus)
  store.getValue(iter, COLUMN_STATUS_ACTION, valStatusAction)
  let status: Status = cast[Status](valStatus.getInt())
  if not (status in {Status.None, Status.MissingLevel, Status.Update}):
    return

  if x.int >= valXOffset.getInt() and x.int <= valXOffset.getInt() + valWidth.getInt():
    var statusAction: StatusAction
    if status == Status.None:
      statusAction = StatusAction.Remove
    else:
      statusAction = StatusAction.Download

    store.setStatusAction(iter, statusAction)

    var valGame, valMod, valMap, valUrl, valVersion: Value
    store.getValue(iter, COLUMN_GAME, valGame)
    store.getValue(iter, COLUMN_MOD, valMod)
    store.getValue(iter, COLUMN_MAP, valMap)
    store.getValue(iter, COLUMN_URL, valUrl)
    store.getValue(iter, COLUMN_VERSION, valVersion)

    var data: ThreadData
    data.pathBf2142Client = pathBf2142Client
    data.gameName = valGame.getString()
    data.modName = valMod.getString()
    data.levelName = valMap.getString()
    data.versionFl = valVersion.getFloat()
    data.source = valUrl.getString()

    var thread: system.Thread[ThreadData]
    threads.add(thread)
    case statusAction:
    of StatusAction.Download:
      let version: Version = iter.getLevelVersion()
      var versionClientOpt: Option[Version] = getLevelVersionClient(data.gameName, data.modName, data.levelName)

      for file in version.files:
        var hasSameFileHash: bool = false
        if isSome(versionClientOpt):
          for fileClient in get(versionClientOpt).files:
            if fileClient.path != file.path:
              continue
            if fileClient.hash64 == file.hash64:
              hasSameFileHash = true
              break
        if not hasSameFileHash:
          data.size += file.size
          data.files.add(file)
        else:
          data.bytesSkipped += file.size
      threads[threads.high].createThread(threadDownloadProc, data)
    of StatusAction.Remove:
      threads[threads.high].createThread(threadRemoveProc, data)
    of StatusAction.None:
      raise newException(ValueError, "SHOULDN'T BE HERE!")
    return EVENT_STOP
  return EVENT_PROPAGATE


proc onCbxDownloadsLevelsStatusChanged(self: ptr ComboBox00) {.signal.} =
  treeFilterMaps.refilter()
  trvDownloadsMaps.expandAll() # TODO: Remove

proc onCbxDownloadsLevelsStatusActionChanged(self: ptr ComboBox00) {.signal.} =
  treeFilterMaps.refilter()
  trvDownloadsMaps.expandAll() # TODO: Remove

proc onCbxDownloadsLevelsGameChanged(self: ptr ComboBox00) {.signal.} =
  treeFilterMaps.refilter()
  trvDownloadsMaps.expandAll() # TODO: Remove

proc onCbxDownloadsLevelsModChanged(self: ptr ComboBox00) {.signal.} =
  treeFilterMaps.refilter()
  trvDownloadsMaps.expandAll() # TODO: Remove

proc onStxtDownloadsLevelsLevelSearchChanged(self: ptr SearchEntry00) {.signal.} =
  treeFilterMaps.refilter()
  trvDownloadsMaps.expandAll() # TODO: Remove


proc handleDownloadCheckButtons(pIndices: seq[int32], pIndicesCur: seq[int32] = @[pIndices[0]], pDownload: bool = true) =
  var depthClicked: int = pIndices.len
  var depthCur: int = pIndicesCur.len
  var indicesCur: seq[int32] = pIndicesCur
  var indices: seq[int32] = pIndices
  indices.setLen(3)
  var indicesSameLen: seq[int32] = pIndices
  indicesSameLen.setLen(indicesCur.len)

  var iter: TreeIter
  let store: TreeStore = treeStore(treeFilterMaps.model)
  var treePath: TreePath

  if indicesCur.len == 1:
    var valDownload: Value
    var valIsRadioButton: Value
    treePath = newTreePathFromIndices(pIndices)
    discard store.getIter(iter, treePath)
    store.getValue(iter, COLUMN_DOWNLOAD, valDownload)
    store.getValue(iter, COLUMN_IS_RADIOBUTTON, valIsRadioButton)
    if valDownload.getBoolean() and valIsRadioButton.getBoolean():
      # Clicked on a radio button which is already set/true -> nothing to do
      return

  treePath = newTreePathFromIndices(indicesCur)
  var whileCond: bool = store.getIter(iter, treePath)

  while whileCond:
    var valDownload: Value
    var valIsRadioButton: Value

    var download: bool = indicesSameLen == indicesCur and pDownload

    store.getValue(iter, COLUMN_IS_RADIOBUTTON, valIsRadioButton)

    if depthClicked == depthCur and not valIsRadioButton.getBoolean():
      store.getValue(iter, COLUMN_DOWNLOAD, valDownload)
      download = not valDownload.getBoolean()
    else:
      discard valDownload.init(g_boolean_get_type())

    valDownload.setBoolean(download)
    store.setValue(iter, COLUMN_DOWNLOAD, valDownload)

    var indicesNext: seq[int32] = indicesCur
    indicesNext.setLen(indicesNext.len + 1)

    handleDownloadCheckButtons(indices, indicesNext, download)

    if valIsRadioButton.getBoolean():
      whileCond = store.iterNext(iter)
    else:
      whileCond = false # Checkbox, no need to iterate
    indicesCur[^1].inc()


proc onTrvDownloadsMapsDownloadToggled(cellRenderer00: ptr CellRendererToggle00, path: cstring) {.signal.} =
  let treePath: TreePath = newTreePathFromString(path)
  var depth: int = treePath.getDepth()
  let indices: seq[int32] = treePath.getIndices(depth)
  handleDownloadCheckButtons(indices)


proc queryMaps(): Games =
  let client: HttpClient = newHttpClient()
  let jsonNode: JsonNode = parseJson(client.getContent($URL))
  client.close()
  return to(jsonNode, Games)


import algorithm
proc cmpVersion(v1, v2: Version): int =
  if v1.version == v2.version: return 0
  if v1.version < v2.version: return -1
  return 1


proc names*(games: Games): seq[string] =
  for game in games:
    result.add(game.name)


proc names*(mods: seq[Mod]): seq[string] =
  for `mod` in mods:
    result.add(`mod`.name)


proc getBackgroundColor(status: Status): string =
  case status:
  of Status.None:
    return "green"
  of Status.MissingGame, Status.MissingMod:
    return "red"
  of Status.MissingLevel:
    return "orange"
  of Status.Update:
    return "yellow"


proc getSizeNet(versionServer, versionClient: Version): uint =
  result = versionServer.size.uint
  for fileServer in versionServer.files:
    for fileClient in versionClient.files:
      if fileClient.path != fileServer.path:
        continue
      if fileClient.hash64 == fileServer.hash64:
        result -= fileClient.size.uint
        break


proc addUpdateLevel(store: TreeStore, iter: var TreeIter, status: Status, game, `mod`, map: string, version: Version, versionClientOpt: Option[Version], depth: int, iterParentOpt: Option[TreeIter] = none(TreeIter), update: bool = false) =
  var
    valGame, valMod, valMap, valSize, valUrl, valProgress: Value
    valProgressVisible, valMapHorizontalPadding, valIconName, valSpinnerPulse: Value
    valSpinnerVisible, valIconVisible: Value
    valSizeInBytes, valStatus, valDownload, valIsRadioButton: Value
    valVersion, valBackgroundColor: Value
    valSizeInBytesNet, valSizeNet, valMapFormatted: Value
    valIsCheckButtonSensitive, valStatusAction: Value
    valGameVisible, valModVisible: Value
  discard valGame.init(g_string_get_type())
  discard valMod.init(g_string_get_type())
  discard valMap.init(g_string_get_type())
  discard valSize.init(g_string_get_type())
  discard valUrl.init(g_string_get_type())
  discard valProgress.init(g_float_get_type())
  discard valProgressVisible.init(g_boolean_get_type())
  discard valMapHorizontalPadding.init(g_uint_get_type())
  discard valIconName.init(g_string_get_type())
  discard valSpinnerPulse.init(g_uint_get_type())
  discard valSpinnerVisible.init(g_boolean_get_type())
  discard valIconVisible.init(g_boolean_get_type())
  discard valSizeInBytes.init(g_uint_get_type())
  discard valStatus.init(g_int_get_type())
  discard valDownload.init(g_boolean_get_type())
  discard valIsRadioButton.init(g_boolean_get_type())
  discard valVersion.init(g_float_get_type())
  discard valBackgroundColor.init(g_string_get_type())
  discard valSizeInBytesNet.init(g_uint_get_type())
  discard valSizeNet.init(g_string_get_type())
  discard valMapFormatted.init(g_string_get_type())
  discard valIsCheckButtonSensitive.init(g_boolean_get_type())
  discard valStatusAction.init(g_int_get_type())
  discard valGameVisible.init(g_boolean_get_type())
  discard valModVisible.init(g_boolean_get_type())

  var size: string
  var url: string
  var progress: float
  var progressVisible: bool
  var mapHorizontalPadding: uint
  var iconName: string
  var spinnerPulse: uint
  var spinnerVisible: bool
  var iconVisible: bool
  var sizeInBytes: uint
  var download: bool
  var isRadioButton: bool
  var versionFl: float
  var backgroundColor: string
  var sizeInBytesNet: uint
  var sizeNet: string
  var mapFormatted: string
  var isCheckButtonSensitive: bool
  var statusAction: int
  var gameVisible: bool
  var modVisible: bool

  if depth == 2:
    mapFormatted = "➥  "

  mapFormatted &= "<span weight=\"bold\" foreground=\"#008080\">" & map & "</span>" &
    " <span weight=\"bold\" foreground=\"#55ff55\">" & $version.version & "</span>"
  if status == Status.None:
    sizeInBytesNet = 0u
    progress = 0f
    if depth == 1:
      mapFormatted &= " <span weight=\"bold\" foreground=\"#55ffff\">[installed]</span>"
    elif depth == 2:
      if get(versionClientOpt).version == version.version:
        mapFormatted &= " <span weight=\"bold\" foreground=\"#55ffff\">(current)</span>"
    progressVisible = false
    download = false
    isCheckButtonSensitive = true
  elif status == Status.Update:
    sizeInBytesNet = getSizeNet(version, get(versionClientOpt))
    progress = (version.size.float - sizeInBytesNet.float).float / version.size.float * 100f
    if depth == 1:
      mapFormatted &= " <span weight=\"bold\" foreground=\"#55ffff\">[installed: " & $get(versionClientOpt).version & "]</span>"
    progressVisible = true
    download = true
    isCheckButtonSensitive = true
  else:
    if status == Status.MissingLevel and isSome(versionClientOpt) and version.version < get(versionClientOpt).version: # TODO: Rename version to version
      sizeInBytesNet = getSizeNet(version, get(versionClientOpt))
      progress = (version.size.float - sizeInBytesNet.float).float / version.size.float * 100f
    else:
      sizeInBytesNet = version.size.uint
      progress = 0f
    download = false
    if status in {Status.MissingGame, Status.MissingMod}:
      isCheckButtonSensitive = false
      progressVisible = false
    else:
      isCheckButtonSensitive = true
      progressVisible = true

  size = formatFloat(version.size.int / 1024 / 1024, ffDecimal, 2) & " MiB"
  url = version.locations[0]
  iconName = getIconName(status)
  spinnerPulse = 0u
  spinnerVisible = false
  iconVisible = true
  sizeInBytes = version.size.uint
  if depth == 1:
    isRadioButton = false
    gameVisible = true
    modVisible = true
    mapHorizontalPadding = 0u
  elif depth == 2:
    isRadioButton = true
    gameVisible = false
    modVisible = false
    mapHorizontalPadding = 10u
  versionFl = version.version
  backgroundColor = getBackgroundColor(status)
  sizeNet = formatFloat(sizeInBytesNet.int / 1024 / 1024, ffDecimal, 2) & " MiB"
  statusAction = StatusAction.None.int

  valGame.setString(game)
  valMod.setString(`mod`)
  valMap.setString(map)
  valSize.setString(size)
  valUrl.setString(url)
  valProgress.setFloat(progress)
  valProgressVisible.setBoolean(progressVisible)
  valMapHorizontalPadding.setUint(mapHorizontalPadding.int)
  valSpinnerPulse.setUint(spinnerPulse.int)
  valSpinnerVisible.setBoolean(spinnerVisible)
  valIconVisible.setBoolean(iconVisible)
  valSizeInBytes.setUint(sizeInBytes.int)
  valIsRadioButton.setBoolean(isRadioButton)
  valVersion.setFloat(versionFl)
  valBackgroundColor.setString(backgroundColor)
  valSizeInBytesNet.setUint(sizeInBytesNet.int)
  valMapFormatted.setString(mapFormatted)
  valSizeNet.setString(sizeNet)

  valStatus.setInt(status.int)
  valIconName.setString(iconName)
  valDownload.setBoolean(download)
  valIsCheckButtonSensitive.setBoolean(isCheckButtonSensitive)
  valStatusAction.setInt(statusAction)
  valGameVisible.setBoolean(gameVisible)
  valModVisible.setBoolean(modVisible)

  if not update:
    if isSome(iterParentOpt):
      store.append(iter, get(iterParentOpt))
    else:
      store.append(iter)

  store.setValue(iter, COLUMN_GAME, valGame)
  store.setValue(iter, COLUMN_MOD, valMod)
  store.setValue(iter, COLUMN_MAP, valMap)
  store.setValue(iter, COLUMN_SIZE, valSize)
  store.setValue(iter, COLUMN_URL, valUrl)
  store.setValue(iter, COLUMN_PROGRESS, valProgress)
  store.setValue(iter, COLUMN_PROGRESS_VISIBLE, valProgressVisible)
  store.setValue(iter, COLUMN_MAP_HORIZONTAL_PADDING, valMapHorizontalPadding)
  store.setValue(iter, COLUMN_ICON_NAME, valIconName)
  store.setValue(iter, COLUMN_SPINNER_PULSE, valSpinnerPulse)
  store.setValue(iter, COLUMN_SPINNER_VISIBLE, valSpinnerVisible)
  store.setValue(iter, COLUMN_ICON_VISIBLE, valIconVisible)
  store.setValue(iter, COLUMN_SIZE_IN_BYTES, valSizeInBytes)
  store.setValue(iter, COLUMN_STATUS, valStatus)
  store.setValue(iter, COLUMN_DOWNLOAD, valDownload)
  store.setValue(iter, COLUMN_IS_RADIOBUTTON, valIsRadioButton)
  store.setValue(iter, COLUMN_VERSION, valVersion)
  store.setValue(iter, COLUMN_BACKGROUND_COLOR, valBackgroundColor)
  store.setValue(iter, COLUMN_SIZE_IN_BYTES_NET, valSizeInBytesNet)
  store.setValue(iter, COLUMN_SIZE_NET, valSizeNet)
  store.setValue(iter, COLUMN_MAP_FORMATTED, valMapFormatted)
  store.setValue(iter, COLUMN_IS_CHECKBUTTON_SENSITIVE, valIsCheckButtonSensitive)
  store.setValue(iter, COLUMN_STATUS_ACTION, valStatusAction)
  store.setValue(iter, COLUMN_GAME_VISIBLE, valGameVisible)
  store.setValue(iter, COLUMN_MOD_VISIBLE, valModVisible)

proc addLevel(store: TreeStore, iter: var TreeIter, status: Status, game, `mod`, map: string, versionServer: Version, versionClientOpt: Option[Version], depth: int, iterParentOpt: Option[TreeIter] = none(TreeIter)) =
  addUpdateLevel(store, iter, status, game, `mod`, map, versionServer, versionClientOpt, depth, iterParentOpt, false)

proc updateLevel(store: TreeStore, iter: var TreeIter, status: Status, game, `mod`, map: string, versionServer: Version, versionClientOpt: Option[Version]) =
  var depth: int = store.getPath(iter).getDepth()
  addUpdateLevel(store, iter, status, game, `mod`, map, versionServer, versionClientOpt, depth, none(TreeIter), true)


proc fillStatus(self: ComboBox) =
  var valId, valStatus: Value
  discard valId.init(g_string_get_type())
  discard valStatus.init(g_string_get_type())
  var iter: TreeIter
  let store = listStore(self.model)
  store.clear()

  valId.setString("")
  valStatus.setString("ALL")
  store.append(iter)
  store.setValue(iter, 0, valId)
  store.setValue(iter, 1, valStatus)

  for status in Status:
    valId.setString($status.int)
    valStatus.setString($status)
    store.append(iter)
    store.setValue(iter, 0, valId)
    store.setValue(iter, 1, valStatus)


proc fillStatusAction(self: ComboBox) =
  var valId, valStatusAction: Value
  discard valId.init(g_string_get_type())
  discard valStatusAction.init(g_string_get_type())
  var iter: TreeIter
  let store = listStore(self.model)
  store.clear()

  valId.setString("")
  valStatusAction.setString("ALL")
  store.append(iter)
  store.setValue(iter, 0, valId)
  store.setValue(iter, 1, valStatusAction)

  for statusAction in StatusAction:
    valId.setString($statusAction.int)
    valStatusAction.setString($statusAction)
    store.append(iter)
    store.setValue(iter, 0, valId)
    store.setValue(iter, 1, valStatusAction)


proc fillGames(self: ComboBox, games: seq[string]) =
  var valId, valGame: Value
  discard valId.init(g_string_get_type())
  discard valGame.init(g_string_get_type())
  var iter: TreeIter
  let store = listStore(self.model)
  store.clear()
  var idx: int = 0
  for game in @["ALL"] & games:
    if idx == 0:
      valId.setString("")
    else:
      valId.setString(game)
    valGame.setString(game)
    store.append(iter)
    store.setValue(iter, 0, valId)
    store.setValue(iter, 1, valGame)
    idx.inc()

proc fillMods(self: ComboBox, mods: seq[string]) = # TODO: REDUNDANT
  var valId, valMod: Value
  discard valId.init(g_string_get_type())
  discard valMod.init(g_string_get_type())
  var iter: TreeIter
  let store = listStore(self.model)
  store.clear()
  var idx: int = 0
  for `mod` in @["ALL"] & mods:
    if idx == 0:
      valId.setString("")
    else:
      valId.setString(`mod`)
    valMod.setString(`mod`)
    store.append(iter)
    store.setValue(iter, 0, valId)
    store.setValue(iter, 1, valMod)
    idx.inc()

proc fillMaps() =
  var iter: TreeIter
  let store: TreeStore = treeStore(treeFilterMaps.model)

  var games, mods: seq[string]

  for gameServer in gamesServer:
    var status: Status = MissingLevel
    var gameClientOpt: Option[Game]

    games.add(gameServer.name)

    for game in gamesClient:
      if game.name == gameServer.name:
        gameClientOpt = some(game)

    if isNone(gameClientOpt):
      status = MissingGame  # Game not set in path or not installed

    for modServer in gameServer.mods:
      var modClientOpt: Option[Mod]

      mods.add(modServer.name)

      if status != MissingGame:
      # if isSome(gameClientOpt):
        for `mod` in get(gameClientOpt).mods:
          if `mod`.name == modServer.name:
            modClientOpt = some(`mod`)
            if `mod`.versions[0].version != modServer.versions[^1].version:
              status = Update

      if isNone(modClientOpt):
        if status != MissingGame:
          # status = Install
          status = MissingMod

      for levelServer in modServer.levels:
        var levelClientOpt: Option[Level]

        if levelServer.versions.len == 0:
          continue

        if isSome(modClientOpt):
          for level in get(modClientOpt).levels:
            if level.name == levelServer.name:
              levelClientOpt = some(level)

          if isSome(levelClientOpt):
            if get(levelClientOpt).versions[0].version == 0.0:
              for version in levelServer.versions:
                if version.files == get(levelClientOpt).versions[0].files:
                  get(levelClientOpt).versions[0].version = version.version
            if get(levelClientOpt).versions[0].version == levelServer.versions[^1].version:
              status = Status.None
            else:
              status = Status.Update
          else:
            status = Status.MissingLevel

        ########################################################################

        # Newest version
        var versionClientOpt: Option[Version]
        if isSome(levelClientOpt):
          versionClientOpt = some(get(levelClientOpt).versions[0])
        store.addLevel(iter, status, gameServer.name, modServer.name, levelServer.name, levelServer.versions[^1], versionClientOpt, 1)

        # Available versions (tree depth 2)
        var iterParent: TreeIter = iter
        for version in levelServer.versions.sorted(cmpVersion, Descending):
          if isSome(levelClientOpt):
            if get(levelClientOpt).versions[0].version == version.version:
              status = Status.None
            elif get(levelClientOpt).versions[0].version < version.version:
              status = Status.Update
            else:
              status = Status.MissingLevel
          store.addLevel(iter, status, gameServer.name, modServer.name, levelServer.name, version, versionClientOpt, 2, some(iterParent))

  cbxGame.fillGames(games)
  cbxGame.active = 0
  cbxMod.fillMods(mods)
  cbxMod.active = 0


proc spinTest(TODO: int): bool = # TODO: start timeout only when downloading something and remove when finished
  var channelDataTbl: tables.Table[string, ChannelData] = initTable[string, ChannelData]()
  while channel.peek() > 0:
    let channelData: ChannelData = channel.recv()
    channelDataTbl[channelData.gameName & channelData.modName & channelData.levelName] = channelData

  let store: TreeStore = treeStore(treeFilterMaps.model)

  for iter in store.iterAllRec:
    var valStatusAction: Value
    store.getValue(iter, COLUMN_STATUS_ACTION, valStatusAction)
    var statusAction: StatusAction = StatusAction(valStatusAction.getInt())

    if statusAction == StatusAction.None:
      continue

    var depth: int = store.getPath(iter).getDepth()

    var valGame, valMod, valMap, valVersion, valUrl, valProgress: Value
    var valSizeInBytes: Value
    store.getValue(iter, COLUMN_GAME, valGame)
    store.getValue(iter, COLUMN_MOD, valMod)
    store.getValue(iter, COLUMN_MAP, valMap)
    store.getValue(iter, COLUMN_VERSION, valVersion)
    store.getValue(iter, COLUMN_URL, valUrl)
    store.getValue(iter, COLUMN_PROGRESS, valProgress)
    store.getValue(iter, COLUMN_SIZE_IN_BYTES, valSizeInBytes)

    for data in channelDataTbl.values():
      if data.gameName == valGame.getString() and data.modName == valMod.getString() and data.levelName == valMap.getString():

        var version: Version = iter.getLevelVersion()
        if data.versionFl == valVersion.getFloat():
          valProgress.setFloat((data.bytesSkipped + data.bytesDownloaded).float / valSizeInBytes.getUint().float * 100f)
          store.setValue(iter, COLUMN_PROGRESS, valProgress)

          if data.done:
            if depth == 2: # depth 2, because if someone is downgrading (version on depth 1 is always the newest verison)
              case statusAction:
              of StatusAction.Download:
                if isSome(getLevelVersionClient(data.gameName, data.modName, data.levelName)):
                  iter.updateLevelClient(version)
                else:
                  iter.addLevelClient(version)
              of StatusAction.Remove:
                iter.delLevelClient()
              of StatusAction.None:
                raise newException(ValueError, "SHOULDN'T BE HERE 2!")
              saveGamesClient()

              var status: Status
              var versionClientOpt: Option[Version] = getLevelVersionClient(data.gameName, data.modName, data.levelName)

              var iterParent: TreeIter
              discard store.iterParent(iterParent, iter)
              for iter in store.iterRec(iterParent):
                version = iter.getLevelVersion()

                if isSome(versionClientOpt):
                  if version.version == get(versionClientOpt).version:
                    status = Status.None
                  elif version.version > get(versionClientOpt).version:
                    status = Status.Update
                  else:
                    status = Status.MissingLevel
                else:
                  status = Status.MissingLevel
                store.updateLevel(iter, status, data.gameName, data.modName, data.levelName, version, versionClientOpt)

    var valSpinnerPulse, valSpinnerVisible: Value
    store.getValue(iter, COLUMN_SPINNER_PULSE, valSpinnerPulse)
    store.getValue(iter, COLUMN_SPINNER_VISIBLE, valSpinnerVisible)
    if valSpinnerVisible.getBoolean():
      if valSpinnerPulse.getUint() == 11:
        valSpinnerPulse.setUint(0)
      else:
        valSpinnerPulse.setUint(valSpinnerPulse.getUint() + 1)
      store.setValue(iter, COLUMN_SPINNER_PULSE, valSpinnerPulse)


  return SOURCE_CONTINUE


proc setBF2142ClientPath*(bf2142ClientPath: string) =
  if fileExists("config" / "download.json"):
    gamesClient = to(parseFile("config" / "download.json"), Games)
  else:
    gamesClient = getGamesClient(bf2142ClientPath)
    saveGamesClient()
  pathBf2142Client = bf2142ClientPath
  gamesServer = queryMaps()
  fillMaps()
  cbxStatus.fillStatus()
  cbxStatus.active = 0
  cbxStatusAction.fillStatusAction()
  cbxStatusAction.active = 0
  trvDownloadsMaps.expandAll() # TODO: Remove

proc trvLevelsFilter(model: ptr TreeModel00; iter: TreeIter; data: pointer): gboolean {.cdecl.} =
  let store: TreeStore = treeStore(treeFilterMaps.model)
  let depth: int = store.getPath(iter).getDepth()
  var valStatus, valStatusAction, valGame, valMod, valLevel: Value
  store.getValue(iter, COLUMN_STATUS, valStatus)
  store.getValue(iter, COLUMN_STATUS_ACTION, valStatusAction)
  store.getValue(iter, COLUMN_GAME, valGame)
  store.getValue(iter, COLUMN_MOD, valMod)
  store.getValue(iter, COLUMN_MAP, valLevel)

  if cbxStatus.activeId != "":
    if Status(valStatus.getInt()) != Status(parseInt(cbxStatus.activeId)):
      return false.gboolean

  if cbxStatusAction.activeId != "":
    if Status(valStatusAction.getInt()) != Status(parseInt(cbxStatusAction.activeId)):
      return false.gboolean

  if cbxGame.activeId != "":
    if valGame.getString() != cbxGame.activeId:
      return false.gboolean

  if cbxMod.activeId != "":
    if valMod.getString() != cbxMod.activeId:
      return false.gboolean

  if stxtLevel.text != "":
    if not (stxtLevel.text.toLower() in valLevel.getString().toLower()):
      return false.gboolean

  return true.gboolean


proc init*(builder: Builder, windowShownPtr, ignoreEventsPtr: ptr bool) =
  windowShown = windowShownPtr; ignoreEvents = ignoreEventsPtr
  trvDownloadsMaps = builder.getTreeView("trvDownloadsMaps")
  trvcDownloads = builder.getTreeViewColumn("download")
  cbxStatus = builder.getComboBox("cbxDownloadsLevelsStatus")
  cbxStatusAction = builder.getComboBox("cbxDownloadsLevelsStatusAction")
  cbxGame = builder.getComboBox("cbxDownloadsLevelsGame")
  cbxMod = builder.getComboBox("cbxDownloadsLevelsMod")
  stxtLevel = builder.getSearchEntry("stxtDownloadsLevelsLevel")
  # treeFilterMaps = builder.getTreeModelFilter("treeFilterMaps") # TODO: getTreeModelFilter doesn't exist

  treeFilterMaps = cast[TreeModelFilter](trvDownloadsMaps.model.filterNew())
  treeFilterMaps.setVisibleFunc(trvLevelsFilter, nil, nil)
  trvDownloadsMaps.model = treeFilterMaps

  let TODO: int = 0
  discard timeoutAdd(80, spinTest, TODO)
