import gintro/[gtk, gobject, glib, gtksource, cairo, gdk, gdkpixbuf]
import "../../macro/signal"
import ../../profile/general as profileGeneral
import os
import strutils
import std/with

when defined(release):
  const BACKGROUND_IMAGE_RAW: string = staticRead(".." / ".." / "asset" / "hud" / "background.png")
  const HUD_IMAGE_RAW: string = staticRead(".." / ".." / "asset" / "hud" / "hud.png")
  const MINIMAP_IMAGE_RAW: string = staticRead(".." / ".." / "asset" / "hud" / "minimap.png")
  const ICONS_IMAGE_RAW: string = staticRead(".." / ".." / "asset" / "hud" / "icons.png")
  const CROSSHAIR_IMAGE_RAW: string = staticRead(".." / ".." / "asset" / "hud" / "crosshair.png")
  const HELPPOPUP_IMAGE_RAW: string = staticRead(".." / ".." / "asset" / "hud" / "helppopup.png")
  const VOTING_IMAGE_RAW: string = staticRead(".." / ".." / "asset" / "hud" / "voting.png")
  const KILLMESSAGES_IMAGE_RAW: string = staticRead(".." / ".." / "asset" / "hud" / "killmessages.png")
  const RADIOMESSAGES_IMAGE_RAW: string = staticRead(".." / ".." / "asset" / "hud" / "radiomessages.png")
  const CHATMESSAGES_IMAGE_RAW: string = staticRead(".." / ".." / "asset" / "hud" / "chatmessages.png")
else:
  const BACKGROUND_IMAGE_RAW: string = readFile("asset" / "hud" / "background.png")
  const HUD_IMAGE_RAW: string = readFile("asset" / "hud" / "hud.png")
  const MINIMAP_IMAGE_RAW: string = readFile("asset" / "hud" / "minimap.png")
  const ICONS_IMAGE_RAW: string = readFile("asset" / "hud" / "icons.png")
  const CROSSHAIR_IMAGE_RAW: string = readFile("asset" / "hud" / "crosshair.png")
  const HELPPOPUP_IMAGE_RAW: string = readFile("asset" / "hud" / "helppopup.png")
  const VOTING_IMAGE_RAW: string = readFile("asset" / "hud" / "voting.png")
  const KILLMESSAGES_IMAGE_RAW: string = readFile("asset" / "hud" / "killmessages.png")
  const RADIOMESSAGES_IMAGE_RAW: string = readFile("asset" / "hud" / "radiomessages.png")
  const CHATMESSAGES_IMAGE_RAW: string = readFile("asset" / "hud" / "chatmessages.png")

var windowShown: ptr bool
var ignoreEvents: ptr bool

var generalDirty, general: General
var path0001GeneralCon, pathDefaultGeneralCon: string # Path to General.con file
var isGeneralValid: bool

var cbtnCrosshair: ColorButton
var daHud: DrawingArea
var pixbufBackground: Pixbuf
var pixbufHud: Pixbuf
var pixbufMinimap: Pixbuf
var pixbufIcons: Pixbuf
# var pixbufCrosshair: Pixbuf
var sfCrosshair: Surface
var pixbufHelpPopup: Pixbuf
var pixbufVoting: Pixbuf
var pixbufKillMessages: Pixbuf
var pixbufRadioMessages: Pixbuf
var pixbufChatMessages: Pixbuf

# General
var gridHud: Grid
var scaleHudTransparency: Scale
var scaleMinimapTransparency: Scale
var scaleIconsTransparency: Scale
var switchHelpPopups: Switch
var switchCameraShake: Switch
var switchRotateMinimap: Switch
var switchOptOutOfVoting: Switch
var switchReverseMousewheelSelection: Switch
var switchAutoReloadWeapons: Switch
var switchIgnoreBuddyRequests: Switch
var switchShowKillMessages: Switch
var switchShowRadioMessages: Switch
var switchShowChatMessages: Switch

var btnRevert: Button
var btnSave: Button
var dlgConfigCorrupt: Dialog
var lblConfigCorruptTitle: Label
var viewConfigCorruptBody: View
var btnConfigCorruptYes: Button
var btnConfigCorruptNo: Button


import conparser/exports/markup
proc markupEscapeProc(str: string): string =
  markupEscapeText(str, str.len)
proc markup(report: ConReport): string =
  markup(report, markupEscapeProc)

proc loadGeneral(general: General) =
  cbtnCrosshair.setRgba(gdk.RGBA(
    red: general.crosshairColor.r.float / 255,
    green: general.crosshairColor.g.float / 255,
    blue: general.crosshairColor.b.float / 255,
    alpha: general.crosshairColor.a.float / 255
  ))
  scaleHudTransparency.value = 255 - general.hudTransparency.float
  scaleMinimapTransparency.value = 255 - general.minimapTransparency.float
  scaleIconsTransparency.value =  255 - general.mapIconAlphaTransparency.float
  switchHelpPopups.active = general.helpPopups
  switchCameraShake.active = general.cameraShake
  switchRotateMinimap.active = general.minimapRotate
  switchOptOutOfVoting.active = general.outOfVoting
  switchReverseMousewheelSelection.active = general.reverseMousewheelSelection
  switchAutoReloadWeapons.active = general.autoReload
  switchIgnoreBuddyRequests.active = general.ignoreBuddyRequests
  switchShowKillMessages.active = general.killMessagesFilter
  switchShowRadioMessages.active = general.radioMessagesFilter
  switchShowChatMessages.active = general.chatMessagesFilter

proc updateSaveRevertSensitivity() =
  if isGeneralValid:
    btnSave.sensitive = general != generalDirty
    btnRevert.sensitive = btnSave.sensitive
  else:
    btnSave.sensitive = true
    btnRevert.sensitive = false

proc scaleSettingsHudTransparencyFormatValue(self: ptr Scale00, value: float): cstring {.signalNoCheck.} =
  return g_strdup(cstring($int((value / 255) * 100) & "%"))

proc onScaleSettingsHudHudTransparencyValueChanged(self: ptr Scale00) {.signal.} =
  generalDirty.hudTransparency = 255 - scaleHudTransparency.value.uint8
  updateSaveRevertSensitivity()
  daHud.queueDraw()

proc onScaleSettingsHudMinimapTransparencyValueChanged(self: ptr Scale00) {.signal.} =
  generalDirty.minimapTransparency = 255 - scaleMinimapTransparency.value.uint8
  updateSaveRevertSensitivity()
  daHud.queueDraw()

proc onScaleSettingsHudIconsTransparencyValueChanged(self: ptr Scale00) {.signal.} =
  generalDirty.mapIconAlphaTransparency = 255 - scaleIconsTransparency.value.uint8
  updateSaveRevertSensitivity()
  daHud.queueDraw()

proc onCbtnSettingsHudCrosshairColorSet(self: ptr ColorSelection00) {.signal.} =
  let rgba: gdk.RGBA = cbtnCrosshair.getRgba()
  generalDirty.crosshairColor.r = uint8(rgba.red * 255)
  generalDirty.crosshairColor.g = uint8(rgba.green * 255)
  generalDirty.crosshairColor.b = uint8(rgba.blue * 255)
  generalDirty.crosshairColor.a = uint8(rgba.alpha * 255)
  updateSaveRevertSensitivity()
  daHud.queueDraw()

proc onSwitchSettingsHudHelpPopupsStateSet(self: ptr Switch00, state: bool): bool {.signal.} =
  generalDirty.helpPopups = switchHelpPopups.active
  updateSaveRevertSensitivity()
  daHud.queueDraw()

proc onSwitchSettingsHudCameraShakeStateSet(self: ptr Switch00, state: bool): bool {.signal.} =
  generalDirty.cameraShake = switchCameraShake.active
  updateSaveRevertSensitivity()

proc onSwitchSettingsHudRotateMinimapStateSet(self: ptr Switch00, state: bool): bool {.signal.} =
  generalDirty.minimapRotate = switchRotateMinimap.active
  updateSaveRevertSensitivity()

proc onSwitchSettingsHudOptOutOfVotingStateSet(self: ptr Switch00, state: bool): bool {.signal.} =
  generalDirty.outOfVoting = switchOptOutOfVoting.active
  updateSaveRevertSensitivity()
  daHud.queueDraw()

proc onSwitchSettingsHudReverseMousewheelSelectionStateSet(self: ptr Switch00, state: bool): bool {.signal.} =
  generalDirty.reverseMousewheelSelection = switchReverseMousewheelSelection.active
  updateSaveRevertSensitivity()

proc onSwitchSettingsHudAutoReloadWeaponsStateSet(self: ptr Switch00, state: bool): bool {.signal.} =
  generalDirty.autoReload = switchAutoReloadWeapons.active
  updateSaveRevertSensitivity()

proc onSwitchSettingsHudIgnoreBuddyRequestsStateSet(self: ptr Switch00, state: bool): bool {.signal.} =
  generalDirty.ignoreBuddyRequests = switchIgnoreBuddyRequests.active
  updateSaveRevertSensitivity()

proc onSwitchSettingsHudShowKillMessagesStateSet(self: ptr Switch00, state: bool): bool {.signal.} =
  generalDirty.killMessagesFilter = switchShowKillMessages.active
  updateSaveRevertSensitivity()
  daHud.queueDraw()

proc onSwitchSettingsHudShowRadioMessagesStateSet(self: ptr Switch00, state: bool): bool {.signal.} =
  generalDirty.radioMessagesFilter = switchShowRadioMessages.active
  updateSaveRevertSensitivity()
  daHud.queueDraw()

proc onSwitchSettingsHudShowChatMessagesStateSet(self: ptr Switch00, state: bool): bool {.signal.} =
  generalDirty.chatMessagesFilter = switchShowChatMessages.active
  updateSaveRevertSensitivity()
  daHud.queueDraw()

proc onDaSettingsHudHudDraw(self: ptr DrawingArea00, ctx00: ptr Context00) {.signal.} =
  var ctx: Context = new Context
  ctx.impl = ctx00
  ctx.ignoreFinalizer = true

  var scale: float = min(
    daHud.getAllocatedWidth() / pixbufBackground.getWidth(),
    daHud.getAllocatedHeight() / pixbufBackground.getHeight()
  )
  var offsetX: float = daHud.getAllocatedWidth().float - pixbufBackground.getWidth().float * scale
  if offsetX > 0:
    offsetX /= scale * 2

  ctx.save()
  ctx.scale(scale, scale)

  # Background
  with ctx:
    save()
    cairoSetSourcePixbuf(pixbufBackground, offsetX, 0)
    paint()
    restore()

  # Hud
  with ctx:
    save()
    cairoSetSourcePixbuf(pixbufHud, offsetX, 0)
    paintWithAlpha(1.0 - (scaleHudTransparency.value / 255))
    restore()

  # Minimap
  with ctx:
    save()
    cairoSetSourcePixbuf(pixbufMinimap, offsetX, 0)
    paintWithAlpha(1.0 - (scaleMinimapTransparency.value / 255))
    restore()

  # Icons
  with ctx:
    save()
    cairoSetSourcePixbuf(pixbufIcons, offsetX, 0)
    paintWithAlpha(1.0 - (scaleIconsTransparency.value / 255))
    restore()

  # Crosshair
  let rgba: gdk.RGBA = cbtnCrosshair.getRgba()
  with ctx:
    save()
    setSourceSurface(sfCrosshair, 0, 0)
    setSource(rgba.red, rgba.green, rgba.blue, rgba.alpha)
    maskSurface(sfCrosshair, offsetX, 0)
    restore()

  # Help popups
  if switchHelpPopups.active:
    with ctx:
      save()
      cairoSetSourcePixbuf(pixbufHelpPopup, offsetX, 0)
      # maskSurface(sfHelpPopup, offsetX, 0)
      paint()
      restore()

  # Voting
  if not switchOptOutOfVoting.active:
    with ctx:
      save()
      cairoSetSourcePixbuf(pixbufVoting, offsetX, 0)
      paint()
      restore()

  # Kill messages
  if switchShowKillMessages.active:
    with ctx:
      save()
      cairoSetSourcePixbuf(pixbufKillMessages, offsetX, 0)
      paint()
      restore()

  # Radio messages
  if switchShowRadioMessages.active:
    with ctx:
      save()
      cairoSetSourcePixbuf(pixbufRadioMessages, offsetX, 0)
      paint()
      restore()

  # Chat messages
  if switchShowChatMessages.active:
    with ctx:
      save()
      cairoSetSourcePixbuf(pixbufChatMessages, offsetX, 0)
      paint()
      restore()

  ctx.restore()

proc onBtnSettingsHudSaveClicked(self: ptr Switch00) {.signal.} =
  isGeneralValid = true
  generalDirty.writeCon(path0001GeneralCon)
  generalDirty.writeCon(pathDefaultGeneralCon)
  general = generalDirty
  updateSaveRevertSensitivity()

proc onBtnSettingsHudRevertClicked(self: ptr Switch00) {.signal.} =
  generalDirty = general
  loadGeneral(general)
  updateSaveRevertSensitivity()

proc setDocumentsPath*(documentsPath: string) =
  # TODO: Only required because of linux
  #       Documents path is queried with wine prefix (which may not be set when init proc is called).
  path0001GeneralCon = documentsPath / "Battlefield 2142" / "Profiles" / "0001" / "General.con"
  pathDefaultGeneralCon = documentsPath / "Battlefield 2142" / "Profiles" / "Default" / "General.con"

  var report: ConReport
  (general, report) = readCon[General](path0001GeneralCon)

  isGeneralValid = report.valid
  if not isGeneralValid and report.settingsNotFound.len == 0:
    isGeneralValid = true
    for line in report.invalidLines:
      if line.setting != "GeneralSettings.setPlayedVOHelp" or line.redundant:
        isGeneralValid = false
        break

  if isGeneralValid:
    generalDirty = general
    loadGeneral(general)
  else:
    generalDirty = general

    lblConfigCorruptTitle.text = cstring(dgettext("gui", "SETTINGS_CONFIG_CORRUPT_TITLE") % ["General", "General.con"])
    var iter: TextIter
    let markup: string = markup(report)
    viewConfigCorruptBody.buffer.getEndIter(iter)
    viewConfigCorruptBody.buffer.insertMarkup(iter, cstring(markup), markup.len)

    btnConfigCorruptYes.label = "Fix it!"
    btnConfigCorruptNo.label = "Cancel"

    if dlgConfigCorrupt.run() == ResponseType.yes.int:
      generalDirty.writeCon(path0001GeneralCon)
      generalDirty.writeCon(pathDefaultGeneralCon)
      general = generalDirty
      isGeneralValid = true
    else: # if not accepted
      btnSave.sensitive = true
    dlgConfigCorrupt.hide()
    loadGeneral(generalDirty)
  gridHud.visible = true


proc init*(builder: Builder, windowShownPtr, ignoreEventsPtr: ptr bool) =
  windowShown = windowShownPtr; ignoreEvents = ignoreEventsPtr

  cbtnCrosshair = builder.getColorButton("cbtnSettingsHudCrosshair")
  daHud = builder.getDrawingArea("daSettingsHudHud")
  # sfBackground = imageSurfaceCreateFromPng("asset" / "hud" / "background.png")
  # sfHud = imageSurfaceCreateFromPng("asset" / "hud" / "hud.png")
  # sfMinimap = imageSurfaceCreateFromPng("asset" / "hud" / "minimap.png")
  # sfIcons = imageSurfaceCreateFromPng("asset" / "hud" / "icons.png")
  # sfCrosshair = imageSurfaceCreateFromPng("asset" / "hud" / "crosshair.png")
  # sfHelpPopup = imageSurfaceCreateFromPng("asset" / "hud" / "helppopup.png")
  # sfVoting = imageSurfaceCreateFromPng("asset" / "hud" / "voting.png")
  # sfKillMessages = imageSurfaceCreateFromPng("asset" / "hud" / "killmessages.png")
  # sfRadioMessages = imageSurfaceCreateFromPng("asset" / "hud" / "radiomessages.png")
  # sfChatMessages = imageSurfaceCreateFromPng("asset" / "hud" / "chatmessages.png")


  var loader: PixbufLoader

  loader = newPixbufLoader()
  discard loader.write(BACKGROUND_IMAGE_RAW)
  pixbufBackground = loader.pixbuf
  discard loader.close()

  loader = newPixbufLoader()
  discard loader.write(HUD_IMAGE_RAW)
  pixbufHud = loader.pixbuf
  discard loader.close()

  loader = newPixbufLoader()
  discard loader.write(MINIMAP_IMAGE_RAW)
  pixbufMinimap = loader.pixbuf
  discard loader.close()

  loader = newPixbufLoader()
  discard loader.write(ICONS_IMAGE_RAW)
  pixbufIcons = loader.pixbuf
  discard loader.close()

  loader = newPixbufLoader()
  discard loader.write(CROSSHAIR_IMAGE_RAW)
  sfCrosshair = imageSurfaceCreate(cairo.Format.argb32, loader.pixbuf.width, loader.pixbuf.height)
  var context: Context = newContext(sfCrosshair)
  context.cairoSetSourcePixbuf(loader.pixbuf, 0, 0)
  context.paint()
  discard loader.close()

  loader = newPixbufLoader()
  discard loader.write(HELPPOPUP_IMAGE_RAW)
  pixbufHelpPopup = loader.pixbuf
  discard loader.close()

  loader = newPixbufLoader()
  discard loader.write(VOTING_IMAGE_RAW)
  pixbufVoting = loader.pixbuf
  discard loader.close()

  loader = newPixbufLoader()
  discard loader.write(KILLMESSAGES_IMAGE_RAW)
  pixbufKillMessages = loader.pixbuf
  discard loader.close()

  loader = newPixbufLoader()
  discard loader.write(RADIOMESSAGES_IMAGE_RAW)
  pixbufRadioMessages = loader.pixbuf
  discard loader.close()

  loader = newPixbufLoader()
  discard loader.write(CHATMESSAGES_IMAGE_RAW)
  pixbufChatMessages = loader.pixbuf
  discard loader.close()


  scaleHudTransparency = builder.getScale("scaleSettingsHudHudTransparency")
  scaleMinimapTransparency = builder.getScale("scaleSettingsHudMinimapTransparency")
  scaleIconsTransparency = builder.getScale("scaleSettingsHudIconsTransparency")
  switchHelpPopups = builder.getSwitch("switchSettingsHudHelpPopups")
  switchCameraShake = builder.getSwitch("switchSettingsHudCameraShake")
  switchRotateMinimap = builder.getSwitch("switchSettingsHudRotateMinimap")
  switchOptOutOfVoting = builder.getSwitch("switchSettingsHudOptOutOfVoting")
  switchReverseMousewheelSelection = builder.getSwitch("switchSettingsHudReverseMousewheelSelection")
  switchAutoReloadWeapons = builder.getSwitch("switchSettingsHudAutoReloadWeapons")
  switchIgnoreBuddyRequests = builder.getSwitch("switchSettingsHudIgnoreBuddyRequests")
  switchShowKillMessages = builder.getSwitch("switchSettingsHudShowKillMessages")
  switchShowRadioMessages = builder.getSwitch("switchSettingsHudShowRadioMessages")
  switchShowChatMessages = builder.getSwitch("switchSettingsHudShowChatMessages")

  btnRevert = builder.getButton("btnSettingsHudRevert")
  btnSave = builder.getButton("btnSettingsHudSave")
  dlgConfigCorrupt = builder.getDialog("dlgConfigCorrupt")
  lblConfigCorruptTitle = builder.getLabel("lblConfigCorruptTitle")
  viewConfigCorruptBody = cast[View](getObject(builder, "viewConfigCorruptBody")) # TODO: https://github.com/StefanSalewski/gintro/issues/40
  btnConfigCorruptYes = builder.getButton("btnConfigCorruptYes")
  btnConfigCorruptNo = builder.getButton("btnConfigCorruptNo")

  gridHud = builder.getGrid("gridSettingsHud")
  gridHud.visible = false
