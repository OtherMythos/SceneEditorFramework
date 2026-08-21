//Holding the one-sided scale modifier while a scale drag begins holds the side
//of an object opposite the handle where it is, so the object grows out of that
//side rather than out of its own middle. Ogre has no scale which does that, so
//the framework moves the object as it resizes it - and the move is part of the
//same undo step as the resize.
//
//Whether the key itself is down is the engine's business, so these tests answer
//that question themselves and check what the framework does with the answer.
function start(){
    local editorBase = ::SceneEditorFramework.Base();
    local parentNode = _scene.getRootSceneNode().createChildSceneNode();
    local tree = editorBase.loadSceneTree(parentNode, "res://test.avScene");
    editorBase.setActiveSceneTree(tree);

    setOneSidedHeld(false);
    setSnapHeld(false);

    local alpha = findObjectId(tree, "Alpha");
    local beta = findObjectId(tree, "Beta");
    local lonely = findObjectId(tree, "Lonely");

    testHandleLayout(editorBase, parentNode);
    testSingleObject(editorBase, tree, alpha);
    testUndo(editorBase, tree, alpha);
    testSnapping(editorBase, tree, alpha);
    testDragWhichStopsBeingOneSided(editorBase, tree, alpha);
    testMultipleSelection(editorBase, tree, alpha, beta);
    testObjectWithNoBounds(editorBase, tree, lonely);

    _test.endTest();
}

//The scale gizmo grows three arms while the modifier is held, one for the
//negative end of each axis, so every side of an object has a handle of its own.
function testHandleLayout(editorBase, parentNode){
    local handles = ::SceneEditorFramework.SceneEditorGizmoObjectHandles(
        parentNode, coordinateType("SCALE"), editorBase.mBus_, 0);

    //Three arms and three plane handles, and then the same six facing the other
    //way.
    _test.assertEqual(12, handles.getNumHandles_());

    assertVec3Close(Vec3(1, 0, 0), handles.handleDirection_(0));
    assertVec3Close(Vec3(0, 1, 0), handles.handleDirection_(1));
    assertVec3Close(Vec3(0, 0, 1), handles.handleDirection_(2));
    //A plane handle sits in the positive quadrant of the pair it lies between,
    //so it grows an object out of both of those sides at once.
    assertVec3Close(Vec3(0, 1, 1), handles.handleDirection_(3));
    assertVec3Close(Vec3(1, 0, 1), handles.handleDirection_(4));
    assertVec3Close(Vec3(1, 1, 0), handles.handleDirection_(5));
    assertVec3Close(Vec3(-1, 0, 0), handles.handleDirection_(6));
    assertVec3Close(Vec3(0, -1, 0), handles.handleDirection_(7));
    assertVec3Close(Vec3(0, 0, -1), handles.handleDirection_(8));
    //A plane handle facing the other way sits in the negative quadrant of the
    //pair it lies between, so it takes both of those sides at once.
    assertVec3Close(Vec3(0, -1, -1), handles.handleDirection_(9));
    assertVec3Close(Vec3(-1, 0, -1), handles.handleDirection_(10));
    assertVec3Close(Vec3(-1, -1, 0), handles.handleDirection_(11));

    _test.assertTrue(handles.isPlaneHandle_(9));
    _test.assertTrue(handles.isDirectionalHandle_(9));
    //Both of a pair's plane handles make the same drag, along the same two axes.
    _test.assertEqual(3, handles.dragForHandle_(9));
    _test.assertEqual(0, handles.dragForHandle_(6));

    //An arm is coloured for the axis it belongs to, whichever way it points, and
    //the plane handles keep the colours of the pairs they stand for.
    _test.assertEqual("SceneEditorFramework/handle0", handles.datablockName_(0));
    _test.assertEqual("SceneEditorFramework/handle0", handles.datablockName_(6));
    _test.assertEqual("SceneEditorFramework/handle2", handles.datablockName_(8));
    _test.assertEqual("SceneEditorFramework/planeHandle1", handles.datablockName_(4));
    _test.assertEqual("SceneEditorFramework/planeHandle1", handles.datablockName_(10));
    _test.assertEqual("planeHandle.obj", handles.getObjectForHandle_(11));
    _test.assertEqual("SceneEditorFramework/handleHighlight1",
        handles.datablockName_(7, true));

    { //Without the modifier the extra arms are neither drawn nor picked, and a
      //drag of an ordinary arm resizes about the object's middle as it always
      //has.
        handles.setQueryable(true);
        handles.updateHandleModifiers();

        _test.assertEqual(0, handles.visibilityFlagsForHandle_(6));
        _test.assertEqual(0, handles.queryFlagsForHandle_(6));
        _test.assertEqual(0, handles.visibilityFlagsForHandle_(9));
        _test.assertEqual(0, handles.queryFlagsForHandle_(9));
        _test.assertTrue(handles.queryFlagsForHandle_(0) != 0);
        _test.assertTrue(handles.queryFlagsForHandle_(3) != 0);
        _test.assertTrue(handles.oneSidedDirectionForDrag_(0) == null);
    }

    { //With it held they appear in the viewport, and every arm - the ones which
      //were always there included - drags one side of the object.
        setOneSidedHeld(true);
        handles.updateHandleModifiers();

        _test.assertEqual(1, handles.visibilityFlagsForHandle_(6));
        _test.assertEqual(1, handles.visibilityFlagsForHandle_(9));
        _test.assertTrue(handles.queryFlagsForHandle_(6) != 0);
        _test.assertTrue(handles.queryFlagsForHandle_(9) != 0);
        assertVec3Close(Vec3(1, 0, 0), handles.oneSidedDirectionForDrag_(0));
        assertVec3Close(Vec3(0, 0, -1), handles.oneSidedDirectionForDrag_(8));
        assertVec3Close(Vec3(1, 1, 0), handles.oneSidedDirectionForDrag_(5));
        assertVec3Close(Vec3(-1, -1, 0), handles.oneSidedDirectionForDrag_(11));

        setOneSidedHeld(false);
        handles.updateHandleModifiers();
        _test.assertEqual(0, handles.queryFlagsForHandle_(6));
        _test.assertEqual(0, handles.queryFlagsForHandle_(9));
    }

    { //A negative arm can only have been grabbed with the modifier held, so a
      //drag of one is one-sided whether it is still held or not.
        assertVec3Close(Vec3(0, -1, 0), handles.oneSidedDirectionForDrag_(7));
    }

    { //The position gizmo is untouched by any of it. There is no one side of an
      //object to move it from.
        local movement = ::SceneEditorFramework.SceneEditorGizmoObjectHandles(
            parentNode, coordinateType("POSITION"), editorBase.mBus_, 0);
        _test.assertEqual(6, movement.getNumHandles_());
        setOneSidedHeld(true);
        _test.assertTrue(movement.oneSidedDirectionForDrag_(0) == null);
        setOneSidedHeld(false);
        movement.shutdown();
    }

    handles.shutdown();
}

//One object, dragged from each side in turn.
function testSingleObject(editorBase, tree, alpha){
    tree.notifySelectionChanged(alpha);
    local half = boundsOf(tree, alpha).getHalfSize();

    { //Dragging the positive X arm inward holds the object's own -X face where
      //it was, so the object shrinks toward it rather than toward its middle.
        local before = boundsOf(tree, alpha);
        dragOneSidedScale(tree, Vec3(1, 0, 0), Vec3(1, 0, 0));

        assertScale(tree, alpha, 0.8, 1, 1);
        local after = boundsOf(tree, alpha);
        assertClose(minOf(before).x, minOf(after).x);
        assertClose(minOf(before).x + 0.8 * (2.0 * half.x), maxOf(after).x);
        //The axes the drag left alone are left exactly as they were.
        assertClose(minOf(before).y, minOf(after).y);
        assertClose(maxOf(before).z, maxOf(after).z);
        //Which is a move of the object itself, since a scene node has no other
        //way of holding one of its sides still.
        assertPosition(tree, alpha, -0.2 * half.x, 0, 0);

        editorBase.mActionStack_.undo();
    }

    { //The same drag outward grows it the same way: the -X face stays put and
      //the +X face is the one which moves.
        local before = boundsOf(tree, alpha);
        dragOneSidedScale(tree, Vec3(-1, 0, 0), Vec3(1, 0, 0));

        assertScale(tree, alpha, 1.2, 1, 1);
        local after = boundsOf(tree, alpha);
        assertClose(minOf(before).x, minOf(after).x);
        assertClose(minOf(before).x + 1.2 * (2.0 * half.x), maxOf(after).x);

        editorBase.mActionStack_.undo();
    }

    { //The arm pointing the other way holds the opposite face instead, which is
      //the whole reason for it being there.
        local before = boundsOf(tree, alpha);
        dragOneSidedScale(tree, Vec3(1, 0, 0), Vec3(-1, 0, 0));

        assertScale(tree, alpha, 0.8, 1, 1);
        local after = boundsOf(tree, alpha);
        assertClose(maxOf(before).x, maxOf(after).x);
        assertPosition(tree, alpha, 0.2 * half.x, 0, 0);

        editorBase.mActionStack_.undo();
    }

    { //Every axis has both of its sides, so an object can be stood on a floor
      //and grown upward.
        local before = boundsOf(tree, alpha);
        dragOneSidedScale(tree, Vec3(0, -1, 0), Vec3(0, 1, 0));

        assertScale(tree, alpha, 1, 1.2, 1);
        local after = boundsOf(tree, alpha);
        assertClose(minOf(before).y, minOf(after).y);
        assertPosition(tree, alpha, 0, 0.2 * half.y, 0);

        editorBase.mActionStack_.undo();
    }

    { //A plane handle grows the object out of both of the sides it lies between
      //and leaves the third axis alone.
        local before = boundsOf(tree, alpha);
        dragOneSidedScale(tree, Vec3(-1, 0, -1), Vec3(1, 0, 1));

        assertScale(tree, alpha, 1.2, 1, 1.2);
        local after = boundsOf(tree, alpha);
        assertClose(minOf(before).x, minOf(after).x);
        assertClose(minOf(before).z, minOf(after).z);
        assertClose(minOf(before).y, minOf(after).y);
        assertClose(maxOf(before).y, maxOf(after).y);

        editorBase.mActionStack_.undo();
    }

    { //The plane handle in the negative quadrant of that same pair grows the
      //object out of its other two sides instead.
        local before = boundsOf(tree, alpha);
        dragOneSidedScale(tree, Vec3(-1, 0, -1), Vec3(-1, 0, -1));

        assertScale(tree, alpha, 1.2, 1, 1.2);
        local after = boundsOf(tree, alpha);
        assertClose(maxOf(before).x, maxOf(after).x);
        assertClose(maxOf(before).z, maxOf(after).z);
        assertPosition(tree, alpha, -0.2 * half.x, 0, -0.2 * half.z);

        editorBase.mActionStack_.undo();
    }

    { //An ordinary drag of the same arm still resizes about the middle and
      //leaves the object where it is.
        local before = boundsOf(tree, alpha);
        dragScale(tree, Vec3(1, 0, 0));

        assertScale(tree, alpha, 0.8, 1, 1);
        assertPosition(tree, alpha, 0, 0, 0);
        local after = boundsOf(tree, alpha);
        assertClose(0.1 * (2.0 * half.x), minOf(after).x - minOf(before).x);

        editorBase.mActionStack_.undo();
        assertScale(tree, alpha, 1, 1, 1);
    }
}

//The resize and the move it takes to hold one side still are one edit, so one
//undo takes back both of them.
function testUndo(editorBase, tree, alpha){
    tree.notifySelectionChanged(alpha);
    local half = boundsOf(tree, alpha).getHalfSize();

    local undoCount = editorBase.mActionStack_.mUndoStack_.len();
    dragOneSidedScale(tree, Vec3(1, 0, 0), Vec3(1, 0, 0));
    _test.assertEqual(undoCount + 1, editorBase.mActionStack_.mUndoStack_.len());

    assertScale(tree, alpha, 0.8, 1, 1);
    assertPosition(tree, alpha, -0.2 * half.x, 0, 0);

    editorBase.mActionStack_.undo();
    assertScale(tree, alpha, 1, 1, 1);
    assertPosition(tree, alpha, 0, 0, 0);

    editorBase.mActionStack_.redo();
    assertScale(tree, alpha, 0.8, 1, 1);
    assertPosition(tree, alpha, -0.2 * half.x, 0, 0);

    editorBase.mActionStack_.undo();
    assertScale(tree, alpha, 1, 1, 1);
    assertPosition(tree, alpha, 0, 0, 0);
}

//The snap modifier still applies, and the side is held against the size the
//snap settled on rather than the one the cursor asked for.
function testSnapping(editorBase, tree, alpha){
    tree.notifySelectionChanged(alpha);
    local half = boundsOf(tree, alpha).getHalfSize();

    setSnapHeld(true);
    local before = boundsOf(tree, alpha);
    dragOneSidedScale(tree, Vec3(1, 0, 0), Vec3(1, 0, 0));
    setSnapHeld(false);

    assertScale(tree, alpha, 0.75, 1, 1);
    local after = boundsOf(tree, alpha);
    assertClose(minOf(before).x, minOf(after).x);
    assertClose(minOf(before).x + 0.75 * (2.0 * half.x), maxOf(after).x);

    editorBase.mActionStack_.undo();
    assertScale(tree, alpha, 1, 1, 1);
    assertPosition(tree, alpha, 0, 0, 0);
}

//A drag which was holding one side of an object and stops doing so puts the
//object back where it began: an ordinary scale moves nothing, so leaving it
//where the one-sided part of the drag had moved it would describe a place the
//drag never asked for.
function testDragWhichStopsBeingOneSided(editorBase, tree, alpha){
    tree.notifySelectionChanged(alpha);

    tree.notifyBusEvent(busEvent("HANDLES_GIZMO_INTERACTION_BEGAN"), coordinateType("SCALE"));
    tree.notifyBusEvent(busEvent("SELECTED_SCALE_ONE_SIDED_CHANGE"), {
        "amount": Vec3(1, 0, 0),
        "direction": Vec3(1, 0, 0)
    });
    _test.assertTrue(tree.getEntryForId(alpha).position.x != 0);

    tree.notifyBusEvent(busEvent("SELECTED_SCALE_CHANGE"), Vec3(1, 0, 0));
    tree.notifyBusEvent(busEvent("HANDLES_GIZMO_INTERACTION_ENDED"), coordinateType("SCALE"));

    assertScale(tree, alpha, 0.8, 1, 1);
    assertPosition(tree, alpha, 0, 0, 0);

    editorBase.mActionStack_.undo();
    assertScale(tree, alpha, 1, 1, 1);
    assertPosition(tree, alpha, 0, 0, 0);
}

//A drag with more than one object selected asks the same change of size of each
//of them, and holds each one by its own opposite side rather than by one side
//of the group - so a row of things standing on a floor is still standing on it
//afterward, however far apart they were.
function testMultipleSelection(editorBase, tree, alpha, beta){
    tree.notifySelectionChanged(null);
    tree.notifySelectionChanged(alpha);
    tree.notifySelectionChanged(beta, true, false);
    //Mixed sizes, so the drag is measured as a change rather than as a size.
    tree.getEntryForId(alpha).setScale(Vec3(2, 1, 1));

    local alphaBefore = boundsOf(tree, alpha);
    local betaBefore = boundsOf(tree, beta);
    local half = betaBefore.getHalfSize();

    local undoCount = editorBase.mActionStack_.mUndoStack_.len();
    //Beta was clicked last, so the drag is measured against it: four fifths of
    //the size each object had.
    dragOneSidedScale(tree, Vec3(1, 0, 0), Vec3(1, 0, 0));

    assertScale(tree, beta, 0.8, 1, 1);
    assertScale(tree, alpha, 1.6, 1, 1);

    local alphaAfter = boundsOf(tree, alpha);
    local betaAfter = boundsOf(tree, beta);
    assertClose(minOf(alphaBefore).x, minOf(alphaAfter).x);
    assertClose(minOf(betaBefore).x, minOf(betaAfter).x);
    //Each was moved by as much as holding its own side still asked for, which
    //is twice as far for the object which was twice the size.
    assertPosition(tree, alpha, -0.4 * half.x, 0, 0);
    assertPosition(tree, beta, 4 - 0.2 * half.x, 0, 0);

    //One undo step, however many objects the drag resized and moved.
    _test.assertEqual(undoCount + 1, editorBase.mActionStack_.mUndoStack_.len());
    editorBase.mActionStack_.undo();
    assertScale(tree, beta, 1, 1, 1);
    assertScale(tree, alpha, 2, 1, 1);
    assertPosition(tree, alpha, 0, 0, 0);
    assertPosition(tree, beta, 4, 0, 0);

    editorBase.mActionStack_.redo();
    assertPosition(tree, alpha, -0.4 * half.x, 0, 0);
    assertPosition(tree, beta, 4 - 0.2 * half.x, 0, 0);
    editorBase.mActionStack_.undo();

    tree.getEntryForId(alpha).setScale(Vec3(1, 1, 1));
    tree.notifySelectionChanged(null);
}

//An object which draws nothing has no side to be held by, so it is resized and
//left where it is rather than the drag guessing at a size for it.
function testObjectWithNoBounds(editorBase, tree, lonely){
    tree.notifySelectionChanged(lonely);

    dragOneSidedScale(tree, Vec3(1, 0, 0), Vec3(1, 0, 0));

    assertScale(tree, lonely, 0.8, 1, 1);
    assertPosition(tree, lonely, 0, 0, 8);

    editorBase.mActionStack_.undo();
    assertScale(tree, lonely, 1, 1, 1);
}

//The framework asks whether the modifiers are held through these, so a test can
//answer for them without needing a key to be down.
function setOneSidedHeld(held){
    ::SceneEditorFramework.gizmoOneSidedScaleModifierHeld <- function(){
        return held;
    };
}

function setSnapHeld(held){
    ::SceneEditorFramework.gizmoSnapModifierHeld <- function(){
        return held;
    };
}

//Drive one drag of the scale handles from beginning to end, as the gizmo does
//through the bus. The amount is how far the handle was dragged; the direction
//is which way the handle it was dragged by points.
function dragOneSidedScale(tree, amount, direction){
    tree.notifyBusEvent(busEvent("HANDLES_GIZMO_INTERACTION_BEGAN"), coordinateType("SCALE"));
    tree.notifyBusEvent(busEvent("SELECTED_SCALE_ONE_SIDED_CHANGE"), {
        "amount": amount,
        "direction": direction
    });
    tree.notifyBusEvent(busEvent("HANDLES_GIZMO_INTERACTION_ENDED"), coordinateType("SCALE"));
}

function dragScale(tree, amount){
    tree.notifyBusEvent(busEvent("HANDLES_GIZMO_INTERACTION_BEGAN"), coordinateType("SCALE"));
    tree.notifyBusEvent(busEvent("SELECTED_SCALE_CHANGE"), amount);
    tree.notifyBusEvent(busEvent("HANDLES_GIZMO_INTERACTION_ENDED"), coordinateType("SCALE"));
}

//The framework's enums are squirrel constants, which resolve when a file is
//compiled - and this file was compiled before the plugin's scripts ran, so
//naming one directly would not resolve. They are in the constant table at
//runtime, which is where these read them from.
function busEvent(name){
    return getconsttable()["SceneEditorFramework_BusEvents"][name];
}

function coordinateType(name){
    return getconsttable()["SceneEditorFramework_BasicCoordinateType"][name];
}

function findObjectId(tree, name){
    foreach(entry in tree.mEntries_){
        if(entry.name == name) return entry.entryId;
    }

    return null;
}

function boundsOf(tree, entryId){
    return tree.getEntryAABB(entryId);
}

function minOf(bounds){
    return bounds.getCentre() - bounds.getHalfSize();
}

function maxOf(bounds){
    return bounds.getCentre() + bounds.getHalfSize();
}

function assertPosition(tree, entryId, x, y, z){
    local position = tree.getEntryForId(entryId).node.getPositionVec3();
    assertClose(x, position.x);
    assertClose(y, position.y);
    assertClose(z, position.z);
}

function assertScale(tree, entryId, x, y, z){
    local scale = tree.getEntryForId(entryId).scale;
    assertClose(x, scale.x);
    assertClose(y, scale.y);
    assertClose(z, scale.z);
}

function assertVec3Close(expected, found){
    assertClose(expected.x, found.x);
    assertClose(expected.y, found.y);
    assertClose(expected.z, found.z);
}

function assertClose(expected, found){
    local difference = expected - found;
    if(difference < 0) difference = -difference;
    _test.assertTrue(difference <= 0.001);
}
