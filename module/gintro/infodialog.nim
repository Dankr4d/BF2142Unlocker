import gintro/[gtk, gobject]


proc newInfoDialog*(title, text: string, okText: string = "OK") =
  # TODO/INFO: https://github.com/StefanSalewski/gintro/issues/35
  var dialog: Dialog = newDialog()
  dialog.title = title
  var lblText: Label = newLabel(text)
  dialog.contentArea.add(lblText)
  var btnOk: Button = newButton(okText)
  dialog.contentArea.add(btnOk)
  btnOk.halign = Align.center
  proc onBtnOkClicked(self: Button, dialog: Dialog) =
    dialog.destroy()
  when defined(nimHasStyleChecks): {.push styleChecks: off.}
  btnOk.connect("clicked", onBtnOkClicked, dialog)
  when defined(nimHasStyleChecks): {.push styleChecks: on.}
  dialog.contentArea.showAll()
  dialog.setPosition(WindowPosition.center)
  discard dialog.run()
  dialog.destroy()