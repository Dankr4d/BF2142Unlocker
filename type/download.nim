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
  Version* = object
    version*: float
    size*: int64
    locations*: seq[string]
