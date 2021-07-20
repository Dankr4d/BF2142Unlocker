import gintro/[gtk, gobject, glib]
import "../../macro/signal"
import ../../module/gintro/liststore
import ../../module/resolution
import ../../profile/video as profileVideo
import os

var windowShown: ptr bool
var ignoreEvents: ptr bool

var videoDirty, video: Video
var pathVideoCon: string # Path to Video.con file

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
var lblTerrain: Label
var lblEffects: Label
var lblGeometry: Label
var lblTexture: Label
var lblLighting: Label
var lblDynamicShadows: Label
var lblDynamicLight: Label
var lblAntialiasing: Label
var lblTextureFiltering: Label
var lblViewDistanceScale: Label
var btnSave: Button
var btnRevert: Button



proc `$`(resolution: tuple[width, height: uint16, frequence: uint8]): string =
  return $Resolution(width: resolution.width, height: resolution.height, frequence: resolution.frequence)


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


proc `resolution=`(self: ComboBox, resolution: Resolution) =
  if not self.setActiveId($resolution):
    self.setActive(0)


proc fillResolutions(self: ComboBox, resolutions: seq[tuple[width, height: uint16, frequence: uint8]]) =
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
  for resolution in getAvailableResolutions():
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
  lblTerrain.text = translate(video.terrainQuality)

  scaleGeometry.value = video.geometryQuality.float
  lblGeometry.text = translate(video.geometryQuality)

  scaleLighting.value = video.lightingQuality.float
  lblLighting.textWithMnemonic = $video.lightingQuality

  scaleDynamicLight.value = video.dynamicLightingQuality.float
  lblDynamicLight.text = translate(video.dynamicLightingQuality)

  scaleDynamicShadows.value = video.dynamicShadowsQuality.float
  lblDynamicShadows.text = translate(video.dynamicShadowsQuality)

  scaleEffects.value = video.effectsQuality.float
  lblEffects.text = translate(video.effectsQuality)

  scaleTexture.value = video.textureQuality.float
  lblTexture.text = translate(video.textureQuality)

  scaleTextureFiltering.value = video.textureFilteringQuality.float
  lblTextureFiltering.text = translate(video.textureFilteringQuality)

  cbxResolution.resolution = video.resolution

  scaleAntialiasing.value = video.antialiasing.float
  lblAntialiasing.text = translate(video.antialiasing)

  scaleViewDistanceScale.value = video.viewDistanceScale
  lblViewDistanceScale.text = $(int(video.viewDistanceScale * 100)) & "%" # TODO: Redundant

  switchEnhancedLighting.active = video.useBloom


proc setDocumentsPath*(documentsPath: string) =
  # TODO: Only required because of linux
  #       Documents path is queried with wine prefix (which may not be set when init proc is called).
  pathVideoCon = documentsPath / "Battlefield 2142" / "Profiles" / "0001" / "Video.con"
  video = readVideo(pathVideoCon)
  video.videoOptionScheme = Presets.Custom
  videoDirty = video
  loadVideo(video)


# INFO: https://github.com/StefanSalewski/gintro/issues/161
# proc onScaleSettingsVideoTerrainFormatValue(self: ptr Scale00, value: cdouble): cstring {.signal.} =
#   return "HALLO"

proc updateServerRevertSensitivity() =
  btnSave.sensitive = video != videoDirty
  btnRevert.sensitive = btnSave.sensitive

proc onCbxSettingsVideoResolutionChanged(self: ptr ComboBox00) {.signal.} =
  videoDirty.resolution = cbxResolution.resolution
  updateServerRevertSensitivity()

proc onScaleSettingsVideoTerrainValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.terrainQuality = cast[LowMediumHigh](scaleTerrain.value.int)
  lblTerrain.text = translate(cast[LowMediumHigh](scaleTerrain.value.int))
  updateServerRevertSensitivity()

proc onScaleSettingsVideoEffectsValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.effectsQuality = cast[LowMediumHigh](scaleEffects.value.int)
  lblEffects.text = translate(cast[LowMediumHigh](scaleEffects.value.int))
  updateServerRevertSensitivity()

proc onScaleSettingsVideoGeometryValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.geometryQuality = cast[LowMediumHigh](scaleGeometry.value.int)
  lblGeometry.text = translate(cast[LowMediumHigh](scaleGeometry.value.int))
  updateServerRevertSensitivity()

proc onScaleSettingsVideoTextureValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.textureQuality = cast[LowMediumHigh](scaleTexture.value.int)
  lblTexture.text = translate(cast[LowMediumHigh](scaleTexture.value.int))
  updateServerRevertSensitivity()

proc onScaleSettingsVideoLightingValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.lightingQuality = cast[LowMediumHigh](scaleLighting.value.int)
  lblLighting.text = translate(cast[LowMediumHigh](scaleLighting.value.int))
  updateServerRevertSensitivity()

proc onScaleSettingsVideoDynamicShadowsValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.dynamicShadowsQuality = cast[OffLowMediumHigh](scaleDynamicShadows.value.int)
  lblDynamicShadows.text = translate(cast[OffLowMediumHigh](scaleDynamicShadows.value.int))
  updateServerRevertSensitivity()

proc onScaleSettingsVideoDynamicLightValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.dynamicLightingQuality = cast[OffLowMediumHigh](scaleDynamicLight.value.int)
  lblDynamicLight.text = translate(cast[OffLowMediumHigh](scaleDynamicLight.value.int))
  updateServerRevertSensitivity()

proc onScaleSettingsVideoAntialiasingValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.antialiasing = cast[Antialiasing](scaleAntialiasing.value.int)
  lblAntialiasing.text = translate(cast[Antialiasing](scaleAntialiasing.value.int))
  updateServerRevertSensitivity()

proc onScaleSettingsVideoTextureFilteringValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.textureFilteringQuality = cast[LowMediumHigh](scaleTextureFiltering.value.int)
  lblTextureFiltering.text = translate(cast[LowMediumHigh](scaleTextureFiltering.value.int))
  updateServerRevertSensitivity()

proc onScaleSettingsVideoViewDistanceScaleValueChanged(self: ptr Scale00) {.signal.} =
  videoDirty.viewDistanceScale = scaleViewDistanceScale.value.float * 2 - 1
  lblViewDistanceScale.text = $(int(scaleViewDistanceScale.value * 100)) & "%" # TODO: Redundant
  updateServerRevertSensitivity()

proc onSwitchSettingsVideoEnhancedLightingStateSet(self: ptr Switch00) {.signal.} =
  videoDirty.useBloom = switchEnhancedLighting.active
  updateServerRevertSensitivity()


proc onBtnSettingsVideoSaveClicked(self: ptr Button00) {.signal.} =
  videoDirty.writeVideo(pathVideoCon)
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
  lblTerrain = builder.getLabel("lblSettingsVideoTerrain")
  lblEffects = builder.getLabel("lblSettingsVideoEffects")
  lblGeometry = builder.getLabel("lblSettingsVideoGeometry")
  lblTexture = builder.getLabel("lblSettingsVideoTexture")
  lblLighting = builder.getLabel("lblSettingsVideoLighting")
  lblDynamicShadows = builder.getLabel("lblSettingsVideoDynamicShadows")
  lblDynamicLight = builder.getLabel("lblSettingsVideoDynamicLight")
  lblAntialiasing = builder.getLabel("lblSettingsVideoAntialiasing")
  lblTextureFiltering = builder.getLabel("lblSettingsVideoTextureFiltering")
  lblViewDistanceScale = builder.getLabel("lblSettingsVideoViewDistanceScale")
  btnSave = builder.getButton("btnSettingsVideoSave")
  btnRevert = builder.getButton("btnSettingsVideoRevert")

  cbxResolution.fillResolutions(getAvailableResolutions())
  # video = readVideo(pathVideoCon)
  # loadVideo(video)