import conparser
export conparser

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

type
  Video* {.Prefix: "VideoSettings.".} = object
    terrainQuality* {.Setting: "setTerrainQuality", Default: LowMediumHigh.Low.}: LowMediumHigh
    geometryQuality* {.Setting: "setGeometryQuality", Default: LowMediumHigh.Low.}: LowMediumHigh
    lightingQuality* {.Setting: "setLightingQuality", Default: LowMediumHigh.Low.}: LowMediumHigh
    dynamicLightingQuality* {.Setting: "setDynamicLightingQuality", Default: OffLowMediumHigh.Off.}: OffLowMediumHigh
    dynamicShadowsQuality* {.Setting: "setDynamicShadowsQuality", Default: OffLowMediumHigh.Off.}: OffLowMediumHigh
    effectsQuality* {.Setting: "setEffectsQuality", Default: LowMediumHigh.Low.}: LowMediumHigh
    textureQuality* {.Setting: "setTextureQuality", Default: LowMediumHigh.Low.}: LowMediumHigh
    textureFilteringQuality* {.Setting: "setTextureFilteringQuality", Default: LowMediumHigh.Low.}: LowMediumHigh
    resolution* {.Setting: "setResolution", Format: "[width]x[height]@[frequence]Hz", Default: Resolution(width: 800, height: 600, frequence: 60).}: Resolution
    antialiasing* {.Setting: "setAntialiasing", Default: Antialiasing.Off.}: Antialiasing
    viewDistanceScale* {.Setting: "setViewDistanceScale", Default: 1.0f}: range[0.0f .. 1.0f] # 0.0 = 50%, 1.0 = 100%
    useBloom* {.Setting: "setUseBloom", Valid: Bools(`true`: @["1"], `false`: @["0"]), Default: false.}: bool
    videoOptionScheme* {.Setting: "setVideoOptionScheme", Default: Presets.Custom.}: Presets
##

proc `$`*(resolution: Resolution): string =
  return resolution.serialize(Video().resolution.getCustomPragmaVal(Format))

when isMainModule:
  let path: string = """/home/dankrad/Battlefield 2142/Profiles/0001/Video.con"""
  var video: Video
  var report: ConReport
  (video, report) = readCon[Video](path)
  for line in report.lines:
    echo line
