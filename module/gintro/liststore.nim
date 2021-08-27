import gintro/[gtk, glib, gobject]

proc typeTest(o: gobject.Object; s: string): bool =
  let gt = g_type_from_name(s)
  return g_type_check_instance_is_a(cast[ptr TypeInstance00](o.impl), gt).toBool

proc listStore*(o: gobject.Object): gtk.ListStore =
  assert(typeTest(o, "GtkListStore"))
  cast[gtk.ListStore](o)

proc treeStore*(o: gobject.Object): TreeStore = # TODO: Rename liststore.nim or create treestore.nim
  assert(typeTest(o, "GtkTreeStore"))
  cast[TreeStore](o)
