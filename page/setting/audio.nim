import gintro/[gtk, gobject, glib, gtksource]
import "../../macro/signal"
import ../../profile/audio as profileAudio
import os
import strutils

var windowShown: ptr bool
var ignoreEvents: ptr bool

var audioDirty, audio: Audio
var path0001AudioCon, pathDefaultAudioCon: string # Path to Audio.con file
var isAudioValid: bool

var gridAudio: Grid
var scaleRenderer: Scale
var scaleSoundQuality: Scale
var switchEnableEax: Switch
var switchEnglishVoOnly: Switch
var scaleEffects: Scale
var scaleMusic: Scale
var scaleVoiceOver: Scale
var switchVoipEnabled: Switch
var scaleVoipTransmit: Scale
var scaleVoipReceive: Scale
var switchVoipBoostMicGain: Switch
var scaleMicrophoneTresholdTest: Scale
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

proc translate(lowMediumHigh: LowMediumHigh): string =
  case lowMediumHigh:
  of LowMediumHigh.Low:
    return dgettext("gui", "SETTINGS_AUDIO_LOW")
  of LowMediumHigh.Medium:
    return dgettext("gui", "SETTINGS_AUDIO_MEDIUM")
  of LowMediumHigh.High:
    return dgettext("gui", "SETTINGS_AUDIO_HIGH")

proc translate(provider: Provider): string =
  case provider:
  of Provider.Software:
    return dgettext("gui", "SETTINGS_AUDIO_SOFTWARE")
  of Provider.Hardware:
    return dgettext("gui", "SETTINGS_AUDIO_HARDWARE")


proc loadAudio(audio: Audio) =
  scaleRenderer.value = audio.provider.float
  scaleSoundQuality.value = audio.soundQuality.float
  switchEnableEax.active = audio.enableEax
  switchEnglishVoOnly.active = audio.englishOnlyVoices
  scaleEffects.value = audio.effectsVolume
  scaleMusic.value = audio.musicVolume
  scaleVoiceOver.value = audio.helpVoiceVolume
  switchVoipEnabled.active = audio.voipEnabled
  scaleVoipTransmit.value = audio.voipCaptureVolume
  scaleVoipReceive.value = audio.voipPlaybackVolume
  switchVoipBoostMicGain.active = audio.voipBoostEnabled
  scaleMicrophoneTresholdTest.value = audio.voipCaptureThreshold


proc onScaleSettingsAudioRendererFormatValue(self: ptr Scale00, value: float): cstring {.signalNoCheck.} =
  return g_strdup(translate(cast[Provider](value.int)))

proc onScaleSettingsAudioSoundQualityFormatValue(self: ptr Scale00, value: float): cstring {.signalNoCheck.} =
  return g_strdup(translate(cast[LowMediumHigh](value.int)))

proc onScaleSettingsAudioPercentFormatValue(self: ptr Scale00, value: float): cstring {.signalNoCheck.} =
  return g_strdup($(int(value * 100)) & "%")


proc updateSaveRevertSensitivity() =
  if isAudioValid:
    btnSave.sensitive = audio != audioDirty
    btnRevert.sensitive = btnSave.sensitive
  else:
    btnSave.sensitive = true
    btnRevert.sensitive = false


proc onScaleSettingsAudioRendererValueChanged(self: ptr Scale00) {.signal.} =
  audioDirty.provider = cast[Provider](scaleRenderer.value.int)
  updateSaveRevertSensitivity()

proc onScaleSettingsAudioSoundQualityValueChanged(self: ptr Scale00) {.signal.} =
  audioDirty.soundQuality = cast[LowMediumHigh](scaleSoundQuality.value.int)
  updateSaveRevertSensitivity()

proc onScaleSettingsAudioEffectsValueChanged(self: ptr Scale00) {.signal.} =
  audioDirty.effectsVolume = scaleEffects.value
  updateSaveRevertSensitivity()

proc onScaleSettingsAudioMusicValueChanged(self: ptr Scale00) {.signal.} =
  audioDirty.musicVolume = scaleMusic.value
  updateSaveRevertSensitivity()

proc onScaleSettingsAudioVoiceOverValueChanged(self: ptr Scale00) {.signal.} =
  audioDirty.helpVoiceVolume = scaleVoiceOver.value
  updateSaveRevertSensitivity()

proc onScaleSettingsAudioVoipTransmitValueChanged(self: ptr Scale00) {.signal.} =
  audioDirty.voipCaptureVolume = scaleVoipTransmit.value
  updateSaveRevertSensitivity()

proc onScaleSettingsAudioVoipReceiveValueChanged(self: ptr Scale00) {.signal.} =
  audioDirty.voipPlaybackVolume = scaleVoipReceive.value
  updateSaveRevertSensitivity()

proc onSwitchSettingsAudioEnableEaxStateSet(self: ptr Switch00) {.signal.} =
  audioDirty.enableEax = switchEnableEax.active
  updateSaveRevertSensitivity()

proc onSwitchSettingsAudioEnglishVoOnlyStateSet(self: ptr Switch00) {.signal.} =
  audioDirty.englishOnlyVoices = switchEnglishVoOnly.active
  updateSaveRevertSensitivity()

proc onSwitchSettingsAudioVoipEnabledStateSet(self: ptr Switch00) {.signal.} =
  audioDirty.voipEnabled = switchVoipEnabled.active
  updateSaveRevertSensitivity()

proc onSwitchSettingsAudioVoipBoostMicGainStateSet(self: ptr Switch00) {.signal.} =
  audioDirty.voipBoostEnabled = switchVoipBoostMicGain.active
  updateSaveRevertSensitivity()

proc onScaleSettingsAudioMicrophoneTresholdTestValueChanged(self: ptr Switch00) {.signal.} =
  audioDirty.voipCaptureThreshold = scaleMicrophoneTresholdTest.value
  updateSaveRevertSensitivity()


proc onBtnSettingsAudioSaveClicked(self: ptr Switch00) {.signal.} =
  isAudioValid = true
  audioDirty.writeCon(path0001AudioCon)
  audioDirty.writeCon(pathDefaultAudioCon)
  audio = audioDirty
  updateSaveRevertSensitivity()

proc onBtnSettingsAudioRevertClicked(self: ptr Switch00) {.signal.} =
  audioDirty = audio
  loadAudio(audio)
  updateSaveRevertSensitivity()


proc setDocumentsPath*(documentsPath: string) =
  # TODO: Only required because of linux
  #       Documents path is queried with wine prefix (which may not be set when init proc is called).
  path0001AudioCon = documentsPath / "Battlefield 2142" / "Profiles" / "0001" / "Audio.con"
  pathDefaultAudioCon = documentsPath / "Battlefield 2142" / "Profiles" / "Default" / "Audio.con"

  var report: ConReport
  (audio, report) = readCon[Audio](path0001AudioCon)

  isAudioValid = report.valid

  if isAudioValid:
    audioDirty = audio
    loadAudio(audio)
  else:
    audioDirty = audio

    lblConfigCorruptTitle.text = dgettext("gui", "SETTINGS_CONFIG_CORRUPT_TITLE") % ["Audio", "Audio.con"]
    var iter: TextIter
    let markup: string = markup(report)
    viewConfigCorruptBody.buffer.getEndIter(iter)
    viewConfigCorruptBody.buffer.insertMarkup(iter, markup, markup.len)

    btnConfigCorruptYes.label = "Fix it!"
    btnConfigCorruptNo.label = "Cancel"

    if dlgConfigCorrupt.run() == ResponseType.yes.int:
      audioDirty.writeCon(path0001AudioCon)
      audioDirty.writeCon(pathDefaultAudioCon)
      audio = audioDirty
      isAudioValid = true
    else: # if not accepted
      btnSave.sensitive = true
    dlgConfigCorrupt.hide()
    loadAudio(audioDirty)
  gridAudio.visible = true


proc init*(builder: Builder, windowShownPtr, ignoreEventsPtr: ptr bool) =
  windowShown = windowShownPtr; ignoreEvents = ignoreEventsPtr
  scaleRenderer = builder.getScale("scaleSettingsAudioRenderer")
  scaleSoundQuality = builder.getScale("scaleSettingsAudioSoundQuality")
  switchEnableEax = builder.getSwitch("switchSettingsAudioEnableEax")
  switchEnglishVoOnly = builder.getSwitch("switchSettingsAudioEnglishVoOnly")
  scaleEffects = builder.getScale("scaleSettingsAudioEffects")
  scaleMusic = builder.getScale("scaleSettingsAudioMusic")
  scaleVoiceOver = builder.getScale("scaleSettingsAudioVoiceOver")
  switchVoipEnabled = builder.getSwitch("switchSettingsAudioVoipEnabled")
  scaleVoipTransmit = builder.getScale("scaleSettingsAudioVoipTransmit")
  scaleVoipReceive = builder.getScale("scaleSettingsAudioVoipReceive")
  switchVoipBoostMicGain = builder.getSwitch("switchSettingsAudioVoipBoostMicGain")
  scaleMicrophoneTresholdTest = builder.getScale("scaleSettingsAudioMicrophoneTresholdTest")
  btnRevert = builder.getButton("btnSettingsAudioRevert")
  btnSave = builder.getButton("btnSettingsAudioSave")
  dlgConfigCorrupt = builder.getDialog("dlgConfigCorrupt")
  lblConfigCorruptTitle = builder.getLabel("lblConfigCorruptTitle")
  viewConfigCorruptBody = cast[View](getObject(builder, "viewConfigCorruptBody")) # TODO: https://github.com/StefanSalewski/gintro/issues/40
  btnConfigCorruptYes = builder.getButton("btnConfigCorruptYes")
  btnConfigCorruptNo = builder.getButton("btnConfigCorruptNo")
  gridAudio = builder.getGrid("gridSettingsAudio")
  gridAudio.visible = false
