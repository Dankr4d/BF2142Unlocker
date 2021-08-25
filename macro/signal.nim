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
  # when windowShown is ptr bool:
  #   if not windowShown[]: return
  # else:
  #   if not windowShown: return
  let windowShownStatement: NimNode = nnkStmtList.newTree(
    nnkWhenStmt.newTree(
      nnkElifBranch.newTree(
        nnkInfix.newTree(
          newIdentNode("is"),
          newIdentNode("windowShown"),
          nnkPtrTy.newTree(
            newIdentNode("bool")
          )
        ),
        nnkStmtList.newTree(
          nnkIfStmt.newTree(
            nnkElifBranch.newTree(
              nnkPrefix.newTree(
                newIdentNode("not"),
                nnkBracketExpr.newTree(
                  newIdentNode("windowShown")
                )
              ),
              nnkStmtList.newTree(
                nnkReturnStmt.newTree(
                  newEmptyNode()
                )
              )
            )
          )
        )
      ),
      nnkElse.newTree(
        nnkStmtList.newTree(
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
      )
    )
  )
  # when ignoreEvents is ptr bool:
  #   if ignoreEvents[]: return
  # else:
  #   if ignoreEvents: return
  let ignoreEventsStatement: NimNode = nnkStmtList.newTree(
    nnkWhenStmt.newTree(
      nnkElifBranch.newTree(
        nnkInfix.newTree(
          newIdentNode("is"),
          newIdentNode("ignoreEvents"),
          nnkPtrTy.newTree(
            newIdentNode("bool")
          )
        ),
        nnkStmtList.newTree(
          nnkIfStmt.newTree(
            nnkElifBranch.newTree(
              nnkBracketExpr.newTree(
                newIdentNode("ignoreEvents")
              ),
              nnkStmtList.newTree(
                nnkReturnStmt.newTree(
                  newEmptyNode()
                )
              )
            )
          )
        )
      ),
      nnkElse.newTree(
        nnkStmtList.newTree(
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
      )
    )
  )
  eventProc.body.insert(0, windowShownStatement)
  eventProc.body.insert(1, ignoreEventsStatement)
  eventProc.pragma = pragmas
  result = quote do:
    `eventProc`