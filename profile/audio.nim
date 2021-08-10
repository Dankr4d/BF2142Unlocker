import conparser
export conparser

type
  LowMediumHigh* {.pure.} = enum
    Low = "\"Low\""
    Medium = "\"Medium\""
    High = "\"High\""
    # UltraHigh # TODO: Is set ingame to the same value as High
  Provider* {.pure.} = enum
    Software = "\"software\""
    Hardware = "\"hardware\""
    # CreativeXFi # TODO: Not used?
  Audio* {.Prefix: "AudioSettings.".} = object
    voipEnabled* {.Setting: "setVoipEnabled", Default: true.}: bool
    voipPlaybackVolume* {.Setting: "setVoipPlaybackVolume", Default: 1.0.}: range[0.0 .. 1.0]
    voipCaptureVolume* {.Setting: "setVoipCaptureVolume", Default: 1.0.}: range[0.0 .. 1.0]
    voipCaptureThreshold* {.Setting: "setVoipCaptureThreshold", Default: 0.1.}: range[0.0 .. 1.0]
    voipBoostEnabled* {.Setting: "setVoipBoostEnabled", Default: false.}: bool # TODO: When changing ingame, it's not set in config.
    voipUsePushToTalk* {.Setting: "setVoipUsePushToTalk", Default: true.}: bool # TODO: It's not possible to set this setting ingame.
    provider* {.Setting: "setProvider", Default: Provider.Software.}: Provider
    soundQuality* {.Setting: "setSoundQuality", Default: LowMediumHigh.Low.}: LowMediumHigh
    effectsVolume* {.Setting: "setEffectsVolume", Default: 1.0.}: range[0.0 .. 1.0]
    musicVolume* {.Setting: "setMusicVolume", Default: 0.5.}: range[0.0 .. 1.0]
    helpVoiceVolume* {.Setting: "setHelpVoiceVolume", Default: 0.5.}: range[0.0 .. 1.0]
    englishOnlyVoices* {.Setting: "setEnglishOnlyVoices", Default: false.}: bool
    enableEax* {.Setting: "setEnableEAX", Default: true.}: bool

