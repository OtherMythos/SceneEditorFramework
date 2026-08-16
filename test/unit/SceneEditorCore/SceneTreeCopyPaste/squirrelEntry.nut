//Copying the selection into the clipboard, and pasting it back as an undoable
//action. Insertion values mirror SceneEditorFramework_ObjectInsertionType; the
//plugin constants are loaded after this test script is compiled.
function start(){
    local INTO = 1;
    local BELOW = 3;

    local editorBase = ::SceneEditorFramework.Base();
    local parentNode = _scene.getRootSceneNode().createChildSceneNode();
    local tree = editorBase.loadSceneTree(parentNode, "res://test.avScene");
    editorBase.setActiveSceneTree(tree);

    local clipboard = editorBase.getClipboard();
    local a = findId(tree, "A");
    local a1 = findId(tree, "A1");
    local b = findId(tree, "B");
    local c = findId(tree, "C");

    { //A copy with nothing selected leaves the clipboard as it was.
        tree.clearAllSelection();
        _test.assertFalse(clipboard.hasEntries());
        _test.assertFalse(clipboard.copyFromTree(tree));
        _test.assertFalse(clipboard.hasEntries());
        _test.assertEqual(null, tree.pasteFromClipboard(clipboard));
        _test.assertEqual(0, editorBase.mActionStack_.mUndoStack_.len());
    }

    { //A copied subtree is detached: no entry ids, no scene nodes, and its own
      //copies of the transform and the entry data.
        tree.setSingleSelection(a);
        _test.assertTrue(tree.copySelectionToClipboard(clipboard));
        _test.assertTrue(clipboard.hasEntries());
        _test.assertEqual(1, clipboard.getCopiedCount());

        //A copied object is followed by its descendants wrapped in the same
        //CHILD and TERM markers the tree itself uses, so what the clipboard
        //holds describes the hierarchy rather than a flat list of objects.
        //Marker values mirror SceneEditorFramework_SceneTreeEntryType.
        local CHILD = 1;
        local TERM = 2;
        local MESH = nodeType("mesh");
        assertLayout(clipboard.getEntries(), [MESH, CHILD, MESH, TERM]);
        assertCopiedNames(clipboard, ["A", "A1"]);

        local copiedMesh = clipboardEntry(clipboard, "A1");
        _test.assertEqual("cube", copiedMesh.data.meshName);
        _test.assertEqual(1.0, copiedMesh.position.x);
        _test.assertEqual(2.0, copiedMesh.position.y);
        _test.assertEqual(3.0, copiedMesh.position.z);
        _test.assertEqual(2.0, copiedMesh.scale.x);
    }

    { //Pasting builds real entries below the object the copy was taken from,
      //and what was pasted becomes the selection.
        local pasted = tree.pasteFromClipboard(clipboard);
        _test.assertNotEqual(null, pasted);
        _test.assertEqual(1, pasted.len());

        local pastedA = pasted[0];
        _test.assertNotEqual(a, pastedA);
        assertNames(tree, ["A", "A1", "A", "A1", "B", "C"]);
        assertTopLevelWith(tree, pastedA, a);
        _test.assertEqual(1, tree.getSelectedCount());
        _test.assertTrue(tree.isEntrySelected(pastedA));
        _test.assertEqual(pastedA, tree.mCurrentSelection);

        //The pasted child is a child of the pasted parent rather than of the
        //original, and carries the same transform and mesh.
        local pastedA1 = childIdOf(tree, pastedA);
        _test.assertNotEqual(a1, pastedA1);
        assertParent(tree, pastedA1, pastedA);
        assertPosition(tree, pastedA1, 1.0, 2.0, 3.0);
        _test.assertEqual("cube", tree.getEntryForId(pastedA1).data.meshName);
        _test.assertEqual(1, tree.getEntryForId(pastedA1).node.getNumAttachedObjects());

        //Editing the paste changes neither the original nor the clipboard, so
        //the next paste is still of what was copied.
        tree.getEntryForId(pastedA1).data.meshName = "capsule";
        _test.assertEqual("cube", tree.getEntryForId(a1).data.meshName);
        _test.assertEqual("cube", clipboardEntry(clipboard, "A1").data.meshName);

        //Undo removes the whole paste, and redo brings it back with the ids it
        //had, so anything else on the stack still names the same objects.
        editorBase.mActionStack_.undo();
        assertNames(tree, ["A", "A1", "B", "C"]);
        _test.assertEqual(null, tree.findEntryIdIndexInTree_(pastedA));
        _test.assertEqual(null, tree.findEntryIdIndexInTree_(pastedA1));

        editorBase.mActionStack_.redo();
        assertNames(tree, ["A", "A1", "A", "A1", "B", "C"]);
        _test.assertNotEqual(null, tree.findEntryIdIndexInTree_(pastedA));
        _test.assertEqual(pastedA1, childIdOf(tree, pastedA));
        _test.assertTrue(tree.isEntrySelected(pastedA));

        editorBase.mActionStack_.undo();
    }

    { //The same clipboard can be pasted repeatedly, each paste creating objects
      //of its own. The second lands beside the first, which the first paste
      //left selected.
        tree.setSingleSelection(a);
        local first = tree.pasteFromClipboard(clipboard)[0];
        local second = tree.pasteFromClipboard(clipboard)[0];
        _test.assertNotEqual(first, second);
        _test.assertNotEqual(childIdOf(tree, first), childIdOf(tree, second));
        assertNames(tree, ["A", "A1", "A", "A1", "A", "A1", "B", "C"]);

        editorBase.mActionStack_.undo();
        editorBase.mActionStack_.undo();
        assertNames(tree, ["A", "A1", "B", "C"]);
    }

    { //A paste can be aimed at an entry rather than at the selection, which is
      //what the scene tree's right click menu does: what is pasted becomes a
      //child of the object which was right clicked, whatever is selected at the
      //time. Pasting into a leaf gives it the child group it did not have.
        tree.setSingleSelection(c);
        local pasted = tree.pasteFromClipboard(clipboard, b, INTO);
        _test.assertNotEqual(null, pasted);
        assertParent(tree, pasted[0], b);
        assertNames(tree, ["A", "A1", "B", "A", "A1", "C"]);

        //The copied object's own child comes with it, below it rather than
        //beside it under the object which was pasted into.
        local pastedChild = childIdOf(tree, pasted[0]);
        _test.assertNotEqual(null, pastedChild);
        assertParent(tree, pastedChild, pasted[0]);
        _test.assertEqual(1, tree.getEntryForId(b).node.getNumChildren());

        editorBase.mActionStack_.undo();
        assertNames(tree, ["A", "A1", "B", "C"]);
        _test.assertFalse(tree.itemHasChildren_(tree.findEntryIdIndexInTree_(b)));
    }

    { //Pasting into an object which already has children adds to them rather
      //than replacing the group.
        local pasted = tree.pasteFromClipboard(clipboard, a, INTO);
        _test.assertNotEqual(null, pasted);
        assertParent(tree, pasted[0], a);
        assertNames(tree, ["A", "A1", "A", "A1", "B", "C"]);
        _test.assertEqual(2, tree.getEntryForId(a).node.getNumChildren());

        editorBase.mActionStack_.undo();
        assertNames(tree, ["A", "A1", "B", "C"]);
        _test.assertEqual(1, tree.getEntryForId(a).node.getNumChildren());
    }

    { //Selecting a parent as well as one of its children copies that child once,
      //as part of its parent.
        tree.setSingleSelection(a);
        tree.notifySelectionChanged(a1, true, false);
        tree.notifySelectionChanged(c, true, false);
        _test.assertEqual(3, tree.getSelectedCount());
        _test.assertTrue(clipboard.copyFromTree(tree));
        _test.assertEqual(2, clipboard.getCopiedCount());
        //A copies with its child group, C follows it as a second top level
        //object rather than as one of A's children.
        assertLayout(clipboard.getEntries(),
            [nodeType("mesh"), 1, nodeType("mesh"), 2, nodeType("mesh")]);
        assertCopiedNames(clipboard, ["A", "A1", "C"]);

        local pasted = tree.pasteFromClipboard(clipboard, c, BELOW);
        _test.assertEqual(2, pasted.len());
        assertNames(tree, ["A", "A1", "B", "C", "A", "A1", "C"]);
        assertTopLevelWith(tree, pasted[0], a);
        _test.assertEqual(2, tree.getSelectedCount());
        _test.assertTrue(tree.isEntrySelected(pasted[0]));
        _test.assertTrue(tree.isEntrySelected(pasted[1]));

        editorBase.mActionStack_.undo();
        assertNames(tree, ["A", "A1", "B", "C"]);
    }

    { //The clipboard describes what was copied rather than pointing at it, so
      //it outlives the objects it was taken from. With them gone there is no
      //selection to paste beside, and the paste goes in at the top level.
        tree.setSingleSelection(a);
        _test.assertTrue(clipboard.copyFromTree(tree));
        tree.deleteCurrentSelection();
        assertNames(tree, ["B", "C"]);
        _test.assertEqual(-1, tree.mCurrentSelection);

        local pasted = tree.pasteFromClipboard(clipboard);
        _test.assertNotEqual(null, pasted);
        assertNames(tree, ["B", "C", "A", "A1"]);
        assertTopLevelWith(tree, pasted[0], b);
        _test.assertEqual("cube", tree.getEntryForId(childIdOf(tree, pasted[0])).data.meshName);

        editorBase.mActionStack_.undo();
        assertNames(tree, ["B", "C"]);
        editorBase.mActionStack_.undo();
        assertNames(tree, ["A", "A1", "B", "C"]);
    }

    { //A paste asked for by the scene tree's child wrapper - a right click which
      //hit no entry - goes at the end of the top level whatever is selected,
      //rather than beside the selection.
        tree.setSingleSelection(b);
        local pasted = tree.pasteFromClipboardAtTopLevel(clipboard);
        _test.assertNotEqual(null, pasted);
        _test.assertEqual(1, pasted.len());
        assertNames(tree, ["A", "A1", "B", "C", "A", "A1"]);
        assertTopLevelWith(tree, pasted[0], b);
        assertParent(tree, childIdOf(tree, pasted[0]), pasted[0]);

        editorBase.mActionStack_.undo();
        assertNames(tree, ["A", "A1", "B", "C"]);
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

function assertLayout(entries, expected){
    _test.assertEqual(expected.len(), entries.len());
    for(local i = 0; i < expected.len(); i++){
        _test.assertEqual(expected[i], entries[i].nodeType);
    }
}

//The copied objects, in layout order. Every one of them is detached from the
//tree it came from: no entry id, and no scene node.
function assertCopiedNames(clipboard, expected){
    local names = [];
    foreach(entry in clipboard.getEntries()){
        if(entry.name == null) continue;
        names.append(entry.name);
        _test.assertEqual(null, entry.entryId);
        _test.assertEqual(null, entry.node);
    }

    _test.assertEqual(expected.len(), names.len());
    for(local i = 0; i < expected.len(); i++){
        _test.assertEqual(expected[i], names[i]);
    }
}

function clipboardEntry(clipboard, name){
    foreach(entry in clipboard.getEntries()){
        if(entry.name == name) return entry;
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
