### imports
from os import `/`
from strformat import fmt
from strutils import strip, toLower, find, parseInt
##

### Consts
const CPU_CORES: string = gorgeEx("nproc").output # TODO: staticExec instead of gorgeEx

template filename: string = instantiationInfo().filename
from os import splitFile
const FILE_NAME: string = splitFile(filename()).name

# TODO: Redundant (see BF2142Unlocker.nim ... pass this via symbol?)
const VERSION: string = static:
  let raw: string = staticRead("BF2142Unlocker.nimble")
  let posVersionStart: int = raw.find("version")
  let posQuoteStart: int = raw.find('"', posVersionStart)
  let posQuoteEnd: int = raw.find('"', posQuoteStart + 1)
  raw.substr(posQuoteStart + 1, posQuoteEnd - 1)

const LANGUAGES: seq[string] = @["en", "de", "ru"]

# OpenSSL
const
  OPENSSL_VERSION: string = "1.0.2u"
  OPENSSL_ARCHIVE_BASENAME: string = fmt"openssl-{OPENSSL_VERSION}"
  OPENSSL_URL: string = fmt"https://www.openssl.org/source/openssl-{OPENSSL_VERSION}.tar.gz"

# Ncurses (linux)
const
  NCURSES_VERSION: string = "5.9"
  NCURSES_ARCHIVE_BASENAME = fmt"ncurses-{NCURSES_VERSION}"
  NCURSES_URL: string = fmt"https://ftp.gnu.org/gnu/ncurses/ncurses-{NCURSES_VERSION}.tar.gz"
##

### VARS
# TODO: Rename: 32 -> i868, 64 -> amd64? ... If yes, fix BUILD_DIR const
# TODO: Rename CPU_ARCH -> COMPILER_ARCH?
var CPU_ARCH: int
# TODO: LTO crashes openssl and also when launching singleplayer the first time (starting unlocker without config.ini) on 32bit build
var COMPILE_PARAMS: string = "-f -d:release --stackTrace:on --lineTrace:on --opt:speed --passL:-s" # -d:lto"

var CROSS_COMPILE: bool = false

var BUILD_DIR: string
var BUILD_BIN_DIR: string
var BUILD_DIR_NAME: string

var RC: int = 0

# when defined(windows):
var BUILD_LIB_DIR: string
var BUILD_SHARE_DIR: string
var BUILD_SHARE_THEME_DIR: string

# GTK
var GTK_LIBS: seq[string]

# OpenSSL
var OPENSSL_DIR: string
var OPENSSL_PATH: string

# Ncurses (linux)
var NCURSES_DIR: string
var NCURSES_PATH: string
##

### Procs helper
proc toExe*(filename: string): string =
  ## On Windows adds ".exe" to `filename`, else returns `filename` unmodified.
  (if defined(windows) or defined(linux) and CROSS_COMPILE: filename & ".exe" else: filename)
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
  var path: string
  if defined(windows) or defined(linux) and CROSS_COMPILE:
    path = BUILD_BIN_DIR
  else:
    path = BUILD_DIR
  for lang in LANGUAGES:
    mkDir(path / "locale" / lang / "LC_MESSAGES")
    cpFile("locale" / lang / "LC_MESSAGES" / "gui.mo", path / "locale" / lang / "LC_MESSAGES" / "gui.mo")

proc compileLauncher() =
  exec("nim c " & COMPILE_PARAMS & " -o:" & BUILD_DIR / "BF2142Unlocker".toExe & " BF2142UnlockerLauncher.nim")

proc compileGui() =
  var rcStr: string
  if RC > 0:
    rcStr =  fmt"-d:RC={RC} "
  if defined(windows) or defined(linux) and CROSS_COMPILE:
    exec("nim c " & COMPILE_PARAMS & " " & rcStr & " -o:" & BUILD_BIN_DIR / "BF2142Unlocker".toExe & " BF2142Unlocker")
  else:
    exec("nim c " & COMPILE_PARAMS & " " & rcStr & " -o:" & BUILD_DIR / "BF2142Unlocker".toExe & " BF2142Unlocker")

proc compileServer() =
  if defined(windows) or defined(linux) and CROSS_COMPILE:
    # TODO: https://github.com/nim-lang/Nim/issues/16268
    #       Crashes without any exception in net module, in loadCertificates, while calling SSL_CTX_use_certificate_chain_file.
    #       This is caused by "-fomit-frame-pointer" flag (which is set by optimization level 1 to 3 from gcc).
    #       Also link time optimization (-d:lto) causes crashes.
    #       Workaround: Set -fno-omit-frame-pointer compiler flag.
    if CPU_ARCH == 64:
      exec("nim c " & COMPILE_PARAMS & " -o:" & BUILD_BIN_DIR / "BF2142UnlockerSrv".toExe & " BF2142UnlockerSrv")
    else:
      exec("nim c " & COMPILE_PARAMS & " --passC:-fno-omit-frame-pointer -o:" & BUILD_BIN_DIR / "BF2142UnlockerSrv".toExe & " BF2142UnlockerSrv")
  else:
    exec("nim c " & COMPILE_PARAMS & " -o:" & BUILD_DIR / "BF2142UnlockerSrv".toExe & " BF2142UnlockerSrv")

proc compileOpenSsl() =
  mkDir("thirdparty")
  withDir("thirdparty"):
    if not fileExists(fmt"{OPENSSL_ARCHIVE_BASENAME}.tar.gz"):
      exec(fmt"wget {OPENSSL_URL} -O {OPENSSL_ARCHIVE_BASENAME}.tar.gz")
    if dirExists(OPENSSL_DIR):
      rmDir(OPENSSL_DIR) # TODO: make clean?
    when defined(windows):
      exec(fmt"tar xvzf {OPENSSL_ARCHIVE_BASENAME}.tar.gz")
      mvDir(OPENSSL_ARCHIVE_BASENAME, OPENSSL_DIR)
    else:
      exec(fmt"tar xvzf {OPENSSL_ARCHIVE_BASENAME}.tar.gz --one-top-level={OPENSSL_DIR} --strip=1")
  withDir(OPENSSL_PATH):
    when defined(windows):
      if CPU_ARCH == 64:
        exec("perl Configure mingw64 enable-ssl3 shared -m64")
      else:
        exec("perl Configure mingw enable-ssl3 shared -m32")
    else:
      if CROSS_COMPILE:
        if CPU_ARCH == 64:
          exec(fmt"./Configure --cross-compile-prefix=x86_64-w64-mingw32- mingw64 enable-ssl3 shared -m64")
        else:
          exec(fmt"./Configure --cross-compile-prefix=i686-w64-mingw32- mingw enable-ssl3 shared -m32")
      else:
        exec(fmt"./Configure linux-generic{CPU_ARCH} enable-ssl3 shared -m{CPU_ARCH}")
    exec("make depend")
    exec(fmt"make -j{CPU_CORES}")

when defined(linux):
  proc compileNcurses() =
    mkDir("thirdparty")
    withDir("thirdparty"):
      if not fileExists(fmt"{NCURSES_ARCHIVE_BASENAME}.tar.gz"):
        exec(fmt"wget {NCURSES_URL} -O {NCURSES_ARCHIVE_BASENAME}.tar.gz")
      if dirExists(NCURSES_DIR):
        rmDir(NCURSES_DIR) # TODO: make clean?
      exec(fmt"tar xvzf {NCURSES_ARCHIVE_BASENAME}.tar.gz --one-top-level={NCURSES_DIR} --strip=1")
    # Applying patch (fixes compilation with newer gcc)
    withDir(NCURSES_PATH):
      exec(fmt"patch ncurses/base/MKlib_gen.sh < ../../patch/ncurses-5.9-gcc-5.patch")
      if CPU_ARCH == 64:
        exec("./configure x86_64-pc-linux-gnu --with-shared --without-debug --without-normal --without-cxx-binding --without-gpm CFLAGS=-m64 CXXFLAGS=-m64 LDFLAGS=-m64")
      else:
        exec("./configure i686-pc-linux-gnu --with-shared --without-debug --without-normal --without-cxx-binding --without-gpm CFLAGS=-m32 CXXFLAGS=-m32 LDFLAGS=-m32")
      exec(fmt"make -j{CPU_CORES}")

proc compileAll() =
  if not fileExists(OPENSSL_PATH / "libssl.a") or not fileExists(OPENSSL_PATH / "libcrypto.a"):
    compileOpenSsl()
  when defined(linux):
    if not CROSS_COMPILE and not fileExists(NCURSES_PATH / "lib" / "libncurses.so.5.9"):
      compileNcurses()
  compileGui() # Needs to be build before Launcher get's build, because it creates the BF2142Unlocker.res ressource file during compile time
  compileServer()
  if defined(windows) or defined(linux) and CROSS_COMPILE:
    compileLauncher()
  createTranslationMo()

# if defined(windows) or defined(linux) and CROSS_COMPILE:
proc copyGtk() =
  mkDir(BUILD_LIB_DIR)
  cpDir("C:" / "msys64" / fmt"mingw{CPU_ARCH}" / "lib" / "gdk-pixbuf-2.0", BUILD_LIB_DIR / "gdk-pixbuf-2.0")

  mkdir(BUILD_SHARE_THEME_DIR)
  cpFile("C:" / "msys64" / fmt"mingw{CPU_ARCH}" / "share" / "icons" / "Adwaita" / "icon-theme.cache", BUILD_SHARE_THEME_DIR / "icon-theme.cache")
  cpFile("C:" / "msys64" / fmt"mingw{CPU_ARCH}" / "share" / "icons" / "Adwaita" / "index.theme", BUILD_SHARE_THEME_DIR / "index.theme")
  mkDir(BUILD_SHARE_THEME_DIR / "scalable")
  cpDir("C:" / "msys64" / fmt"mingw{CPU_ARCH}" / "share" / "icons" / "Adwaita" / "scalable" / "actions", BUILD_SHARE_THEME_DIR / "scalable" / "actions")
  cpDir("C:" / "msys64" / fmt"mingw{CPU_ARCH}" / "share" / "icons" / "Adwaita" / "scalable" / "devices", BUILD_SHARE_THEME_DIR / "scalable" / "devices")
  cpDir("C:" / "msys64" / fmt"mingw{CPU_ARCH}" / "share" / "icons" / "Adwaita" / "scalable" / "mimetypes", BUILD_SHARE_THEME_DIR / "scalable" / "mimetypes")
  cpDir("C:" / "msys64" / fmt"mingw{CPU_ARCH}" / "share" / "icons" / "Adwaita" / "scalable" / "places", BUILD_SHARE_THEME_DIR / "scalable" / "places")
  cpDir("C:" / "msys64" / fmt"mingw{CPU_ARCH}" / "share" / "icons" / "Adwaita" / "scalable" / "ui", BUILD_SHARE_THEME_DIR / "scalable" / "ui")
  cpDir("C:" / "msys64" / fmt"mingw{CPU_ARCH}" / "share" / "icons" / "Adwaita" / "scalable-up-to-32", BUILD_SHARE_THEME_DIR / "scalable-up-to-32") # GtkSpinner

  mkDir(BUILD_SHARE_DIR / "glib-2.0" / "schemas")
  cpFile("C:" / "msys64" / fmt"mingw{CPU_ARCH}" / "share" / "glib-2.0" / "schemas" / "gschemas.compiled", BUILD_SHARE_DIR / "glib-2.0" / "schemas" / "gschemas.compiled")

  for lib in GTK_LIBS:
    cpFile("C:" / "msys64" / fmt"mingw{CPU_ARCH}" / "bin" / lib, BUILD_BIN_DIR / lib)

proc copyNcurses() =
  cpFile(NCURSES_PATH / "lib" / "libncurses.so.5.9", BUILD_DIR / "libncurses.so.5")

proc copyOpenSSL() =
  if defined(windows) or defined(linux) and CROSS_COMPILE:
    cpFile(OPENSSL_PATH / "libeay32.dll", BUILD_BIN_DIR / "libeay32.dll")
    cpFile(OPENSSL_PATH / "ssleay32.dll", BUILD_BIN_DIR / "ssleay32.dll")
  else:
    cpFile(OPENSSL_PATH / "libssl.so.1.0.0", BUILD_DIR / "libssl.so.1.0.0")
    cpFile(OPENSSL_PATH / "libcrypto.so.1.0.0", BUILD_DIR / "libcrypto.so.1.0.0")

proc copyServersConfig() =
  if defined(windows) or defined(linux) and CROSS_COMPILE:
    mkDir(BUILD_BIN_DIR / "config")
    cpFile("config" / "server.ini", BUILD_BIN_DIR / "config" / "server.ini")
  else:
    mkDir(BUILD_DIR / "config")
    cpFile("config" / "server.ini", BUILD_DIR / "config" / "server.ini")

proc copyAll() =
  if defined(windows) or defined(linux) and CROSS_COMPILE:
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

proc prepare() =
  # Parse release candidate number if any is provided
  if paramStr(paramCount()).toLower() != FILE_NAME.toLower():
    RC = parseInt(paramStr(paramCount()))

  # OpenSSL
  OPENSSL_DIR = fmt"{OPENSSL_ARCHIVE_BASENAME}_"
  if CROSS_COMPILE:
    when defined(windows):
      OPENSSL_DIR &= "linux"
    else:
      OPENSSL_DIR &= "win"
  else:
    when defined(windows):
      OPENSSL_DIR &= "win"
    else:
      OPENSSL_DIR &= "linux"
  OPENSSL_DIR &= fmt"_{CPU_ARCH}"
  OPENSSL_PATH = "thirdparty" / OPENSSL_DIR

  BUILD_DIR_NAME = fmt"BF2142Unlocker_v{VERSION}_"
  if RC > 0:
    BUILD_DIR_NAME &= fmt"rc{RC}_"
  if defined(windows) or defined(linux) and CROSS_COMPILE:
    BUILD_DIR_NAME &= "win"
  else:
    BUILD_DIR_NAME &= "linux"
  BUILD_DIR_NAME &= fmt"_{CPU_ARCH}bit"
  BUILD_DIR = "build" / BUILD_DIR_NAME
  if defined(windows) or defined(linux) and CROSS_COMPILE:
    BUILD_BIN_DIR = BUILD_DIR / "bin"
    BUILD_LIB_DIR = BUILD_DIR / "lib"
    BUILD_SHARE_DIR = BUILD_DIR / "share"
    BUILD_SHARE_THEME_DIR = BUILD_SHARE_DIR / "icons" / "Adwaita"

    # GTK
    GTK_LIBS = @[
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
    if CPU_ARCH == 64:
      GTK_LIBS.add("gspawn-win64-helper-console.exe")
      GTK_LIBS.add("libgcc_s_seh-1.dll")
    else:
      GTK_LIBS.add("gspawn-win32-helper-console.exe")
      GTK_LIBS.add("libgcc_s_dw2-1.dll")
  else:
    # NCURSES
    NCURSES_DIR = fmt"{NCURSES_ARCHIVE_BASENAME}_{CPU_ARCH}"
    NCURSES_PATH = "thirdparty" / NCURSES_DIR

  # Additional compile parameter
  if CPU_ARCH == 64:
    COMPILE_PARAMS &= " --cpu:amd64"
  else:
    COMPILE_PARAMS &= " --cpu:i386"

  if CROSS_COMPILE:
    COMPILE_PARAMS &= " -d:mingw"

  COMPILE_PARAMS &= fmt" --passC:-m{CPU_ARCH} --passL:-m{CPU_ARCH}"

proc compile() =
  mode = Verbose
  rmDir(BUILD_DIR)
  mkDir(BUILD_DIR)
  compileAll()
  copyAll()

proc zip() =
  withDir("build"):
    if fileExists(BUILD_DIR_NAME & ".zip"):
      rmFile(BUILD_DIR_NAME & ".zip")
    exec(fmt"zip -r {BUILD_DIR_NAME}.zip {BUILD_DIR_NAME}")
##

### Tasks
task buildall, "Compile and bundle 64 bit release.":
  CPU_ARCH = 64
  prepare()
  compile()
  zip()
  CPU_ARCH = 32
  prepare()
  compile()
  zip()

task build64, "Compile and bundle 64 bit release.":
  CPU_ARCH = 64
  prepare()
  compile()
  zip()

task build32, "Compile and bundle 32 bit release.":
  CPU_ARCH = 32
  prepare()
  compile()
  zip()

task zip, "":
  CPU_ARCH = 64
  prepare()
  zip()

# task xbuild64, "Cross compile and bundle 64 bit release.":
#   CPU_ARCH = 64
#   CROSS_COMPILE = true
#   prepare()
#   compile()

task translatePo, "Update po files from pot file.":
  mode = Verbose
  updateTranslationPo()

task translateMo, "Creates binary files from po files.":
  mode = Verbose
  createTranslationMo()
##