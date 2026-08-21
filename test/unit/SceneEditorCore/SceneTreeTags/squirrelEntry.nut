//The tag an object is found by, which is unique within a scene: at most one
//object carries any given tag, so claiming one which is taken is refused rather
//than moving it. Claiming and giving up a tag are both undoable.
function start(){
    local editorBase = ::SceneEditorFramework.Base();
    local parentNode = _scene.getRootSceneNode().createChildSceneNode();
    local tree = editorBase.loadSceneTree(parentNode, "res://test.avScene");
    editorBase.setActiveSceneTree(tree);

    local a = findId(tree, "A");
    local a1 = findId(tree, "A1");
    local b = findId(tree, "B");
    local c = findId(tree, "C");

    { //Tags come out of the file, and an object without one carries null.
        _test.assertEqual("playerStart", tree.getEntryForId(a).tag);
        _test.assertEqual(null, tree.getEntryForId(a1).tag);

        //The file claims 'exit' twice. The first claim is kept and the second
        //is dropped, rather than a tree being loaded which the engine would
        //then refuse to parse back.
        _test.assertEqual("exit", tree.getEntryForId(b).tag);
        _test.assertEqual(null, tree.getEntryForId(c).tag);
    }

    { //A tag names the one object carrying it, and nothing else.
        _test.assertEqual(a, tree.getEntryIdForTag("playerStart"));
        _test.assertEqual(b, tree.getEntryIdForTag("exit"));
        _test.assertEqual(null, tree.getEntryIdForTag("nothingHasThis"));
        _test.assertEqual(null, tree.getEntryIdForTag(null));
    }

    { //Claiming a free tag is one undoable step.
        local undoCount = editorBase.mActionStack_.mUndoStack_.len();
        _test.assertTrue(tree.setEntryTag(a1, "checkpoint"));
        _test.assertEqual("checkpoint", tree.getEntryForId(a1).tag);
        _test.assertEqual(a1, tree.getEntryIdForTag("checkpoint"));
        _test.assertEqual(undoCount + 1, editorBase.mActionStack_.mUndoStack_.len());

        editorBase.mActionStack_.undo();
        _test.assertEqual(null, tree.getEntryForId(a1).tag);
        _test.assertEqual(null, tree.getEntryIdForTag("checkpoint"));

        editorBase.mActionStack_.redo();
        _test.assertEqual("checkpoint", tree.getEntryForId(a1).tag);
    }

    { //A tag another object holds is refused, and nothing is pushed for it:
      //which of the two was meant to keep it is not the tree's decision.
        local undoCount = editorBase.mActionStack_.mUndoStack_.len();
        _test.assertFalse(tree.setEntryTag(c, "exit"));
        _test.assertEqual(null, tree.getEntryForId(c).tag);
        _test.assertEqual(b, tree.getEntryIdForTag("exit"));
        _test.assertEqual(undoCount, editorBase.mActionStack_.mUndoStack_.len());

        //The object already holding a tag is allowed to ask for it again, which
        //is what a properties field committing an unchanged value does. That is
        //no change, so nothing is pushed for it either.
        _test.assertTrue(tree.isTagAvailable("exit", b));
        _test.assertFalse(tree.setEntryTag(b, "exit"));
        _test.assertEqual("exit", tree.getEntryForId(b).tag);
        _test.assertEqual(undoCount, editorBase.mActionStack_.mUndoStack_.len());
    }

    { //A tag freed by its holder can then be claimed by another object.
        _test.assertTrue(tree.clearEntryTag(b));
        _test.assertEqual(null, tree.getEntryForId(b).tag);
        _test.assertTrue(tree.setEntryTag(c, "exit"));
        _test.assertEqual(c, tree.getEntryIdForTag("exit"));

        //Undoing the claim frees it again, and undoing the clear puts it back
        //where it was.
        editorBase.mActionStack_.undo();
        _test.assertEqual(null, tree.getEntryIdForTag("exit"));
        editorBase.mActionStack_.undo();
        _test.assertEqual(b, tree.getEntryIdForTag("exit"));
    }

    { //An empty tag is no tag rather than a tag which is the empty string,
      //which is what an emptied properties field asks for.
        _test.assertTrue(tree.setEntryTag(c, "spawn"));
        _test.assertTrue(tree.setEntryTag(c, ""));
        _test.assertEqual(null, tree.getEntryForId(c).tag);
        _test.assertFalse(tree.setEntryTag(c, ""));

        //Clearing a tag is always allowed, whatever else the scene holds.
        _test.assertTrue(tree.isTagAvailable(null, c));
        _test.assertTrue(tree.isTagAvailable(null, null));
    }

    { //A pasted copy is a new object, so it does not take the original's tag -
      //which would be a second claim on it.
        local clipboard = editorBase.getClipboard();
        tree.setSingleSelection(a);
        _test.assertTrue(tree.copySelectionToClipboard(clipboard));
        //Marker values mirror SceneEditorFramework_SceneTreeEntryType; the
        //plugin constants are loaded after this test script is compiled.
        local CHILD = 1;
        local TERM = 2;
        foreach(entry in clipboard.getEntries()){
            if(entry.nodeType == CHILD || entry.nodeType == TERM) continue;
            _test.assertEqual(null, entry.tag);
        }

        local pasted = tree.pasteFromClipboardAtTopLevel(clipboard);
        _test.assertEqual(1, pasted.len());
        _test.assertEqual(null, tree.getEntryForId(pasted[0]).tag);
        //The object copied from still holds it.
        _test.assertEqual(a, tree.getEntryIdForTag("playerStart"));

        editorBase.mActionStack_.undo();
    }

    { //Tags survive a write and a read back, and a duplicate cannot be written
      //because the tree cannot be made to hold one.
        editorBase.writeSceneFile("res://written.avScene");

        local secondNode = _scene.getRootSceneNode().createChildSceneNode();
        local reloaded = editorBase.loadSceneTree(secondNode, "res://written.avScene");
        _test.assertEqual("playerStart", reloaded.getEntryForId(findId(reloaded, "A")).tag);
        _test.assertEqual("exit", reloaded.getEntryForId(findId(reloaded, "B")).tag);
        _test.assertEqual(null, reloaded.getEntryForId(findId(reloaded, "C")).tag);
    }

    _test.endTest();
}

function findId(tree, name){
    foreach(entry in tree.mEntries_){
        if(entry.name == name) return entry.entryId;
    }
    return null;
}
