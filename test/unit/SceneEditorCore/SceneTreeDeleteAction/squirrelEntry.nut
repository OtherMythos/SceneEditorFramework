//Deleting a multiple selection acts on its reduced form: selecting a parent
//and one of its descendants must delete that subtree once, alongside any other
//independently selected entries.
function start(){
    local editorBase = ::SceneEditorFramework.Base();
    local parentNode = _scene.getRootSceneNode().createChildSceneNode();
    local tree = editorBase.loadSceneTree(parentNode, "res://test.avScene");
    editorBase.setActiveSceneTree(tree);

    local parent = findId(tree, "Parent");
    local firstChild = findId(tree, "First child");
    local secondChild = findId(tree, "Second child");
    local middle = findId(tree, "Middle");
    local otherParent = findId(tree, "Other parent");
    local onlyChild = findId(tree, "Only child");
    local tail = findId(tree, "Tail");

    tree.setSingleSelection(parent);
    tree.notifySelectionChanged(firstChild, true, false);
    tree.notifySelectionChanged(onlyChild, true, false);
    _test.assertEqual(3, tree.getSelectedCount());

    local reduced = tree.getReducedSelection();
    _test.assertEqual(2, reduced.len());
    _test.assertTrue(arrayContains(reduced, parent));
    _test.assertFalse(arrayContains(reduced, firstChild));
    _test.assertTrue(arrayContains(reduced, onlyChild));

    tree.deleteCurrentSelection();

    //Both independent targets were given to one action. The descendant of the
    //selected parent was omitted, avoiding a second deletion of the same node.
    local action = editorBase.mActionStack_.mUndoStack_.top();
    _test.assertEqual(2, action.mSelectedEntries_.len());
    _test.assertTrue(arrayContains(action.mSelectedEntries_, parent));
    _test.assertTrue(arrayContains(action.mSelectedEntries_, onlyChild));

    _test.assertEqual(null, tree.findEntryIdIndexInTree_(parent));
    _test.assertEqual(null, tree.findEntryIdIndexInTree_(firstChild));
    _test.assertEqual(null, tree.findEntryIdIndexInTree_(secondChild));
    _test.assertEqual(null, tree.findEntryIdIndexInTree_(onlyChild));
    _test.assertNotEqual(null, tree.findEntryIdIndexInTree_(middle));
    _test.assertNotEqual(null, tree.findEntryIdIndexInTree_(otherParent));
    _test.assertNotEqual(null, tree.findEntryIdIndexInTree_(tail));
    assertNames(tree, ["Middle", "Other parent", "Tail"]);

    //Deleting the only child removes its now-empty hierarchy markers as well.
    local otherParentIndex = tree.findEntryIdIndexInTree_(otherParent);
    _test.assertFalse(tree.itemHasChildren_(otherParentIndex));
    _test.assertEqual(0, tree.getEntryForId(otherParent).node.getNumChildren());

    _test.assertEqual(0, tree.getSelectedCount());
    _test.assertEqual(-1, tree.mCurrentSelection);
    _test.assertEqual(-1, tree.mCurrentSelectionIdx);

    //Only object IDs, never CHILD/TERM marker nulls, go back into the pool.
    local recycled = {};
    for(local i = 0; i < 4; i++){
        local id = tree.getId();
        _test.assertNotEqual(null, id);
        _test.assertFalse(recycled.rawin(id));
        recycled.rawset(id, true);
    }

    _test.endTest();
}

function findId(tree, name){
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

function assertNames(tree, expected){
    local actual = [];
    foreach(entry in tree.mEntries_){
        if(entry.name != null) actual.append(entry.name);
    }

    _test.assertEqual(expected.len(), actual.len());
    for(local i = 0; i < expected.len(); i++){
        _test.assertEqual(expected[i], actual[i]);
    }
}
