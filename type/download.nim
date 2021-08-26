import tables

type
  Games* = Table[string, Game]
  Game* = object
    mods*: seq[string]
    maps*: Maps
  Maps* = Table[string, seq[Map]]
  Map* = object
    name*: string
    versions*: seq[Version]
  PathHash* = object
    path*, hash32*, hash64*: string
  Version* = object
    version*: float
    size*: int64
    files*: seq[PathHash]
    locations*: seq[string]


import xxhash, streams # Required for streamed hashing

proc streamedXXH[T: uint32 | uint64](path: string, bufferSize: int, seed: T = 0): T =
  when T is uint32:
    var state: Xxh32State = newXxh32()
  else:
    var state: Xxh64State = newXxh64()
  # if state == nil: return 0
  var buffer: string
  buffer.setLen(bufferSize)
  # discard XXH64_reset(state, seed) # if XXH64_reset(state, seed) == XXH_ERROR: return 0
  var strm = newFileStream(path, fmRead)
  # if strm.isNil: return 0
  while not strm.atEnd():
    buffer.setLen(strm.readData(buffer.cstring, bufferSize))
    state.update(buffer)
  strm.close()
  return state.digest()

proc streamedXXH32*(path: string, bufferSize: int, seed: uint32 = 0): uint32 =
  return streamedXXH[uint32](path, bufferSize, seed)

proc streamedXXH64*(path: string, bufferSize: int, seed: uint64 = 0): uint64 =
  return streamedXXH[uint64](path, bufferSize, seed)
