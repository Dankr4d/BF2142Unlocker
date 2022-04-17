### Package
version       = "0.9.7"
author        = "Dankrad"
description   = "Play and host BF2142 server with all unlocks or join multiplayer servers."
license       = "MIT"
##

### Dependencies
requires "nim >= 1.6.5"
requires "gintro >= 0.9.8"
requires "regex >= 0.19.0" # Using this regex module because it doesn't depend to a shared library
requires "https://github.com/Dankr4d/conparser >= 0.1.14"
when defined(windows):
  requires "winim >= 3.8.0"
when defined(linux):
  requires "psutil >= 0.6.0"
##
