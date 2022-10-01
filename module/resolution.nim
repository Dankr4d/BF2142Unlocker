when defined(linux):
  {.passL: "-lX11 -lXrandr".}

  type
    Rotation = cushort
    Display {.importc, header: "<X11/Xlib.h>", bycopy.} = object
    Window {.importc, header: "<X11/Xlib.h>", bycopy.} = object
    XRRScreenConfiguration {.importc, header: "<X11/Xlib.h>", bycopy.} = object
    # SizeID {.importc, header: "<X11/Xlib.h>", bycopy.} = object
    XRRScreenSize {.importc, header: "<X11/extensions/Xrandr.h>", bycopy.} = object
      width, height, mwidth, mheight: cint

  proc XOpenDisplay(displayName: ptr char): ptr Display {.importc, header: "<X11/Xlib.h>".}
  proc RootWindow(display: ptr Display, screenNumber: int): Window {.importc, header: "<X11/Xlib.h>".}
  proc XRRGetScreenInfo(display: ptr Display, window: Window): ptr XRRScreenConfiguration {.importc, header: "<X11/Xlib.h>".}
  # proc XRRConfigCurrentConfiguration(config: ptr XRRScreenConfiguration, rotation: ptr Rotation): SizeID {.importc, header: "<X11/Xlib.h>".}
  proc XRRConfigSizes(config: ptr XRRScreenConfiguration, nsizes: ptr cint): ptr XRRScreenSize {.importc, header: "<X11/Xlib.h>".}
  proc XRRConfigCurrentRate(config: ptr XRRScreenConfiguration): cshort {.importc, header: "<X11/Xlib.h>".}

  template `+`*[T](p: ptr T, off: int): ptr T =
    cast[ptr type(p[])](cast[ByteAddress](p) +% off * sizeof(p[]))
  template `[]`*[T](p: ptr T, off: int): T =
    (p + off)[]

  proc getAvailableResolutions*(): seq[tuple[width, height: uint16, frequence: uint8]] =
    # var currentRotation: Rotation
    var displayName: char
    var screenNumber: cint
    var nsize: cint
    var dpy: ptr Display = XOpenDisplay(addr(displayName))
    var rootWindow: Window = RootWindow(dpy, screenNumber)
    var sc: ptr XRRScreenConfiguration = XRRGetScreenInfo(dpy, rootWindow)
    # var currentSize: SizeID = XRRConfigCurrentConfiguration(sc, addr(currentRotation))
    var sizes: ptr XRRScreenSize = XRRConfigSizes(sc, addr(nsize))
    var frequence: cshort = XRRConfigCurrentRate(sc) # TODO: Use XRRRates?
    var i: cint = 0
    while i < nsize:
      # if i == cast[cint](currentSize) is the current resolution
      result.add((cast[uint16](sizes[i].width), cast[uint16](sizes[i].height), cast[uint8](frequence)))
      inc(i)
else:
  import winim

  proc getAvailableResolutions*(): seq[tuple[width, height: uint16, frequence: uint8]] =
    var dm: DEVMODE # = [0]
    dm.dmSize = cast[WORD](sizeof(dm))
    var iModeNum: cint = 0
    while EnumDisplaySettings(nil, iModeNum, addr(dm)) != 0:
      if dm.dmPelsWidth >= 800 and dm.dmDisplayFrequency >= 60 and dm.dmBitsPerPel == 32 and
      dm.dmDisplayFixedOutput == 0 and dm.dmDisplayFlags == 0:
        result.add((cast[uint16](dm.dmPelsWidth), cast[uint16](dm.dmPelsHeight), cast[uint8](dm.dmDisplayFrequency)))
      inc(iModeNum)


when isMainModule:
  echo getAvailableResolutions()