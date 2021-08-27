import xxhash, streams # Required for streamed hashing
import xmlparser, xmltree
import os, strutils, uri

type
  PathHashSize* = object of RootObj
    # path*, hash32*, hash64*: string # TODO: Conparser cannot handle this
    path*: string
    hash32*: string
    hash64*: string
    size*: int64
  Version* = object of RootObj
    version*: float
    size*: int64
    files*: seq[PathHashSize]
    locations*: seq[string]

  Games* = seq[Game]
  Game* = object of RootObj
    name*: string
    mods*: seq[Mod]
  Mod*  = object of RootObj
    name*: string
    versions*: seq[Version]
    levels*: seq[Level]
  Level* = object of RootObj
    name*: string
    versions*: seq[Version]


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


proc getModVersion(path: string): float =
  var node: XmlNode = loadXml(path)
  return node.child("version").innerText.strip().parseFloat()


proc getGamesServer*(path: string): Games =
  for gameTpl in walkDir(path, true):
    var game: Game
    game.name = gameTpl.path

    for modTpl in walkDir(path / gameTpl.path, true):
      if modTpl.path in ["patches"]:
        continue

      var `mod`: Mod
      `mod`.name = modTpl.path

      for modVersionTpl in walkDir(path / gameTpl.path / modTpl.path, true):
        var version: Version
        version.version = parseFloat(modVersionTpl.path) # TODO: Replace with real version (major, minior, patch)
        version.locations = @[] # TODO

        if dirExists(path / gameTpl.path / modTpl.path / modVersionTpl.path / "files"):
          for filePath in walkDirRec(path / gameTpl.path / modTpl.path / modVersionTpl.path / "files", relative = true):
            var pathHashSize: PathHashSize = PathHashSize(
              path: filePath,
              # hash32: toHex(streamedXXH32(path / gameTpl.path / modTpl.path / modVersionTpl.path / filePath, 1024)),
              hash64: toHex(streamedXXH64(path / gameTpl.path / modTpl.path / modVersionTpl.path / filePath, 1024)),
              size: getFileSize(path / gameTpl.path / modTpl.path / modVersionTpl.path / filePath)
            )
            version.size += pathHashSize.size
            version.files.add(pathHashSize)
        `mod`.versions.add(version)

        if dirExists(path / gameTpl.path / modTpl.path / modVersionTpl.path / "levels"):
          for levelTpl in walkDir(path / gameTpl.path / modTpl.path / modVersionTpl.path / "levels", true):
            var level: Level
            level.name = levelTpl.path
            for levelVersionTpl in walkDir(path / gameTpl.path / modTpl.path / modVersionTpl.path / "levels" / levelTpl.path, true):
              var version: Version
              version.version = parseFloat(levelVersionTpl.path) # TODO: Replace with real version (major, minior, patch)

              for filePath in walkDirRec(path / gameTpl.path / modTpl.path / modVersionTpl.path / "levels" / levelTpl.path / levelVersionTpl.path, relative = true):
                var pathHashSize: PathHashSize = PathHashSize(
                # version.files.add(PathHash(
                  path: filePath,
                  # hash32: toHex(streamedXXH32(path / gameTpl.path / modTpl.path / modVersionTpl.path / "levels" / levelTpl.path / levelVersionTpl.path / filePath, 1024)),
                  hash64: toHex(streamedXXH64(path / gameTpl.path / modTpl.path / modVersionTpl.path / "levels" / levelTpl.path / levelVersionTpl.path / filePath, 1024)),
                  size: getFileSize(path / gameTpl.path / modTpl.path / modVersionTpl.path / "levels" / levelTpl.path / levelVersionTpl.path / filePath)
                )
                version.size += pathHashSize.size
                version.files.add(pathHashSize)
              version.locations = @[ # TODO
                $(parseUri("http://127.0.0.1:8080/") / gameTpl.path / modTpl.path / modVersionTpl.path / "levels" / levelTpl.path / levelVersionTpl.path),
                $(parseUri("http://192.168.1.107:8080/") / gameTpl.path / modTpl.path / modVersionTpl.path / "levels" / levelTpl.path / levelVersionTpl.path)
              ]
              level.versions.add(version)
            `mod`.levels.add(level)
      game.mods.add(`mod`)
    result.add(game)


proc getGamesClient*(path: string): Games =
  var game: Game
  game.name = "bf2142" # TODO

  for modTpl in walkDir(path / "mods", true):
    var `mod`: Mod
    `mod`.name = modTpl.path
    var version: Version
    # version.version = 0f # TODO: Read out of mod version file
    # `mod`.versions.add(version)

    if modTpl.path != "bf2142": continue # TODO: REMOVE!!!

    var levelDirName: string = "Levels"
    when defined(linux):
      for modDirTpl in walkDir(path / "mods" / modTpl.path, true):
        if modDirTpl.kind != pcDir:
          continue
        if modDirTpl.path.toLower() == "levels":
          levelDirName = modDirTpl.path
          break

    for filePath in walkDirRec(path / "mods" / modTpl.path, relative = true):
      if filePath.toLower().startsWith("levels"): # TODO: Split path, because someone could add a "levelsSUFFIX" folder
        continue

      if filePath.toLower() == "mod.desc":
        version.version = getModVersion(path / "mods" / modTpl.path / filePath)

      var pathHashSize: PathHashSize = PathHashSize(
        path: filePath,
        # hash32: toHex(streamedXXH32(path / "mods" / modTpl.path / filePath, 1024)),
        hash64: toHex(streamedXXH64(path / "mods" / modTpl.path / filePath, 1024)),
        size: getFileSize(path / "mods" / modTpl.path / filePath)
      )
      version.size += pathHashSize.size
      version.files.add(pathHashSize)
      # version.locations = @[] # TODO
    `mod`.versions.add(version)

    if dirExists(path / "mods" / modTpl.path / levelDirName):
      for levelTpl in walkDir(path / "mods" / modTpl.path / levelDirName, true):
        var level: Level
        level.name = levelTpl.path
        var version: Version
        version.version = 0f # TODO: Read out of config file, if exists

        for filePath in walkDirRec(path / "mods" / modTpl.path / levelDirName / levelTpl.path, relative = true):
          var pathHashSize: PathHashSize = PathHashSize(
            path: filePath,
            # hash32: toHex(streamedXXH32(path / "mods" / modTpl.path / levelDirName / levelTpl.path / filePath, 1024)),
            hash64: toHex(streamedXXH64(path / "mods" / modTpl.path / levelDirName / levelTpl.path / filePath, 1024)),
            size: getFileSize(path / "mods" / modTpl.path / levelDirName / levelTpl.path / filePath)
          )
          version.size += pathHashSize.size
          version.files.add(pathHashSize)
        version.locations = @[ # TODO
          $("mods" / modTpl.path / levelDirName / levelTpl.path),
          $("mods" / modTpl.path / levelDirName / levelTpl.path)
        ]
        level.versions.add(version)
        `mod`.levels.add(level)
      game.mods.add(`mod`)
  result.add(game)
