import conparser
export conparser

type
  Device {.pure.} = enum
    All = "IDFAll"
    Falcon = "IDFFalcon"
    GameController_0 = "IDFGameController_0"
    GameController_1 = "IDFGameController_1"
    GameController_2 = "IDFGameController_2"
    GameController_3 = "IDFGameController_3"
    GameController_4 = "IDFGameController_4"
    GameController_5 = "IDFGameController_5"
    GameController_6 = "IDFGameController_6"
    GameController_7 = "IDFGameController_7"
    Keyboard = "IDFKeyboard"
    Mouse = "IDFMouse"
    None = "IDFNone"
  Key = enum
    Key0 = "IDKey_0"
    Key1 = "IDKey_1"
    Key2 = "IDKey_2"
    Key3 = "IDKey_3"
    Key4 = "IDKey_4"
    Key5 = "IDKey_5"
    Key6 = "IDKey_6"
    Key7 = "IDKey_7"
    Key8 = "IDKey_8"
    Key9 = "IDKey_9"
    KeyA = "IDKey_A"
    KeyAdd = "IDKey_Add"
    KeyApostrophe = "IDKey_Apostrophe"
    KeyAppMenu = "IDKey_AppMenu"
    KeyArrowDown = "IDKey_ArrowDown"
    KeyArrowLeft = "IDKey_ArrowLeft"
    KeyArrowRight = "IDKey_ArrowRight"
    KeyArrowUp = "IDKey_ArrowUp"
    KeyAt = "IDKey_At"
    KeyAx = "IDKey_Ax"
    KeyB = "IDKey_B"
    KeyBackslash = "IDKey_Backslash"
    KeyBackspace = "IDKey_Backspace"
    KeyC = "IDKey_C"
    KeyCalculator = "IDKey_Calculator"
    KeyCapital = "IDKey_Capital"
    KeyColon = "IDKey_Colon"
    KeyComma = "IDKey_Comma"
    KeyConvert = "IDKey_Convert"
    KeyD = "IDKey_D"
    KeyDecimal = "IDKey_Decimal"
    KeyDelete = "IDKey_Delete"
    KeyDivide = "IDKey_Divide"
    KeyE = "IDKey_E"
    KeyEnd = "IDKey_End"
    KeyEnter = "IDKey_Enter"
    KeyEquals = "IDKey_Equals"
    KeyEscape = "IDKey_Escape"
    KeyF = "IDKey_F"
    KeyF1 = "IDKey_F1"
    KeyF10 = "IDKey_F10"
    KeyF11 = "IDKey_F11"
    KeyF12 = "IDKey_F12"
    KeyF13 = "IDKey_F13"
    KeyF14 = "IDKey_F14"
    KeyF15 = "IDKey_F15"
    KeyF2 = "IDKey_F2"
    KeyF3 = "IDKey_F3"
    KeyF4 = "IDKey_F4"
    KeyF5 = "IDKey_F5"
    KeyF6 = "IDKey_F6"
    KeyF7 = "IDKey_F7"
    KeyF8 = "IDKey_F8"
    KeyF9 = "IDKey_F9"
    KeyG = "IDKey_G"
    KeyGrave = "IDKey_Grave"
    KeyH = "IDKey_H"
    KeyHome = "IDKey_Home"
    KeyI = "IDKey_I"
    KeyInsert = "IDKey_Insert"
    KeyJ = "IDKey_J"
    KeyK = "IDKey_K"
    KeyKana = "IDKey_Kana"
    KeyKanji = "IDKey_Kanji"
    KeyL = "IDKey_L"
    KeyLeftAlt = "IDKey_LeftAlt"
    KeyLeftBracket = "IDKey_LeftBracket"
    KeyLeftCtrl = "IDKey_LeftCtrl"
    KeyLeftShift = "IDKey_LeftShift"
    KeyLeftWin = "IDKey_LeftWin"
    KeyM = "IDKey_M"
    KeyMail = "IDKey_Mail"
    KeyMediaSelect = "IDKey_MediaSelect"
    KeyMediaStop = "IDKey_MediaStop"
    KeyMinus = "IDKey_Minus"
    KeyMultiply = "IDKey_Multiply"
    KeyMute = "IDKey_Mute"
    KeyMyComputer = "IDKey_MyComputer"
    KeyN = "IDKey_N"
    KeyNextTrack = "IDKey_NextTrack"
    KeyNoConvert = "IDKey_NoConvert"
    KeyNumlock = "IDKey_Numlock"
    KeyNumpad0 = "IDKey_Numpad0"
    KeyNumpad1 = "IDKey_Numpad1"
    KeyNumpad2 = "IDKey_Numpad2"
    KeyNumpad3 = "IDKey_Numpad3"
    KeyNumpad4 = "IDKey_Numpad4"
    KeyNumpad5 = "IDKey_Numpad5"
    KeyNumpad6 = "IDKey_Numpad6"
    KeyNumpad7 = "IDKey_Numpad7"
    KeyNumpad8 = "IDKey_Numpad8"
    KeyNumpad9 = "IDKey_Numpad9"
    KeyNumpadComma = "IDKey_NumpadComma"
    KeyNumpadEnter = "IDKey_NumpadEnter"
    KeyNumpadEquals = "IDKey_NumpadEquals"
    KeyO = "IDKey_O"
    KeyOEM_102 = "IDKey_OEM_102"
    KeyP = "IDKey_P"
    KeyPageDown = "IDKey_PageDown"
    KeyPageUp = "IDKey_PageUp"
    KeyPause = "IDKey_Pause"
    KeyPeriod = "IDKey_Period"
    KeyPlayPause = "IDKey_PlayPause"
    KeyPower = "IDKey_Power"
    KeyPrevTrack = "IDKey_PrevTrack"
    KeyPrintScreen = "IDKey_PrintScreen"
    KeyQ = "IDKey_Q"
    KeyR = "IDKey_R"
    KeyRightAlt = "IDKey_RightAlt"
    KeyRightBracket = "IDKey_RightBracket"
    KeyRightCtrl = "IDKey_RightCtrl"
    KeyRightShift = "IDKey_RightShift"
    KeyRightWin = "IDKey_RightWin"
    KeyS = "IDKey_S"
    KeyScrollLock = "IDKey_ScrollLock"
    KeySemicolon = "IDKey_Semicolon"
    KeySlash = "IDKey_Slash"
    KeySleep = "IDKey_Sleep"
    KeySpace = "IDKey_Space"
    KeyStop = "IDKey_Stop"
    KeySubtract = "IDKey_Subtract"
    KeyT = "IDKey_T"
    KeyTab = "IDKey_Tab"
    KeyU = "IDKey_U"
    KeyUnderline = "IDKey_Underline"
    KeyUnknown = "IDKey_Unknown"
    KeyUnlabeled = "IDKey_Unlabeled"
    KeyV = "IDKey_V"
    KeyVolumeDown = "IDKey_VolumeDown"
    KeyVolumeUp = "IDKey_VolumeUp"
    KeyW = "IDKey_W"
    KeyWake = "IDKey_Wake"
    KeyWebBack = "IDKey_WebBack"
    KeyWebFavorites = "IDKey_WebFavorites"
    KeyWebForward = "IDKey_WebForward"
    KeyWebHome = "IDKey_WebHome"
    KeyWebRefresh = "IDKey_WebRefresh"
    KeyWebSearch = "IDKey_WebSearch"
    KeyWebStop = "IDKey_WebStop"
    KeyX = "IDKey_X"
    KeyY = "IDKey_Y"
    KeyYen = "IDKey_Yen"
    KeyZ = "IDKey_Z"
  Mouse = enum
    MouseAxisNone = "IDAxis_None"
    MouseAxis0 = "IDAxis_0"
    MouseAxis1 = "IDAxis_1"
    MouseAxis2 = "IDAxis_2"
    MouseAxis3 = "IDAxis_3"
    MouseAxis4 = "IDAxis_4"
    MouseAxis5 = "IDAxis_5"
    MouseAxis6 = "IDAxis_6"
    MouseAxis7 = "IDAxis_7"
    MouseAxis8 = "IDAxis_8"
    MouseAxis9 = "IDAxis_9"
    MouseAxis10 = "IDAxis_10"
    MouseAxis11 = "IDAxis_11"
    MouseAxis12 = "IDAxis_12"
    MouseAxis13 = "IDAxis_13"
    MouseAxis14 = "IDAxis_14"
    MouseButton0 = "IDButton_0"
    MouseButton1 = "IDButton_1"
    MouseButton2 = "IDButton_2"
    MouseButton3 = "IDButton_3"
    MouseButton4 = "IDButton_4"
    MouseButton5 = "IDButton_5"
    MouseButton6 = "IDButton_6"
    MouseButton7 = "IDButton_7"
    MouseButton8 = "IDButton_8"
    MouseButton9 = "IDButton_9"
    MouseButton10 = "IDButton_10"
    MouseButton11 = "IDButton_11"
    MouseButton12 = "IDButton_12"
    MouseButton13 = "IDButton_13"
    MouseButton14 = "IDButton_14"
    MouseButton15 = "IDButton_15"
    MouseButton16 = "IDButton_16"
    MouseButton17 = "IDButton_17"
    MouseButton18 = "IDButton_18"
    MouseButton19 = "IDButton_19"
    MouseButton20 = "IDButton_20"
    MouseButton21 = "IDButton_21"
    MouseButton22 = "IDButton_22"
    MouseButton23 = "IDButton_23"
    MouseButton24 = "IDButton_24"
    MouseButton25 = "IDButton_25"
    MouseButton26 = "IDButton_26"
    MouseButton27 = "IDButton_27"
    MouseButton28 = "IDButton_28"
    MouseButton29 = "IDButton_29"
    MouseButton30 = "IDButton_30"
    MouseButton31 = "IDButton_31"
  PAction {.pure.} = enum # Player Action
    ToggleFireRate = "c_PIToggleFireRate"
    ToggleWeapon = "c_PIToggleWeapon"
    SelectSecWeapon = "c_PISelectSecWeapon"
    SelectPrimWeapon = "c_PISelectPrimWeapon"
    SayTeam = "c_PISayTeam"
    SayAll = "c_PISayAll"
    ToolTip = "c_PIToolTip"
    ScreenShot = "c_PIScreenShot"
    Radio8 = "c_PIRadio8"
    Radio7 = "c_PIRadio7"
    Radio6 = "c_PIRadio6"
    Radio5 = "c_PIRadio5"
    Radio4 = "c_PIRadio4"
    Radio3 = "c_PIRadio3"
    Radio2 = "c_PIRadio2"
    Radio1 = "c_PIRadio1"
    PositionSelect8 = "c_PIPositionSelect8"
    PositionSelect7 = "c_PIPositionSelect7"
    PositionSelect6 = "c_PIPositionSelect6"
    PositionSelect5 = "c_PIPositionSelect5"
    PositionSelect4 = "c_PIPositionSelect4"
    PositionSelect3 = "c_PIPositionSelect3"
    PositionSelect2 = "c_PIPositionSelect2"
    PositionSelect1 = "c_PIPositionSelect1"
    WeaponSelect9 = "c_PIWeaponSelect9"
    WeaponSelect8 = "c_PIWeaponSelect8"
    WeaponSelect7 = "c_PIWeaponSelect7"
    WeaponSelect6 = "c_PIWeaponSelect6"
    WeaponSelect5 = "c_PIWeaponSelect5"
    WeaponSelect4 = "c_PIWeaponSelect4"
    WeaponSelect3 = "c_PIWeaponSelect3"
    WeaponSelect2 = "c_PIWeaponSelect2"
    WeaponSelect1 = "c_PIWeaponSelect1"
    None = "c_PINone"
    ToggleCamera = "c_PIToggleCamera"
    CameraMode4 = "c_PICameraMode4"
    CameraMode3 = "c_PICameraMode3"
    CameraMode2 = "c_PICameraMode2"
    CameraMode1 = "c_PICameraMode1"
    ToggleCameraMode = "c_PIToggleCameraMode"
    Sprint = "c_PISprint"
    AltSprint = "c_PIAltSprint"
    Communication = "c_PICommunication"
    PrevItem = "c_PIPrevItem"
    NextItem = "c_PINextItem"
    Drop = "c_PIDrop"
    MouseLook = "c_PIMouseLook"
    Use = "c_PIUse"
    Action = "c_PIAction"
    SelectFunc = "c_PISelectFunc"
    Reload = "c_PIReload"
    FlareFire = "c_PIFlareFire"
    AltFire = "c_PIAltFire"
    Fire = "c_PIFire"
    NumInput = "c_PINumInput"
    CameraY = "c_PICameraY"
    CameraX = "c_PICameraX"
    MouseLookY = "c_PIMouseLookY"
    MouseLookX = "c_PIMouseLookX"
    Throttle = "c_PIThrottle"
    Roll = "c_PIRoll"
    Pitch = "c_PIPitch"
    Yaw = "c_PIYaw"
    Crouch = "c_PICrouch"
    Lie = "c_PILie"
    ShowScoreBoard = "c_PIShowScoreBoard"
    MinusOne = "-1" # TODO: Maybe use Options?
  GAction {.pure.} = enum # Game Action
    None = "c_GINone"
    ToggleFreeCamera = "c_GIToggleFreeCamera"
    ShowUnlock = "c_GIShowUnlock"
    Leader = "c_GILeader"
    SelectAll = "c_GISelectAll"
    DeselectAll = "c_GIDeselectAll"
    ShowScoreboard = "c_GIShowScoreboard"
    HotRankUp = "c_GIHotRankUp"
    SelectSquad = "c_GISelectSquad"
    JoinSquad = "c_GIJoinSquad"
    CreateSquad = "c_GICreateSquad"
    AutoAccept = "c_GIAutoAccept"
    No = "c_GINo"
    Yes = "c_GIYes"
    ThreeDMap = "c_GI3dMap" # TODO
    # 3dMap = "c_GI3dMap" # TODO
    MapSize = "c_GIMapSize"
    MapZoom = "c_GIMapZoom"
    RadioComm = "c_GIRadioComm"
    TacticalComm = "c_GITacticalComm"
    TogglePause = "c_GITogglePause"
    ScreenShot = "c_GIScreenShot"
    VoipUseLeaderChannel = "c_GIVoipUseLeaderChannel"
    VoipPushToTalk = "c_GIVoipPushToTalk"
    SaySquad = "c_GISaySquad"
    SayTeam = "c_GISayTeam"
    SayAll = "c_GISayAll"
    MouseWheelUp = "c_GIMouseWheelUp"
    MouseWheelDown = "c_GIMouseWheelDown"
    MouseLookY = "c_GIMouseLookY"
    MouseLookX = "c_GIMouseLookX"
    Quit = "c_GIQuit"
    MenuSelect9 = "c_GIMenuSelect9"
    MenuSelect8 = "c_GIMenuSelect8"
    MenuSelect7 = "c_GIMenuSelect7"
    MenuSelect6 = "c_GIMenuSelect6"
    MenuSelect5 = "c_GIMenuSelect5"
    MenuSelect4 = "c_GIMenuSelect4"
    MenuSelect3 = "c_GIMenuSelect3"
    MenuSelect2 = "c_GIMenuSelect2"
    MenuSelect1 = "c_GIMenuSelect1"
    MenuSelect0 = "c_GIMenuSelect0"
    Cancel = "c_GICancel"
    Enter = "c_GIEnter"
    Tab = "c_GITab"
    AltOk = "c_GIAltOk"
    Ok = "c_GIOk"
    RightAlt = "c_GIRightAlt"
    LeftAlt = "c_GILeftAlt"
    RightCtrl = "c_GIRightCtrl"
    LeftCtrl = "c_GILeftCtrl"
    LeftShift = "c_GILeftShift"
    RightShift = "c_GIRightShift"
    PageDown = "c_GIPageDown"
    PageUp = "c_GIPageUp"
    Back = "c_GIBack"
    Delete = "c_GIDelete"
    Right = "c_GIRight"
    Left = "c_GILeft"
    Down = "c_GIDown"
    Up = "c_GIUp"
    Escape = "c_GIEscape"
    ToggleConsole = "c_GIToggleConsole"
    Menu = "c_GIMenu"
    MinusOne = "-1" # TODO: Maybe use Options?


type
  KeysToAxis*[T] = object of RootObj
    action*: T # c_PIYaw, c_PIThrottle, c_PIFire, ...
    device*: Device # IDFKeyboard, IDFMouse
    key1*: Key # IDKey_D, ...
    key2*: Key # IDKey_A, ...
    secondary {.Valid: Bools01, Default: false}: bool
  ButtonToTrigger*[T] = object of RootObj
    action*: T # c_PIYaw, c_PIThrottle, c_PIFire, ...
    device*: Device
    mouse*: Mouse
    num*: uint
    secondary {.Valid: Bools01, Default: false}: bool
  AxisToAxis*[T] = object of ButtonToTrigger[T]
  KeyToTrigger*[T] = object of RootObj
    action*: T # c_PIYaw, c_PIThrottle, c_PIFire, ...
    device*: Device
    key*: Key
    num*: uint
    secondary {.Valid: Bools01, Default: false}: bool
  AxisToTrigger*[T] = object of RootObj
    action1*: T # c_GIMouseWheelUp, -1 <-- Action or -1
    action2*: T #  # -1, c_GIMouseWheelDown <-- Action or -1
    device*: Device
    mouse*: Mouse
    secondary {.Valid: Bools01, Default: false}: bool
  BaseControls*[T] {.Prefix: "ControlMap.".} = object of RootObj
    keysToAxis* {.Setting: "addKeysToAxisMapping", Format: "[action] [device] [key1] [key2] [secondary]".}: seq[KeysToAxis[T]]
    buttonToTrigger* {.Setting: "addButtonToTriggerMapping", Format: "[action] [device] [mouse] [num] [secondary]".}: seq[ButtonToTrigger[T]]
    keyToTrigger* {.Setting: "addKeyToTriggerMapping", Format: "[action] [device] [key] [num] [secondary]".}: seq[KeyToTrigger[T]]
    axisToAxis {.Setting: "addAxisToAxisMapping", Format: "[action] [device] [mouse] [num] [secondary]".}: seq[AxisToAxis[T]]
    axisToTrigger {.Setting: "addAxisToTriggerMapping", Format: "[action1] [action2] [device] [mouse] [secondary]".}: seq[AxisToTrigger[T]]
    invertMouse* {.Setting: "invertMouse", Valid: Bools01, Default: false, IgnoreWhenDefault.}: bool # 0
    yawFactor* {.Setting: "setYawFactor", Default: 1u8, IgnoreWhenDefault.}: range[1u8 .. 10u8] # 1 # TODO: Add IgnoreWriteWhenDefault pragma and don't write this attribute if value is equal Default
    pitchFactor* {.Setting: "setPitchFactor", Default: 1u8, IgnoreWhenDefault.}: range[1u8 .. 10u8] # 1 # TODO: Add IgnoreWriteWhenDefault pragma and don't write this attribute if value is equal Default
    mouseSensitivity* {.Setting: "mouseSensitivity", Default: 1f, IgnoreWhenDefault.}: range[0f .. 10f] # 1 # TODO: Add IgnoreWriteWhenDefault pragma and don't write this attribute if value is equal Default
  ControlsInfantry* = object of BaseControls[PAction]
  ControlsLand* = object of BaseControls[PAction]
  ControlsAir* = object of BaseControls[PAction]
  ControlsHelicopter* = object of BaseControls[PAction]
  ControlsSea* = object of BaseControls[PAction]
  ControlsDefaultGame* = object of BaseControls[GAction]
  ControlsDefaultPlayer* = object of BaseControls[PAction]

func newDefaultInfantry(): ControlsInfantry =
  result.keysToAxis.add(KeysToAxis[PAction](action: PAction.Yaw, device: Device.Keyboard, key1: KeyD, key2: KeyA, secondary: false))
  result.keysToAxis.add(KeysToAxis[PAction](action: PAction.Throttle, device: Device.Keyboard, key1: KeyW, key2: KeyS, secondary: false))
  result.buttonToTrigger.add(ButtonToTrigger[PAction](action: PAction.Fire, device: Device.Mouse, mouse: MouseButton0, num: 0, secondary: false))
  result.buttonToTrigger.add(ButtonToTrigger[PAction](action: PAction.AltFire, device: Device.Mouse, mouse: MouseButton1, num: 0, secondary: false))
  result.buttonToTrigger.add(ButtonToTrigger[PAction](action: PAction.Lie, device: Device.Mouse, mouse: MouseButton3, num: 0, secondary: true))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Action, device: Device.Keyboard, key: KeySpace, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.AltSprint, device: Device.Keyboard, key: KeyLeftShift, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Sprint, device: Device.Keyboard, key: KeyLeftShift, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect1, device: Device.Keyboard, key: Key1, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect2, device: Device.Keyboard, key: Key2, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect3, device: Device.Keyboard, key: Key3, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect4, device: Device.Keyboard, key: Key4, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect5, device: Device.Keyboard, key: Key5, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect6, device: Device.Keyboard, key: Key6, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect7, device: Device.Keyboard, key: Key7, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect8, device: Device.Keyboard, key: Key8, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect1, device: Device.Keyboard, key: KeyF1, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect2, device: Device.Keyboard, key: KeyF2, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect3, device: Device.Keyboard, key: KeyF3, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect4, device: Device.Keyboard, key: KeyF4, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect5, device: Device.Keyboard, key: KeyF5, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect6, device: Device.Keyboard, key: KeyF6, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect7, device: Device.Keyboard, key: KeyF7, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect8, device: Device.Keyboard, key: KeyF8, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Drop, device: Device.Keyboard, key: KeyG, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Lie, device: Device.Keyboard, key: KeyZ, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.ToggleWeapon, device: Device.Keyboard, key: KeyF, num: 10000, secondary: false))
  result.invertMouse = result.invertMouse.getCustomPragmaVal(Default)[0]
  result.yawFactor = result.yawFactor.getCustomPragmaVal(Default)[0]
  result.pitchFactor = result.pitchFactor.getCustomPragmaVal(Default)[0]
  result.mouseSensitivity = result.mouseSensitivity.getCustomPragmaVal(Default)[0]

func newDefaultLand(): ControlsLand =
  result.keysToAxis.add(KeysToAxis[PAction](action: PAction.Yaw, device: Device.Keyboard, key1: KeyD, key2: KeyA, secondary: false))
  result.keysToAxis.add(KeysToAxis[PAction](action: PAction.Throttle, device: Device.Keyboard, key1: KeyW, key2: KeyS, secondary: false))
  result.axisToAxis.add(AxisToAxis[PAction](action: PAction.Pitch, device: Device.Mouse, mouse: MouseAxis1, num: 0, secondary: false))
  result.axisToAxis.add(AxisToAxis[PAction](action: PAction.Roll, device: Device.Mouse, mouse: MouseAxis0, num: 0, secondary: false))
  result.buttonToTrigger.add(ButtonToTrigger[PAction](action: PAction.Fire, device: Device.Mouse, mouse: MouseButton0, num: 0, secondary: false))
  result.buttonToTrigger.add(ButtonToTrigger[PAction](action: PAction.AltFire, device: Device.Mouse, mouse: MouseButton1, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Fire, device: Device.Keyboard, key: KeySpace, num: 0, secondary: true))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.MouseLook, device: Device.Keyboard, key: KeyLeftCtrl, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Sprint, device: Device.Keyboard, key: KeyLeftShift, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect1, device: Device.Keyboard, key: Key1, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect2, device: Device.Keyboard, key: Key2, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect3, device: Device.Keyboard, key: Key3, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect4, device: Device.Keyboard, key: Key4, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect5, device: Device.Keyboard, key: Key5, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect6, device: Device.Keyboard, key: Key6, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect7, device: Device.Keyboard, key: Key7, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect8, device: Device.Keyboard, key: Key8, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect1, device: Device.Keyboard, key: KeyF1, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect2, device: Device.Keyboard, key: KeyF2, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect3, device: Device.Keyboard, key: KeyF3, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect4, device: Device.Keyboard, key: KeyF4, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect5, device: Device.Keyboard, key: KeyF5, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect6, device: Device.Keyboard, key: KeyF6, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect7, device: Device.Keyboard, key: KeyF7, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect8, device: Device.Keyboard, key: KeyF8, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.AltFire, device: Device.Keyboard, key: KeyNumpad0, num: 0, secondary: true))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Crouch, device: Device.Keyboard, key: KeyZ, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode1, device: Device.Keyboard, key: KeyF9, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode2, device: Device.Keyboard, key: KeyF10, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode3, device: Device.Keyboard, key: KeyF11, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode4, device: Device.Keyboard, key: KeyF12, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.ToggleWeapon, device: Device.Keyboard, key: KeyF, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.FlareFire, device: Device.Keyboard, key: KeyX, num: 0, secondary: false))
  result.invertMouse = result.invertMouse.getCustomPragmaVal(Default)[0]
  result.yawFactor = result.yawFactor.getCustomPragmaVal(Default)[0]
  result.pitchFactor = result.pitchFactor.getCustomPragmaVal(Default)[0]
  result.mouseSensitivity = result.mouseSensitivity.getCustomPragmaVal(Default)[0]

func newDefaultAir(): ControlsAir =
  result.keysToAxis.add(KeysToAxis[PAction](action: PAction.Yaw, device: Device.Keyboard, key1: KeyD, key2: KeyA, secondary: false))
  result.keysToAxis.add(KeysToAxis[PAction](action: PAction.Throttle, device: Device.Keyboard, key1: KeyW, key2: KeyS, secondary: false))
  result.axisToAxis.add(AxisToAxis[PAction](action: PAction.Pitch, device: Device.Mouse, mouse: MouseAxis1, num: 0, secondary: false))
  result.axisToAxis.add(AxisToAxis[PAction](action: PAction.Pitch, device: Device.Falcon, mouse: MouseAxis2, num: 0, secondary: true))
  result.axisToAxis.add(AxisToAxis[PAction](action: PAction.Roll, device: Device.Mouse, mouse: MouseAxis0, num: 0, secondary: false))
  result.buttonToTrigger.add(ButtonToTrigger[PAction](action: PAction.Fire, device: Device.Mouse, mouse: MouseButton0, num: 0, secondary: false))
  result.buttonToTrigger.add(ButtonToTrigger[PAction](action: PAction.AltFire, device: Device.Mouse, mouse: MouseButton1, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Fire, device: Device.Keyboard, key: KeySpace, num: 0, secondary: true))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.MouseLook, device: Device.Keyboard, key: KeyLeftCtrl, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Sprint, device: Device.Keyboard, key: KeyLeftShift, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.AltSprint, device: Device.Keyboard, key: KeyW, num: 1000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect1, device: Device.Keyboard, key: Key1, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect2, device: Device.Keyboard, key: Key2, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect3, device: Device.Keyboard, key: Key3, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect4, device: Device.Keyboard, key: Key4, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect5, device: Device.Keyboard, key: Key5, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect6, device: Device.Keyboard, key: Key6, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect7, device: Device.Keyboard, key: Key7, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect8, device: Device.Keyboard, key: Key8, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect1, device: Device.Keyboard, key: KeyF1, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect2, device: Device.Keyboard, key: KeyF2, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect3, device: Device.Keyboard, key: KeyF3, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect4, device: Device.Keyboard, key: KeyF4, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect5, device: Device.Keyboard, key: KeyF5, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect6, device: Device.Keyboard, key: KeyF6, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect7, device: Device.Keyboard, key: KeyF7, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect8, device: Device.Keyboard, key: KeyF8, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.AltFire, device: Device.Keyboard, key: KeyNumpad0, num: 0, secondary: true))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode1, device: Device.Keyboard, key: KeyF9, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode2, device: Device.Keyboard, key: KeyF10, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode3, device: Device.Keyboard, key: KeyF11, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode4, device: Device.Keyboard, key: KeyF12, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.ToggleWeapon, device: Device.Keyboard, key: KeyF, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.FlareFire, device: Device.Keyboard, key: KeyX, num: 0, secondary: false))
  result.invertMouse = result.invertMouse.getCustomPragmaVal(Default)[0]
  result.yawFactor = result.yawFactor.getCustomPragmaVal(Default)[0]
  result.pitchFactor = result.pitchFactor.getCustomPragmaVal(Default)[0]
  result.mouseSensitivity = 1.7

func newDefaultHelicopter(): ControlsHelicopter =
  result.keysToAxis.add(KeysToAxis[PAction](action: PAction.Yaw, device: Device.Keyboard, key1: KeyD, key2: KeyA, secondary: false))
  result.keysToAxis.add(KeysToAxis[PAction](action: PAction.Throttle, device: Device.Keyboard, key1: KeyW, key2: KeyS, secondary: false))
  result.axisToAxis.add(AxisToAxis[PAction](action: PAction.Pitch, device: Device.Mouse, mouse: MouseAxis1, num: 0, secondary: false))
  result.axisToAxis.add(AxisToAxis[PAction](action: PAction.Pitch, device: Device.Falcon, mouse: MouseAxis2, num: 0, secondary: true))
  result.axisToAxis.add(AxisToAxis[PAction](action: PAction.Roll, device: Device.Mouse, mouse: MouseAxis0, num: 0, secondary: false))
  result.axisToAxis.add(AxisToAxis[PAction](action: PAction.Roll, device: Device.Falcon, mouse: MouseAxis0, num: 0, secondary: true))
  result.buttonToTrigger.add(ButtonToTrigger[PAction](action: PAction.Fire, device: Device.Mouse, mouse: MouseButton0, num: 0, secondary: false))
  result.buttonToTrigger.add(ButtonToTrigger[PAction](action: PAction.AltFire, device: Device.Mouse, mouse: MouseButton1, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Fire, device: Device.Keyboard, key: KeySpace, num: 0, secondary: true))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.MouseLook, device: Device.Keyboard, key: KeyLeftCtrl, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Sprint, device: Device.Keyboard, key: KeyLeftShift, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.AltSprint, device: Device.Keyboard, key: KeyW, num: 1000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect1, device: Device.Keyboard, key: Key1, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect2, device: Device.Keyboard, key: Key2, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect3, device: Device.Keyboard, key: Key3, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect4, device: Device.Keyboard, key: Key4, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect5, device: Device.Keyboard, key: Key5, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect6, device: Device.Keyboard, key: Key6, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect7, device: Device.Keyboard, key: Key7, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect8, device: Device.Keyboard, key: Key8, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect1, device: Device.Keyboard, key: KeyF1, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect2, device: Device.Keyboard, key: KeyF2, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect3, device: Device.Keyboard, key: KeyF3, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect4, device: Device.Keyboard, key: KeyF4, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect5, device: Device.Keyboard, key: KeyF5, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect6, device: Device.Keyboard, key: KeyF6, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect7, device: Device.Keyboard, key: KeyF7, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect8, device: Device.Keyboard, key: KeyF8, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.AltFire, device: Device.Keyboard, key: KeyNumpad0, num: 0, secondary: true))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode1, device: Device.Keyboard, key: KeyF9, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode2, device: Device.Keyboard, key: KeyF10, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode3, device: Device.Keyboard, key: KeyF11, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode4, device: Device.Keyboard, key: KeyF12, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.ToggleWeapon, device: Device.Keyboard, key: KeyF, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.FlareFire, device: Device.Keyboard, key: KeyX, num: 0, secondary: false))
  result.invertMouse = result.invertMouse.getCustomPragmaVal(Default)[0]
  result.yawFactor = result.yawFactor.getCustomPragmaVal(Default)[0]
  result.pitchFactor = result.pitchFactor.getCustomPragmaVal(Default)[0]
  result.mouseSensitivity = 3

func newDefaultSea(): ControlsSea =
  result.keysToAxis.add(KeysToAxis[PAction](action: PAction.Yaw, device: Device.Keyboard, key1: KeyD, key2: KeyA, secondary: false))
  result.keysToAxis.add(KeysToAxis[PAction](action: PAction.Pitch, device: Device.Keyboard, key1: KeyArrowUp, key2: KeyArrowDown, secondary: false))
  result.keysToAxis.add(KeysToAxis[PAction](action: PAction.Throttle, device: Device.Keyboard, key1: KeyW, key2: KeyS, secondary: false))
  result.buttonToTrigger.add(ButtonToTrigger[PAction](action: PAction.Fire, device: Device.Mouse, mouse: MouseButton0, num: 0, secondary: false))
  result.buttonToTrigger.add(ButtonToTrigger[PAction](action: PAction.AltFire, device: Device.Mouse, mouse: MouseButton1, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Fire, device: Device.Keyboard, key: KeySpace, num: 0, secondary: true))
  # result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.MouseLook, device: Device.Keyboard, key: KeyLeftCtrl, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Sprint, device: Device.Keyboard, key: KeyLeftShift, num: 0, secondary: false))
  # result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.AltSprint, device: Device.Keyboard, key: KeyW, num: 1000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect1, device: Device.Keyboard, key: Key1, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect2, device: Device.Keyboard, key: Key2, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect3, device: Device.Keyboard, key: Key3, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect4, device: Device.Keyboard, key: Key4, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect5, device: Device.Keyboard, key: Key5, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect6, device: Device.Keyboard, key: Key6, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect7, device: Device.Keyboard, key: Key7, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.WeaponSelect8, device: Device.Keyboard, key: Key8, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect1, device: Device.Keyboard, key: KeyF1, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect2, device: Device.Keyboard, key: KeyF2, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect3, device: Device.Keyboard, key: KeyF3, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect4, device: Device.Keyboard, key: KeyF4, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect5, device: Device.Keyboard, key: KeyF5, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect6, device: Device.Keyboard, key: KeyF6, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect7, device: Device.Keyboard, key: KeyF7, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.PositionSelect8, device: Device.Keyboard, key: KeyF8, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.AltFire, device: Device.Keyboard, key: KeyNumpad0, num: 0, secondary: true))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode1, device: Device.Keyboard, key: KeyF9, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode2, device: Device.Keyboard, key: KeyF10, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode3, device: Device.Keyboard, key: KeyF11, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.CameraMode4, device: Device.Keyboard, key: KeyF12, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.ToggleWeapon, device: Device.Keyboard, key: KeyF, num: 10000, secondary: false))
  # result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.FlareFire, device: Device.Keyboard, key: KeyX, num: 0, secondary: false))
  result.invertMouse = result.invertMouse.getCustomPragmaVal(Default)[0]
  result.yawFactor = result.yawFactor.getCustomPragmaVal(Default)[0]
  result.pitchFactor = result.pitchFactor.getCustomPragmaVal(Default)[0]
  result.mouseSensitivity = result.mouseSensitivity.getCustomPragmaVal(Default)[0]


proc newDefaultDefaultGame(): ControlsDefaultGame =
  result.axisToAxis.add(AxisToAxis[GAction](action: GAction.MouseLookX, device: Device.Mouse, mouse: MouseAxis0, num: 0, secondary: false))
  result.axisToAxis.add(AxisToAxis[GAction](action: GAction.MouseLookY, device: Device.Mouse, mouse: MouseAxis1, num: 0, secondary: false))
  result.axisToTrigger.add(AxisToTrigger[GAction](action1: GAction.MouseWheelUp, action2: GAction.MinusOne, device: Device.Mouse, mouse: MouseAxis2, secondary: false)) # TODO: -1
  result.axisToTrigger.add(AxisToTrigger[GAction](action1: GAction.MinusOne, action2: GAction.MouseWheelDown, device: Device.Mouse, mouse: MouseAxis2, secondary: false)) # TODO: -1
  result.buttonToTrigger.add(ButtonToTrigger[GAction](action: GAction.Ok, device: Device.Mouse, mouse: MouseButton0, num: 0, secondary: false))
  result.buttonToTrigger.add(ButtonToTrigger[GAction](action: GAction.AltOk, device: Device.Mouse, mouse: MouseButton1, num: 0, secondary: false))
  result.buttonToTrigger.add(ButtonToTrigger[GAction](action: GAction.RadioComm, device: Device.Mouse, mouse: MouseButton2, num: 0, secondary: true))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.Menu, device: Device.Keyboard, key: KeyEscape, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.ToggleConsole, device: Device.Keyboard, key: KeyGrave, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.ToggleConsole, device: Device.Keyboard, key: KeyEnd, num: 10000, secondary: true))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.Escape, device: Device.Keyboard, key: KeyEscape, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.Up, device: Device.Keyboard, key: KeyArrowUp, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.Down, device: Device.Keyboard, key: KeyArrowDown, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.Left, device: Device.Keyboard, key: KeyArrowLeft, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.Right, device: Device.Keyboard, key: KeyArrowRight, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.PageUp, device: Device.Keyboard, key: KeyPageUp, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.PageDown, device: Device.Keyboard, key: KeyPageDown, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.RightShift, device: Device.Keyboard, key: KeyRightShift, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.LeftShift, device: Device.Keyboard, key: KeyLeftShift, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.LeftCtrl, device: Device.Keyboard, key: KeyLeftCtrl, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.RightCtrl, device: Device.Keyboard, key: KeyRightCtrl, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.RightAlt, device: Device.Keyboard, key: KeyRightAlt, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.ScreenShot, device: Device.Keyboard, key: KeyPrintScreen, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.TogglePause, device: Device.Keyboard, key: KeyP, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.SayAll, device: Device.Keyboard, key: KeyJ, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.SayTeam, device: Device.Keyboard, key: KeyK, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.SaySquad, device: Device.Keyboard, key: KeyL, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.Tab, device: Device.Keyboard, key: KeyTab, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.Enter, device: Device.Keyboard, key: KeyEnter, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.Delete, device: Device.Keyboard, key: KeyDelete, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.Back, device: Device.Keyboard, key: KeyBackspace, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.TacticalComm, device: Device.Keyboard, key: KeyT, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.RadioComm, device: Device.Keyboard, key: KeyQ, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.MapSize, device: Device.Keyboard, key: KeyM, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.MapZoom, device: Device.Keyboard, key: KeyN, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.MenuSelect0, device: Device.Keyboard, key: Key0, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.MenuSelect1, device: Device.Keyboard, key: Key1, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.MenuSelect2, device: Device.Keyboard, key: Key2, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.MenuSelect3, device: Device.Keyboard, key: Key3, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.MenuSelect4, device: Device.Keyboard, key: Key4, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.MenuSelect5, device: Device.Keyboard, key: Key5, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.MenuSelect6, device: Device.Keyboard, key: Key6, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.MenuSelect7, device: Device.Keyboard, key: Key7, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.MenuSelect8, device: Device.Keyboard, key: Key8, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.Yes, device: Device.Keyboard, key: KeyPageUp, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.No, device: Device.Keyboard, key: KeyPageDown, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.CreateSquad, device: Device.Keyboard, key: KeyInsert, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.ToggleFreeCamera, device: Device.Keyboard, key: Key0, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.HotRankUp, device: Device.Keyboard, key: KeyAdd, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.ShowScoreboard, device: Device.Keyboard, key: KeyTab, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.VoipUseLeaderChannel, device: Device.Keyboard, key: KeyB, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.ThreeDMap, device: Device.Keyboard, key: KeyLeftAlt, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.SelectAll, device: Device.Keyboard, key: KeyA, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.DeselectAll, device: Device.Keyboard, key: KeyD, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.Leader, device: Device.Keyboard, key: KeyCapital, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.Leader, device: Device.Keyboard, key: KeyHome, num: 10000, secondary: true))
  result.keyToTrigger.add(KeyToTrigger[GAction](action: GAction.VoipPushToTalk, device: Device.Keyboard, key: KeyV, num: 0, secondary: false))
  result.invertMouse = result.invertMouse.getCustomPragmaVal(Default)[0]
  result.yawFactor = result.yawFactor.getCustomPragmaVal(Default)[0]
  result.pitchFactor = result.pitchFactor.getCustomPragmaVal(Default)[0]
  result.mouseSensitivity = result.mouseSensitivity.getCustomPragmaVal(Default)[0]

proc newDefaultDefaultPlayer(): ControlsDefaultPlayer =
  result.axisToAxis.add(AxisToAxis[PAction](action: PAction.MouseLookX, device: Device.Mouse, mouse: MouseAxis0, num: 0, secondary: false))
  result.axisToAxis.add(AxisToAxis[PAction](action: PAction.MouseLookX, device: Device.Falcon, mouse: MouseAxis0, num: 0, secondary: true))
  result.axisToAxis.add(AxisToAxis[PAction](action: PAction.MouseLookY, device: Device.Mouse, mouse: MouseAxis1, num: 0, secondary: false))
  result.axisToAxis.add(AxisToAxis[PAction](action: PAction.MouseLookY, device: Device.Falcon, mouse: MouseAxis1, num: 0, secondary: true))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Use, device: Device.Keyboard, key: KeyE, num: 0, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Reload, device: Device.Keyboard, key: KeyR, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.ToggleCameraMode, device: Device.Keyboard, key: KeyC, num: 10000, secondary: false))
  result.keyToTrigger.add(KeyToTrigger[PAction](action: PAction.Crouch, device: Device.Keyboard, key: KeyLeftCtrl, num: 0, secondary: false))
  result.axisToTrigger.add(AxisToTrigger[PAction](action1: PAction.NextItem, action2: PAction.MinusOne, device: Device.Mouse, mouse: MouseAxis2, secondary: false)) # TODO: -1
  result.axisToTrigger.add(AxisToTrigger[PAction](action1: PAction.MinusOne, action2: PAction.PrevItem, device: Device.Mouse, mouse: MouseAxis2, secondary: false)) # TODO: -1
  result.invertMouse = result.invertMouse.getCustomPragmaVal(Default)[0]
  result.yawFactor = result.yawFactor.getCustomPragmaVal(Default)[0]
  result.pitchFactor = result.pitchFactor.getCustomPragmaVal(Default)[0]
  result.mouseSensitivity = result.mouseSensitivity.getCustomPragmaVal(Default)[0]


type
  Controls* {.Prefix: "ControlMap.", BlockStart: "ControlMap.create".} = object
    infantry* {.BlockValue: "InfantryPlayerInputControlMap", Default: newDefaultInfantry().}: ControlsInfantry
    land* {.BlockValue: "LandPlayerInputControlMap", Default: newDefaultLand().}: ControlsLand
    air* {.BlockValue: "AirPlayerInputControlMap", Default: newDefaultAir().}: ControlsAir
    helicopter* {.BlockValue: "HelicopterPlayerInputControlMap", Default: newDefaultHelicopter().}: ControlsHelicopter
    sea* {.BlockValue: "SeaPlayerInputControlMap", Default: newDefaultSea().}: ControlsSea
    defaultGame* {.BlockValue: "defaultGameControlMap", Default: newDefaultDefaultGame().}: ControlsDefaultGame
    defaultPlayer* {.BlockValue: "defaultPlayerInputControlMap", Default: newDefaultDefaultPlayer().}: ControlsDefaultPlayer



when isMainModule:
  let path: string = """/home/dankrad/Battlefield 2142/Profiles/0001/Controls.con"""
  var controls: Controls = newDefault[Controls]()
  validate(Controls)
  # controls.writeCon("/home/dankrad/Desktop/controls.con")
  # echo controls

  # var report: ConReport
  # (controls, report) = readCon[Controls](path)
  # # for line in report.lines:
  # #   echo line
  # # echo "################################"
  # # echo "controls Game: ", controls.defaultGame.keyToTrigger[0].type
  # # echo "controls Player: ", controls.defaultPlayer.keyToTrigger[0].type
  # # controls.writeCon("/home/dankrad/Desktop/controls.con")
  # if not report.valid:
  #   var amount: int = 0
  #   for line in report.invalidLines:
  #     amount.inc()
  #     # echo line.raw, " <---", "Setting: ", line.validSetting, " | Value: ", line.validValue
  #   echo "\n", amount, " invalid lines of ", report.lines.len

  # # controls.writeCon("/home/dankrad/Desktop/controls.con")

  # # for key, val in controls.fieldPairs:
  # #   for key2, val2 in val.fieldPairs:
  # #     echo val2.hasCustomPragma(Setting)
