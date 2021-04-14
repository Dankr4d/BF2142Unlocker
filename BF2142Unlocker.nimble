### Package
version       = "0.9.6"
author        = "Dankrad"
description   = "Play and host BF2142 server with all unlocks or join multiplayer servers."
license       = "MIT"
srcDir        = "src"
bin           = @[""]
##

### Dependencies
requires "nim >= 1.2.6"
requires "gintro >= 0.8.3"
requires "winim >= 3.4.0"
requires "regex >= 0.18.0" # Using this regex module because it doesn't depend to a shared library
when defined(windows):
  requires "winregistry >= 0.2.1"
when defined(linux):
  requires "psutil >= 0.6.0"
##

### imports
from os import `/`
from strformat import fmt
##

### Consts
const CPU_CORES: string = gorgeEx("nproc").output

const
  BUILD_DIR: string = "build"
  LANGUAGES: seq[string] = @["en", "de", "ru"]

const # OpenSSL
  OPENSSL_VERSION: string = "1.0.2r"
  OPENSSL_DIR: string = fmt"openssl-{OPENSSL_VERSION}"
  OPENSSL_PATH: string = "thirdparty" / "openssl"
  OPENSSL_URL: string = fmt"https://www.openssl.org/source/openssl-{OPENSSL_VERSION}.tar.gz"

when defined(linux):
  const # Ncurses
    NCURSES_VERSION: string = "5.9"
    NCURSES_DIR: string = fmt"ncurses-{NCURSES_VERSION}"
    NCURSES_PATH: string = "thirdparty" / "ncurses"
    NCURSES_URL: string = fmt"https://ftp.gnu.org/gnu/ncurses/ncurses-{NCURSES_VERSION}.tar.gz"

when defined(windows):
  const
    BUILD_BIN_DIR: string = BUILD_DIR / "bin"
    BUILD_LIB_DIR: string = BUILD_DIR / "lib"
    BUILD_SHARE_DIR: string = BUILD_DIR / "share"
    BUILD_SHARE_THEME_DIR: string = BUILD_SHARE_DIR / "icons" / "Adwaita"
##

### Procs
proc updateTranslationPo() =
  for lang in LANGUAGES:
    exec(fmt"msgmerge --update --no-fuzzy-matching --no-wrap locale/{lang}.po locale/gui.pot")

proc createTranslationMo() =
  for lang in LANGUAGES:
    mkDir("locale" / lang / "LC_MESSAGES")
    exec(fmt"msgfmt -o locale/{lang}/LC_MESSAGES/gui.mo locale/{lang}.po")

proc copyTranslation() =
  when defined(windows):
    let path: string = BUILD_BIN_DIR
  else:
    let path: string = BUILD_DIR
  for lang in LANGUAGES:
    mkDir(path / "locale" / lang / "LC_MESSAGES")
    cpFile("locale" / lang / "LC_MESSAGES" / "gui.mo", path / "locale" / lang / "LC_MESSAGES" / "gui.mo")

when defined(windows):
  proc compileLauncher() =
    exec("nim c -d:release --opt:speed --passL:-s -o:" & BUILD_DIR / "BF2142Unlocker".toExe & " BF2142UnlockerLauncher.nim")

proc compileGui(rc: string) =
  var rcStr: string
  if rc != "":
    rcStr =  "-d:RC=" & rc & " "
  when defined(windows):
    exec("nim c " & rcStr & " -d:release --stackTrace:on --lineTrace:on --opt:speed --passL:-s -o:" & BUILD_BIN_DIR / "BF2142Unlocker".toExe & " BF2142Unlocker")
  else:
    exec("nim c " & rcStr & " -d:release --stackTrace:on --lineTrace:on --opt:speed --passL:-s -o:" & BUILD_DIR / "BF2142Unlocker".toExe & " BF2142Unlocker")

proc compileServer() =
  when defined(windows):
    exec("nim c -d:release --stackTrace:on --lineTrace:on --opt:speed --passL:-s -o:" & BUILD_BIN_DIR / "BF2142UnlockerSrv".toExe & " BF2142UnlockerSrv")
  else:
    exec("nim c -d:release --stackTrace:on --lineTrace:on --opt:speed --passL:-s -o:" & BUILD_DIR / "BF2142UnlockerSrv".toExe & " BF2142UnlockerSrv")

proc compileOpenSsl() =
  mkDir("thirdparty")
  withDir("thirdparty"):
    exec(fmt"wget {OPENSSL_URL} -O {OPENSSL_DIR}.tar.gz")
    when defined(linux):
      exec(fmt"tar xvzf {OPENSSL_DIR}.tar.gz --one-top-level=openssl --strip=1")
    elif defined(windows):
      exec(fmt"tar xvzf {OPENSSL_DIR}.tar.gz")
      if dirExists("openssl"):
        rmDir("openssl")
      mvDir(OPENSSL_DIR, "openssl")
  withDir(OPENSSL_PATH):
  when defined(windows):
    exec("perl Configure mingw64 enable-ssl3 shared")
    exec("make depend")
    exec(fmt"make -j{CPU_CORES}")
  else:
    exec("./config enable-ssl3 shared")
    exec("make depend")
    exec(fmt"make -j{CPU_CORES}")

when defined(linux):
  proc compileNcurses() =
    mkDir("thirdparty")
    withDir("thirdparty"):
      exec(fmt"wget {NCURSES_URL} -O {NCURSES_DIR}.tar.gz")
      mkDir("ncurses")
      exec(fmt"tar xvzf {NCURSES_DIR}.tar.gz --strip=1 -C ncurses")
    # Applying patch (fixes compilation with newer gcc)
    withDir(NCURSES_PATH):
      exec(fmt"patch ncurses/base/MKlib_gen.sh < ../patch/ncurses-5.9-gcc-5.patch")
      # --without-cxx-binding is required or build fails
      exec("./configure --with-shared --without-debug --without-normal --without-cxx-binding")
      exec(fmt"make -j{CPU_CORES}")

proc compileAll(rc: string) =
  if not fileExists(OPENSSL_PATH / "libssl.a") or not fileExists(OPENSSL_PATH / "libcrypto.a"):
    compileOpenSsl()
  compileGui(rc) # Needs to be build before Launcher get's build, because it creates the BF2142Unlocker.res ressource file during compile time
  compileServer()
  when defined(windows):
    compileLauncher()
  else:
    if not fileExists(NCURSES_PATH / "lib" / "libncurses.so.5.9"):
      compileNcurses()
  createTranslationMo()

when defined(windows):
  const GTK_LIBS: seq[string] = @[
    "gdbus.exe", "gspawn-win64-helper-console.exe", "libatk-1.0-0.dll", "libbz2-1.dll", "libcairo-2.dll",
    "libcairo-gobject-2.dll", "libdatrie-1.dll", "libepoxy-0.dll", "libexpat-1.dll", "libssp-0.dll",
    "libffi-7.dll", "libfontconfig-1.dll", "libfreetype-6.dll", "libfribidi-0.dll", "libgcc_s_seh-1.dll",
    "libgdk-3-0.dll", "libgdk_pixbuf-2.0-0.dll", "libgio-2.0-0.dll", "libglib-2.0-0.dll", "libgmodule-2.0-0.dll",
    "libgobject-2.0-0.dll", "libgraphite2.dll", "libgtk-3-0.dll", "libharfbuzz-0.dll", "libiconv-2.dll",
    "libintl-8.dll", "liblzma-5.dll", "libpango-1.0-0.dll", "libpangocairo-1.0-0.dll", "libpangoft2-1.0-0.dll",
    "libpangowin32-1.0-0.dll", "libpcre-1.dll", "libpixman-1-0.dll", "libpng16-16.dll", "librsvg-2-2.dll",
    "libstdc++-6.dll", "libthai-0.dll", "libwinpthread-1.dll", "libxml2-2.dll", "zlib1.dll", "libbrotlidec.dll",
    "libbrotlicommon.dll"
  ]
  proc copyGtk() =
    mkDir(BUILD_LIB_DIR)
    cpDir("C:" / "msys64" / "mingw64" / "lib" / "gdk-pixbuf-2.0", BUILD_LIB_DIR / "gdk-pixbuf-2.0")

    mkdir(BUILD_SHARE_THEME_DIR)
    cpFile("C:" / "msys64" / "mingw64" / "share" / "icons" / "Adwaita" / "icon-theme.cache", BUILD_SHARE_THEME_DIR / "icon-theme.cache")
    cpFile("C:" / "msys64" / "mingw64" / "share" / "icons" / "Adwaita" / "index.theme", BUILD_SHARE_THEME_DIR / "index.theme")
    mkDir(BUILD_SHARE_THEME_DIR / "scalable")
    cpDir("C:" / "msys64" / "mingw64" / "share" / "icons" / "Adwaita" / "scalable" / "actions", BUILD_SHARE_THEME_DIR / "scalable" / "actions")
    cpDir("C:" / "msys64" / "mingw64" / "share" / "icons" / "Adwaita" / "scalable" / "devices", BUILD_SHARE_THEME_DIR / "scalable" / "devices")
    cpDir("C:" / "msys64" / "mingw64" / "share" / "icons" / "Adwaita" / "scalable" / "mimetypes", BUILD_SHARE_THEME_DIR / "scalable" / "mimetypes")
    cpDir("C:" / "msys64" / "mingw64" / "share" / "icons" / "Adwaita" / "scalable" / "places", BUILD_SHARE_THEME_DIR / "scalable" / "places")
    cpDir("C:" / "msys64" / "mingw64" / "share" / "icons" / "Adwaita" / "scalable" / "ui", BUILD_SHARE_THEME_DIR / "scalable" / "ui")
    cpDir("C:" / "msys64" / "mingw64" / "share" / "icons" / "Adwaita" / "scalable-up-to-32", BUILD_SHARE_THEME_DIR / "scalable-up-to-32") # GtkSpinner

    mkDir(BUILD_SHARE_DIR / "glib-2.0" / "schemas")
    cpFile("C:" / "msys64" / "mingw64" / "share" / "glib-2.0" / "schemas" / "gschemas.compiled", BUILD_SHARE_DIR / "glib-2.0" / "schemas" / "gschemas.compiled")

    for lib in GTK_LIBS:
      cpFile("C:" / "msys64" / "mingw64" / "bin" / lib, BUILD_BIN_DIR / lib)

  proc copyOpenSSL() =
    cpFile(OPENSSL_PATH / "libeay32.dll", BUILD_BIN_DIR / "libeay32.dll")
    cpFile(OPENSSL_PATH / "ssleay32.dll", BUILD_BIN_DIR / "ssleay32.dll")
else:
  proc copyNcurses() =
    cpFile(NCURSES_PATH / "lib" / "libncurses.so.5.9", BUILD_DIR / "libncurses.so.5")
  proc copyOpenSSL() =
    cpFile(OPENSSL_PATH / "libssl.so.1.0.0", BUILD_DIR / "libssl.so.1.0.0")
    cpFile(OPENSSL_PATH / "libcrypto.so.1.0.0", BUILD_DIR / "libcrypto.so.1.0.0")

proc copyServersConfig() =
  when defined(windows):
    mkDir(BUILD_BIN_DIR / "config")
    cpFile("config/server.ini", BUILD_BIN_DIR / "config/server.ini")
  else:
    mkDir(BUILD_DIR / "config")
    cpFile("config/server.ini", BUILD_DIR / "config/server.ini")

proc copyAll() =
  when defined(windows):
    mkDir(BUILD_BIN_DIR / "asset")
    mkDir(BUILD_BIN_DIR / "log")
    cpDir("cert", BUILD_BIN_DIR / "cert")
    cpFile("asset/nopreview.png", BUILD_BIN_DIR / "asset/nopreview.png")
    copyGtk()
    copyOpenSSL()
  else:
    mkDir(BUILD_DIR / "asset")
    mkDir(BUILD_DIR / "log")
    cpDir("cert", BUILD_DIR / "cert")
    cpFile("asset/nopreview.png", BUILD_DIR / "asset/nopreview.png")
    copyNcurses()
    copyOpenSSL()
  copyServersConfig()
  copyTranslation()
##

### Tasks
task release, "Compile and bundle (release).":
  var rc: string
  if paramStr(paramCount()) != "release":
    rc = paramStr(paramCount())
  mode = Verbose
  rmDir(BUILD_DIR)
  mkDir(BUILD_DIR)
  compileAll(rc)
  copyAll()

task translatePo, "Update po files from pot file.":
  mode = Verbose
  updateTranslationPo()

task translateMo, "Creates binary files from po files.":
  mode = Verbose
  createTranslationMo()
##