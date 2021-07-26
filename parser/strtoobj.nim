import parseutils
import strutils # TODO: parseutils also has a parseInt/Uint .. use it, instead of reparsing
import "../macro/dot"

proc parse*[T](format, value: string): T =
  var tokenAttribute, tokenValue, tokenDelimiters: string
  var posFormat, posValue: int = 0

  # Skip delemitters at start of string
  posFormat = format.skipUntil('[', 0) + 1
  posValue = posFormat - 1

  while posFormat < format.len:
    # TODO: Add "InvalidFormat" and "InvalidValue" exceptions
    posFormat += format.parseUntil(tokenAttribute, ']', posFormat) + 1
    posFormat += format.parseUntil(tokenDelimiters, '[', posFormat) + 1

    posValue += value.parseUntil(tokenValue, tokenDelimiters, posValue)
    posValue += tokenDelimiters.len

    # echo "delimiters: ", tokenDelimiters
    # echo tokenAttribute, ": ", tokenValue
    # echo "---"

    for key, val in result.fieldPairs:
      if key == tokenAttribute:
        when type(result.dot(key)) is SomeSignedInt:
          result.dot(key) = type(result.dot(key))(parseInt(tokenValue))
        elif type(result.dot(key)) is SomeUnsignedInt:
          result.dot(key) = type(result.dot(key))(parseUInt(tokenValue))
        elif type(result.dot(key)) is string:
          result.dot(key) = tokenValue
        elif type(result.dot(key)) is bool:
          result.dot(key) = parseBool(tokenValue)
        else:
          {.error: "Type '" & $type(result.dot(key)) & "' not implemented!".}


when isMainModule:
  type
    Resolution* = object
      width*: uint16
      height*: uint16
      frequence*: int
      mystr*: string
      mybool*: bool

  let format: string = "a[width]xx[height]@@[frequence]Hz[mystr]ab[mybool]hallo"
  let value: string = "a800xx600@@60HzHALLOab1hallo"

  echo parse[Resolution](format, value)
