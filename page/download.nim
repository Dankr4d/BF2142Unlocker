import gintro/[gtk, glib, gobject]

import json
import httpclient
import tables
import uri
import strutils
import httpclient
import streams
import times

import ../type/download

import gintro/gdk
import "../macro/signal" # Required to use the custom signal pragma (checks windowShown flag and returns if false)
var windowShown: bool = true # TODO
var ignoreEvents: bool = false

const
  COLUMN_GAME: int = 0
  COLUMN_MOD: int = 1
  COLUMN_MAP: int = 2
  COLUMN_SIZE: int = 3
  COLUMN_URL: int = 4
  COLUMN_PROGRESS: int = 5
  COLUMN_PROGRESSVISIBLE: int = 6
  COLUMN_MAPHORIZONTALPADDING: int = 7
  COLUMN_ICONNAME: int = 8
  COLUMN_SPINNERPULSE: int = 9
  COLUMN_SPINNERVISIBLE: int = 10
  COLUMN_ICONVISIBLE: int = 11
  COLUMN_SIZEINBYTES: int = 12
  COLUMN_STATUS: int = 13
  COLUMN_DOWNLOAD: int = 14
  COLUMN_ISRADIOBUTTON: int = 15
  COLUMN_VERSION: int = 16

type
  Status = enum
    Missing = 0,
    Downloading = 1,
    Downloaded = 2,
    Aborted = 3

type
  ThreadMapData = object of RootObj
    game: string
    `mod`: string
    mapName: string
    source: string
  ChannelMapData = object of ThreadMapData
    bytesDownloaded: int


const URL: uri.Uri = parseUri("http://127.0.0.1:8080/")

var trvDownloadsMaps: TreeView
var trvcDownloads: TreeViewColumn


# var thread: system.Thread[ThreadMapData]
var threads: seq[system.Thread[ThreadMapData]]
var channel: Channel[ChannelMapData]
channel.open()


proc typeTest(o: gobject.Object; s: string): bool =
  let gt = g_type_from_name(s)
  return g_type_check_instance_is_a(cast[ptr TypeInstance00](o.impl), gt).toBool
proc treeStore(o: gobject.Object): TreeStore =
  assert(typeTest(o, "GtkTreeStore"))
  cast[TreeStore](o)


proc threadProc(data: ThreadMapData) {.thread.} =
  var client = newHttpClient()
  var response = client.get(data.source)
  let len: uint = 32 #1024 #* 1024
  var buffer = newString(len)
  var totalReceived: int = 0

  var lastEpochTime, currentEpochTime: float = epochTime()

  var strm = newFileStream("/home/dankrad/Desktop/ddd/" & data.mapName & ".zip", fmWrite)

  while not response.bodyStream.atEnd():
    buffer.setLen(len)
    let nrecv = response.bodyStream.readDataStr(buffer, 0..len.int - 1)
    totalReceived += nrecv
    buffer.setLen(nrecv)

    if not isNil(strm):
      strm.write(buffer)

    currentEpochTime = epochTime()

    if (
      currentEpochTime - lastEpochTime >= 25 / 1000 or # Send to channel each milliseconds
      response.bodyStream.atEnd()
    ):
      lastEpochTime = currentEpochTime
      var threadData: ChannelMapData
      threadData.game = data.game
      threadData.`mod` = data.`mod`
      threadData.mapName = data.mapName
      threadData.source = data.source
      threadData.bytesDownloaded = totalReceived
      channel.send(threadData)
  if not isNil(strm):
    strm.close()



var isLastIterValid: bool = false
var lastIter: TreeIter
proc onTrvDownloadsMapsMotionNotifyEvent(self: ptr TreeView00, event00: ptr EventMotion00): bool {.signal.} =
  var event: EventMotion = new EventMotion
  event.impl = event00
  event.ignoreFinalizer = true

  var x, y: cdouble
  if not event.getCoords(x, y):
    return

  var treePath: TreePath
  var column: TreeViewColumn
  var cellX, cellY: int
  if not trvDownloadsMaps.getPathAtPos(x.int, y.int, treePath, column, cellX, cellY):
    return

  var depth: int
  var indices: seq[int32] = treePath.getIndices(depth)

  var valXOffset: Value
  var valWidth: Value
  trvcDownloads.getProperty("x-offset", valXOffset)
  trvcDownloads.getProperty("width", valWidth)

  var iter: TreeIter
  let store: TreeStore = treeStore(trvDownloadsMaps.getModel())
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

  if x.int >= valXOffset.getInt() and x.int <= valXOffset.getInt() + valWidth.getInt() and status == Status.Missing:
    valIconName.setString("emblem-downloads")
    store.setValue(iter, COLUMN_ICONNAME, valIconName)

    if isLastIterValid and iter != lastIter and statusLastIter == Status.Missing:
      valIconName.setString("document-save")
      store.setValue(lastIter, COLUMN_ICONNAME, valIconName)

    lastIter = iter
    isLastIterValid = true

    trvDownloadsMaps.getWindow().cursor = newCursorForDisplay(trvDownloadsMaps.getDisplay(), CursorType.hand2)
  else:
    if isLastIterValid and statusLastIter == Status.Missing:
      valIconName.setString("document-save")
      store.setValue(lastIter, COLUMN_ICONNAME, valIconName)

    isLastIterValid = false
    trvDownloadsMaps.getWindow().setCursor()
  return EVENT_PROPAGATE


proc onTrvDownloadsMapsLeaveNotifyEvent(self: ptr TreeView00, event00: ptr Event00): bool {.signal.} =
  var event: EventMotion = new EventMotion
  event.impl = event00
  event.ignoreFinalizer = true

  if isLastIterValid:
    let store: TreeStore = treeStore(trvDownloadsMaps.getModel())
    var valIconName: Value
    discard valIconName.init(g_string_get_type())

    valIconName.setString("document-save")
    store.setValue(lastIter, COLUMN_ICONNAME, valIconName)
  return EVENT_PROPAGATE


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
  var depth: int
  var indices: seq[int32] = treePath.getIndices(depth)

  var valXOffset: Value
  var valWidth: Value
  trvcDownloads.getProperty("x-offset", valXOffset)
  trvcDownloads.getProperty("width", valWidth)

  var iter: TreeIter
  let store: TreeStore = treeStore(trvDownloadsMaps.getModel())
  discard store.getIter(iter, treePath)
  var valIconName: Value
  discard valIconName.init(g_string_get_type())

  var valStatus, valStatusLastIter: Value
  store.getValue(iter, COLUMN_STATUS, valStatus)
  let status: Status = cast[Status](valStatus.getInt())
  if status != Status.Missing and status != Aborted:
    return

  if x.int >= valXOffset.getInt() and x.int <= valXOffset.getInt() + valWidth.getInt():
    var valSpinnerVisible, valIconVisible: Value
    var valStatus: Value
    discard valSpinnerVisible.init(g_boolean_get_type())
    discard valIconVisible.init(g_boolean_get_type())
    discard valStatus.init(g_int_get_type())
    valSpinnerVisible.setBoolean(true)
    valIconVisible.setBoolean(false)
    valStatus.setInt(Status.Downloading.int)
    store.setValue(iter, COLUMN_SPINNERVISIBLE, valSpinnerVisible)
    store.setValue(iter, COLUMN_ICONVISIBLE, valIconVisible)
    store.setValue(iter, COLUMN_STATUS, valStatus)

    var valGame, valMod, valMap, valUrl: Value
    store.getValue(iter, COLUMN_GAME, valGame)
    store.getValue(iter, COLUMN_MOD, valMod)
    store.getValue(iter, COLUMN_MAP, valMap)
    store.getValue(iter, COLUMN_URL, valUrl)

    var data: ThreadMapData
    data.game = valGame.getString()
    data.`mod` = valMod.getString()
    data.mapName = valMap.getString()
    data.source = valUrl.getString()
    var thread: system.Thread[ThreadMapData]
    threads.add(thread)
    threads[threads.high].createThread(threadProc, data)
    return EVENT_STOP
  return EVENT_PROPAGATE


proc handleDownloadCheckButtons(pIndices: seq[int32], pIndicesCur: seq[int32] = @[pIndices[0]], pDownload: bool = true) =
  var depthClicked: int = pIndices.len
  var depthCur: int = pIndicesCur.len
  var indicesCur: seq[int32] = pIndicesCur
  var indices: seq[int32] = pIndices
  indices.setLen(3)
  var indicesSameLen: seq[int32] = pIndices
  indicesSameLen.setLen(indicesCur.len)

  var iter: TreeIter
  let store: TreeStore = treeStore(trvDownloadsMaps.getModel())
  var treePath: TreePath

  if indicesCur.len == 1:
    var valDownload: Value
    var valIsRadioButton: Value
    treePath = newTreePathFromIndices(pIndices)
    discard store.getIter(iter, treePath)
    store.getValue(iter, COLUMN_DOWNLOAD, valDownload)
    store.getValue(iter, COLUMN_ISRADIOBUTTON, valIsRadioButton)
    if valDownload.getBoolean() and valIsRadioButton.getBoolean():
      # Clicked on a radio button which is already set/true -> nothing to do
      return

  treePath = newTreePathFromIndices(indicesCur)
  var whileCond: bool = store.getIter(iter, treePath)

  while whileCond:
    var valDownload: Value
    var valIsRadioButton: Value

    var download: bool = indicesSameLen == indicesCur and pDownload

    store.getValue(iter, COLUMN_ISRADIOBUTTON, valIsRadioButton)

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

proc fillMaps(games: Games) =
  var
    valGame, valMod, valMap, valSize, valUrl, valProgress: Value
    valProgressVisible, valMapHorizontalPadding, valIconName, valSpinnerPulse: Value
    valSpinnerVisible, valIconVisible: Value
    valSizeInBytes, valStatus, valDownload, valIsRadioButton: Value
    valVersion: Value
    iter: TreeIter
  let store: TreeStore = treeStore(trvDownloadsMaps.getModel())
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

  for gameName, game in games.pairs():
    for modName, maps in game.maps:
      for map in maps:
        valGame.setString(gameName)
        valMod.setString(modName)
        valMap.setString(map.name & " (version: " & $map.versions[^1].version & ")")
        valSize.setString(formatFloat(map.versions[^1].size.int / 1024 / 1024, ffDecimal, 2) & " MiB")
        # valUrl.setString("")
        valUrl.setString(map.versions[^1].locations[0]) # TODO: Test
        valProgress.setFloat(10.0)
        valProgressVisible.setBoolean(true)
        valMapHorizontalPadding.setUint(0)
        valIconName.setString("document-save")
        valSpinnerPulse.setUint(0)
        valSpinnerVisible.setBoolean(false)
        valIconVisible.setBoolean(true)
        valSizeInBytes.setUint(map.versions[^1].size.int)
        valStatus.setInt(Status.Missing.int)
        valDownload.setBoolean(false)
        valIsRadioButton.setBoolean(false)
        valVersion.setFloat(map.versions[^1].version)
        store.append(iter)
        store.setValue(iter, COLUMN_GAME, valGame)
        store.setValue(iter, COLUMN_MOD, valMod)
        store.setValue(iter, COLUMN_MAP, valMap)
        store.setValue(iter, COLUMN_SIZE, valSize)
        store.setValue(iter, COLUMN_URL, valUrl)
        store.setValue(iter, COLUMN_PROGRESS, valProgress)
        store.setValue(iter, COLUMN_PROGRESSVISIBLE, valProgressVisible)
        store.setValue(iter, COLUMN_MAPHORIZONTALPADDING, valMapHorizontalPadding)
        store.setValue(iter, COLUMN_ICONNAME, valIconName)
        store.setValue(iter, COLUMN_SPINNERPULSE, valSpinnerPulse)
        store.setValue(iter, COLUMN_SPINNERVISIBLE, valSpinnerVisible)
        store.setValue(iter, COLUMN_ICONVISIBLE, valIconVisible)
        store.setValue(iter, COLUMN_SIZEINBYTES, valSizeInBytes)
        store.setValue(iter, COLUMN_STATUS, valStatus)
        store.setValue(iter, COLUMN_DOWNLOAD, valDownload)
        store.setValue(iter, COLUMN_ISRADIOBUTTON, valIsRadioButton)
        store.setValue(iter, COLUMN_VERSION, valVersion)

        var iterParent: TreeIter = iter
        for version in map.versions.sorted(cmpVersion, Descending):
        # for url in map.locations:
          # valMap.setString("➥  " & url)
          valMap.setString(map.name & " (version: " & $version.version & ")")
          valMod.setString("")
          valGame.setString("")
          valSize.setString("")
          # valUrl.setString(url)
          valProgress.setFloat(0.0)
          valProgressVisible.setBoolean(false)
          valMapHorizontalPadding.setUint(10)
          valIconName.setString("document-save")
          valSpinnerPulse.setUint(0)
          valSpinnerVisible.setBoolean(false)
          valIconVisible.setBoolean(true)
          valSizeInBytes.setUint(version.size.int)
          valStatus.setInt(Status.Missing.int)
          valDownload.setBoolean(false)
          valIsRadioButton.setBoolean(true)
          valVersion.setFloat(version.version)
          store.append(iter, iterParent)
          store.setValue(iter, COLUMN_GAME, valGame)
          store.setValue(iter, COLUMN_MOD, valMod)
          store.setValue(iter, COLUMN_MAP, valMap)
          store.setValue(iter, COLUMN_SIZE, valSize)
          store.setValue(iter, COLUMN_URL, valUrl)
          store.setValue(iter, COLUMN_PROGRESS, valProgress)
          store.setValue(iter, COLUMN_PROGRESSVISIBLE, valProgressVisible)
          store.setValue(iter, COLUMN_MAPHORIZONTALPADDING, valMapHorizontalPadding)
          store.setValue(iter, COLUMN_ICONNAME, valIconName)
          store.setValue(iter, COLUMN_SPINNERPULSE, valSpinnerPulse)
          store.setValue(iter, COLUMN_SPINNERVISIBLE, valSpinnerVisible)
          store.setValue(iter, COLUMN_ICONVISIBLE, valIconVisible)
          store.setValue(iter, COLUMN_SIZEINBYTES, valSizeInBytes)
          store.setValue(iter, COLUMN_STATUS, valStatus)
          store.setValue(iter, COLUMN_DOWNLOAD, valDownload)
          store.setValue(iter, COLUMN_ISRADIOBUTTON, valIsRadioButton)
          store.setValue(iter, COLUMN_VERSION, valVersion)

          var iterParentBefore: TreeIter = iterParent
          iterParent = iter
          for location in version.locations:
            valMap.setString("    ➥  " & location)
            valMod.setString("")
            valGame.setString("")
            valSize.setString("")
            valUrl.setString(location)
            valProgress.setFloat(0.0)
            valProgressVisible.setBoolean(false)
            valMapHorizontalPadding.setUint(10)
            valIconName.setString("document-save")
            valSpinnerPulse.setUint(0)
            valSpinnerVisible.setBoolean(false)
            valIconVisible.setBoolean(true)
            valSizeInBytes.setUint(version.size.int)
            valStatus.setInt(Status.Missing.int)
            valDownload.setBoolean(false)
            valIsRadioButton.setBoolean(true)
            valVersion.setFloat(version.version)
            store.append(iter, iterParent)
            store.setValue(iter, COLUMN_GAME, valGame)
            store.setValue(iter, COLUMN_MOD, valMod)
            store.setValue(iter, COLUMN_MAP, valMap)
            store.setValue(iter, COLUMN_SIZE, valSize)
            store.setValue(iter, COLUMN_URL, valUrl)
            store.setValue(iter, COLUMN_PROGRESS, valProgress)
            store.setValue(iter, COLUMN_PROGRESSVISIBLE, valProgressVisible)
            store.setValue(iter, COLUMN_MAPHORIZONTALPADDING, valMapHorizontalPadding)
            store.setValue(iter, COLUMN_ICONNAME, valIconName)
            store.setValue(iter, COLUMN_SPINNERPULSE, valSpinnerPulse)
            store.setValue(iter, COLUMN_SPINNERVISIBLE, valSpinnerVisible)
            store.setValue(iter, COLUMN_ICONVISIBLE, valIconVisible)
            store.setValue(iter, COLUMN_SIZEINBYTES, valSizeInBytes)
            store.setValue(iter, COLUMN_STATUS, valStatus)
            store.setValue(iter, COLUMN_DOWNLOAD, valDownload)
            store.setValue(iter, COLUMN_ISRADIOBUTTON, valIsRadioButton)
            store.setValue(iter, COLUMN_VERSION, valVersion)
          iterParent = iterParentBefore



proc spinTest(TODO: int): bool =
  var maps: tables.Table[string, ChannelMapData] = initTable[string, ChannelMapData]()
  while channel.peek() > 0:
    let channelData: ChannelMapData = channel.recv()
    maps[channelData.game & channelData.`mod` & channelData.mapName] = channelData

  let store: TreeStore = treeStore(trvDownloadsMaps.getModel())
  var iter: TreeIter
  var whileCond: bool = store.getIterFirst(iter)
  while whileCond:
    var valGame, valMod, valMap, valUrl, valProgress: Value
    var valSizeInBytes: Value
    store.getValue(iter, COLUMN_GAME, valGame)
    store.getValue(iter, COLUMN_MOD, valMod)
    store.getValue(iter, COLUMN_MAP, valMap)
    store.getValue(iter, COLUMN_URL, valUrl)
    store.getValue(iter, COLUMN_PROGRESS, valProgress)
    store.getValue(iter, COLUMN_SIZEINBYTES, valSizeInBytes)

    for map in maps.values():
      if (
        map.game == valGame.getString() and
        map.`mod` == valMod.getString() and
        map.mapName == valMap.getString()
      ):
        valProgress.setFloat(map.bytesDownloaded / valSizeInBytes.getUint() * 100)
        store.setValue(iter, COLUMN_PROGRESS, valProgress)
        if valProgress.getFloat() == 100.0:
          var valSpinnerVisible, valIconVisible: Value
          var valIconName, valStatus: Value
          discard valSpinnerVisible.init(g_boolean_get_type())
          discard valIconVisible.init(g_boolean_get_type())
          discard valIconName.init(g_string_get_type())
          discard valStatus.init(g_int_get_type())
          valSpinnerVisible.setBoolean(false)
          valIconVisible.setBoolean(true)
          valIconName.setString("gtk-apply")
          valStatus.setInt(Status.Downloaded.int)
          store.setValue(iter, COLUMN_SPINNERVISIBLE, valSpinnerVisible)
          store.setValue(iter, COLUMN_ICONVISIBLE, valIconVisible)
          store.setValue(iter, COLUMN_ICONNAME, valIconName)
          store.setValue(iter, COLUMN_STATUS, valStatus)

    var valSpinnerPulse, valSpinnerVisible: Value
    store.getValue(iter, COLUMN_SPINNERPULSE, valSpinnerPulse)
    store.getValue(iter, COLUMN_SPINNERVISIBLE, valSpinnerVisible)
    if valSpinnerVisible.getBoolean():
      if valSpinnerPulse.getUint() == 11:
        valSpinnerPulse.setUint(0)
      else:
        valSpinnerPulse.setUint(valSpinnerPulse.getUint() + 1)
      store.setValue(iter, COLUMN_SPINNERPULSE, valSpinnerPulse)
    whileCond = store.iterNext(iter)
  return SOURCE_CONTINUE


proc init*(builder: Builder) =
  trvDownloadsMaps = builder.getTreeView("trvDownloadsMaps")
  trvcDownloads = builder.getTreeViewColumn("download")
  let TODO: int = 0
  discard timeoutAdd(80, spinTest, TODO)
  fillMaps(queryMaps())
  trvDownloadsMaps.expandAll() # TODO: Remove