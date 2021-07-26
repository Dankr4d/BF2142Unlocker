import streams
import strutils
import strtoobj
import parseutils
import math
import macros
import "../macro/dot"
import typeinfo

export macros
export typeinfo

template Settings*(val: string) {.pragma.}
template Setting*(val: string) {.pragma.}
template Format*(val: string) {.pragma.}
template Range*(val: tuple[min, max: SomeFloat]) {.pragma.}


type
  Lines* = seq[Line] # TODO: Change to object and with valid flag to increase "invalidLines" iterator
  Line* = object
    valid*: bool
    emptyLine*: bool # TODO: Remove and check against setting and value == empty?
    setting*: string
    value*: string
    validValues*: seq[string] # TODO: query it when it's required and add something like "isSettingValid"
    raw*: string
    lineIdx*: uint # Starts at 1
    kind*: AnyKind

    # notFound*: bool
    # foundMultiple*: bool

import sequtils
export sequtils

template validValues(attr: typed): seq[string] =
  var result: seq[string]
  when type(attr) is enum:
    result = type(attr).toSeq().mapIt($ord(it))
  elif type(attr) is SomeFloat:
    when attr.hasCustomPragma(Range):
      let rangeTpl: tuple[min, max: SomeFloat] = attr.getCustomPragmaVal(Range)
      result = @[$rangeTpl.min, $rangeTpl.max]
    else:
      result = @["TODO to TODO"]
  elif type(attr) is bool:
    result = @["0", "1"]
  elif type(attr) is object:
    result = @[attr.getCustomPragmaVal(Format)]
  else:
    result = @[]
  result


iterator invalidLines*(lines: Lines): Line =
  # if lines.valid: # TODO
  #   return
  for line in lines:
    if not line.valid:
      yield line


proc readCon*[T](path: string): tuple[obj: T, lines: Lines] =
  when not T.hasCustomPragma(Settings):
    {.error: "Type T misses pragma 'Settings'.".}

  var file: File
  if file.open(path, fmRead, -1):
    let fileStream: FileStream = newFileStream(file)
    var lineRaw, lineStr: string # stripped

    var lineIdx: uint = 0
    var line: Line

    while fileStream.readLine(lineRaw):
      lineIdx.inc()
      lineStr = lineRaw.strip()

      line = Line(
        valid: true,
        lineIdx: lineIdx
      )

      if lineRaw.len == 0:
        line.emptyLine = true
        result.lines.add(line)
        continue

      line.raw = lineRaw

      try:
        (line.setting, line.value) = lineStr.splitWhitespace(maxsplit = 1)
      except IndexDefect:  # Whitespace is missing, value is empty
        line.setting = lineStr
        line.value = ""

      var conSettingName: string
      var foundSetting: bool = false
      for key, val in result.obj.fieldPairs:
        when result.obj.dot(key).hasCustomPragma(Setting):
          when T.hasCustomPragma(Settings):
            conSettingName = T.getCustomPragmaVal(Settings) & "."
          conSettingName &= result.obj.dot(key).getCustomPragmaVal(Setting)

          if conSettingName == line.setting:
            foundSetting = true
            line.validValues = validValues(result.obj.dot(key))
            line.kind = toAny(result.obj.dot(key)).kind

            if line.value.len > 0:
              try:
                when type(result.obj.dot(key)) is enum:
                  # TODO: Enum signed int, unsigned int, string
                  # try:
                    # Signed int enum
                    result.obj.dot(key) = type(result.obj.dot(key))(parseInt(line.value))
                  # try:
                  #   result.obj.dot(key) = type(result.obj.dot(key))(parseInt(line.value))
                  # except ValueError:
                  #   result.obj.dot(key) = parseEnum[type(result.obj.dot(key))](line.value)
                elif type(result.obj.dot(key)) is SomeFloat:
                  when result.obj.dot(key).hasCustomPragma(Range):
                    var valFloat: SomeFloat = parseFloat(line.value)
                    valFloat = parseFloat(line.value)
                    let rangeTpl: tuple[min, max: SomeFloat] = result.obj.dot(key).getCustomPragmaVal(Range)
                    # result = @[$rangeTpl.min, $rangeTpl.max]
                    if valFloat >= rangeTpl.min and valFloat <= rangeTpl.max:
                      result.obj.dot(key) = valFloat
                    else:
                      line.valid = false
                  else:
                    result.obj.dot(key) = parseFloat(line.value)
                elif type(result.obj.dot(key)) is bool:
                  result.obj.dot(key) = parseBool(line.value)
                elif type(result.obj.dot(key)) is object:
                  result.obj.dot(key) = parse[type(result.obj.dot(key))](result.obj.dot(key).getCustomPragmaVal(Format), line.value)
                else:
                  {.error: "Attribute type not implemented".}
              except RangeDefect, ValueError:
                line.valid = false
            else:
              # Setting found, but value is empty
              line.valid = false
      if not foundSetting:
        line.valid = false
      result.lines.add(line)
  else:
    raise newException(ValueError, "FILE COULD NOT BE OPENED!") # TODO



proc writeCon*[T](t: T, path: string) =
  let fileStream: FileStream = newFileStream(path, fmWrite)

  if not isNil(fileStream):
    var conSettingName: string

    for key, val in t.fieldPairs:
      when t.dot(key).hasCustomPragma(Setting):
        when T.hasCustomPragma(Settings):
          conSettingName = T.getCustomPragmaVal(Settings) & "."
        conSettingName &= t.dot(key).getCustomPragmaVal(Setting)

        when type(t.dot(key)) is enum or type(t.dot(key)) is bool:
          fileStream.writeLine(conSettingName & " " & $t.dot(key).int)
        elif type(t.dot(key)) is SomeFloat:
          fileStream.writeLine(conSettingName & " " & $round(t.dot(key), 6)) # TODO: Add MaxLen
        elif type(t.dot(key)) is object:
          discard # TODO
          # result.obj.dot(key) = parse[type(result.obj.dot(key))](result.obj.dot(key).getCustomPragmaVal(Format), line.value)
        else:
          {.error: "Attribute type not implemented".}

    fileStream.close()




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

  var (obj, lines) = readCon[Video]("""/home/dankrad/Battlefield 2142/Profiles/0001/Video.con""")
  echo "=== OBJ ==="
  echo obj
  echo "=== LINES ==="
  for line in lines.invalidLines:
    echo line
