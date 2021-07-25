import parseutils
import strutils # TODO: parseutils also has a parseInt/Uint .. use it, instead of reparsing
import "../macro/dot"

proc parse*[T](format, value: string): T =
  var tokenAttribute, tokenValue, tokenDelimiters: string
  var pos: int = 0
  var idxValue: int = 0
  while pos < format.len:
    # TODO: Add "InvalidFormat", "InvalidValue", review code (it's not thr best)
    pos += format.parseUntil(tokenDelimiters, '[', pos) + 1
    pos += format.parseUntil(tokenAttribute, ']', pos) + 1

    idxValue += tokenDelimiters.len # If delemiters found at start in format string, skip it
    discard format.parseUntil(tokenDelimiters, '[', pos) + 1
    pos += tokenDelimiters.len

    idxValue += value.parseUntil(tokenValue, tokenDelimiters, idxValue)
    idxValue += tokenDelimiters.len

    echo "delimiters: ", tokenDelimiters
    echo tokenAttribute, ": ", tokenValue
    echo "---"

    for key, val in result.fieldPairs:
      if key == tokenAttribute:
        when type(result.dot(key)) is SomeSignedInt:
          result.dot(key) = type(result.dot(key))(parseInt(tokenValue))
        elif type(result.dot(key)) is SomeUnsignedInt:
          result.dot(key) = type(result.dot(key))(parseUInt(tokenValue))
        elif type(result.dot(key)) is string:
          result.dot(key) = tokenValue
        else:
          {.error: "Type '" & $type(result.dot(key)) & "' not implemented!".}


when isMainModule:
  type
    Resolution* = object
      width*: uint16
      height*: uint16
      frequence*: int
      mystr*: string

  let format: string = "a[width]xx[height]@@[frequence]Hz[mystr]ab"
  let value: string = "a800xx600@@60HzHALLOab"

  echo parse[Resolution](format, value)
