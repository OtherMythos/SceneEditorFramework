//Single, additive, range and reduced scene-tree selection, including what the
//selection means once an object it names is gone.
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

    local firstId = findObjectId(tree, "First");
    local firstChildId = findObjectId(tree, "First child");
    local secondId = findObjectId(tree, "Second");
    local thirdId = findObjectId(tree, "Third");
    _test.assertNotEqual(null, firstId);
    _test.assertNotEqual(null, firstChildId);
    _test.assertNotEqual(null, secondId);
    _test.assertNotEqual(null, thirdId);

    { //Selecting names the entry.
        tree.notifySelectionChanged(firstId);
        _test.assertEqual(firstId, tree.mCurrentSelection);
        _test.assertEqual(1, tree.getSelectedCount());
        _test.assertTrue(tree.isEntrySelected(firstId));
        _test.assertEqual(firstId, tree.getFirstSelection());
    }

    { //Control adds to the selection. Clicking one of the selected entries
      //again without modifiers keeps the group ready for dragging.
        tree.notifySelectionChanged(secondId, true, false);
        _test.assertEqual(2, tree.getSelectedCount());
        _test.assertTrue(tree.isEntrySelected(firstId));
        _test.assertTrue(tree.isEntrySelected(secondId));

        tree.notifySelectionChanged(firstId);
        _test.assertEqual(2, tree.getSelectedCount());
        _test.assertEqual(firstId, tree.mCurrentSelection);
    }

    { //An ordinary click on an unselected entry starts a new selection.
        tree.notifySelectionChanged(thirdId);
        _test.assertEqual(1, tree.getSelectedCount());
        _test.assertTrue(tree.isEntrySelected(thirdId));
        _test.assertFalse(tree.isEntrySelected(firstId));
    }

    { //Shift selects every object in the flattened tree between the most
      //recent selection and the clicked entry, ignoring hierarchy markers.
        tree.notifySelectionChanged(firstId, false, true);
        _test.assertEqual(4, tree.getSelectedCount());
        _test.assertTrue(tree.isEntrySelected(firstId));
        _test.assertTrue(tree.isEntrySelected(firstChildId));
        _test.assertTrue(tree.isEntrySelected(secondId));
        _test.assertTrue(tree.isEntrySelected(thirdId));
    }

    { //A reduced selection omits a selected descendant when its parent is
      //also selected; reordering actions can operate on this list directly.
        local reduced = tree.getReducedSelection();
        _test.assertEqual(3, reduced.len());
        _test.assertTrue(arrayContains(reduced, firstId));
        _test.assertFalse(arrayContains(reduced, firstChildId));
    }

    { //Selecting nothing - clicking empty space in the scene tree, say - names
      //nothing rather than leaving the previous entry named.
        tree.notifySelectionChanged(null);
        _test.assertEqual(-1, tree.mCurrentSelection);
        _test.assertEqual(-1, tree.mCurrentSelectionIdx);
        _test.assertEqual(0, tree.getSelectedCount());
    }

    { //Deleting a multi-selection removes every selected entry and clears the
      //selection, so nothing is left naming a deleted entry.
        tree.notifySelectionChanged(secondId);
        tree.notifySelectionChanged(thirdId, true, false);
        tree.deleteCurrentSelection();

        _test.assertEqual(null, tree.findEntryIdIndexInTree_(secondId));
        _test.assertEqual(null, tree.findEntryIdIndexInTree_(thirdId));
        _test.assertNotEqual(null, tree.findEntryIdIndexInTree_(firstId));
        _test.assertEqual(-1, tree.mCurrentSelection);
        _test.assertEqual(-1, tree.mCurrentSelectionIdx);
        _test.assertEqual(0, tree.getSelectedCount());
    }

    { //A position outside the scene viewport is over nothing, rather than an
      //error. @see SceneTree.findEntryIdAtScenePosition
        _test.assertEqual(null, tree.findEntryIdAtScenePosition(null));
        _test.assertEqual(0, tree.findEntryIdsAtScenePosition(null).len());
    }

    _test.endTest();
}

//The first entry which is an object rather than one of the markers which give
//the flattened tree its shape.
//
//Found by name rather than by node type, because the framework's enums are
//squirrel constants: they exist once the plugin's scripts have run, which is
//after this file was compiled, so naming one here would not resolve.
function findObjectId(tree, name){
    foreach(entry in tree.mEntries_){
        if(entry.name == name) return entry.entryId;
    }

    return null;
}

function arrayContains(values, target){
    foreach(value in values){
        if(value == target) return true;
    }
    return false;
}
