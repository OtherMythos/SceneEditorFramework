//Taking the selection out of sight and bringing it back, which is what the
//editor's H shortcut asks the tree for. One keypress is one undo step however
//many objects it covered.
function start(){
    local editorBase = ::SceneEditorFramework.Base();
    local parentNode = _scene.getRootSceneNode().createChildSceneNode();
    local tree = editorBase.loadSceneTree(parentNode, "res://test.avScene");
    editorBase.setActiveSceneTree(tree);

    local a = findId(tree, "A");
    local a1 = findId(tree, "A1");
    local b = findId(tree, "B");
    local c = findId(tree, "C");

    { //Nothing selected is nothing to hide, and nothing is pushed for it.
        tree.clearAllSelection();
        _test.assertFalse(tree.toggleSelectionVisibility());
        _test.assertEqual(0, editorBase.mActionStack_.mUndoStack_.len());
    }

    { //One selected object goes out of sight and comes back.
        tree.setSingleSelection(b);
        _test.assertTrue(tree.toggleSelectionVisibility());
        assertVisible(tree, b, false);
        _test.assertEqual(1, editorBase.mActionStack_.mUndoStack_.len());

        _test.assertTrue(tree.toggleSelectionVisibility());
        assertVisible(tree, b, true);

        editorBase.mActionStack_.undo();
        assertVisible(tree, b, false);
        editorBase.mActionStack_.undo();
        assertVisible(tree, b, true);
    }

    { //A selection with anything still showing in it is hidden, rather than
      //each object being flipped against its own state - which would leave a
      //mixed selection mixed the other way round.
        tree.setSingleSelection(b);
        tree.toggleEntrySelection(c);
        tree.toggleSelectionVisibility();
        assertVisible(tree, b, false);
        assertVisible(tree, c, false);

        //Only B back, so the selection is mixed again.
        tree.setSingleSelection(b);
        tree.toggleSelectionVisibility();
        assertVisible(tree, b, true);

        tree.toggleEntrySelection(c);
        local undoCount = editorBase.mActionStack_.mUndoStack_.len();
        tree.toggleSelectionVisibility();
        assertVisible(tree, b, false);
        assertVisible(tree, c, false);

        //One step for the pair, and only B is put back by it: C was already
        //hidden and so was not part of the change.
        _test.assertEqual(undoCount + 1, editorBase.mActionStack_.mUndoStack_.len());
        editorBase.mActionStack_.undo();
        assertVisible(tree, b, true);
        assertVisible(tree, c, false);

        //Everything hidden is the only selection which comes back.
        tree.setSingleSelection(c);
        tree.toggleSelectionVisibility();
        assertVisible(tree, c, true);
    }

    { //A selected object below another selected one is left as it is: hiding
      //its parent already takes it out of sight, and its own flag is what it
      //goes back to being when the parent is shown again.
        tree.setSingleSelection(a);
        tree.toggleEntrySelection(a1);
        _test.assertTrue(tree.toggleSelectionVisibility());
        assertVisible(tree, a, false);
        assertVisible(tree, a1, true);

        editorBase.mActionStack_.undo();
        assertVisible(tree, a, true);
        assertVisible(tree, a1, true);
    }

    { //A selection which is already entirely hidden by a previous press is
      //brought back by the next one, whatever else in the scene is hidden.
        tree.setSingleSelection(a);
        tree.toggleSelectionVisibility();
        assertVisible(tree, a, false);
        tree.setSingleSelection(b);
        tree.toggleSelectionVisibility();
        assertVisible(tree, b, false);

        tree.setSingleSelection(a);
        tree.toggleEntrySelection(b);
        tree.toggleSelectionVisibility();
        assertVisible(tree, a, true);
        assertVisible(tree, b, true);
    }

    _test.endTest();
}

function findId(tree, name){
    foreach(entry in tree.mEntries_){
        if(entry.name == name) return entry.entryId;
    }
    return null;
}

function assertVisible(tree, entryId, expected){
    local entry = tree.getEntryForId(entryId);
    if(expected) _test.assertTrue(entry.visible);
    else _test.assertFalse(entry.visible);
}
