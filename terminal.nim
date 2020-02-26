#[
  TODO: Encapsulate and refactor or rewrite!
  Currently:
    Do not create multiple processes or multiple forked processes.
    Only one process and one forked process is allowed.
]#

import gintro/[gtk, glib, gobject, gio]

import strutils
import os

when defined(linux):
  import gintro/vte # Requierd for terminal (linux only feature)
  export vte
elif defined(windows):
  import osproc
  import streams
  import winim
  import getprocessbyname # requierd for getPidByName (processname)
  import stdoutreader # requierd for read stdoutput form another process
  import gethwndbypid # requierd for getHWndByPid to hide forked process
  type
    Terminal* = ref object of ScrolledWindow
  proc newTerminal*(): Terminal =
    var textView = newTextView()
    # textView.monospace = true
    var scrolledWindow = newScrolledWindow(textView.getHadjustment(), textView.getVadjustment())
    scrolledWindow.propagateNaturalHeight = true
    scrolledWindow.add(textView)
    result = cast[Terminal](scrolledWindow)
    result.styleContext.addClass("terminal")
  proc textView(terminal: Terminal): TextView =
    return cast[TextView](terminal.getChild())
  proc buffer(terminal: Terminal): TextBuffer =
    return terminal.textView.getBuffer()
  proc `text=`(terminal: Terminal, text: string) =
    terminal.buffer.setText(text, text.len)
  proc text(terminal: Terminal): string =
    var startIter: TextIter
    var endIter: TextIter
    terminal.buffer.getStartIter(startIter)
    terminal.buffer.getEndIter(endIter)
    return terminal.buffer.getText(startIter, endIter, true)
  proc visible*(terminal: Terminal): bool =
    return terminal.textView.visible
  proc `visible=`*(terminal: Terminal, visible: bool) =
    cast[ScrolledWindow](terminal).visible = visible # TODO: Need to be casted otherwise it will visible infix proc
    terminal.textView.visible = visible

proc addText*(terminal: Terminal, text: string, scrollDown: bool = false) =
  when defined(linux):
    discard # TODO: implement
  elif defined(windows):
    terminal.text = terminal.text & text
    if scrollDown:
      var mark: TextMark = terminal.buffer.getInsert()
      terminal.textView.scrollMarkOnScreen(mark)

proc clear*(terminal: Terminal) =
  when defined(linux):
    terminal.reset(true, true)
  elif defined(windows):
    terminal.text = ""

# proc processId*(terminal: Terminal): int =
#   discard
#   # var valProcessId: Value
#   # terminal.getProperty("processId", valProcessId)
#   # return valProcessId.getInt()

# proc `processId=`(terminal: Terminal, processId: int) =
#   discard
#   # var valProcessId: Value
#   # valProcessId.setInt(processId)
#   # terminal.setProperty("processId", valProcessId)
#   # # echo "processId: ", terminal.processId

##########################

when defined(windows):
  type
    TimerData = ref object
      terminal: Terminal

  # TODO: There are no multiple Terminals possible. That's because the two global channels.
  # These Channel should be in scope. This is not possible. Adding a global pragma doesn't resolve this.
  # This could be solved with a macro. Creating the channels on compiletime with different names.
  var thread: system.Thread[Process]
  var threadForked: system.Thread[int]
  var channelReplaceText: Channel[string]
  var channelAddText: Channel[string]
  var channelTerminate: Channel[bool]
  var channelTerminateForked: Channel[bool]
  var channelStopTimerAdd: Channel[bool]
  var channelStopTimerReplace: Channel[bool]

  proc timerReplaceTerminalText(timerData: TimerData): bool =
    if channelStopTimerReplace.tryRecv().dataAvailable:
      return SOURCE_REMOVE
    var (hasData, data) = channelReplaceText.tryRecv()
    if hasData:
      timerData.terminal.text = data
    return SOURCE_CONTINUE

  proc timerAddTerminalText(timerData: TimerData): bool =
    if channelStopTimerAdd.tryRecv().dataAvailable:
      return SOURCE_REMOVE
    var (hasData, data) = channelAddText.tryRecv()
    if hasData:
      timerData.terminal.addText(data, scrollDown = true)
    return SOURCE_CONTINUE

  proc terminateThread*() = # TODO
    channelStopTimerAdd.send(true)
    channelTerminate.send(true)

  proc terminateForkedThread*() = # TODO
    channelStopTimerReplace.send(true)
    channelTerminateForked.send(true)

proc startProcess*(terminal: Terminal, command: string, workingDir: string = os.getCurrentDir(), env: string = "", searchForkedProcess: bool = false): int = # TODO: processId should be stored and not returned
  when defined(linux):
    discard terminal.spawnSync(
      ptyFlags = {PtyFlag.noLastlog},
      workingDirectory = workingDir,
      argv = command.strip().splitWhitespace(),
      envv = env.strip().splitWhitespace(),
      spawnFlags = {glib.SpawnFlag.doNotReapChild},
      childSetup = nil,
      childSetupData = nil,
      childPid = result
    )
  elif defined(windows):
    var process: Process
    if searchForkedProcess == true: # TODO: store command in variable
      process = startProcess(
        command = """cmd /c """" & workingDir / command & '"',
        workingDir = workingDir,
        options = {poStdErrToStdOut, poEvalCommand, poEchoCmd}
      )
    else:
      process = startProcess(
        command = workingDir / command,
        workingDir = workingDir,
        options = {poStdErrToStdOut, poEvalCommand, poEchoCmd}
      )
    result = process.processID
    if searchForkedProcess:
      var tryCounter: int = 0
      while tryCounter <= 10: # TODO: if result == 0 after all tries rais an exception
        result = getPidByName(command)
        if result > 0: break
        tryCounter.inc()
        sleep(500)

    if searchForkedProcess:
      channelReplaceText.open()
      channelTerminateForked.open()
      channelStopTimerReplace.open()
      var timerDataReplaceText: TimerData = TimerData(terminal: terminal)
      discard timeoutAdd(250, timerReplaceTerminalText, timerDataReplaceText)
      threadForked.createThread(proc (processId: int) {.thread.} =
        var hwnd: HWND = getHWndByPid(processId)
        while hwnd == 0: # Waiting until window can be accessed
          sleep(250)
          hwnd = getHWndByPid(processId)
        # ShowWindow(hwnd, SW_HIDE) # TODO: Add checkbox to GUI
        while true:
          if channelTerminateForked.tryRecv().dataAvailable:
            return
          channelReplaceText.send(readStdOut(processId))
          sleep(250)
      , (result))
    else:
      channelAddText.open()
      channelTerminate.open()
      channelStopTimerAdd.open()
      var timerDataAddText: TimerData = TimerData(terminal: terminal)
      discard timeoutAdd(250, timerAddTerminalText, timerDataAddText)
      thread.createThread(proc (process: Process) {.thread.} =
        while true:
          if channelTerminate.tryRecv().dataAvailable:
            return
          if process.outputStream.isNil:
            return
          channelAddText.send(process.outputStream.readAll())
          sleep(250)
      , (process))
##########################

when isMainModule:
  proc appActivate (app: Application) =
    let window = newApplicationWindow(app)
    window.title = "Terminal"
    window.defaultSize = (250, 50)
    let terminal: Terminal = newTerminal()
    terminal.text = "TEST: Hallo, was geht?\n"
    terminal.addText("ARSCH:  Gut und dir?\n")
    window.add(terminal)
    window.showAll()
    when defined(linux):
      discard # TODO: implement
    elif defined(windows):
      discard
      # terminal.editable = false # TODO: must be done after terminal/textview is visible

  proc main =
    let app = newApplication("org.gtk.example")
    connect(app, "activate", appActivate)
    discard app.run()

  main()