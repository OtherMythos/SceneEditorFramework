//What the selection means once the object it names is gone.
//
//Everything an editor does to an object - the properties panel, the gizmos, the
//options offered for a right clicked object - goes through the selection, so a
//selection which outlives its entry is a selection pointing at an entry which is
//no longer in the tree.
function start(){
    local editorBase = ::SceneEditorFramework.Base();
    local parentNode = _scene.getRootSceneNode().createChildSceneNode();
    local tree = editorBase.loadSceneTree(parentNode, "res://test.avScene");
    editorBase.setActiveSceneTree(tree);

    local targetId = findFirstObjectId(tree);
    _test.assertNotEqual(null, targetId);

    { //Selecting names the entry.
        tree.notifySelectionChanged(targetId);
        _test.assertEqual(targetId, tree.mCurrentSelection);
    }

    { //Selecting nothing - clicking empty space in the scene tree, say - names
      //nothing rather than leaving the previous entry named.
        tree.notifySelectionChanged(null);
        _test.assertEqual(-1, tree.mCurrentSelection);
        _test.assertEqual(-1, tree.mCurrentSelectionIdx);
    }

    { //Deleting the selection removes the entry and clears the selection with
      //it, so nothing is left naming a deleted entry.
        tree.notifySelectionChanged(targetId);
        tree.deleteCurrentSelection();

        _test.assertEqual(null, tree.findEntryIdIndexInTree_(targetId));
        _test.assertEqual(-1, tree.mCurrentSelection);
        _test.assertEqual(-1, tree.mCurrentSelectionIdx);
    }

    { //A position outside the scene viewport is over nothing, rather than an
      //error. @see SceneTree.findEntryIdAtScenePosition
        _test.assertEqual(null, tree.findEntryIdAtScenePosition(null));
    }

    _test.endTest();
}

//The first entry which is an object rather than one of the markers which give
//the flattened tree its shape.
//
//Found by name rather than by node type, because the framework's enums are
//squirrel constants: they exist once the plugin's scripts have run, which is
//after this file was compiled, so naming one here would not resolve.
function findFirstObjectId(tree){
    foreach(entry in tree.mEntries_){
        if(entry.name == null) continue;

        return entry.entryId;
    }

    return null;
}
