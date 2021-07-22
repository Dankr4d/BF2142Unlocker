import gintro/[gtk, gobject, glib]
import "../../macro/signal"
import ../../module/gintro/exceptiondialog
import ../../module/gintro/liststore
import ../../module/resolution
import ../../profile/video as profileVideo
import os

var windowShown: ptr bool
var ignoreEvents: ptr bool

var videoDirty, video: Video
var path0001VideoCon, pathDefaultVideoCon: string # Path to Video.con file
var isVideoValid: bool
var isResolutionAvailable: bool
var resolutions: seq[Resolution]

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



# proc `$`(resolution: tuple[width, height: uint16, frequence: uint8]): string =
#   return $Resolution(width: resolution.width, height: resolution.height, frequence: resolution.frequence)


proc translate(antialiasing: Antialiasing): string =
  case antialiasing:
  of Antialiasing.Off:
    return dgettext("gui", "SETTINGS_VIDEO_OFF")
  of Antialiasing.FourSamples:
    return "4x"
  of Antialiasing.EightSamples:
    return "8x"
  of Antialiasing.Invalid:
    return


proc translate(lowMediumHigh: LowMediumHigh): string =
  case lowMediumHigh:
  of LowMediumHigh.Low:
    return dgettext("gui", "SETTINGS_VIDEO_LOW")
  of LowMediumHigh.Medium:
    return dgettext("gui", "SETTINGS_VIDEO_MEDIUM")
  of LowMediumHigh.High:
    return dgettext("gui", "SETTINGS_VIDEO_HIGH")
  of LowMediumHigh.Invalid:
    return

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
  of OffLowMediumHigh.Invalid:
    return

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
    valResolution.setString($resolution)
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
  discard cbxResolution.setActiveId($video.resolution)
  scaleAntialiasing.value = video.antialiasing.float
  scaleViewDistanceScale.value = video.viewDistanceScale
  switchEnhancedLighting.active = video.useBloom.bool


proc setDocumentsPath*(documentsPath: string) =
  # TODO: Only required because of linux
  #       Documents path is queried with wine prefix (which may not be set when init proc is called).
  path0001VideoCon = documentsPath / "Battlefield 2142" / "Profiles" / "0001" / "Video.con"
  pathDefaultVideoCon = documentsPath / "Battlefield 2142" / "Profiles" / "Default" / "Video.con"

  video = readVideo(path0001VideoCon)
  echo video

  isVideoValid = video.isValid()
  isResolutionAvailable = video.resolution in resolutions # cbxResolution.hasId($video.resolution):

  if isVideoValid and isResolutionAvailable:
    video.videoOptionScheme = Presets.Custom
    videoDirty = video
    loadVideo(video)
  else:
    videoDirty = video
    if not isVideoValid:
      videoDirty.fixInvalid() # TODO: ASK TO FIX VIDEO SETTINGS
    if not isResolutionAvailable:
      videoDirty.resolution = resolutions[0] #cbxResolution.getResolutionAtIdx(0)
    videoDirty.videoOptionScheme = Presets.Custom
    if false: # TODO: Dialog which write fixes if accepted
      videoDirty.writeVideo(path0001VideoCon)
      videoDirty.writeVideo(pathDefaultVideoCon)
      video = videoDirty
      isVideoValid = true
      isResolutionAvailable = true
    else: # if not accepted
      btnSave.sensitive = true
    loadVideo(videoDirty)

proc onScaleSettingsVideoLowMediumHighFormatValue(self: ptr Scale00, value: float): cstring {.signalNoCheck.} =
  return g_strdup(translate(cast[LowMediumHigh](value.int)))

proc onScaleSettingsVideoOffLowMediumHighFormatValue(self: ptr Scale00, value: float): cstring {.signalNoCheck.} =
  return g_strdup(translate(cast[OffLowMediumHigh](value.int)))

proc onScaleSettingsAntialiasingFormatValue(self: ptr Scale00, value: float): cstring {.signalNoCheck.} =
  return g_strdup(translate(cast[Antialiasing](value.int)))

proc onScaleSettingsVideoViewDistanceScaleFormatValue(self: ptr Scale00, value: float): cstring {.signalNoCheck.} =
  return g_strdup($(int(scaleViewDistanceScale.value * 100)) & "%")

proc updateServerRevertSensitivity() =
  if isVideoValid and isResolutionAvailable:
    btnSave.sensitive = video != videoDirty
    btnRevert.sensitive = btnSave.sensitive
  else:
    btnSave.sensitive = true
    btnRevert.sensitive = false

proc onCbxSettingsVideoResolutionChanged(self: ptr ComboBox00) {.signal.} =
  videoDirty.resolution = cbxResolution.resolution
  updateServerRevertSensitivity()

proc onScaleSettingsVideoTerrainValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.terrainQuality = cast[LowMediumHigh](scaleTerrain.value.int)
  updateServerRevertSensitivity()

proc onScaleSettingsVideoEffectsValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.effectsQuality = cast[LowMediumHigh](scaleEffects.value.int)
  updateServerRevertSensitivity()

proc onScaleSettingsVideoGeometryValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.geometryQuality = cast[LowMediumHigh](scaleGeometry.value.int)
  updateServerRevertSensitivity()

proc onScaleSettingsVideoTextureValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.textureQuality = cast[LowMediumHigh](scaleTexture.value.int)
  updateServerRevertSensitivity()

proc onScaleSettingsVideoLightingValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.lightingQuality = cast[LowMediumHigh](scaleLighting.value.int)
  updateServerRevertSensitivity()

proc onScaleSettingsVideoDynamicShadowsValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.dynamicShadowsQuality = cast[OffLowMediumHigh](scaleDynamicShadows.value.int)
  updateServerRevertSensitivity()

proc onScaleSettingsVideoDynamicLightValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.dynamicLightingQuality = cast[OffLowMediumHigh](scaleDynamicLight.value.int)
  updateServerRevertSensitivity()

proc onScaleSettingsVideoAntialiasingValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.antialiasing = cast[Antialiasing](scaleAntialiasing.value.int)
  updateServerRevertSensitivity()

proc onScaleSettingsVideoTextureFilteringValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.textureFilteringQuality = cast[LowMediumHigh](scaleTextureFiltering.value.int)
  updateServerRevertSensitivity()

proc onScaleSettingsVideoViewDistanceScaleValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.viewDistanceScale = scaleViewDistanceScale.value.float * 2 - 1
  updateServerRevertSensitivity()

proc onSwitchSettingsVideoEnhancedLightingStateSet(self: ptr Switch00) {.signal.} =
  videoDirty.useBloom = switchEnhancedLighting.active.int8
  updateServerRevertSensitivity()


proc onBtnSettingsVideoSaveClicked(self: ptr Button00) {.signal.} =
  isVideoValid = true
  isResolutionAvailable = true
  videoDirty.writeVideo(path0001VideoCon)
  videoDirty.writeVideo(pathDefaultVideoCon)
  video = videoDirty
  updateServerRevertSensitivity()

proc onBtnSettingsVideoRevertClicked(self: ptr Button00) {.signal.} =
  videoDirty = video
  loadVideo(video)
  updateServerRevertSensitivity()


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

  for tpl in getAvailableResolutions():
    resolutions.add(Resolution(width: tpl.width, height: tpl.height, frequence: tpl.frequence))
  cbxResolution.fillResolutions(resolutions)
  # video = readVideo(pathVideoCon)
  # loadVideo(video)