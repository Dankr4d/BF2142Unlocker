from os import `/`
from strformat import fmt

const
  BUILD_DIR: string = "build"
  BUILD_BIN_DIR: string = BUILD_DIR / "bin"
  BUILD_LIB_DIR: string = BUILD_DIR / "lib"
  BUILD_SHARE_DIR: string = BUILD_DIR / "share"
  OPENSSL_VERSION: string = "1.0.2r"
  OPENSSL_DIR: string = "openssl-" & OPENSSL_VERSION
  OPENSSL_PATH: string = "deps" / "openssl"
  OPENSSL_URL: string = "https://www.openssl.org/source/openssl-" & OPENSSL_VERSION & ".tar.gz"

proc createIconRes() =
  echo "Creating icon.res"
  when defined(linux):
    echo "NOT IMPLEMENTED ON LINUX" # TODO
  elif defined(windows) and buildOS == "windows": # TODO: Should also be possible on linux
    exec("""windres.exe .\icon.rc -O coff -o icon.res""")

proc compileGui() =
  when defined(windows) and buildOS == "linux":
    exec("nim c -d:release -d:mingw --opt:speed --passL:-s -o:" & BUILD_BIN_DIR / "gui".toExe & " gui")
  else:
    exec("nim c -d:release --opt:speed --passL:-s -o:" & BUILD_BIN_DIR / "gui".toExe() & " gui")

proc compileServer() =
  when defined(windows) and buildOS == "linux":
    exec("nim c -d:release -d:mingw --opt:speed --passL:-s -o:" & BUILD_BIN_DIR / "server".toExe & " server")
  else:
    exec("nim c -d:release --opt:speed --passL:-s -o:" & BUILD_BIN_DIR / "server".toExe & " server")

proc compileElevatedio() =
  when defined(windows) and buildOS == "linux":
    exec("nim c -d:release -d:mingw --opt:speed --passL:-s -o:" & BUILD_BIN_DIR / "elevatedio".toExe & " elevatedio")
  else:
    exec("nim c -d:release --opt:speed --passL:-s -o:" & BUILD_BIN_DIR / "elevatedio".toExe & " elevatedio")

proc compileOpenSsl() =
  if not dirExists("deps"):
    mkDir("deps")
  withDir("deps"):
    exec(fmt"wget {OPENSSL_URL} -O {OPENSSL_DIR}.tar.gz")
    when defined(linux):
      exec(fmt"tar xvzf {OPENSSL_DIR}.tar.gz --one-top-level=openssl --strip=1")
    elif defined(windows):
      exec(fmt"tar xvzf {OPENSSL_DIR}.tar.gz")
      if dirExists("openssl"):
        rmDir("openssl")
      mvDir(OPENSSL_DIR, "openssl")
  withDir(OPENSSL_PATH):
    when buildOS == "linux":
      when defined(linux):
        exec("./config enable-ssl3 shared")
        exec("make depend")
        exec("make -j4") # TODO: j parameter: `nproc`
      elif defined(windows):
        exec("./Configure --cross-compile-prefix=x86_64-w64-mingw32- mingw64 enable-ssl3 shared")
        exec("make depend")
        exec("make -j4") # TODO: j parameter: `nproc`
    elif buildOS == "windows":
      exec("perl Configure mingw64 enable-ssl3 shared")
      exec("make depend")
      exec("make -j4") # TODO: j parameter: `nproc`

proc compileAll() =
  # compileDownload()
  if not fileExists("deps" / "openssl" / "libssl.a") or not fileExists("deps" / "openssl" / "libcrypto.a"):
    compileOpenSsl()
  compileGui()
  compileServer()
  when defined(windows):
    compileElevatedio()

when defined(windows):
  const GTK_LIBS: seq[string] = @["gdbus.exe", "libatk-1.0-0.dll", "libbz2-1.dll", "libcairo-2.dll", "libcairo-gobject-2.dll", "libcroco-0.6-3.dll", "libdatrie-1.dll", "libepoxy-0.dll", "libexpat-1.dll", "libffi-6.dll", "libfontconfig-1.dll", "libfreetype-6.dll", "libfribidi-0.dll", "libgcc_s_seh-1.dll", "libgdk-3-0.dll", "libgdk_pixbuf-2.0-0.dll", "libgio-2.0-0.dll", "libglib-2.0-0.dll", "libgmodule-2.0-0.dll", "libgobject-2.0-0.dll", "libgraphite2.dll", "libgtk-3-0.dll", "libharfbuzz-0.dll", "libiconv-2.dll", "libintl-8.dll", "liblzma-5.dll", "libpango-1.0-0.dll", "libpangocairo-1.0-0.dll", "libpangoft2-1.0-0.dll", "libpangowin32-1.0-0.dll", "libpcre-1.dll", "libpixman-1-0.dll", "libpng16-16.dll", "librsvg-2-2.dll", "libstdc++-6.dll", "libthai-0.dll", "libwinpthread-1.dll", "libxml2-2.dll", "zlib1.dll"]
  proc copyGtk() =
    mkDir(BUILD_LIB_DIR)
    cpDir("C:" / "msys64"/ "mingw64" / "lib" / "gdk-pixbuf-2.0", BUILD_LIB_DIR / "gdk-pixbuf-2.0")

    mkDir(BUILD_SHARE_DIR)
    cpDir("C:" / "msys64" / "mingw64" / "share" / "icons", BUILD_SHARE_DIR / "icons")

    mkDir(BUILD_SHARE_DIR / "glib-2.0" / "schemas")
    cpFile("C:" / "msys64" / "mingw64" / "share" / "glib-2.0" / "schemas" / "gschemas.compiled", BUILD_SHARE_DIR / "glib-2.0" / "schemas" / "gschemas.compiled")

    for lib in GTK_LIBS:
      cpFile("C:" / "msys64" / "mingw64" / "bin" / lib, BUILD_BIN_DIR / lib)

  proc copyOpenSSL() =
    cpFile(OPENSSL_PATH / "libeay32.dll", BUILD_BIN_DIR / "libeay32.dll")
    cpFile(OPENSSL_PATH / "ssleay32.dll", BUILD_BIN_DIR / "ssleay32.dll")

proc copyAll() =
  cpDir("ssl_certs", BUILD_BIN_DIR / "ssl_certs")
  cpFile("nopreview.png", BUILD_BIN_DIR / "nopreview.png")
  when defined(windows):
    copyGtk()
    copyOpenSSL()

proc createStartupBatch() =
  writeFile(BUILD_DIR / "BF2142Unlocker.bat", """
@echo off
cd /d bin
start gui.exe
  """)

proc installDeps() =
  exec("nim c -f -r instdeps.nim")

when isMainModule:
  mode = Verbose
  installDeps()
  rmDir(BUILD_DIR)
  mkDir(BUILD_DIR)
  when defined(windows):
    mkDir(BUILD_BIN_DIR / "tempfiles") # TODO: This folder should not be created here
    createStartupBatch()
  createIconRes()
  compileAll()
  copyAll()
