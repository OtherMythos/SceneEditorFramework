//A drag of the position handles moves everything which is selected: the objects
//keep the arrangement they were put in rather than the drag pulling one of them
//out of it. The handles sit at the middle of a multiple selection, whichever
//transform tool they belong to, so the drag is about the group rather than about
//whichever object was clicked last. The whole drag is one undo step, and only a
//move widens like this - a scale or a rotation still changes the most recently
//clicked object alone.
function start(){
    local editorBase = ::SceneEditorFramework.Base();
    local parentNode = _scene.getRootSceneNode().createChildSceneNode();
    local tree = editorBase.loadSceneTree(parentNode, "res://test.avScene");
    editorBase.setActiveSceneTree(tree);

    local alpha = findObjectId(tree, "Alpha");
    local beta = findObjectId(tree, "Beta");
    local gamma = findObjectId(tree, "Gamma");
    local parent = findObjectId(tree, "Parent");
    local child = findObjectId(tree, "Child");

    { //One selected object is moved to where the drag asks for, and nothing
      //else moves with it.
        tree.notifySelectionChanged(alpha);
        dragPosition(tree, Vec3(1, 2, 3));

        assertPosition(tree, alpha, 1, 2, 3);
        assertPosition(tree, beta, 4, 0, 0);

        editorBase.mActionStack_.undo();
        assertPosition(tree, alpha, 0, 0, 0);
        editorBase.mActionStack_.redo();
        assertPosition(tree, alpha, 1, 2, 3);
        editorBase.mActionStack_.undo();
    }

    { //With more of them selected, the drag names a place for the middle of the
      //selection - where the gizmo sits, and where the orange outline is drawn
      //around - and every object moves that same distance, so the gap between
      //them is the gap they had.
        tree.notifySelectionChanged(alpha);
        tree.notifySelectionChanged(beta, true, false);
        tree.notifySelectionChanged(gamma, true, false);
        //The properties panel still follows the most recently clicked object,
        //even though the gizmo no longer sits on it.
        _test.assertEqual(gamma, tree.mCurrentSelection);

        //The three cubes span x 0 to 4 and y 0 to 4, so their bounds are
        //centred between them rather than on any one of them.
        assertVec3Close(Vec3(2, 2, 0), tree.mMoveHandles_.mPosition_);

        local undoCount = editorBase.mActionStack_.mUndoStack_.len();
        dragPosition(tree, Vec3(0, 5, 0));

        //A move of (-2, 3, 0), which is the drag's target measured from that
        //centre and not from gamma.
        assertPosition(tree, alpha, -2, 3, 0);
        assertPosition(tree, beta, 2, 3, 0);
        assertPosition(tree, gamma, -2, 7, 0);
        //The gizmo ends the drag where the drag asked for.
        assertVec3Close(Vec3(0, 5, 0), tree.mMoveHandles_.mPosition_);

        //One undo step, however many objects the drag moved.
        _test.assertEqual(undoCount + 1, editorBase.mActionStack_.mUndoStack_.len());
        editorBase.mActionStack_.undo();
        assertPosition(tree, alpha, 0, 0, 0);
        assertPosition(tree, beta, 4, 0, 0);
        assertPosition(tree, gamma, 0, 4, 0);

        editorBase.mActionStack_.redo();
        assertPosition(tree, alpha, -2, 3, 0);
        assertPosition(tree, beta, 2, 3, 0);
        assertPosition(tree, gamma, -2, 7, 0);
        editorBase.mActionStack_.undo();
    }

    { //One object selected puts the gizmo back on that object. Clicking beta
      //while it is part of the selection above would keep that selection, so
      //the group is dropped first.
        tree.notifySelectionChanged(null);
        tree.notifySelectionChanged(beta);
        assertVec3Close(Vec3(4, 0, 0), tree.mMoveHandles_.mPosition_);
    }

    { //A drag of several objects moves each one once. A selected object which
      //hangs below another selected one is carried by that one, so it keeps the
      //place in it that it had rather than being moved a second time - even when
      //it is the object the gizmo is on.
        tree.notifySelectionChanged(parent);
        tree.notifySelectionChanged(child, true, false);
        _test.assertEqual(child, tree.mCurrentSelection);

        local undoCount = editorBase.mActionStack_.mUndoStack_.len();
        //The child is at (1, 0, 8) in the world, so this asks for a move of two
        //along x.
        dragPosition(tree, Vec3(3, 0, 8));

        assertPosition(tree, parent, 2, 0, 8);
        assertPosition(tree, child, 1, 0, 0);
        assertWorldPosition(tree, child, 3, 0, 8);

        _test.assertEqual(undoCount + 1, editorBase.mActionStack_.mUndoStack_.len());
        editorBase.mActionStack_.undo();
        assertPosition(tree, parent, 0, 0, 8);
        assertPosition(tree, child, 1, 0, 0);
    }

    { //Every transform tool's handles go to the same place, so switching between
      //them with a group selected does not move the gizmo about.
        tree.notifySelectionChanged(alpha);
        tree.notifySelectionChanged(beta, true, false);
        tree.notifySelectionChanged(gamma, true, false);

        foreach(tool in ["SCALE", "ORIENTATION", "RAYCAST", "POSITION"]){
            tree.setObjectTransformCoordinateType(coordinateType(tool));
            assertVec3Close(Vec3(2, 2, 0), tree.mMoveHandles_.mPosition_);
        }

        //One selected object has no group centre to use, so every tool's handles
        //are on the object itself.
        tree.notifySelectionChanged(null);
        tree.notifySelectionChanged(beta);
        foreach(tool in ["SCALE", "ORIENTATION", "POSITION"]){
            tree.setObjectTransformCoordinateType(coordinateType(tool));
            assertVec3Close(Vec3(4, 0, 0), tree.mMoveHandles_.mPosition_);
        }
    }

    { //A scale still changes only the most recently clicked object: the others
      //are not resized around a middle they are not at, even though the handles
      //are drawn at that middle.
        tree.notifySelectionChanged(null);
        tree.notifySelectionChanged(alpha);
        tree.notifySelectionChanged(beta, true, false);

        dragScale(tree, Vec3(1, 1, 1));

        assertScale(tree, beta, 0.8, 0.8, 0.8);
        assertScale(tree, alpha, 1, 1, 1);
        assertPosition(tree, alpha, 0, 0, 0);

        editorBase.mActionStack_.undo();
        assertScale(tree, beta, 1, 1, 1);
    }

    _test.endTest();
}

//Drive one drag of the position handles from beginning to end, as the gizmo
//does through the bus.
function dragPosition(tree, target){
    tree.notifyBusEvent(busEvent("HANDLES_GIZMO_INTERACTION_BEGAN"), coordinateType("POSITION"));
    tree.notifyBusEvent(busEvent("SELECTED_POSITION_CHANGE"), target);
    tree.notifyBusEvent(busEvent("HANDLES_GIZMO_INTERACTION_ENDED"), coordinateType("POSITION"));
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

function assertPosition(tree, entryId, x, y, z){
    local position = tree.getEntryForId(entryId).node.getPositionVec3();
    assertClose(x, position.x);
    assertClose(y, position.y);
    assertClose(z, position.z);
}

function assertWorldPosition(tree, entryId, x, y, z){
    local position = tree.getEntryForId(entryId).node.getDerivedPositionVec3();
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
