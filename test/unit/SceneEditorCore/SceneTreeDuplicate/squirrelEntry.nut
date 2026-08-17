//Dropping an alt-held drag in the scene tree leaves a copy of the selection at
//the destination instead of moving it there. Which key was held is the panel's
//business; this is what the tree does when it is asked for the copy.
//
//Insertion values mirror SceneEditorFramework_ObjectInsertionType; the plugin
//constants are loaded after this test script is compiled.
function start(){
    local INTO = 1;
    local ABOVE = 2;
    local BELOW = 3;
    local NONE = 0;

    local editorBase = ::SceneEditorFramework.Base();
    local parentNode = _scene.getRootSceneNode().createChildSceneNode();
    local tree = editorBase.loadSceneTree(parentNode, "res://test.avScene");
    editorBase.setActiveSceneTree(tree);

    local a = findId(tree, "A");
    local a1 = findId(tree, "A1");
    local b = findId(tree, "B");

    { //Nothing selected is nothing to copy, and nothing is pushed for it.
        tree.clearAllSelection();
        _test.assertFalse(tree.canDuplicateCurrentSelection(b, BELOW));
        _test.assertEqual(null, tree.duplicateCurrentSelection(b, BELOW));
        _test.assertEqual(0, editorBase.mActionStack_.mUndoStack_.len());
    }

    { //A duplicate takes the object's descendants with it, lands where the drop
      //asked, and leaves the copy selected in place of what was dragged.
        tree.setSingleSelection(a);
        _test.assertTrue(tree.canDuplicateCurrentSelection(b, INTO));

        local created = tree.duplicateCurrentSelection(b, INTO);
        _test.assertNotEqual(null, created);
        _test.assertEqual(1, created.len());

        local copyOfA = created[0];
        _test.assertNotEqual(a, copyOfA);
        //The original is still where it was, with the copy inside B.
        assertNames(tree, ["A", "A1", "B", "A", "A1"]);
        assertParent(tree, copyOfA, b);
        _test.assertEqual(1, tree.getSelectedCount());
        _test.assertTrue(tree.isEntrySelected(copyOfA));

        //The copy is an object of its own, carrying what the original carried.
        local copyOfA1 = childIdOf(tree, copyOfA);
        _test.assertNotEqual(a1, copyOfA1);
        assertParent(tree, copyOfA1, copyOfA);
        assertPosition(tree, copyOfA, 1.0, 2.0, 3.0);
        _test.assertEqual("cube", tree.getEntryForId(copyOfA).data.meshName);
        _test.assertEqual("sphere", tree.getEntryForId(copyOfA1).data.meshName);
        _test.assertEqual(1, tree.getEntryForId(copyOfA).node.getNumAttachedObjects());

        //Editing the copy leaves the original alone: the two share nothing.
        tree.getEntryForId(copyOfA1).data.meshName = "capsule";
        _test.assertEqual("sphere", tree.getEntryForId(a1).data.meshName);

        //One undo step for the whole drop, however much came along with it.
        _test.assertEqual(1, editorBase.mActionStack_.mUndoStack_.len());
        editorBase.mActionStack_.undo();
        assertNames(tree, ["A", "A1", "B"]);
        _test.assertEqual(null, tree.findEntryIdIndexInTree_(copyOfA));
        _test.assertEqual(null, tree.findEntryIdIndexInTree_(copyOfA1));

        editorBase.mActionStack_.redo();
        assertNames(tree, ["A", "A1", "B", "A", "A1"]);
        editorBase.mActionStack_.undo();
    }

    { //A copy may be dropped inside the object it was copied from, which a move
      //cannot be: what is copied is described before anything is inserted, so
      //the copy is of what the subtree was rather than of what it is becoming.
        tree.setSingleSelection(a);
        _test.assertFalse(tree.canRearrangeCurrentSelection(a1, INTO));
        _test.assertTrue(tree.canDuplicateCurrentSelection(a1, INTO));

        local created = tree.duplicateCurrentSelection(a1, INTO);
        _test.assertNotEqual(null, created);
        assertNames(tree, ["A", "A1", "A", "A1", "B"]);
        assertParent(tree, created[0], a1);

        editorBase.mActionStack_.undo();
        assertNames(tree, ["A", "A1", "B"]);
    }

    { //A selected object below another selected one is copied once, as part of
      //its parent, rather than a second time on its own.
        tree.setSingleSelection(a);
        tree.toggleEntrySelection(a1);
        _test.assertEqual(2, tree.getSelectedCount());

        local created = tree.duplicateCurrentSelection(b, BELOW);
        _test.assertEqual(1, created.len());
        assertNames(tree, ["A", "A1", "B", "A", "A1"]);

        editorBase.mActionStack_.undo();
        assertNames(tree, ["A", "A1", "B"]);
    }

    { //Nowhere to put it is not a drop the tree acts on.
        tree.setSingleSelection(a);
        _test.assertFalse(tree.canDuplicateCurrentSelection(null, BELOW));
        _test.assertFalse(tree.canDuplicateCurrentSelection(b, NONE));
        _test.assertEqual(null, tree.duplicateCurrentSelection(b, NONE));
        assertNames(tree, ["A", "A1", "B"]);
        _test.assertEqual(0, editorBase.mActionStack_.mUndoStack_.len());
    }

    { //Copying above the object rather than into it puts the copy beside it.
        tree.setSingleSelection(b);
        local created = tree.duplicateCurrentSelection(a, ABOVE);
        _test.assertEqual(1, created.len());
        assertNames(tree, ["B", "A", "A1", "B"]);

        editorBase.mActionStack_.undo();
        assertNames(tree, ["A", "A1", "B"]);
    }

    _test.endTest();
}

function findId(tree, name){
    foreach(entry in tree.mEntries_){
        if(entry.name == name) return entry.entryId;
    }
    return null;
}

//The first entry below an object in the flattened tree.
function childIdOf(tree, entryId){
    local index = tree.findEntryIdIndexInTree_(entryId);
    if(index == null || !tree.itemHasChildren_(index)) return null;
    return tree.mEntries_[index + 2].entryId;
}

function objectNames(tree){
    local result = [];
    foreach(entry in tree.mEntries_){
        if(entry.name != null) result.append(entry.name);
    }
    return result;
}

function assertNames(tree, expected){
    local actual = objectNames(tree);
    _test.assertEqual(expected.len(), actual.len());
    for(local i = 0; i < expected.len(); i++){
        _test.assertEqual(expected[i], actual[i]);
    }
}

function assertParent(tree, childId, parentId){
    local child = tree.getEntryForId(childId);
    local parent = tree.getEntryForId(parentId);
    _test.assertEqual(parent.node.getId(), child.node.getParent().getId());
}

function assertPosition(tree, entryId, x, y, z){
    local position = tree.getEntryForId(entryId).node.getPositionVec3();
    _test.assertEqual(x, position.x);
    _test.assertEqual(y, position.y);
    _test.assertEqual(z, position.z);
}
