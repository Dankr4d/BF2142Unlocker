### imports
from os import `/`
from strformat import fmt
from strutils import strip, toLower, find
##

### Consts
const CPU_CORES: string = gorgeEx("nproc").output # TODO: staticExec instead of gorgeEx

when defined(windows):
  const CPU_ARCH: int = when staticExec("gcc -dumpmachine").strip() == "x86_64-w64-mingw32": 64 else: 32
else:
  discard # TODO

# TODO: Rename: 32 -> i868, 64 -> amd64? ... If yes, fix BUILD_DIR const
# TODO: Rename CPU_ARCh -> COMPILER_ARCH?
const COMPILE_PARAMS: string = "-f -d:release --stackTrace:on --lineTrace:on --opt:speed --passL:-s" &
  (if CPU_ARCH == 32: " --cpu:i386 --passC:-m32 --passL:-m32" else: "") # 32 Bit

template filename: string = instantiationInfo().filename
import os
const FILE_NAME: string = splitFile(filename()).name

# TODO: Redundant (see BF2142Unlocker.nim ... pass this via symbol?)
const VERSION: string = static:
  let raw: string = staticRead("BF2142Unlocker.nimble")
  let posVersionStart: int = raw.find("version")
  let posQuoteStart: int = raw.find('"', posVersionStart)
  let posQuoteEnd: int = raw.find('"', posQuoteStart + 1)
  raw.substr(posQuoteStart + 1, posQuoteEnd - 1)
  # TODO: RC
  # let ver: string = raw.substr(posQuoteStart + 1, posQuoteEnd - 1)
  # if RC != 0:
  #   ver & " (RC: " & $RC & ")"
  # else:
  #   ver

const
  BUILD_DIR: string = "build" / fmt"BF2142Unlocker_v{VERSION}_" & (when defined(windows): "win" else: "linux") & fmt"_{CPU_ARCH}bit"
  LANGUAGES: seq[string] = @["en", "de", "ru"]

const # OpenSSL
  OPENSSL_VERSION: string = "1.0.2u"
  OPENSSL_ARCHIVE_BASENAME: string = fmt"openssl-{OPENSSL_VERSION}"
  OPENSSL_DIR: string = fmt"{OPENSSL_ARCHIVE_BASENAME}_{CPU_ARCH}"
  OPENSSL_PATH: string = "thirdparty" / OPENSSL_DIR
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
    exec("nim c " & COMPILE_PARAMS & " -o:" & BUILD_DIR / "BF2142Unlocker".toExe & " BF2142UnlockerLauncher.nim")

proc compileGui(rc: string) =
  var rcStr: string
  if rc != "":
    rcStr =  "-d:RC=" & rc & " "
  when defined(windows):
    exec("nim c " & COMPILE_PARAMS & " " & rcStr & " -o:" & BUILD_BIN_DIR / "BF2142Unlocker".toExe & " BF2142Unlocker")
  else:
    exec("nim c " & COMPILE_PARAMS & " " & rcStr & " -o:" & BUILD_DIR / "BF2142Unlocker".toExe & " BF2142Unlocker")

proc compileServer() =
  when defined(windows):
    # TODO: https://github.com/nim-lang/Nim/issues/16268
    #       Crashes without any exception in net module, in loadCertificates, while calling SSL_CTX_use_certificate_chain_file
    if CPU_ARCH == 64:
      exec("nim c " & COMPILE_PARAMS & " -o:" & BUILD_BIN_DIR / "BF2142UnlockerSrv".toExe & " BF2142UnlockerSrv")
    else:
      exec("nim c -f --passL:-s --cpu:i386 --passC:-m32 --passL:-m32 -o:" & BUILD_BIN_DIR / "BF2142UnlockerSrv".toExe & " BF2142UnlockerSrv")
  else:
    exec("nim c " & COMPILE_PARAMS & " -o:" & BUILD_DIR / "BF2142UnlockerSrv".toExe & " BF2142UnlockerSrv")

proc compileOpenSsl() =
  mkDir("thirdparty")
  withDir("thirdparty"):
    if not fileExists(fmt"{OPENSSL_ARCHIVE_BASENAME}.tar.gz"):
      exec(fmt"wget {OPENSSL_URL} -O {OPENSSL_ARCHIVE_BASENAME}.tar.gz")
    if dirExists(OPENSSL_DIR):
      rmDir(OPENSSL_DIR)
    when defined(windows):
      exec(fmt"tar xvzf {OPENSSL_ARCHIVE_BASENAME}.tar.gz")
      mvDir(OPENSSL_ARCHIVE_BASENAME, OPENSSL_DIR)
    else:
      exec(fmt"tar xvzf {OPENSSL_ARCHIVE_BASENAME}.tar.gz --one-top-level=openssl --strip=1")
  withDir(OPENSSL_PATH):
    when defined(windows):
      if CPU_ARCH == 64:
        exec("perl Configure mingw64 enable-ssl3 shared")
      else:
        exec("perl Configure mingw enable-ssl3 shared -m32")
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
  var GTK_LIBS: seq[string] = @[
    "gdbus.exe", "libatk-1.0-0.dll", "libbz2-1.dll", "libcairo-2.dll",
    "libcairo-gobject-2.dll", "libdatrie-1.dll", "libepoxy-0.dll", "libexpat-1.dll", "libssp-0.dll",
    "libffi-7.dll", "libfontconfig-1.dll", "libfreetype-6.dll", "libfribidi-0.dll",
    "libgdk-3-0.dll", "libgdk_pixbuf-2.0-0.dll", "libgio-2.0-0.dll", "libglib-2.0-0.dll", "libgmodule-2.0-0.dll",
    "libgobject-2.0-0.dll", "libgraphite2.dll", "libgtk-3-0.dll", "libharfbuzz-0.dll", "libiconv-2.dll",
    "libintl-8.dll", "liblzma-5.dll", "libpango-1.0-0.dll", "libpangocairo-1.0-0.dll", "libpangoft2-1.0-0.dll",
    "libpangowin32-1.0-0.dll", "libpcre-1.dll", "libpixman-1-0.dll", "libpng16-16.dll", "librsvg-2-2.dll",
    "libstdc++-6.dll", "libthai-0.dll", "libwinpthread-1.dll", "libxml2-2.dll", "zlib1.dll", "libbrotlidec.dll",
    "libbrotlicommon.dll"
  ]
  when CPU_ARCH == 64: # 64 bit
    GTK_LIBS.add("gspawn-win64-helper-console.exe")
    GTK_LIBS.add("libgcc_s_seh-1.dll")
  else: # 32 bit
    GTK_LIBS.add("gspawn-win32-helper-console.exe")

  proc copyGtk() =
    mkDir(BUILD_LIB_DIR)
    cpDir("C:" / "msys64" / (if CPU_ARCH == 64: "mingw64" else: "mingw32") / "lib" / "gdk-pixbuf-2.0", BUILD_LIB_DIR / "gdk-pixbuf-2.0")

    mkdir(BUILD_SHARE_THEME_DIR)
    cpFile("C:" / "msys64" / (if CPU_ARCH == 64: "mingw64" else: "mingw32") / "share" / "icons" / "Adwaita" / "icon-theme.cache", BUILD_SHARE_THEME_DIR / "icon-theme.cache")
    cpFile("C:" / "msys64" / (if CPU_ARCH == 64: "mingw64" else: "mingw32") / "share" / "icons" / "Adwaita" / "index.theme", BUILD_SHARE_THEME_DIR / "index.theme")
    mkDir(BUILD_SHARE_THEME_DIR / "scalable")
    cpDir("C:" / "msys64" / (if CPU_ARCH == 64: "mingw64" else: "mingw32") / "share" / "icons" / "Adwaita" / "scalable" / "actions", BUILD_SHARE_THEME_DIR / "scalable" / "actions")
    cpDir("C:" / "msys64" / (if CPU_ARCH == 64: "mingw64" else: "mingw32") / "share" / "icons" / "Adwaita" / "scalable" / "devices", BUILD_SHARE_THEME_DIR / "scalable" / "devices")
    cpDir("C:" / "msys64" / (if CPU_ARCH == 64: "mingw64" else: "mingw32") / "share" / "icons" / "Adwaita" / "scalable" / "mimetypes", BUILD_SHARE_THEME_DIR / "scalable" / "mimetypes")
    cpDir("C:" / "msys64" / (if CPU_ARCH == 64: "mingw64" else: "mingw32") / "share" / "icons" / "Adwaita" / "scalable" / "places", BUILD_SHARE_THEME_DIR / "scalable" / "places")
    cpDir("C:" / "msys64" / (if CPU_ARCH == 64: "mingw64" else: "mingw32") / "share" / "icons" / "Adwaita" / "scalable" / "ui", BUILD_SHARE_THEME_DIR / "scalable" / "ui")
    cpDir("C:" / "msys64" / (if CPU_ARCH == 64: "mingw64" else: "mingw32") / "share" / "icons" / "Adwaita" / "scalable-up-to-32", BUILD_SHARE_THEME_DIR / "scalable-up-to-32") # GtkSpinner

    mkDir(BUILD_SHARE_DIR / "glib-2.0" / "schemas")
    cpFile("C:" / "msys64" / (if CPU_ARCH == 64: "mingw64" else: "mingw32") / "share" / "glib-2.0" / "schemas" / "gschemas.compiled", BUILD_SHARE_DIR / "glib-2.0" / "schemas" / "gschemas.compiled")

    for lib in GTK_LIBS:
      cpFile("C:" / "msys64" / (if CPU_ARCH == 64: "mingw64" else: "mingw32") / "bin" / lib, BUILD_BIN_DIR / lib)

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
    cpFile("config" / "server.ini", BUILD_BIN_DIR / "config" / "server.ini")
  else:
    mkDir(BUILD_DIR / "config")
    cpFile("config" / "server.ini", BUILD_DIR / "config" / "server.ini")

proc copyAll() =
  when defined(windows):
    mkDir(BUILD_BIN_DIR / "asset")
    mkDir(BUILD_BIN_DIR / "log")
    cpDir("cert", BUILD_BIN_DIR / "cert")
    cpFile("asset" / "nopreview.png", BUILD_BIN_DIR / "asset" / "nopreview.png")
    copyGtk()
    copyOpenSSL()
  else:
    mkDir(BUILD_DIR / "asset")
    mkDir(BUILD_DIR / "log")
    cpDir("cert", BUILD_DIR / "cert")
    cpFile("asset" / "nopreview.png", BUILD_DIR / "asset" / "nopreview.png")
    copyNcurses()
    copyOpenSSL()
  copyServersConfig()
  copyTranslation()
##

### Tasks
task build, "Compile and bundle (release).":
  var rc: string
  if paramStr(paramCount()).toLower() != FILE_NAME.toLower():
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