import gintro/gtk


import strutils
proc `$`(ex: ref Exception): string = # TODO: Reduntant, outsource
  result.add("Exception: \n\t" & $ex.name & "\n")
  result.add("Message: \n\t" & ex.msg.strip() & "\n")
  result.add("Stacktrace: \n")
  for line in splitLines(getStackTrace(ex)):
    result.add("\t" & line & "\n")


proc showExceptionDialog*(title, text: string, ex: ref Exception, yesText: string = "Yes", noText: string = "No"): int =
  var dialog: Dialog = newDialog()
  var lblTitle: Label = newLabel(title)
  var lblText: Label = newLabel(text)
  var expander: Expander = newExpander("Stacktrace:")
  var txtvException: TextView = newTextView()
  var scrolledWindow = newScrolledWindow(txtvException.getHadjustment(), txtvException.getVadjustment())
    # textView.wrapMode = WrapMode.wordChar
    # result = cast[Terminal](scrolledWindow)

  expander.expanded = true
  txtvException.editable = false
  txtvException.marginLeft = 17
  scrolledWindow.propagateNaturalHeight = true
  cast[ButtonBox](dialog.getActionArea()).setLayout(ButtonBoxStyle.expand) # TODO: dialog.getActionArea() is deprecated -.-

  # var attrList: AttrList lblTitle.getAttributes()
  # attrList.bold

  # lblTitle.xalign = 0
  # lblText.xalign = 0
  # lblException.xalign = 0

  # expander.vexpand = true
  # expander.expanded = true

  dialog.contentArea.add(lblTitle)
  dialog.contentArea.add(lblText)
  scrolledWindow.add(txtvException)
  expander.add(scrolledWindow)
  dialog.contentArea.add(expander)
  discard dialog.addButton(yesText, ResponseType.yes.int)
  discard dialog.addButton(noText, ResponseType.no.int)


  # for widget in dialog.getChildren():
  #   echo widget.type

  # buttonBox.add(btnYes)
  # buttonBox.add(btnNo)
  # dialog.contentArea.add(buttonBox)

  dialog.title = title #"ERROR: " & osErrorMsg(osLastError())
  let exStr: string = $ex
  txtvException.buffer.setText(exStr, exStr.len)

  dialog.showAll()
  # dialog.show()
  # var lblText: Label = newLabel($ex)
  # dialog.contentArea.add(lblText)
  # var hboxButtons: Box = newBox(Orientation.horizontal, 5)
  # dialog.contentArea.add(hboxButtons)
  # var btnOk: Button = newButton("Ok")
  # hboxButtons.add(btnOk)
  # proc onBtnOkClicked(self: Button, dialog: Dialog) =
  #   dialog.destroy()
  # btnOk.connect("clicked", onBtnOkClicked, dialog)
  # var btnCloseAll: Button = newButton("Close BF2142Unlocker")
  # hboxButtons.add(btnCloseAll)
  # proc onBtnCloseAllClicked(self: Button, dialog: Dialog) =
  #   onQuit()
  #   quit(0)
  # btnCloseAll.connect("clicked", onBtnCloseAllClicked, dialog)
  # dialog.contentArea.showAll()
  # dialog.setPosition(WindowPosition.center)
  # result = dialog.run()
  # dialog.destroy()

