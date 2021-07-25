import streams
import strutils
import strtoobj
import parseutils
import macros
import "../macro/dot"

template Settings(val: string) {.pragma.}
template Setting(val: string) {.pragma.}
template Format(val: string) {.pragma.}
template Range(val: tuple[min, max: float]) {.pragma.}

proc readCon[T](path: string): T =
  when not result.hasCustomPragma(Settings):
    {.error: "Type T misses pragma 'Settings'.".}

  var file: File
  if file.open(path, fmRead, -1):
    let fileStream: FileStream = newFileStream(file)
    var
      line: string
      setting: string
      value: string

    var lineIdx: uint = 0

    while fileStream.readLine(line):
      lineIdx.inc()
      line = line.strip() # TODO: Test if the game strip's each line too
      try:
        (setting, value) = line.splitWhitespace(maxsplit = 1)
      except IndexDefect:  # Whitespace is missing, value is empty
        setting = line
        value = ""
        continue # TODO


      let prefix: string = result.getCustomPragmaVal(Settings)
      var conSettingName: string
      for key, val in result.fieldPairs:
        when result.dot(key).hasCustomPragma(Setting):
          if prefix.len > 0:
            conSettingName = prefix & "."
          conSettingName &= result.dot(key).getCustomPragmaVal(Setting)
          if conSettingName == setting:
            when type(result.dot(key)) is enum:
              # TODO: Instead of using try'n catch, check if enum value is int or string
              try:
                result.dot(key) = type(result.dot(key))(parseInt(value))
              except ValueError:
                result.dot(key) = parseEnum[type(result.dot(key))](value)
            elif type(result.dot(key)) is float:
              result.dot(key) = parseFloat(value)
            elif type(result.dot(key)) is bool:
              result.dot(key) = parseBool(value)
            elif type(result.dot(key)) is object:
              discard # create object with Format
              result.dot(key) = parse[type(result.dot(key))](result.dot(key).getCustomPragmaVal(Format), value)
            else:
              {.error: "Attribute type not implemented".}
          #     echo "Float"
  else:
    raise newException(ValueError, "FILE COULD NOT BE OPENED!") # TODO


when isMainModule:
  type
    OffLowMediumHigh* {.pure.} = enum
      Off = 0
      Low = 1
      Medium = 2
      High = 3
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
    Video* {.Settings: "VideoSettings".} = object
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
      viewDistanceScale* {.Setting: "setViewDistanceScale", Range: (0.0, 1.0).}: float # 0.0 = 50%, 1.0 = 100%
      useBloom* {.Setting: "setUseBloom".}: bool # It's a bool, but set to int, to validate if parser couldn't parse this value (-1 = Invalid) # TODO: Maybe not the best solution? Maybe use Options?
      videoOptionScheme* {.Setting: "setVideoOptionScheme".}: Presets
  echo readCon[Video]("""/home/dankrad/Battlefield 2142/Profiles/0001/Video.con""")