import gintro/[gtk, glib, gobject]

proc typeTest(o: gobject.Object; s: string): bool = # TODO: Redundant (see treestore.nim)
  let gt = g_type_from_name(s)
  return g_type_check_instance_is_a(cast[ptr TypeInstance00](o.impl), gt).toBool

proc listStore*(o: gobject.Object): gtk.ListStore =
  assert(typeTest(o, "GtkListStore"))
  cast[gtk.ListStore](o)
