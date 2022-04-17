import gintro/[gtk, gobject, glib, gtksource]
import "../../macro/signal"
import ../../module/gintro/liststore
import ../../module/resolution
import ../../profile/video as profileVideo
import os
import strutils
import system/io
import streams

var windowShown: ptr bool
var ignoreEvents: ptr bool

var videoDirty, video: Video
var path0001VideoCon, pathDefaultVideoCon: string # Path to Video.con file
var isVideoValid: bool
var isResolutionAvailable: bool
var resolutions: seq[Resolution]

# Video
var vboxVideo: Box
var cbxResolution: ComboBox
var scaleTerrain: Scale
var scaleEffects: Scale
var scaleGeometry: Scale
var scaleTexture: Scale
var scaleLighting: Scale
var scaleDynamicShadows: Scale
var scaleDynamicLight: Scale
var scaleAntialiasing: Scale
var scaleTextureFiltering: Scale
var scaleViewDistanceScale: Scale
var switchEnhancedLighting: Switch
var btnSave: Button
var btnRevert: Button
var dlgConfigCorrupt: Dialog
var lblConfigCorruptTitle: Label
var viewConfigCorruptBody: View
var btnConfigCorruptYes: Button
var btnConfigCorruptNo: Button

import conparser/exports/markup
proc markupEscapeProc(str: string): string =
  markupEscapeText(str, str.len)
proc markup(report: ConReport): string =
  markup(report, markupEscapeProc)


proc translate(antialiasing: Antialiasing): string =
  case antialiasing:
  of Antialiasing.Off:
    return dgettext("gui", "SETTINGS_VIDEO_OFF")
  of Antialiasing.FourSamples:
    return "4x"
  of Antialiasing.EightSamples:
    return "8x"


proc translate(lowMediumHigh: LowMediumHigh): string =
  case lowMediumHigh:
  of LowMediumHigh.Low:
    return dgettext("gui", "SETTINGS_VIDEO_LOW")
  of LowMediumHigh.Medium:
    return dgettext("gui", "SETTINGS_VIDEO_MEDIUM")
  of LowMediumHigh.High:
    return dgettext("gui", "SETTINGS_VIDEO_HIGH")

proc translate(offLowMediumHigh: OffLowMediumHigh): string =
  case offLowMediumHigh:
  of OffLowMediumHigh.Off:
    return dgettext("gui", "SETTINGS_VIDEO_OFF")
  of OffLowMediumHigh.Low:
    return dgettext("gui", "SETTINGS_VIDEO_LOW")
  of OffLowMediumHigh.Medium:
    return dgettext("gui", "SETTINGS_VIDEO_MEDIUM")
  of OffLowMediumHigh.High:
    return dgettext("gui", "SETTINGS_VIDEO_HIGH")

proc resolution(self: ComboBox): Resolution =
  var iter: TreeIter
  let store: ListStore = listStore(self.getModel())
  discard self.getActiveIter(iter)
  var valWidth: Value
  var valHeight: Value
  var valFrequence: Value
  store.getValue(iter, 2, valWidth)
  store.getValue(iter, 3, valHeight)
  store.getValue(iter, 4, valFrequence)
  result.width = valWidth.getUint().uint16
  result.height = valHeight.getUint().uint16
  result.frequence = valFrequence.getUint().uint8

proc fillResolutions(self: ComboBox, resolutions: seq[Resolution]) =
  var valResolution: Value
  var valWidth: Value
  var valHeight: Value
  var valFrequence: Value
  discard valResolution.init(g_string_get_type())
  discard valWidth.init(g_uint_get_type())
  discard valHeight.init(g_uint_get_type())
  discard valFrequence.init(g_uint_get_type())
  var iter: TreeIter
  let store = listStore(cbxResolution.getModel())
  store.clear()
  for resolution in resolutions:
    valResolution.setString(cstring($resolution))
    valWidth.setUint(cast[int](resolution.width))
    valHeight.setUint(cast[int](resolution.height))
    valFrequence.setUint(cast[int](resolution.frequence))
    store.append(iter)
    store.setValue(iter, 0, valResolution)
    store.setValue(iter, 1, valResolution)
    store.setValue(iter, 2, valWidth)
    store.setValue(iter, 3, valHeight)
    store.setValue(iter, 4, valFrequence)

proc loadVideo(video: Video) =
  scaleTerrain.value = video.terrainQuality.float
  scaleGeometry.value = video.geometryQuality.float
  scaleLighting.value = video.lightingQuality.float
  scaleDynamicLight.value = video.dynamicLightingQuality.float
  scaleDynamicShadows.value = video.dynamicShadowsQuality.float
  scaleEffects.value = video.effectsQuality.float
  scaleTexture.value = video.textureQuality.float
  scaleTextureFiltering.value = video.textureFilteringQuality.float
  discard cbxResolution.setActiveId(cstring($video.resolution))
  scaleAntialiasing.value = video.antialiasing.float
  scaleViewDistanceScale.value = video.viewDistanceScale
  switchEnhancedLighting.active = video.useBloom

proc setDocumentsPath*(documentsPath: string) =
  # TODO: Only required because of linux
  #       Documents path is queried with wine prefix (which may not be set when init proc is called).
  path0001VideoCon = documentsPath / "Battlefield 2142" / "Profiles" / "0001" / "Video.con"
  pathDefaultVideoCon = documentsPath / "Battlefield 2142" / "Profiles" / "Default" / "Video.con"

  var report: ConReport
  (video, report) = readCon[Video](path0001VideoCon)

  isVideoValid = report.valid
  isResolutionAvailable = video.resolution in resolutions

  if isVideoValid and isResolutionAvailable:
    video.videoOptionScheme = Presets.Custom
    videoDirty = video
    loadVideo(video)
  else:
    videoDirty = video
    if not isVideoValid:
      discard
      # videoDirty.fixInvalid()
    if not isResolutionAvailable:
      videoDirty.resolution = resolutions[0] #cbxResolution.getResolutionAtIdx(0)
    videoDirty.videoOptionScheme = Presets.Custom

    lblConfigCorruptTitle.text = cstring(dgettext("gui", "SETTINGS_CONFIG_CORRUPT_TITLE") % ["Video", "Video.con"])

    var iter: TextIter
    let markup: string = markup(report)
    viewConfigCorruptBody.buffer.getEndIter(iter)
    viewConfigCorruptBody.buffer.insertMarkup(iter, cstring(markup), markup.len)

    btnConfigCorruptYes.label = "Fix it!"
    btnConfigCorruptNo.label = "Cancel"

    if dlgConfigCorrupt.run() == ResponseType.yes.int:
      videoDirty.writeCon(path0001VideoCon)
      videoDirty.writeCon(pathDefaultVideoCon)
      video = videoDirty
      isVideoValid = true
      isResolutionAvailable = true
    else: # if not accepted
      btnSave.sensitive = true
    dlgConfigCorrupt.hide()
    loadVideo(videoDirty)
  vboxVideo.visible = true

proc onScaleSettingsVideoLowMediumHighFormatValue(self: ptr Scale00, value: float): cstring {.signalNoCheck.} =
  return g_strdup(cstring(translate(cast[LowMediumHigh](value.int))))

proc onScaleSettingsVideoOffLowMediumHighFormatValue(self: ptr Scale00, value: float): cstring {.signalNoCheck.} =
  return g_strdup(cstring(translate(cast[OffLowMediumHigh](value.int))))

proc onScaleSettingsAntialiasingFormatValue(self: ptr Scale00, value: float): cstring {.signalNoCheck.} =
  return g_strdup(cstring(translate(cast[Antialiasing](value.int))))

proc onScaleSettingsVideoViewDistanceScaleFormatValue(self: ptr Scale00, value: float): cstring {.signalNoCheck.} =
  return g_strdup(cstring($(int(value * 100)) & "%"))

proc updateSaveRevertSensitivity() =
  if isVideoValid and isResolutionAvailable:
    btnSave.sensitive = (video != videoDirty)
    btnRevert.sensitive = btnSave.sensitive
  else:
    btnSave.sensitive = true
    btnRevert.sensitive = false

proc onCbxSettingsVideoResolutionChanged(self: ptr ComboBox00) {.signal.} =
  videoDirty.resolution = cbxResolution.resolution
  updateSaveRevertSensitivity()

proc onScaleSettingsVideoTerrainValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.terrainQuality = cast[LowMediumHigh](scaleTerrain.value.int)
  updateSaveRevertSensitivity()

proc onScaleSettingsVideoEffectsValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.effectsQuality = cast[LowMediumHigh](scaleEffects.value.int)
  updateSaveRevertSensitivity()

proc onScaleSettingsVideoGeometryValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.geometryQuality = cast[LowMediumHigh](scaleGeometry.value.int)
  updateSaveRevertSensitivity()

proc onScaleSettingsVideoTextureValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.textureQuality = cast[LowMediumHigh](scaleTexture.value.int)
  updateSaveRevertSensitivity()

proc onScaleSettingsVideoLightingValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.lightingQuality = cast[LowMediumHigh](scaleLighting.value.int)
  updateSaveRevertSensitivity()

proc onScaleSettingsVideoDynamicShadowsValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.dynamicShadowsQuality = cast[OffLowMediumHigh](scaleDynamicShadows.value.int)
  updateSaveRevertSensitivity()

proc onScaleSettingsVideoDynamicLightValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.dynamicLightingQuality = cast[OffLowMediumHigh](scaleDynamicLight.value.int)
  updateSaveRevertSensitivity()

proc onScaleSettingsVideoAntialiasingValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.antialiasing = cast[Antialiasing](scaleAntialiasing.value.int)
  updateSaveRevertSensitivity()

proc onScaleSettingsVideoTextureFilteringValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.textureFilteringQuality = cast[LowMediumHigh](scaleTextureFiltering.value.int)
  updateSaveRevertSensitivity()

proc onScaleSettingsVideoViewDistanceScaleValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.viewDistanceScale = scaleViewDistanceScale.value.float * 2 - 1
  updateSaveRevertSensitivity()

proc onSwitchSettingsVideoEnhancedLightingStateSet(self: ptr Switch00, state: bool): bool {.signal.} =
  videoDirty.useBloom = switchEnhancedLighting.active
  updateSaveRevertSensitivity()

proc onBtnSettingsVideoSaveClicked(self: ptr Button00) {.signal.} =
  isVideoValid = true
  isResolutionAvailable = true
  videoDirty.writeCon(path0001VideoCon)
  videoDirty.writeCon(pathDefaultVideoCon)
  video = videoDirty
  updateSaveRevertSensitivity()

proc onBtnSettingsVideoRevertClicked(self: ptr Button00) {.signal.} =
  videoDirty = video
  loadVideo(video)
  updateSaveRevertSensitivity()


proc init*(builder: Builder, windowShownPtr, ignoreEventsPtr: ptr bool) =
  windowShown = windowShownPtr; ignoreEvents = ignoreEventsPtr
  cbxResolution = builder.getComboBox("cbxSettingsVideoResolution")
  scaleTerrain = builder.getScale("scaleSettingsVideoTerrain")
  scaleEffects = builder.getScale("scaleSettingsVideoEffects")
  scaleGeometry = builder.getScale("scaleSettingsVideoGeometry")
  scaleTexture = builder.getScale("scaleSettingsVideoTexture")
  scaleLighting = builder.getScale("scaleSettingsVideoLighting")
  scaleDynamicShadows = builder.getScale("scaleSettingsVideoDynamicShadows")
  scaleDynamicLight = builder.getScale("scaleSettingsVideoDynamicLight")
  scaleAntialiasing = builder.getScale("scaleSettingsVideoAntialiasing")
  scaleTextureFiltering = builder.getScale("scaleSettingsVideoTextureFiltering")
  scaleViewDistanceScale = builder.getScale("scaleSettingsVideoViewDistanceScale")
  switchEnhancedLighting = builder.getSwitch("switchSettingsVideoEnhancedLighting")
  btnSave = builder.getButton("btnSettingsVideoSave")
  btnRevert = builder.getButton("btnSettingsVideoRevert")
  vboxVideo = builder.getBox("vboxSettingsVideo")
  vboxVideo.visible = false

  dlgConfigCorrupt = builder.getDialog("dlgConfigCorrupt")
  lblConfigCorruptTitle = builder.getLabel("lblConfigCorruptTitle")
  viewConfigCorruptBody = cast[View](getObject(builder, "viewConfigCorruptBody")) # TODO: https://github.com/StefanSalewski/gintro/issues/40
  btnConfigCorruptYes = builder.getButton("btnConfigCorruptYes")
  btnConfigCorruptNo = builder.getButton("btnConfigCorruptNo")

  for tpl in getAvailableResolutions():
    resolutions.add(Resolution(width: tpl.width, height: tpl.height, frequence: tpl.frequence))
  cbxResolution.fillResolutions(resolutions)
