//Reparenting a selection with a new empty is one undoable step: the empty is
//created where the most recently selected object was, and everything in the
//reduced selection moves under it.
function start(){
    local editorBase = ::SceneEditorFramework.Base();
    local parentNode = _scene.getRootSceneNode().createChildSceneNode();
    local tree = editorBase.loadSceneTree(parentNode, "res://test.avScene");
    editorBase.setActiveSceneTree(tree);

    local a = findId(tree, "A");
    local a1 = findId(tree, "A1");
    local b = findId(tree, "B");
    local c = findId(tree, "C");
    local c1 = findId(tree, "C1");
    local d = findId(tree, "D");

    { //A single selection is replaced in its parent by the empty, and undo and
      //redo restore both layouts along with the created id.
        tree.setSingleSelection(b);
        local group = tree.reparentSelectionWithEmpty("Group");
        _test.assertNotEqual(null, group);
        _test.assertEqual(nodeType("empty"), tree.getEntryForId(group).nodeType);
        assertNames(tree, ["A", "A1", "A2", "Group", "B", "C", "C1", "D"]);
        assertParent(tree, b, group);
        assertTopLevelWith(tree, group, c);
        //The empty sits at the origin of the parent the object had, so the
        //object it now hangs from has not moved it.
        assertPosition(tree, b, 1.0, 2.0, 3.0);
        //Reparenting is not a selection change - what was picked stays picked.
        _test.assertTrue(tree.isEntrySelected(b));

        local action = editorBase.mActionStack_.mUndoStack_.top();
        _test.assertEqual(group, action.mCreatedEntryId_);

        editorBase.mActionStack_.undo();
        _test.assertEqual(null, tree.findEntryIdIndexInTree_(group));
        assertNames(tree, ["A", "A1", "A2", "B", "C", "C1", "D"]);
        assertTopLevelWith(tree, b, c);

        editorBase.mActionStack_.redo();
        assertNames(tree, ["A", "A1", "A2", "Group", "B", "C", "C1", "D"]);
        assertParent(tree, b, group);

        editorBase.mActionStack_.undo();
    }

    { //A multiple selection is gathered in tree order at the index of the entry
      //which was selected last, rather than at that of the first of them.
        tree.setSingleSelection(b);
        tree.notifySelectionChanged(d, true, false);
        local group = tree.reparentSelectionWithEmpty("Group");
        assertNames(tree, ["A", "A1", "A2", "C", "C1", "Group", "B", "D"]);
        assertParent(tree, b, group);
        assertParent(tree, d, group);

        editorBase.mActionStack_.undo();
        assertNames(tree, ["A", "A1", "A2", "B", "C", "C1", "D"]);
    }

    { //Selecting a parent and one of its descendants moves that subtree once,
      //and the descendant does not decide where the empty goes.
        tree.setSingleSelection(a);
        tree.notifySelectionChanged(a1, true, false);
        local group = tree.reparentSelectionWithEmpty("Group");
        assertNames(tree, ["Group", "A", "A1", "A2", "B", "C", "C1", "D"]);
        assertParent(tree, a, group);
        assertParent(tree, a1, a);

        editorBase.mActionStack_.undo();
        assertNames(tree, ["A", "A1", "A2", "B", "C", "C1", "D"]);
        assertParent(tree, a1, a);
    }

    { //An only child keeps its parent: the empty is created inside that parent,
      //so the child group it lives in is not left empty and removed.
        tree.setSingleSelection(c1);
        local group = tree.reparentSelectionWithEmpty("Group");
        assertNames(tree, ["A", "A1", "A2", "B", "C", "Group", "C1", "D"]);
        assertParent(tree, group, c);
        assertParent(tree, c1, group);

        editorBase.mActionStack_.undo();
        assertNames(tree, ["A", "A1", "A2", "B", "C", "C1", "D"]);
        assertParent(tree, c1, c);
    }

    { //With nothing selected there is nothing to gather, and an attempt is not
      //allowed to leave an action behind for undo to run.
        local undoCount = editorBase.mActionStack_.mUndoStack_.len();
        tree.clearAllSelection();
        _test.assertEqual(null, tree.reparentSelectionWithEmpty("Group"));
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

function nodeType(name){
    return ::SceneEditorFramework.FileParser().getNodeTypeForName(name);
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
