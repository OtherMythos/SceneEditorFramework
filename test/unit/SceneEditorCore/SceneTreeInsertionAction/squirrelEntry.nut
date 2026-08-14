//Child insertion creates both the flattened hierarchy entry and its engine
//node, and retains enough state for undo/redo to restore the same entry id.
function start(){
    local editorBase = ::SceneEditorFramework.Base();
    local parentNode = _scene.getRootSceneNode().createChildSceneNode();
    local tree = editorBase.loadSceneTree(parentNode, "res://test.avScene");
    editorBase.setActiveSceneTree(tree);

    local parent = findId(tree, "Parent");
    local existingChild = findId(tree, "Existing child");
    local leaf = findId(tree, "Leaf");
    local tail = findId(tree, "Tail");
    tree.setSingleSelection(parent);

    local emptyChild = tree.insertEmptyChild(parent, "Empty child");
    _test.assertNotEqual(null, emptyChild);
    assertEntryIsChildOf(tree, emptyChild, parent);
    _test.assertEqual(nodeType("empty"),
        tree.getEntryForId(emptyChild).nodeType);
    _test.assertEqual(2, tree.getEntryForId(parent).node.getNumChildren());
    _test.assertEqual(parent, tree.mCurrentSelection);

    local emptyAction = editorBase.mActionStack_.mUndoStack_.top();
    _test.assertEqual(emptyChild, emptyAction.mCreatedEntryId_);

    editorBase.mActionStack_.undo();
    _test.assertEqual(null, tree.findEntryIdIndexInTree_(emptyChild));
    _test.assertEqual(1, tree.getEntryForId(parent).node.getNumChildren());

    editorBase.mActionStack_.redo();
    _test.assertNotEqual(null, tree.findEntryIdIndexInTree_(emptyChild));
    assertEntryIsChildOf(tree, emptyChild, parent);
    _test.assertEqual(2, tree.getEntryForId(parent).node.getNumChildren());

    //A parent without children gains a CHILD/TERM group. Every primitive used
    //by the context menu must also construct a real renderable mesh node.
    local primitives = [
        ["cube", "Cube"],
        ["sphere", "Sphere"],
        ["capsule", "Capsule"],
        ["plane", "Plane"]
    ];
    foreach(primitive in primitives){
        local meshName = primitive[0];
        local meshId = tree.insertPrimitiveMeshChild(leaf, meshName, primitive[1]);
        local entry = tree.getEntryForId(meshId);
        _test.assertEqual(nodeType("mesh"), entry.nodeType);
        _test.assertEqual(meshName, entry.data.meshName);
        _test.assertEqual(1, entry.node.getNumAttachedObjects());
        assertEntryIsChildOf(tree, meshId, leaf);
    }
    local leafIndex = tree.findEntryIdIndexInTree_(leaf);
    _test.assertTrue(tree.itemHasChildren_(leafIndex));
    _test.assertEqual(primitives.len(), tree.getEntryForId(leaf).node.getNumChildren());

    //Undoing the most recent insertion removes only that mesh; redoing it uses
    //the original id and restores the hierarchy under the same parent.
    local planeId = findId(tree, "Plane");
    editorBase.mActionStack_.undo();
    _test.assertEqual(null, tree.findEntryIdIndexInTree_(planeId));
    _test.assertEqual(primitives.len() - 1, tree.getEntryForId(leaf).node.getNumChildren());
    editorBase.mActionStack_.redo();
    _test.assertNotEqual(null, tree.findEntryIdIndexInTree_(planeId));
    assertEntryIsChildOf(tree, planeId, leaf);

    //If an undone insertion is replaced by a new edit, its reserved id is
    //available to the replacement action after the old redo history is lost.
    editorBase.mActionStack_.undo();
    local replacementId = tree.insertEmptyChild(tail, "Replacement");
    _test.assertEqual(planeId, replacementId);
    assertEntryIsChildOf(tree, replacementId, tail);

    //A parent outline includes renderables below nested empty children. The
    //parent itself has no mesh, so this verifies the separate child-structure
    //outline rather than the ordinary selected-object outline.
    local nestedMesh = tree.insertPrimitiveMeshChild(existingChild, "cube",
        "Nested cube");
    tree.getEntryForId(nestedMesh).setPosition(Vec3(3, 0, 0));
    tree.setSingleSelection(parent);
    local childrenBounds = tree.getChildrenAABB_(
        tree.findEntryIdIndexInTree_(parent));
    _test.assertNotEqual(null, childrenBounds);
    assertClose(childrenBounds.getCentre().x,
        tree.mChildrenOutlineBox_.mCentre_.x);

    _test.endTest();
}

function findId(tree, name){
    foreach(entry in tree.mEntries_){
        if(entry.name == name) return entry.entryId;
    }
    return null;
}

function assertEntryIsChildOf(tree, childId, parentId){
    local childIndex = tree.findEntryIdIndexInTree_(childId);
    local parentIndex = tree.findEntryIdIndexInTree_(parentId);
    _test.assertEqual(parentIndex, tree.getIndexOfParentForEntry_(childIndex));
}

function nodeType(name){
    return ::SceneEditorFramework.FileParser().getNodeTypeForName(name);
}

function assertClose(expected, found){
    local difference = expected - found;
    if(difference < 0) difference = -difference;
    _test.assertTrue(difference <= 0.001);
}
