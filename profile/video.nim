import streams
import strutils
import strformat
import math

const
  SETTING_VIDEO_TERRAIN_QUALITY: string = "VideoSettings.setTerrainQuality"
  SETTING_VIDEO_GEOMETRY_QUALITY: string = "VideoSettings.setGeometryQuality"
  SETTING_VIDEO_LIGHTING_QUALITY: string = "VideoSettings.setLightingQuality"
  SETTING_VIDEO_DYNAMIC_LIGHTING_QUALITY: string = "VideoSettings.setDynamicLightingQuality"
  SETTING_VIDEO_DYNAMIC_SHADOWS_QUALITY: string = "VideoSettings.setDynamicShadowsQuality"
  SETTING_VIDEO_EFFECTS_QUALITY: string = "VideoSettings.setEffectsQuality"
  SETTING_VIDEO_TEXTURE_QUALITY: string = "VideoSettings.setTextureQuality"
  SETTING_VIDEO_TEXTURE_FILTERING_QUALITY: string = "VideoSettings.setTextureFilteringQuality"
  SETTING_VIDEO_RESOLUTION: string = "VideoSettings.setResolution"
  SETTING_VIDEO_ANTIALIASING: string = "VideoSettings.setAntialiasing"
  SETTING_VIDEO_VIEW_DISTANCE_SCALE: string = "VideoSettings.setViewDistanceScale"
  SETTING_VIDEO_USE_BLOOM: string = "VideoSettings.setUseBloom"
  SETTING_VIDEO_VIDEO_OPTION_SCHEME: string = "VideoSettings.setVideoOptionScheme"

type
  OffLowMediumHigh* {.pure.} = enum
    Invalid = -1
    Off = 0
    Low = 1
    Medium = 2
    High = 3
  LowMediumHigh* {.pure.} = enum
    Invalid = 0
    Low = 1
    Medium = 2
    High = 3
  Antialiasing* {.pure.} = enum
    Invalid
    Off = "Off"
    FourSamples = "4Samples"
    EightSamples = "8Samples"
  Presets* {.pure.} = enum
    Invalid = -1
    Low = 0
    Medium = 1
    High = 2
    Custom = 3
  Resolution* = object
    width*: uint16
    height*: uint16
    frequence*: uint8
  Video* = object
    terrainQuality*: LowMediumHigh
    geometryQuality*: LowMediumHigh
    lightingQuality*: LowMediumHigh
    dynamicLightingQuality*: OffLowMediumHigh
    dynamicShadowsQuality*: OffLowMediumHigh
    effectsQuality*: LowMediumHigh
    textureQuality*: LowMediumHigh
    textureFilteringQuality*: LowMediumHigh
    resolution*: Resolution
    antialiasing*: Antialiasing
    viewDistanceScale*: float # 0.0 = 50%, 1.0 = 100%
    # useBloom*: bool
    useBloom*: int8 # It's a bool, but set to int, to validate if parser couldn't parse this value (-1 = Invalid) # TODO: Maybe not the best solution? Maybe use Options?
    videoOptionScheme*: Presets


proc newVideoLow*(): Video =
  result.terrainQuality = LowMediumHigh.Low
  result.geometryQuality = LowMediumHigh.Low
  result.lightingQuality = LowMediumHigh.Low
  result.dynamicLightingQuality = OffLowMediumHigh.Off
  result.dynamicShadowsQuality = OffLowMediumHigh.Off
  result.effectsQuality = LowMediumHigh.Low
  result.textureQuality = LowMediumHigh.Low
  result.textureFilteringQuality = LowMediumHigh.Low
  result.resolution = Resolution(width: 800, height: 600, frequence: 60)
  result.antialiasing = Antialiasing.Off
  result.viewDistanceScale = 1.0
  result.useBloom = 0
  result.videoOptionScheme = Presets.Custom


proc newVideoInvalid*(): Video =
  result.terrainQuality = LowMediumHigh.Invalid
  result.geometryQuality = LowMediumHigh.Invalid
  result.lightingQuality = LowMediumHigh.Invalid
  result.dynamicLightingQuality = OffLowMediumHigh.Invalid
  result.dynamicShadowsQuality = OffLowMediumHigh.Invalid
  result.effectsQuality = LowMediumHigh.Invalid
  result.textureQuality = LowMediumHigh.Invalid
  result.textureFilteringQuality = LowMediumHigh.Invalid
  result.resolution = Resolution(width: 0, height: 0, frequence: 0)
  result.antialiasing = Antialiasing.Invalid
  result.viewDistanceScale = -1.0
  result.useBloom = -1
  result.videoOptionScheme = Presets.Invalid


proc `$`*(resolution: Resolution): string =
  return fmt"{resolution.width}x{resolution.height}@{resolution.frequence}Hz"


proc readVideo*(path: string): Video =
  result = newVideoInvalid()

  var file: File
  if open(file, path, fmRead, -1):
    let fileStream: FileStream = newFileStream(file)
    var
      line: string
      setting: string
      value: string
    while fileStream.readLine(line):
      if not line.contains(Whitespace):
        continue
      (setting, value) = line.splitWhitespace(maxsplit = 1)

      case setting:
      of SETTING_VIDEO_TERRAIN_QUALITY:
        try:
          result.terrainQuality = LowMediumHigh(parseInt(value))
        except ValueError, RangeDefect:
          discard # Value already set with newVideoInvalid
      of SETTING_VIDEO_GEOMETRY_QUALITY:
        try:
          result.geometryQuality = LowMediumHigh(parseInt(value))
        except ValueError, RangeDefect:
          discard # Value already set with newVideoInvalid
      of SETTING_VIDEO_LIGHTING_QUALITY:
        try:
          result.lightingQuality = LowMediumHigh(parseInt(value))
        except ValueError, RangeDefect:
          discard # Value already set with newVideoInvalid
      of SETTING_VIDEO_DYNAMIC_LIGHTING_QUALITY:
        try:
          result.dynamicLightingQuality = OffLowMediumHigh(parseInt(value))
        except ValueError, RangeDefect:
          discard # Value already set with newVideoInvalid
      of SETTING_VIDEO_DYNAMIC_SHADOWS_QUALITY:
        try:
          result.dynamicShadowsQuality = OffLowMediumHigh(parseInt(value))
        except ValueError, RangeDefect:
          discard # Value already set with newVideoInvalid
      of SETTING_VIDEO_EFFECTS_QUALITY:
        try:
          result.effectsQuality = LowMediumHigh(parseInt(value))
        except ValueError, RangeDefect:
          discard # Value already set with newVideoInvalid
      of SETTING_VIDEO_TEXTURE_QUALITY:
        try:
          result.textureQuality = LowMediumHigh(parseInt(value))
        except ValueError, RangeDefect:
          discard # Value already set with newVideoInvalid
      of SETTING_VIDEO_TEXTURE_FILTERING_QUALITY:
        try:
          result.textureFilteringQuality = LowMediumHigh(parseInt(value))
        except ValueError, RangeDefect:
          discard # Value already set with newVideoInvalid
      of SETTING_VIDEO_RESOLUTION:
        try:
          var posX: int = value.find("x")
          var posAt: int = value.find("@")
          result.resolution.width = parseUInt(value.substr(0, posX - 1)).uint16
          result.resolution.height = parseUInt(value.substr(posX + 1, posAt - 1)).uint16
          result.resolution.frequence = parseUInt(value.substr(posAt + 1, value.high - 2)).uint8
        except ValueError:
          discard # Value already set with newVideoInvalid
      of SETTING_VIDEO_ANTIALIASING:
        result.antialiasing = parseEnum[Antialiasing](value, Antialiasing.Invalid)
      of SETTING_VIDEO_VIEW_DISTANCE_SCALE:
        try:
          result.viewDistanceScale = parseFloat(value)
        except ValueError:
          discard # Value already set with newVideoInvalid
      of SETTING_VIDEO_USE_BLOOM:
        try:
          result.useBloom = parseBool(value).int8
        except ValueError:
          discard # Value already set with newVideoInvalid
      of SETTING_VIDEO_VIDEO_OPTION_SCHEME:
        try:
          result.videoOptionScheme = Presets(parseInt(value))
        except ValueError, RangeDefect:
          discard # Value already set with newVideoInvalid
    fileStream.close()
  else:
    # TODO: Create a video file in application startup and throw an exception if running into this else case
    return newVideoLow()


proc writeVideo*(video: Video, path: string) =
  let fileStream: FileStream = newFileStream(path, fmWrite)

  if not isNil(fileStream):
    fileStream.writeLine(fmt"{SETTING_VIDEO_TERRAIN_QUALITY} {video.terrainQuality.int}")
    fileStream.writeLine(fmt"{SETTING_VIDEO_GEOMETRY_QUALITY} {video.geometryQuality.int}")
    fileStream.writeLine(fmt"{SETTING_VIDEO_LIGHTING_QUALITY} {video.lightingQuality.int}")
    fileStream.writeLine(fmt"{SETTING_VIDEO_DYNAMIC_LIGHTING_QUALITY} {video.dynamicLightingQuality.int}")
    fileStream.writeLine(fmt"{SETTING_VIDEO_DYNAMIC_SHADOWS_QUALITY} {video.dynamicShadowsQuality.int}")
    fileStream.writeLine(fmt"{SETTING_VIDEO_EFFECTS_QUALITY} {video.effectsQuality.int}")
    fileStream.writeLine(fmt"{SETTING_VIDEO_TEXTURE_QUALITY} {video.textureQuality.int}")
    fileStream.writeLine(fmt"{SETTING_VIDEO_TEXTURE_FILTERING_QUALITY} {video.textureFilteringQuality.int}")
    fileStream.writeLine(fmt"{SETTING_VIDEO_RESOLUTION} {$video.resolution}")
    fileStream.writeLine(fmt"{SETTING_VIDEO_ANTIALIASING} {video.antialiasing}")
    fileStream.writeLine(fmt"{SETTING_VIDEO_VIEW_DISTANCE_SCALE} {round(video.viewDistanceScale, 6)}")
    fileStream.writeLine(fmt"{SETTING_VIDEO_USE_BLOOM} {video.useBloom.int}")
    fileStream.writeLine(fmt"{SETTING_VIDEO_VIDEO_OPTION_SCHEME} {video.videoOptionScheme.int}")
    fileStream.close()


proc isValid*(resolution: Resolution): bool =
  return (
    resolution.width > 0 and
    resolution.height > 0 and
    resolution.frequence > 0
  )


proc isValid*(video: Video): bool =
  return (
    video.terrainQuality != LowMediumHigh.Invalid and
    video.geometryQuality != LowMediumHigh.Invalid and
    video.lightingQuality != LowMediumHigh.Invalid and
    video.dynamicLightingQuality != OffLowMediumHigh.Invalid and
    video.dynamicShadowsQuality != OffLowMediumHigh.Invalid and
    video.effectsQuality != LowMediumHigh.Invalid and
    video.textureQuality != LowMediumHigh.Invalid and
    video.textureFilteringQuality != LowMediumHigh.Invalid and
    video.resolution.isValid() and
    video.antialiasing != Antialiasing.Invalid and
    video.viewDistanceScale >= 0.0 and video.viewDistanceScale <= 1.0 and
    video.useBloom != -1 and
    video.videoOptionScheme != Presets.Invalid
  )


proc fixInvalid*(video: var Video) =
  if video.terrainQuality == LowMediumHigh.Invalid:
    video.terrainQuality = LowMediumHigh.Low
  if video.geometryQuality == LowMediumHigh.Invalid:
    video.geometryQuality = LowMediumHigh.Low
  if video.lightingQuality == LowMediumHigh.Invalid:
    video.lightingQuality = LowMediumHigh.Low
  if video.dynamicLightingQuality == OffLowMediumHigh.Invalid:
    video.dynamicLightingQuality = OffLowMediumHigh.Off
  if video.dynamicShadowsQuality == OffLowMediumHigh.Invalid:
    video.dynamicShadowsQuality = OffLowMediumHigh.Off
  if video.effectsQuality == LowMediumHigh.Invalid:
    video.effectsQuality = LowMediumHigh.Low
  if video.textureQuality == LowMediumHigh.Invalid:
    video.textureQuality = LowMediumHigh.Low
  if video.textureFilteringQuality == LowMediumHigh.Invalid:
    video.textureFilteringQuality = LowMediumHigh.Low
  if video.resolution.width == 0:
    # TODO: Readout lowest resolution + frequency
    video.resolution.width = 800
    video.resolution.height = 600
    video.resolution.frequence = 60
  if video.antialiasing == Antialiasing.Invalid:
    video.antialiasing = Antialiasing.Off
  if video.viewDistanceScale == -1:
    video.viewDistanceScale = 1.0
  if video.useBloom == -1:
    video.useBloom = 0
  if video.videoOptionScheme == Presets.Invalid:
    video.videoOptionScheme = Presets.Custom

when isMainModule:
  let path: string = """/home/dankrad/Battlefield 2142/Profiles/0001/Video.con"""
  echo readVideo(path)
  echo newVideoLow()
