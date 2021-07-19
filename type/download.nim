import tables

type
  Games* = Table[string, Game]
  Game* = object
    mods*: seq[string]
    maps*: Maps
  Maps* = Table[string, seq[Map]]
  Map* = object
    name*: string
    size*: int64
    locations*: seq[string]