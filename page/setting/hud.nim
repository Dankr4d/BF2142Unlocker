import gintro/[gtk, gobject, glib, gtksource, cairo, gdk]
import "../../macro/signal"
import ../../profile/general as profileGeneral
import os
import strutils
import std/with


var windowShown: ptr bool
var ignoreEvents: ptr bool

var generalDirty, general: General
var path0001GeneralCon, pathDefaultGeneralCon: string # Path to General.con file
var isGeneralValid: bool

var cbtnCrosshair: ColorButton
var daCrosshair: DrawingArea
var sfBackground: Surface
var sfHud: Surface
var sfMinimap: Surface
var sfIcons: Surface
var sfCrosshair: Surface
var sfHelpPopup: Surface
var sfVoting: Surface
var sfKillMessages: Surface
var sfRadioMessages: Surface
var sfChatMessages: Surface

# General
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

proc scaleSettingsGeneralTransparencyFormatValue(self: ptr Scale00, value: float): cstring {.signalNoCheck.} =
  return g_strdup($int((value / 255) * 100) & "%")

proc onScaleSettingsGeneralHudTransparencyValueChanged(self: ptr Scale00) {.signal.} =
  generalDirty.hudTransparency = 255 - scaleHudTransparency.value.uint8
  updateSaveRevertSensitivity()
  daCrosshair.queueDraw()

proc onScaleSettingsGeneralMinimapTransparencyValueChanged(self: ptr Scale00) {.signal.} =
  generalDirty.minimapTransparency = 255 - scaleMinimapTransparency.value.uint8
  updateSaveRevertSensitivity()
  daCrosshair.queueDraw()

proc onScaleSettingsGeneralIconsTransparencyValueChanged(self: ptr Scale00) {.signal.} =
  generalDirty.mapIconAlphaTransparency = 255 - scaleIconsTransparency.value.uint8
  updateSaveRevertSensitivity()
  daCrosshair.queueDraw()

proc onCcSettingsGeneralCrosshairRgbaNotify(self: ptr ColorSelection00) {.signal.} =
  let rgba: gdk.RGBA = cbtnCrosshair.getRgba()
  generalDirty.crosshairColor.r = uint8(rgba.red * 255)
  generalDirty.crosshairColor.g = uint8(rgba.green * 255)
  generalDirty.crosshairColor.b = uint8(rgba.blue * 255)
  generalDirty.crosshairColor.a = uint8(rgba.alpha * 255)
  updateSaveRevertSensitivity()
  daCrosshair.queueDraw()

proc onSwitchSettingsGeneralHelpPopupsStateSet(self: ptr Switch00) {.signal.} =
  generalDirty.helpPopups = switchHelpPopups.active
  updateSaveRevertSensitivity()
  daCrosshair.queueDraw()

proc onSwitchSettingsGeneralCameraShakeStateSet(self: ptr Switch00) {.signal.} =
  generalDirty.cameraShake = switchCameraShake.active
  updateSaveRevertSensitivity()

proc onSwitchSettingsGeneralRotateMinimapStateSet(self: ptr Switch00) {.signal.} =
  generalDirty.minimapRotate = switchRotateMinimap.active
  updateSaveRevertSensitivity()

proc onSwitchSettingsGeneralOptOutOfVotingStateSet(self: ptr Switch00) {.signal.} =
  generalDirty.outOfVoting = switchOptOutOfVoting.active
  updateSaveRevertSensitivity()
  daCrosshair.queueDraw()

proc onSwitchSettingsGeneralReverseMousewheelSelectionStateSet(self: ptr Switch00) {.signal.} =
  generalDirty.reverseMousewheelSelection = switchReverseMousewheelSelection.active
  updateSaveRevertSensitivity()

proc onSwitchSettingsGeneralAutoReloadWeaponsStateSet(self: ptr Switch00) {.signal.} =
  generalDirty.autoReload = switchAutoReloadWeapons.active
  updateSaveRevertSensitivity()

proc onSwitchSettingsGeneralIgnoreBuddyRequestsStateSet(self: ptr Switch00) {.signal.} =
  generalDirty.ignoreBuddyRequests = switchIgnoreBuddyRequests.active
  updateSaveRevertSensitivity()

proc onSwitchSettingsGeneralShowKillMessagesStateSet(self: ptr Switch00) {.signal.} =
  generalDirty.killMessagesFilter = switchShowKillMessages.active
  updateSaveRevertSensitivity()
  daCrosshair.queueDraw()

proc onSwitchSettingsGeneralShowRadioMessagesStateSet(self: ptr Switch00) {.signal.} =
  generalDirty.radioMessagesFilter = switchShowRadioMessages.active
  updateSaveRevertSensitivity()
  daCrosshair.queueDraw()

proc onSwitchSettingsGeneralShowChatMessagesStateSet(self: ptr Switch00) {.signal.} =
  generalDirty.chatMessagesFilter = switchShowChatMessages.active
  updateSaveRevertSensitivity()
  daCrosshair.queueDraw()

proc onDaSettingsGeneralCrosshairDraw(self: ptr DrawingArea00, ctx00: ptr Context00) {.signal.} =
  var ctx: Context = new Context
  ctx.impl = ctx00
  ctx.ignoreFinalizer = true

  var scale: float = daCrosshair.getAllocatedWidth() / sfBackground.imageSurfaceGetWidth
  scale = min(scale, daCrosshair.getAllocatedHeight() / sfBackground.imageSurfaceGetHeight)
  var offsetX: float = daCrosshair.getAllocatedWidth().float - sfBackground.imageSurfaceGetWidth.float * scale
  if offsetX > 0:
    offsetX /= scale * 2
  else:
    offsetX = 0

  ctx.save()
  ctx.scale(scale, scale)

  # Background
  with ctx:
    save()
    setSourceSurface(sfBackground, offsetX, 0)
    paint()
    restore()

  # Hud
  with ctx:
    save()
    setSourceSurface(sfHud, offsetX, 0)
    paintWithAlpha(1.0 - (scaleHudTransparency.value / 255))
    restore()

  # Minimap
  with ctx:
    save()
    setSourceSurface(sfMinimap, offsetX, 0)
    paintWithAlpha(1.0 - (scaleMinimapTransparency.value / 255))
    restore()

  # Icons
  with ctx:
    save()
    setSourceSurface(sfIcons, offsetX, 0)
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
      setSourceSurface(sfHelpPopup, offsetX, 0)
      maskSurface(sfHelpPopup, offsetX, 0)
      restore()

  # Voting
  if not switchOptOutOfVoting.active:
    with ctx:
      save()
      setSourceSurface(sfVoting, offsetX, 0)
      maskSurface(sfVoting, offsetX, 0)
      restore()

  # Kill messages
  if switchShowKillMessages.active:
    with ctx:
      save()
      setSourceSurface(sfKillMessages, offsetX, 0)
      maskSurface(sfKillMessages, offsetX, 0)
      restore()

  # Radio messages
  if switchShowRadioMessages.active:
    with ctx:
      save()
      setSourceSurface(sfRadioMessages, offsetX, 0)
      maskSurface(sfRadioMessages, offsetX, 0)
      restore()

  # Chat messages
  if switchShowChatMessages.active:
    with ctx:
      save()
      setSourceSurface(sfChatMessages, offsetX, 0)
      maskSurface(sfChatMessages, offsetX, 0)
      restore()

  ctx.restore()

proc onBtnSettingsGeneralSaveClicked(self: ptr Switch00) {.signal.} =
  isGeneralValid = true
  generalDirty.writeCon(path0001GeneralCon)
  generalDirty.writeCon(pathDefaultGeneralCon)
  general = generalDirty
  updateSaveRevertSensitivity()

proc onBtnSettingsGeneralRevertClicked(self: ptr Switch00) {.signal.} =
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

    lblConfigCorruptTitle.text = dgettext("gui", "SETTINGS_CONFIG_CORRUPT_TITLE") % ["General", "General.con"]
    var iter: TextIter
    let markup: string = markup(report)
    viewConfigCorruptBody.buffer.getEndIter(iter)
    viewConfigCorruptBody.buffer.insertMarkup(iter, markup, markup.len)

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


proc init*(builder: Builder, windowShownPtr, ignoreEventsPtr: ptr bool) =
  windowShown = windowShownPtr; ignoreEvents = ignoreEventsPtr

  cbtnCrosshair = builder.getColorButton("cbtnSettingsGeneralCrosshair")
  daCrosshair = builder.getDrawingArea("daSettingsGeneralCrosshair")
  sfBackground = imageSurfaceCreateFromPng("asset" / "hud" / "background.png")
  sfHud = imageSurfaceCreateFromPng("asset" / "hud" / "hud_edited.png")
  sfMinimap = imageSurfaceCreateFromPng("asset" / "hud" / "minimap_edited.png")
  sfIcons = imageSurfaceCreateFromPng("asset" / "hud" / "icons_edited.png")
  sfCrosshair = imageSurfaceCreateFromPng("asset" / "hud" / "crosshair_edited.png")
  sfHelpPopup = imageSurfaceCreateFromPng("asset" / "hud" / "helppopup_edited.png")
  sfVoting = imageSurfaceCreateFromPng("asset" / "hud" / "voting_edited.png")
  sfKillMessages = imageSurfaceCreateFromPng("asset" / "hud" / "killmessages_edited.png")
  sfRadioMessages = imageSurfaceCreateFromPng("asset" / "hud" / "radiomessages_edited.png")
  sfChatMessages = imageSurfaceCreateFromPng("asset" / "hud" / "chatmessages_edited.png")

  scaleHudTransparency = builder.getScale("scaleSettingsGeneralHudTransparency")
  scaleMinimapTransparency = builder.getScale("scaleSettingsGeneralMinimapTransparency")
  scaleIconsTransparency = builder.getScale("scaleSettingsGeneralIconsTransparency")
  switchHelpPopups = builder.getSwitch("switchSettingsGeneralHelpPopups")
  switchCameraShake = builder.getSwitch("switchSettingsGeneralCameraShake")
  switchRotateMinimap = builder.getSwitch("switchSettingsGeneralRotateMinimap")
  switchOptOutOfVoting = builder.getSwitch("switchSettingsGeneralOptOutOfVoting")
  switchReverseMousewheelSelection = builder.getSwitch("switchSettingsGeneralReverseMousewheelSelection")
  switchAutoReloadWeapons = builder.getSwitch("switchSettingsGeneralAutoReloadWeapons")
  switchIgnoreBuddyRequests = builder.getSwitch("switchSettingsGeneralIgnoreBuddyRequests")
  switchShowKillMessages = builder.getSwitch("switchSettingsGeneralShowKillMessages")
  switchShowRadioMessages = builder.getSwitch("switchSettingsGeneralShowRadioMessages")
  switchShowChatMessages = builder.getSwitch("switchSettingsGeneralShowChatMessages")

  btnRevert = builder.getButton("btnSettingsGeneralRevert")
  btnSave = builder.getButton("btnSettingsGeneralSave")
  dlgConfigCorrupt = builder.getDialog("dlgConfigCorrupt")
  lblConfigCorruptTitle = builder.getLabel("lblConfigCorruptTitle")
  viewConfigCorruptBody = cast[View](getObject(builder, "viewConfigCorruptBody")) # TODO: https://github.com/StefanSalewski/gintro/issues/40
  btnConfigCorruptYes = builder.getButton("btnConfigCorruptYes")
  btnConfigCorruptNo = builder.getButton("btnConfigCorruptNo")
