import macros

macro signalNoCheck*(eventProc: untyped): untyped =
  # {.exportc, cdecl.}
  let pragmas: NimNode = nnkPragma.newTree(
    newIdentNode("exportc"),
    newIdentNode("cdecl")
  )
  eventProc.pragma = pragmas
  result = quote do:
    `eventProc`

macro signal*(eventProc: untyped): untyped =
  # {.exportc, cdecl.}
  let pragmas: NimNode = nnkPragma.newTree(
    newIdentNode("exportc"),
    newIdentNode("cdecl")
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
  eventProc.body.insert(0, windowShownStatement)
  eventProc.pragma = pragmas
  result = quote do:
    `eventProc`