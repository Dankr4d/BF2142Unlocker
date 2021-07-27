#[
  TODOS:
    * Pragama to allow floats starting with dot
    *
    * Range check in write proc
    * ValidBools `true`, `false` seq len check in parse and write proc
]#

import streams
import strutils
import strtoobj
import parseutils
import math
import macros
import "../macro/dot"
import typeinfo
import sequtils
import tables

export macros
export typeinfo
export strtoobj
export sequtils

type
  Bools* = object
    `true`*: seq[string]
    `false`*: seq[string]

template Prefix*(val: string) {.pragma.}
template Setting*(val: string) {.pragma.}
template Default*(val: string | SomeFloat | enum | bool) {.pragma.}
template Format*(val: string) {.pragma.}
template Range*(val: tuple[min, max: SomeFloat]) {.pragma.} # TODO: Use range
template ValidBools*(val: Bools) {.pragma.}


type
  ConReport* = object
    lines*: seq[ConLine]
    valid*: bool # true if all lines are valid, otherwise false
    invalidLines: seq[uint] # Invalid lines for a faster lookup
    multipleSettings: Table[uint, seq[uint]] # key = first line found, value = lines which same setting found afterwards
    settingsNotFound*: seq[ConSettingNotFound] # Settings which hasn't been found
  ConLine* = object
    valid*: bool
    setting*: string
    value*: string
    validValues*: seq[string] # TODO: query it when it's required and add something like "isSettingValid"
    raw*: string
    lineIdx*: uint # Starts at 0
    kind*: AnyKind
  ConSettingNotFound* = object
    prefix*: string
    setting*: string
    validValues*: seq[string]
    kind*: AnyKind


template validValues(attr: typed): seq[string] =
  var result: seq[string]
  when type(attr) is enum:
    result = type(attr).toSeq().mapIt($it)
  elif type(attr) is SomeFloat:
    when attr.hasCustomPragma(Range):
      let rangeTpl: tuple[min, max: SomeFloat] = attr.getCustomPragmaVal(Range)
      result = @[$rangeTpl.min, $rangeTpl.max]
    else:
      result = @["TODO to TODO"]
  elif type(attr) is bool:
    when attr.hasCustomPragma(ValidBools):
      const validBoolsTpl: Bools = attr.getCustomPragmaVal(ValidBools)
      result.add(validBoolsTpl.`true`)
      result.add(validBoolsTpl.`false`)
    else:
      result = @["1", "0", "true", "false", "yes", "no", "y", "n", "on", "off"]
  elif type(attr) is object:
    result = @[attr.getCustomPragmaVal(Format)]
  else:
    result = @[]
  result


iterator invalidLines*(report: ConReport): ConLine =
  for lineIdx in report.invalidLines:
    yield report.lines[lineIdx]

iterator multipleSettings*(report: ConReport): ConLine =
  # Currently only yields the "duplicate" files and not the first one, add also the first one?
  for lineIdxFirst, lineIdxSeq in report.multipleSettings.pairs:
    for lineIdx in lineIdxSeq:
      yield report.lines[lineIdx]

iterator multipleSettingsLineIdx*(report: ConReport): uint =
  for lineIdxSeq in report.multipleSettings.values:
    for lineIdx in lineIdxSeq:
      yield lineIdx

proc readCon*[T](path: string): tuple[obj: T, report: ConReport] =
  var file: File

  var tableFound: Table[string, uint] # table of first lineIdx setting was found
  # for key, val in result.obj.fieldPairs:
  #   tableFound:
  #   createBool(key & "Found")

  if not file.open(path, fmRead, -1):
    raise newException(ValueError, "FILE COULD NOT BE OPENED!") # TODO

  let fileStream: FileStream = newFileStream(file)
  var lineRaw: string
  var lineIdx: uint = 0

  while fileStream.readLine(lineRaw): # TODO: Doesn't read last empty line (readAll does)

    var line: ConLine = ConLine(
      valid: true,
      lineIdx: lineIdx,
      raw: lineRaw
    )

    let pos: int = lineRaw.parseUntil(line.setting, Whitespace, 0) + 1
    if pos < lineRaw.len:
      discard lineRaw.parseUntil(line.value, Newlines, pos)
      line.value = line.value.strip(leading = false) # TODO: Pass by parameter if multiple whitespaces are allowed as delemitter

    var setting: string
    var foundSetting: bool = false
    for key, val in result.obj.fieldPairs:
      when T.hasCustomPragma(Prefix):
        setting = T.getCustomPragmaVal(Prefix)
      when result.obj.dot(key).hasCustomPragma(Setting):
        setting &= result.obj.dot(key).getCustomPragmaVal(Setting)

        if setting == line.setting:
          foundSetting = true

          # Check if already found and add to duplicates of first found line
          if tableFound.hasKey(setting):
            line.valid = false

            let lineIdxFirst: uint = tableFound[setting]
            if not result.report.multipleSettings.hasKey(lineIdxFirst):
              result.report.multipleSettings[lineIdxFirst]= @[lineIdx]
            else:
              result.report.multipleSettings[lineIdxFirst].add(lineIdx)
          else:
            tableFound[setting] = lineIdx

          line.validValues = validValues(result.obj.dot(key))
          line.kind = toAny(result.obj.dot(key)).kind

          if line.value.len > 0:
            try:
              when type(result.obj.dot(key)) is enum:
                result.obj.dot(key) = parseEnum[type(result.obj.dot(key))](line.value)
              elif type(result.obj.dot(key)) is SomeFloat:
                if line.value.startsWith('.'):
                  line.valid = false
                else:
                  when result.obj.dot(key).hasCustomPragma(Range):
                    let valFloat: SomeFloat = parseFloat(line.value)
                    const rangeTpl: tuple[min, max: SomeFloat] = result.obj.dot(key).getCustomPragmaVal(Range)
                    if valFloat >= rangeTpl.min and valFloat <= rangeTpl.max:
                      result.obj.dot(key) = valFloat
                    else:
                      line.valid = false
                  else:
                    result.obj.dot(key) = parseFloat(line.value)
              elif type(result.obj.dot(key)) is bool:
                when result.obj.dot(key).hasCustomPragma(ValidBools):
                  const validBools: Bools = result.obj.dot(key).getCustomPragmaVal(ValidBools)
                  if line.value in validBools.`true`:
                    result.obj.dot(key) = true
                  elif line.value in validBools.`false`:
                    discard # Not required since default of bool is false
                  else:
                    line.valid = false
                else:
                  result.obj.dot(key) = parseBool(line.value)
              elif type(result.obj.dot(key)) is object:
                result.obj.dot(key) = parse[type(result.obj.dot(key))](result.obj.dot(key).getCustomPragmaVal(Format), line.value)
              else:
                {.error: "Attribute type '" & type(result.obj.dot(key)) & "' not implemented.".}
            except ValueError:
              line.valid = false
          else:
            # Setting found, but value is empty
            line.valid = false
          if not line.valid:
            when result.obj.dot(key).hasCustomPragma(Default):
              when result.obj.dot(key) is SomeFloat:
                const valDefault: SomeFloat = result.obj.dot(key).getCustomPragmaVal(Default)[0] # TODO: Why the fuck do I get a tuple?!?
                when result.obj.dot(key).hasCustomPragma(Range):
                  const rangeTpl: tuple[min, max: SomeFloat] = result.obj.dot(key).getCustomPragmaVal(Range)
                  when valDefault < rangeTpl.min or valDefault > rangeTpl.max:
                    {.error: "Default value " & $valDefault & " is not in range (" & $rangeTpl.min & ", " & $rangeTpl.max & ").".}
                  else:
                    result.obj.dot(key) = valDefault
                else:
                    result.obj.dot(key) = valDefault
              else:
                result.obj.dot(key) = result.obj.dot(key).getCustomPragmaVal(Default)[0] # TODO: Why the fuck do I get a tuple?!?
          break # Setting found, break
    if not foundSetting:
      line.valid = false
    if not line.valid:
      result.report.valid = false
      result.report.invalidLines.add(lineIdx)
    result.report.lines.add(line)
    lineIdx.inc()

  # Check for missing settings and add them to report
  when T.hasCustomPragma(Prefix):
    const prefix: string = T.getCustomPragmaVal(Prefix)
  else:
    const prefix: string = ""
  for key, val in result.obj.fieldPairs:
    when result.obj.dot(key).hasCustomPragma(Setting):
      const setting: string = result.obj.dot(key).getCustomPragmaVal(Setting)
      if not tableFound.hasKey(prefix & setting):
        # TODO: Set default value to result.obj.dot(key)
        result.report.settingsNotFound.add(ConSettingNotFound(
          prefix: prefix,
          setting: setting,
          validValues: validValues(result.obj.dot(key)),
          kind: toAny(result.obj.dot(key)).kind
        ))


proc writeCon*[T](t: T, path: string) =
  let fileStream: FileStream = newFileStream(path, fmWrite)

  if not isNil(fileStream):
    var setting: string

    for key, val in t.fieldPairs:
      when T.hasCustomPragma(Prefix):
        setting = T.getCustomPragmaVal(Prefix)
      when t.dot(key).hasCustomPragma(Setting):
        setting &= t.dot(key).getCustomPragmaVal(Setting)

        when type(t.dot(key)) is enum:
          fileStream.writeLine(setting & " " & $t.dot(key))
        elif type(t.dot(key)) is SomeFloat:
          fileStream.writeLine(setting & " " & $round(t.dot(key), 6)) # TODO: Add Round pragma
        elif type(t.dot(key)) is bool:
          when t.dot(key).hasCustomPragma(ValidBools):
            const validBools: Bools = t.dot(key).getCustomPragmaVal(ValidBools)
            # fileStream.writeLine(setting & " " & validBools.dot($t.dot(key))[0])
            if t.dot(key):
              fileStream.writeLine(setting & " " & validBools.`true`[0])
            else:
              fileStream.writeLine(setting & " " & validBools.`false`[0])
          else:
            fileStream.writeLine(setting & " " & $t.dot(key))
        elif type(t.dot(key)) is object:
          fileStream.writeLine(setting & " " & t.dot(key).serialize(t.dot(key).getCustomPragmaVal(Format)))
        else:
          {.error: "Attribute type '" & type(t.dot(key)) & "' not implemented.".}

    fileStream.close()




when isMainModule:
  from ../profile/video import Video

  var (obj, report) = readCon[Video]("""/home/dankrad/Battlefield 2142/Profiles/0001/Video.con""")
  echo "=== OBJ ==="
  echo obj
  echo "=== LINES ==="
  # for line in report.invalidLines:
  for line in multipleSettings(report):
    echo line
