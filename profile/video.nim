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
  LowMediumHigh* {.pure.} = enum
    Low = 1
    Medium = 2
    High = 3
  Antialiasing* {.pure.} = enum
    Off = "Off"
    FourSamples = "4Samples"
    EightSamples = "8Samples"
  Presets* {.pure.} = enum
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
    dynamicLightingQuality*: LowMediumHigh
    dynamicShadowsQuality*: LowMediumHigh
    effectsQuality*: LowMediumHigh
    textureQuality*: LowMediumHigh
    textureFilteringQuality*: LowMediumHigh
    resolution*: Resolution
    antialiasing*: Antialiasing
    viewDistanceScale*: float # 0.0 = 50%, 1.0 = 100%
    useBloom*: bool
    videoOptionScheme*: Presets

proc newVideo*(): Video =
  result.terrainQuality = LowMediumHigh.Low
  result.geometryQuality = LowMediumHigh.Low
  result.lightingQuality = LowMediumHigh.Low
  result.dynamicLightingQuality = LowMediumHigh.Low
  result.dynamicShadowsQuality = LowMediumHigh.Low
  result.effectsQuality = LowMediumHigh.Low
  result.textureQuality = LowMediumHigh.Low
  result.textureFilteringQuality = LowMediumHigh.Low
  result.resolution = Resolution(width: 800, height: 600, frequence: 60)
  result.antialiasing = Antialiasing.Off
  result.viewDistanceScale = 1.0
  result.useBloom = false
  result.videoOptionScheme = Presets.Custom

proc `$`*(resolution: Resolution): string =
  return fmt"{resolution.width}x{resolution.height}@{resolution.frequence}Hz"

proc readVideo*(path: string): Video =
  var file: File
  if open(file, path, fmRead, -1):
    let fileStream: FileStream = newFileStream(file)
    var
      line: string
      setting: string
      value: string
    while fileStream.readLine(line):
      (setting, value) = line.splitWhitespace(maxsplit = 1)

      case setting:
      of SETTING_VIDEO_TERRAIN_QUALITY:
        result.terrainQuality = cast[LowMediumHigh](parseInt(value))
      of SETTING_VIDEO_GEOMETRY_QUALITY:
        result.geometryQuality = cast[LowMediumHigh](parseInt(value))
      of SETTING_VIDEO_LIGHTING_QUALITY:
        result.lightingQuality = cast[LowMediumHigh](parseInt(value))
      of SETTING_VIDEO_DYNAMIC_LIGHTING_QUALITY:
        result.dynamicLightingQuality = cast[LowMediumHigh](parseInt(value))
      of SETTING_VIDEO_DYNAMIC_SHADOWS_QUALITY:
        result.dynamicShadowsQuality = cast[LowMediumHigh](parseInt(value))
      of SETTING_VIDEO_EFFECTS_QUALITY:
        result.effectsQuality = cast[LowMediumHigh](parseInt(value))
      of SETTING_VIDEO_TEXTURE_QUALITY:
        result.textureQuality = cast[LowMediumHigh](parseInt(value))
      of SETTING_VIDEO_TEXTURE_FILTERING_QUALITY:
        result.textureFilteringQuality = cast[LowMediumHigh](parseInt(value))
      of SETTING_VIDEO_RESOLUTION:
        var posX: int = value.find("x")
        var posAt: int = value.find("@")
        result.resolution.width = parseUInt(value.substr(0, posX - 1)).uint16
        result.resolution.height = parseUInt(value.substr(posX + 1, posAt - 1)).uint16
        result.resolution.frequence = parseUInt(value.substr(posAt + 1, value.high - 2)).uint8
      of SETTING_VIDEO_ANTIALIASING:
        result.antialiasing = parseEnum[Antialiasing](value)
      of SETTING_VIDEO_VIEW_DISTANCE_SCALE:
        result.viewDistanceScale = parseFloat(value)
      of SETTING_VIDEO_USE_BLOOM:
        result.useBloom = parseBool(value)
      of SETTING_VIDEO_VIDEO_OPTION_SCHEME:
        result.videoOptionScheme = cast[Presets](parseInt(value))
    fileStream.close()
  else:
    # TODO: Create a video file in application startup and throw an exception if running into this else case
    return newVideo()

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

when isMainModule:
  let path: string = """/home/dankrad/Battlefield 2142/Profiles/0001/Video.con"""
  echo readVideo(path)
  echo newVideo()
