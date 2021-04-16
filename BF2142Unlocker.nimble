### Package
version       = "0.9.6"
author        = "Dankrad"
description   = "Play and host BF2142 server with all unlocks or join multiplayer servers."
license       = "MIT"
##

### Dependencies
requires "nim >= 1.2.6"
requires "gintro >= 0.8.3"
requires "regex >= 0.18.0" # Using this regex module because it doesn't depend to a shared library
when defined(windows):
  requires "winim >= 3.4.0"
when defined(linux):
  requires "psutil >= 0.6.0"
##
