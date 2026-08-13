//Hierarchy-safe, undoable scene-tree rearrangement for single and multiple
//selection. Insertion values mirror SceneEditorFramework_ObjectInsertionType;
//the plugin constants are loaded after this test script is compiled.
function start(){
    local INTO = 1;
    local ABOVE = 2;
    local BELOW = 3;

    local editorBase = ::SceneEditorFramework.Base();
    local parentNode = _scene.getRootSceneNode().createChildSceneNode();
    local tree = editorBase.loadSceneTree(parentNode, "res://test.avScene");
    editorBase.setActiveSceneTree(tree);

    local a = findId(tree, "A");
    local a1 = findId(tree, "A1");
    local b = findId(tree, "B");
    local c = findId(tree, "C");
    local d = findId(tree, "D");

    { //Moving into an entry reparents it, and undo/redo restore both the
      //flattened hierarchy and its engine scene-node hierarchy.
        tree.setSingleSelection(b);
        _test.assertTrue(tree.rearrangeCurrentSelection(a, INTO));
        assertParent(tree, b, a);
        _test.assertTrue(tree.isEntrySelected(b));
        assertPosition(tree, b, 1.0, 2.0, 3.0);
        assertNames(tree, ["A", "A1", "A2", "B", "C", "C1", "D"]);

        editorBase.mActionStack_.undo();
        assertTopLevelWith(tree, b, c);
        _test.assertTrue(tree.isEntrySelected(b));
        assertPosition(tree, b, 1.0, 2.0, 3.0);
        assertNames(tree, ["A", "A1", "A2", "B", "C", "C1", "D"]);

        editorBase.mActionStack_.redo();
        assertParent(tree, b, a);
        editorBase.mActionStack_.undo();
    }

    { //A parent moves with its complete subtree.
        tree.setSingleSelection(a);
        _test.assertTrue(tree.rearrangeCurrentSelection(c, BELOW));
        assertNames(tree, ["B", "C", "C1", "A", "A1", "A2", "D"]);
        assertParent(tree, a1, a);
        assertTopLevelWith(tree, a, c);
        editorBase.mActionStack_.undo();
    }

    { //Moving an only child removes its old empty marker pair and moving into
      //a leaf creates a new child group. Undo restores both shapes.
        local c1 = findId(tree, "C1");
        tree.setSingleSelection(c1);
        _test.assertTrue(tree.rearrangeCurrentSelection(b, INTO));
        assertParent(tree, c1, b);
        assertNames(tree, ["A", "A1", "A2", "B", "C1", "C", "D"]);

        editorBase.mActionStack_.undo();
        assertParent(tree, c1, c);
        assertTopLevelWith(tree, b, c);
    }

    { //Reduced multi-selection moves in tree order as one batch.
        tree.setSingleSelection(b);
        tree.notifySelectionChanged(d, true, false);
        _test.assertTrue(tree.rearrangeCurrentSelection(a, ABOVE));
        _test.assertEqual(2, tree.getSelectedCount());
        _test.assertTrue(tree.isEntrySelected(b));
        _test.assertTrue(tree.isEntrySelected(d));
        assertNames(tree, ["B", "D", "A", "A1", "A2", "C", "C1"]);
        assertTopLevelWith(tree, b, a);
        assertTopLevelWith(tree, d, a);

        editorBase.mActionStack_.undo();
        assertNames(tree, ["A", "A1", "A2", "B", "C", "C1", "D"]);
        editorBase.mActionStack_.redo();
        assertNames(tree, ["B", "D", "A", "A1", "A2", "C", "C1"]);
        editorBase.mActionStack_.undo();
    }

    { //A move cannot target its own subtree, and a move which changes nothing
      //does not create an undo action.
        local undoCount = editorBase.mActionStack_.mUndoStack_.len();
        tree.setSingleSelection(a);
        _test.assertFalse(tree.rearrangeCurrentSelection(a1, INTO));
        _test.assertEqual(undoCount, editorBase.mActionStack_.mUndoStack_.len());

        tree.setSingleSelection(b);
        _test.assertFalse(tree.rearrangeCurrentSelection(c, ABOVE));
        _test.assertEqual(undoCount, editorBase.mActionStack_.mUndoStack_.len());
        assertNames(tree, ["A", "A1", "A2", "B", "C", "C1", "D"]);
    }

    _test.endTest();
}

function findId(tree, name){
    foreach(entry in tree.mEntries_){
        if(entry.name == name) return entry.entryId;
    }
    return null;
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

function assertTopLevelWith(tree, firstId, secondId){
    local first = tree.getEntryForId(firstId);
    local second = tree.getEntryForId(secondId);
    _test.assertEqual(first.node.getParent().getId(), second.node.getParent().getId());
}

function assertPosition(tree, entryId, x, y, z){
    local position = tree.getEntryForId(entryId).node.getPositionVec3();
    _test.assertEqual(x, position.x);
    _test.assertEqual(y, position.y);
    _test.assertEqual(z, position.z);
}
