//Centring a node on its contents moves it to the middle of what hangs below it
//and takes that same offset back out of its direct children, so the group can be
//moved as one object while nothing in it appears to have moved at all.
function start(){
    local editorBase = ::SceneEditorFramework.Base();
    local parentNode = _scene.getRootSceneNode().createChildSceneNode();
    local tree = editorBase.loadSceneTree(parentNode, "res://test.avScene");
    editorBase.setActiveSceneTree(tree);

    local group = findId(tree, "Group");
    local left = findId(tree, "Left");
    local right = findId(tree, "Right");
    local rightChild = findId(tree, "RightChild");
    local inner = findId(tree, "Inner");
    local innerLeft = findId(tree, "InnerLeft");
    local innerRight = findId(tree, "InnerRight");
    local empties = findId(tree, "Empties");
    local emptyA = findId(tree, "EmptyA");
    local emptyB = findId(tree, "EmptyB");
    local lonely = findId(tree, "Lonely");

    { //The middle of the meshes below the group is what it moves to: the bounds
      //of a cube are symmetric about it, so its size does not come into where
      //the middle of a pair of them is. Everything is left in the world where it
      //was, and the descendant below one of the children does not move at all -
      //its position already describes where it is in the child it hangs from.
        local worldBefore = worldPositions(tree, [left, right, rightChild]);
        _test.assertTrue(tree.centreEntryOnContents(group));

        assertPosition(tree, group, 0.0, 5.5, 3.0);
        assertPosition(tree, left, -2.0, -1.5, 0.0);
        assertPosition(tree, right, 2.0, 0.5, 0.0);
        assertPosition(tree, rightChild, 0.0, 1.0, 0.0);
        assertWorldPositions(tree, [left, right, rightChild], worldBefore);

        //One undo step, however many objects it moved.
        editorBase.mActionStack_.undo();
        assertPosition(tree, group, 0.0, 0.0, 0.0);
        assertPosition(tree, left, -2.0, 4.0, 3.0);
        assertPosition(tree, right, 2.0, 6.0, 3.0);
        assertPosition(tree, rightChild, 0.0, 1.0, 0.0);

        editorBase.mActionStack_.redo();
        assertPosition(tree, group, 0.0, 5.5, 3.0);
        assertPosition(tree, left, -2.0, -1.5, 0.0);
        assertWorldPositions(tree, [left, right, rightChild], worldBefore);
    }

    { //A node which is already in the middle of its contents has nothing to
      //move, and an edit which changes nothing does not become an undo step.
        local undoCount = editorBase.mActionStack_.mUndoStack_.len();
        _test.assertFalse(tree.centreEntryOnContents(group));
        _test.assertEqual(undoCount, editorBase.mActionStack_.mUndoStack_.len());
        assertPosition(tree, group, 0.0, 5.5, 3.0);
    }

    { //Positions describe an object's place in its parent, so a group inside a
      //scaled one is moved by the distance its own parent measures rather than
      //by the world one, and its children come out the same way.
        local worldBefore = worldPositions(tree, [innerLeft, innerRight]);
        _test.assertTrue(tree.centreEntryOnContents(inner));

        assertPosition(tree, inner, -1.0, 0.0, 0.0);
        assertPosition(tree, innerLeft, -2.0, 0.0, 0.0);
        assertPosition(tree, innerRight, 2.0, 0.0, 0.0);
        assertWorldPositions(tree, [innerLeft, innerRight], worldBefore);

        editorBase.mActionStack_.undo();
        assertPosition(tree, inner, 0.0, 0.0, 0.0);
        assertPosition(tree, innerLeft, -3.0, 0.0, 0.0);
    }

    { //A group of empties shows nothing to take bounds from, so the middle of
      //where those empties are stands in for them.
        local worldBefore = worldPositions(tree, [emptyA, emptyB]);
        _test.assertTrue(tree.centreEntryOnContents(empties));

        assertPosition(tree, empties, 2.0, 1.0, 3.0);
        assertPosition(tree, emptyA, -2.0, -1.0, -3.0);
        assertPosition(tree, emptyB, 2.0, 1.0, 3.0);
        assertWorldPositions(tree, [emptyA, emptyB], worldBefore);

        editorBase.mActionStack_.undo();
        assertPosition(tree, empties, 0.0, 0.0, 0.0);
        assertPosition(tree, emptyA, 0.0, 0.0, 0.0);
    }

    { //An object with nothing below it has no contents to be centred on, and
      //neither has an id which is not in the tree.
        local undoCount = editorBase.mActionStack_.mUndoStack_.len();
        _test.assertFalse(tree.centreEntryOnContents(lonely));
        _test.assertFalse(tree.centreEntryOnContents(1000));
        _test.assertEqual(undoCount, editorBase.mActionStack_.mUndoStack_.len());
        assertPosition(tree, lonely, 1.0, 1.0, 1.0);
    }

    _test.endTest();
}

function findId(tree, name){
    foreach(entry in tree.mEntries_){
        if(entry.name == name) return entry.entryId;
    }
    return null;
}

function worldPositions(tree, entryIds){
    local result = [];
    foreach(entryId in entryIds){
        result.append(tree.getEntryForId(entryId).node.getDerivedPositionVec3());
    }
    return result;
}

function assertWorldPositions(tree, entryIds, expected){
    local found = worldPositions(tree, entryIds);
    _test.assertEqual(expected.len(), found.len());
    for(local i = 0; i < expected.len(); i++){
        assertClose(expected[i].x, found[i].x);
        assertClose(expected[i].y, found[i].y);
        assertClose(expected[i].z, found[i].z);
    }
}

function assertPosition(tree, entryId, x, y, z){
    local position = tree.getEntryForId(entryId).node.getPositionVec3();
    assertClose(x, position.x);
    assertClose(y, position.y);
    assertClose(z, position.z);
}

function assertClose(expected, found){
    local difference = expected - found;
    if(difference < 0) difference = -difference;
    _test.assertTrue(difference <= 0.001);
}
