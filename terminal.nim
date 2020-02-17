import gintro/[gtk, glib, gobject, gio]

import strutils
import os

when defined(linux):
  import gintro/vte # Requierd for terminal (linux only feature)
  export vte
  import posix # Requierd for kill process
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
    var scrolledWindow = newScrolledWindow(textView.getHadjustment(), textView.getVadjustment())
    scrolledWindow.add(textView)
    result = cast[Terminal](scrolledWindow)
    # textView.buffer = result.getBuffer()
  proc buffer*(terminal: Terminal): TextBuffer =
    return cast[TextView](terminal.getChild()).getBuffer()

proc `text=`*(terminal: Terminal, text: string) =
  when defined(linux):
    discard # TODO: implement
  elif defined(windows):
    terminal.buffer.setText(text, text.len)

proc text*(terminal: Terminal): string =
  when defined(linux):
    discard # TODO: implement
  elif defined(windows):
    var startIter: TextIter
    var endIter: TextIter
    terminal.buffer.getStartIter(startIter)
    terminal.buffer.getEndIter(endIter)
    return terminal.buffer.getText(startIter, endIter, true)

proc addText*(terminal: Terminal, text: string) =
  when defined(linux):
    discard # TODO: implement
  elif defined(windows):
    terminal.text = terminal.text & text

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
  var thread {.global.}: system.Thread[tuple[process: Process, terminal: Terminal, searchForkedProcess: bool, processId: int]]
  var channelReplaceText: Channel[string]
  var channelAddText: Channel[string]

  proc timerReplaceTerminalText(timerData: TimerData): bool =
    var (hasData, data) = channelReplaceText.tryRecv()
    if hasData:
      timerData.terminal.text = data
    return SOURCE_CONTINUE

  proc timerAddTerminalText(timerData: TimerData): bool =
    var (hasData, data) = channelAddText.tryRecv()
    if hasData:
      timerData.terminal.addText(data)
    return SOURCE_CONTINUE

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
      var timerDataReplaceText: TimerData = TimerData(terminal: terminal)
      channelReplaceText.open()
      discard timeoutAdd(250, timerReplaceTerminalText, timerDataReplaceText)
    else:
      var timerDataAddText: TimerData = TimerData(terminal: terminal)
      channelAddText.open()
      discard timeoutAdd(250, timerAddTerminalText, timerDataAddText)


    thread.createThread(proc (data: tuple[process: Process, terminal: Terminal, searchForkedProcess: bool, processId: int]) {.thread.} =
      if data.searchForkedProcess:
        var hwnd: HWND = getHWndByPid(data.processId)
        while hwnd == 0: # Waiting until window can be accessed
          sleep(250)
          hwnd = getHWndByPid(data.processId)
        # ShowWindow(hwnd, SW_HIDE) # TODO: Add checkbox to GUI
        channelReplaceText.send(readStdOut(data.processId))
        sleep(250)
      else:
        while not isNil(data.process.outputStream):
          channelAddText.send(data.process.outputStream.readAll())
          sleep(250)
    , (process, terminal, searchForkedProcess, result))
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