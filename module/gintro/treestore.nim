import gintro/[gtk, glib, gobject]

proc typeTest(o: gobject.Object; s: string): bool = # TODO: Redundant (see liststore.nim)
  let gt = g_type_from_name(s)
  return g_type_check_instance_is_a(cast[ptr TypeInstance00](o.impl), gt).toBool

proc treeStore*(o: gobject.Object): TreeStore = # TODO: Rename liststore.nim or create treestore.nim
  assert(typeTest(o, "GtkTreeStore"))
  cast[TreeStore](o)

iterator iterAllRec*(store: TreeStore): var TreeIter =
  var iter {.global.}: TreeIter
  let indices: seq[int32] = @[0i32]
  var treePath: TreePath = newTreePathFromIndices(indices)

  var whileCond: bool = true
  while whileCond:
    var depth: int = treePath.getDepth()

    if store.getIter(iter, treePath):
      yield iter
      treePath.down()
    elif depth > 1:
      discard treePath.up()
      treePath.next()
    else:
      whileCond = false


iterator iterRec*(store: TreeStore, pIter: TreeIter): var TreeIter =
  var iter {.global.}: TreeIter
  var minDepth: int = store.getPath(pIter).getDepth()
  let indices: seq[int32] = store.getPath(pIter).getIndices(minDepth) # @[0i32]
  var treePath: TreePath = newTreePathFromIndices(indices)

  var whileCond: bool = true
  while whileCond:
    var depth: int = treePath.getDepth()

    if store.getIter(iter, treePath):
      yield iter
      treePath.down()
    elif depth - 1 > minDepth:
      discard treePath.up()
      treePath.next()
    else:
      whileCond = false
