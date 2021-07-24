import streams
import strutils
import strformat
import math
import sequtils

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

### TODO: Outsource
import gintro/glib
type
  ConEntries* = seq[ConEntry]
  ConEntry* = object
    valid*: bool
    line*: uint
    raw*: string # raw line
    setting*: string
    value*: string
    validValues*: seq[string]

proc markup*(entries: ConEntries): string =
  for entry in entries:
    if entry.valid:
      result &= "<span foreground=\"#DCDCDC\">"
      result &= markupEscapeText(entry.raw, entry.raw.len)
      result &= "</span>"
    else:
      if entry.validValues.len == 0:
        if entry.raw.len == 0:
          discard # Empty line
        else:
          # Setting unknown
          result &= "<b>"
          result &= "<span foreground=\"#FF6347\" strikethrough=\"true\">"
          result &= markupEscapeText(entry.raw, entry.raw.len)
          result &= "</span>"
          result &= "</b>"
      else:
        result &= "<b>"
        result &= entry.setting
        result &= " "
        if entry.value.len == 0:
          # Value missing
          result &= "<span foreground=\"#8B4513\">"
          result &= "[MISSING]"
          result &= "</span>"
        else:
          result &= "<span foreground=\"#FF6347\">"
          result &= markupEscapeText(entry.value, entry.value.len)
          result &= "</span>"
        result &= " "

        var validValuesStr: string = entry.validValues.join(", ")
        result &= "<span foreground=\"#ADFF2F\">"
        result &= "[" & markupEscapeText(validValuesStr, validValuesStr.len) & "]"
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


proc isValid*(resolution: Resolution): bool =
  return (
    resolution.width > 0 and
    resolution.height > 0 and
    resolution.frequence > 0
  )

proc isViewDistanceValid*(val: float): bool =
  return (
    val >= 0.0 and
    val <= 1.0
  )

proc isBloomValid(val: int): bool =
  return (
    val == 0 or val == 1
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
    isValid(video.resolution) and
    video.antialiasing != Antialiasing.Invalid and
    isViewDistanceValid(video.viewDistanceScale) and
    isBloomValid(video.useBloom) and
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
  if not isViewDistanceValid(video.viewDistanceScale):
    video.viewDistanceScale = 1.0
  if not isBloomValid(video.useBloom):
    video.useBloom = 0
  if video.videoOptionScheme == Presets.Invalid:
    video.videoOptionScheme = Presets.Custom

proc validValues*(t: typedesc): seq[string] =
  if t is LowMediumHigh or t is OffLowMediumHigh or t is Presets:
    return t.toSeq()[1..^1].mapIt($ord(it))
  elif t is Antialiasing:
    return t.toSeq()[1..^1].mapIt($it)

proc readVideo*(path: string, video: var Video, entries: var ConEntries): bool =
  # TODO:
  #      1. Multiple settings (more then one setting in config)
  #      2. Missing setting
  video = newVideoInvalid()

  var file: File
  if open(file, path, fmRead, -1):
    let fileStream: FileStream = newFileStream(file)
    var
      line: string
      setting: string
      value: string
    var entry: ConEntry
    var foundSetting: bool
    var isValid: bool
    var idx: uint = 0
    while fileStream.readLine(line):
      idx.inc()
      line = line.strip() # TODO: Test if the game strip's each line too
      try:
        (setting, value) = line.splitWhitespace(maxsplit = 1)
      except IndexDefect:  # Whitespace is missing, value is empty
        setting = line
        value = ""

      isValid = true
      foundSetting = false
      entry = ConEntry(
        valid: false,
        line: idx,
        raw: line,
        setting: setting,
        value: value
      )

      try: # LowMediumHigh
        if setting == SETTING_VIDEO_TERRAIN_QUALITY:
          video.terrainQuality = LowMediumHigh(parseInt(value))
          foundSetting = true
        elif setting == SETTING_VIDEO_GEOMETRY_QUALITY:
          video.geometryQuality = LowMediumHigh(parseInt(value))
          foundSetting = true
        elif setting == SETTING_VIDEO_LIGHTING_QUALITY:
          video.lightingQuality = LowMediumHigh(parseInt(value))
          foundSetting = true
        elif setting == SETTING_VIDEO_EFFECTS_QUALITY:
          video.effectsQuality = LowMediumHigh(parseInt(value))
          foundSetting = true
        elif setting == SETTING_VIDEO_TEXTURE_QUALITY:
          video.textureQuality = LowMediumHigh(parseInt(value))
          foundSetting = true
        elif setting == SETTING_VIDEO_TEXTURE_FILTERING_QUALITY:
          video.textureFilteringQuality = LowMediumHigh(parseInt(value))
          foundSetting = true
      except ValueError, RangeDefect:
        isValid = false
        entry.validValues = validValues(LowMediumHigh)
        entries.add(entry)
        continue

      if foundSetting:
        entry.valid = true
        entries.add(entry)
        continue

      try: # OffLowMediumHigh
        if setting == SETTING_VIDEO_DYNAMIC_LIGHTING_QUALITY:
          video.dynamicLightingQuality = OffLowMediumHigh(parseInt(value))
          foundSetting = true
        elif setting == SETTING_VIDEO_DYNAMIC_SHADOWS_QUALITY:
          video.dynamicShadowsQuality = OffLowMediumHigh(parseInt(value))
          foundSetting = true
      except ValueError, RangeDefect:
        isValid = false
        entry.validValues = validValues(OffLowMediumHigh)
        entries.add(entry)
        continue

      if foundSetting:
        entry.valid = true
        entries.add(entry)
        continue

      # Resolution
      if setting == SETTING_VIDEO_RESOLUTION:
        try:
          var posX: int = value.find("x")
          var posAt: int = value.find("@")
          video.resolution.width = parseUInt(value.substr(0, posX - 1)).uint16
          video.resolution.height = parseUInt(value.substr(posX + 1, posAt - 1)).uint16
          video.resolution.frequence = parseUInt(value.substr(posAt + 1, value.high - 2)).uint8
          foundSetting = true
        except ValueError:
          isValid = false
          entry.validValues = @["[width]x[height]@[frequence]Hz"]
          entries.add(entry)
          continue

      if foundSetting:
        entry.valid = true
        entries.add(entry)
        continue

      # Antialiasing
      if setting == SETTING_VIDEO_ANTIALIASING:
        try:
          video.antialiasing = parseEnum[Antialiasing](value)
          foundSetting = true
        except ValueError:
          isValid = false
          entry.validValues = validValues(Antialiasing)
          entries.add(entry)
          continue

      if foundSetting:
        entry.valid = true
        entries.add(entry)
        continue

      # View distance
      if setting == SETTING_VIDEO_VIEW_DISTANCE_SCALE:
        try:
          video.viewDistanceScale = parseFloat(value)
          if not isViewDistanceValid(video.viewDistanceScale):
            entry.validValues = @[">= 0.0", "<= 1.0"]
            entries.add(entry)
            continue
          else:
            foundSetting = true
        except ValueError:
          isValid = false
          entry.validValues = @[">= 0.0", "<= 1.0"]
          entries.add(entry)
          continue

      if foundSetting:
        entry.valid = true
        entries.add(entry)
        continue

      # Bloom
      if setting == SETTING_VIDEO_USE_BLOOM:
        try:
          video.useBloom = parseInt(value).int8
          if not isBloomValid(video.useBloom):
            video.useBloom = -1
            entry.validValues = @["0", "1"]
            entries.add(entry)
            continue
          else:
            foundSetting = true
        except ValueError:
          isValid = false
          entry.validValues = @["0", "1"]
          entries.add(entry)
          continue

      if foundSetting:
        entry.valid = true
        entries.add(entry)
        continue

      # Presets
      if setting == SETTING_VIDEO_VIDEO_OPTION_SCHEME:
        try:
          video.videoOptionScheme = Presets(parseInt(value))
          foundSetting = true
        except ValueError, RangeDefect:
          isValid = false
          entry.validValues = validValues(Presets)
          entries.add(entry)
          continue

      if foundSetting:
        entry.valid = true
        entries.add(entry)
        continue

      # Unknown
      isValid = false
      entries.add(entry)

    fileStream.close()

    return isValid
  else:
    discard # TODO


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
  var video: Video
  var entries: ConEntries
  echo "readVideo: ", readVideo(path, video, entries)
  echo "entries: ", entries
  # echo newVideoLow()
