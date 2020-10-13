import macros

macro signalNoCheck*(eventProc: untyped): untyped =
  # {.exportc, cdecl, dynlib.}
  let pragmas: NimNode = nnkPragma.newTree(
    newIdentNode("exportc"),
    newIdentNode("cdecl"),
    newIdentNode("dynlib"),
  )
  eventProc.pragma = pragmas
  result = quote do:
    `eventProc`

macro signal*(eventProc: untyped): untyped =
  # {.exportc, cdecl, dynlib.}
  let pragmas: NimNode = nnkPragma.newTree(
    newIdentNode("exportc"),
    newIdentNode("cdecl"),
    newIdentNode("dynlib"),
  )
  # if not windowShown: return
  let windowShownStatement: NimNode = nnkStmtList.newTree(
    nnkIfStmt.newTree(
      nnkElifBranch.newTree(
        nnkPrefix.newTree(
          newIdentNode("not"),
          newIdentNode("windowShown")
        ),
        nnkStmtList.newTree(
          nnkReturnStmt.newTree(
            newEmptyNode()
          )
        )
      )
    )
  )
  let ignoreEventsStatement: NimNode =nnkStmtList.newTree(
    nnkIfStmt.newTree(
      nnkElifBranch.newTree(
        newIdentNode("ignoreEvents"),
        nnkStmtList.newTree(
          nnkReturnStmt.newTree(
            newEmptyNode()
          )
        )
      )
    )
  )
  eventProc.body.insert(0, windowShownStatement)
  eventProc.body.insert(1, ignoreEventsStatement)
  eventProc.pragma = pragmas
  result = quote do:
    `eventProc`