import strutils
import ../parser/con
export con

type
  OffLowMediumHigh* {.pure.} = enum
    Off = "0"
    Low = "1"
    Medium = "2"
    High = "3"
  LowMediumHigh* {.pure.} = enum
    Low = "1"
    Medium = "2"
    High = "3"
  Antialiasing* {.pure.} = enum
    Off = "Off"
    FourSamples = "4Samples"
    EightSamples = "8Samples"
  Presets* {.pure.} = enum
    Low = "0"
    Medium = "1"
    High = "2"
    Custom = "3"
  Resolution* = object of RootObj # When "of RootObj" kind == akTpl? .. optimization? dunno ....
    width*: uint16
    height*: uint16
    frequence*: uint8
  Video* {.Prefix: "VideoSettings.".} = object
    terrainQuality* {.Setting: "setTerrainQuality".}: LowMediumHigh
    geometryQuality* {.Setting: "setGeometryQuality".}: LowMediumHigh
    lightingQuality* {.Setting: "setLightingQuality".}: LowMediumHigh
    dynamicLightingQuality* {.Setting: "setDynamicLightingQuality".}: OffLowMediumHigh
    dynamicShadowsQuality* {.Setting: "setDynamicShadowsQuality".}: OffLowMediumHigh
    effectsQuality* {.Setting: "setEffectsQuality".}: LowMediumHigh
    textureQuality* {.Setting: "setTextureQuality".}: LowMediumHigh
    textureFilteringQuality* {.Setting: "setTextureFilteringQuality".}: LowMediumHigh
    resolution* {.Setting: "setResolution", Format: "[width]x[height]@[frequence]Hz".}: Resolution
    antialiasing* {.Setting: "setAntialiasing".}: Antialiasing
    viewDistanceScale* {.Setting: "setViewDistanceScale", Range: (0.0, 1.0), Default: 1.0}: float # 0.0 = 50%, 1.0 = 100%
    useBloom* {.Setting: "setUseBloom", ValidBools: Bools(`true`: @["1"], `false`: @["0"]).}: bool
    videoOptionScheme* {.Setting: "setVideoOptionScheme", Default: Presets.Custom.}: Presets

import gintro/glib
proc markup*(lines: Lines): string = # TODO: Outsource to con parser (without glib)
  for line in lines:
    if line.valid:
      result &= "<span foreground=\"#DCDCDC\">"
      result &= markupEscapeText(line.raw, line.raw.len)
      result &= "</span>"
    else:
      # if line.notFound:
      #   result &= "<b>"
      #   result &= "<span foreground=\"#8B4513\">"
      #   result &= markupEscapeText(line.setting, line.setting.len)
      #   result &= "</span> "
      #   var validValuesStr: string = line.validValues.join(", ")
      #   result &= "<span foreground=\"#ADFF2F\">"
      #   result &= "[" & markupEscapeText(validValuesStr, validValuesStr.len) & "]"
      #   result &= "</span>"
      #   result &= "</b>"
      # elif line.foundMultiple:
      #   result &= "<b>"
      #   result &= "<span foreground=\"#FFA500\" strikethrough=\"true\">"
      #   result &= markupEscapeText(line.raw, line.raw.len)
      #   result &= "</span>"
      #   result &= "</b>"
      # else:
        if line.validValues.len == 0:
          if line.setting.len == 0 and line.value.len == 0:
            discard # Empty line
          else:
            # Setting unknown
            result &= "<b>"
            result &= "<span foreground=\"#FF6347\" strikethrough=\"true\">"
            result &= markupEscapeText(line.raw, line.raw.len)
            result &= "</span>"
            result &= "</b>"
        else:
          result &= "<b>"
          result &= line.setting
          result &= " "
          if line.value.len == 0:
            # Value missing
            result &= "<span foreground=\"#8B4513\">"
            result &= "[MISSING]"
            result &= "</span>"
          else:
            # Value not valid
            result &= "<span foreground=\"#FF6347\">"
            result &= markupEscapeText(line.value, line.value.len)
            result &= "</span>"
          result &= " "

          result &= "<span foreground=\"#ADFF2F\">"
          case line.kind:
          of akObject:
            result &= markupEscapeText(line.validValues[0], line.validValues[0].len)
          of akFloat, akFloat32, akFloat64, akFloat128:
            var validValuesStr: string = line.validValues.join(" .. ")
            result &= "[" & markupEscapeText(validValuesStr, validValuesStr.len) & "]"
          of akEnum, akBool:
            var validValuesStr: string = line.validValues.join(", ")
            result &= "[" & markupEscapeText(validValuesStr, validValuesStr.len) & "]"
          else:
            discard
            # raise newException(ValueError, $line.kind & " not implemented!")
            # {.error: "Not implemented!".}
          result &= "</span>"
          result &= "</b>"
    result &= "\n"
##


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
  result.useBloom = false
  result.videoOptionScheme = Presets.Custom


proc `$`*(resolution: Resolution): string =
  return resolution.serialize(Video().resolution.getCustomPragmaVal(Format))

when isMainModule:
  let path: string = """/home/dankrad/Battlefield 2142/Profiles/0001/Video.con"""
  var video: Video
  var lines: Lines
  (video, lines) = readCon[Video](path)
  echo "lines: ", lines
