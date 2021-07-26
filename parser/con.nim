#[
  TODOS:
    * Pragama to set which bool formats are valid. E.g. 0, 1 is valid, but true, false, on and off are not
    * Pragama to allow floats starting with dot
]#

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
export strtoobj

template Prefix*(val: string) {.pragma.}
template Setting*(val: string) {.pragma.}
template Default*(val: string | SomeFloat | enum) {.pragma.}
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
    result = type(attr).toSeq().mapIt($it)
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
        when T.hasCustomPragma(Prefix):
          conSettingName = T.getCustomPragmaVal(Prefix)
        when result.obj.dot(key).hasCustomPragma(Setting):
          conSettingName &= result.obj.dot(key).getCustomPragmaVal(Setting)

          if conSettingName == line.setting:
            foundSetting = true
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
                  result.obj.dot(key) = result.obj.dot(key).getCustomPragmaVal(Default)[0] # TODO: Why the fuck do I get a tuple?!?
            break # Setting found, break
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
      when T.hasCustomPragma(Prefix):
        conSettingName = T.getCustomPragmaVal(Prefix)
      when t.dot(key).hasCustomPragma(Setting):
        conSettingName &= t.dot(key).getCustomPragmaVal(Setting)

        when type(t.dot(key)) is enum:
          fileStream.writeLine(conSettingName & " " & $t.dot(key))
        elif type(t.dot(key)) is SomeFloat:
          fileStream.writeLine(conSettingName & " " & $round(t.dot(key), 6)) # TODO: Add Round pragma
        elif type(t.dot(key)) is bool:
          fileStream.writeLine(conSettingName & " " & $t.dot(key).int)
        elif type(t.dot(key)) is object:
          fileStream.writeLine(conSettingName & " " & t.dot(key).serialize(t.dot(key).getCustomPragmaVal(Format)))
        else:
          {.error: "Attribute type not implemented".}

    fileStream.close()




when isMainModule:
  from ../profile/video import Video

  var (obj, lines) = readCon[Video]("""/home/dankrad/Battlefield 2142/Profiles/0001/Video.con""")
  echo "=== OBJ ==="
  echo obj
  # echo "=== LINES ==="
  # for line in lines.invalidLines:
  #   echo line
