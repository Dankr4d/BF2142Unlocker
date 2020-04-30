when defined(linux):
  {.passL: "-lX11 -lXrandr".}

  type
    Rotation = cushort
    Display {.importc, header: "<X11/Xlib.h>", bycopy.} = object
    Window {.importc, header: "<X11/Xlib.h>", bycopy.} = object
    XRRScreenConfiguration {.importc, header: "<X11/Xlib.h>", bycopy.} = object
    SizeID {.importc, header: "<X11/Xlib.h>", bycopy.} = object
    XRRScreenSize {.importc, header: "<X11/extensions/Xrandr.h>", bycopy.} = object
      width, height, mwidth, mheight: cint

  proc XOpenDisplay(display_name: ptr char): ptr Display {.importc, header: "<X11/Xlib.h>".}
  proc RootWindow(display: ptr Display, screen_number: int): Window {.importc, header: "<X11/Xlib.h>".}
  proc XRRGetScreenInfo(display: ptr Display, window: Window): ptr XRRScreenConfiguration {.importc, header: "<X11/Xlib.h>".}
  proc XRRConfigCurrentConfiguration(config: ptr XRRScreenConfiguration, rotation: ptr Rotation): SizeID {.importc, header: "<X11/Xlib.h>".}
  proc XRRConfigSizes(config: ptr XRRScreenConfiguration, nsizes: ptr cint): ptr XRRScreenSize {.importc, header: "<X11/Xlib.h>".}

  template `+`*[T](p: ptr T, off: int): ptr T =
    cast[ptr type(p[])](cast[ByteAddress](p) +% off * sizeof(p[]))
  template `[]`*[T](p: ptr T, off: int): T =
    (p + off)[]

  proc getAvailableResolutions*(): seq[tuple[width, height: uint]] =
    var current_rotation: Rotation
    var display_name: char
    var screen_number: cint
    var nsize: cint
    var dpy: ptr Display = XOpenDisplay(addr(display_name))
    var root_window: Window = RootWindow(dpy, screen_number)
    var sc: ptr XRRScreenConfiguration = XRRGetScreenInfo(dpy, root_window)
    var current_size: SizeID = XRRConfigCurrentConfiguration(sc, addr(current_rotation))
    var sizes: ptr XRRScreenSize = XRRConfigSizes(sc, addr(nsize))
    var i: cint = 0
    while i < nsize:
      # if i == cast[cint](current_size) is the current resolution
      result.add((cast[uint](sizes[i].width), cast[uint](sizes[i].height)))
      inc(i)
else:
  import winim

  proc getAvailableResolutions*(): seq[tuple[width, height: uint]] =
    var dm: DEVMODE # = [0]
    dm.dmSize = cast[WORD](sizeof(dm))
    var iModeNum: cint = 0
    while EnumDisplaySettings(nil, iModeNum, addr(dm)) != 0:
      if dm.dmPelsWidth >= 800 and dm.dmDisplayFrequency >= 60 and dm.dmBitsPerPel == 32 and
      dm.dmDisplayFixedOutput == 0 and dm.dmDisplayFlags == 0:
        result.add((cast[uint](dm.dmPelsWidth), cast[uint](dm.dmPelsHeight)))
      inc(iModeNum)


when isMainModule:
  echo getAvailableResolutions()