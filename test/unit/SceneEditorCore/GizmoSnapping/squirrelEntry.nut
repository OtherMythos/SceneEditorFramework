//Holding the snap modifier makes a gizmo drag move in steps rather than
//continuously, for all three of position, scale and rotation.
//
//Whether the key itself is down is the engine's business, so these tests answer
//that question themselves and check what the framework does with the answer.
function start(){
    local editorBase = ::SceneEditorFramework.Base();
    local parentNode = _scene.getRootSceneNode().createChildSceneNode();
    local tree = editorBase.loadSceneTree(parentNode, "res://test.avScene");
    editorBase.setActiveSceneTree(tree);

    local alpha = findObjectId(tree, "Alpha");

    { //Rounding is to the nearest step and away from zero on a half, on both
      //sides of it, so no step is twice the size of its neighbours.
        local snap = ::SceneEditorFramework.snapValueToStep;
        assertClose(2.0, snap(2.4, 1.0));
        assertClose(3.0, snap(2.5, 1.0));
        assertClose(-2.0, snap(-2.4, 1.0));
        assertClose(-2.0, snap(-2.5, 1.0));
        assertClose(0.0, snap(0.1, 1.0));

        //Fifteen degrees lands exactly on the eighths and the thirds of a turn.
        local step = snapStep("ORIENTATION");
        assertClose(PI / 4, snap(PI / 4 + 0.05, step));
        assertClose(2.0 * PI / 3, snap(2.0 * PI / 3 - 0.05, step));
    }

    { //A drag of the position handles with the modifier held puts the object on
      //whole world units, whichever direction it came from.
        setSnapHeld(true);
        tree.notifySelectionChanged(alpha);
        dragPosition(tree, Vec3(1.4, -0.6, 2.5));
        assertPosition(tree, alpha, 1, -1, 3);

        //Undone as one action, the same as an unsnapped drag.
        editorBase.mActionStack_.undo();
        assertPosition(tree, alpha, 0, 0, 0);
    }

    { //Without it the drag lands exactly where it asked to.
        setSnapHeld(false);
        dragPosition(tree, Vec3(1.4, -0.6, 2.5));
        assertPosition(tree, alpha, 1.4, -0.6, 2.5);
        editorBase.mActionStack_.undo();
    }

    { //A snapped scale drag lands on quarters.
        setSnapHeld(true);
        //The gizmo reports how far it has been dragged; a fifth of that is
        //taken off the size the object was when the drag began, so this asks
        //for 0.8 and the snap puts it at 0.75.
        dragScale(tree, Vec3(1, 1, 1));
        assertScale(tree, alpha, 0.75, 0.75, 0.75);
        editorBase.mActionStack_.undo();
        assertScale(tree, alpha, 1, 1, 1);
    }

    { //A drag which asks for nothing at all is held one step off zero rather
      //than collapsing the object onto a plane.
        dragScale(tree, Vec3(5, 5, 5));
        assertScale(tree, alpha, 0.25, 0.25, 0.25);
        editorBase.mActionStack_.undo();

        //A mirrored object is held one step off it on its own side.
        dragScale(tree, Vec3(5.25, 5.25, 5.25));
        assertScale(tree, alpha, -0.25, -0.25, -0.25);
        editorBase.mActionStack_.undo();
        setSnapHeld(false);
    }

    { //The unsnapped drag it is built on is left alone.
        dragScale(tree, Vec3(1, 1, 1));
        assertScale(tree, alpha, 0.8, 0.8, 0.8);
        editorBase.mActionStack_.undo();
    }

    _test.endTest();
}

//The framework asks whether the modifier is held through this, so a test can
//answer for it without needing a key to be down.
function setSnapHeld(held){
    ::SceneEditorFramework.gizmoSnapModifierHeld <- function(){
        return held;
    };
}

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

function snapStep(name){
    return getconsttable()["SceneEditorFramework_GizmoSnap"][name];
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

function assertScale(tree, entryId, x, y, z){
    local scale = tree.getEntryForId(entryId).scale;
    assertClose(x, scale.x);
    assertClose(y, scale.y);
    assertClose(z, scale.z);
}

function assertClose(expected, found){
    local difference = expected - found;
    if(difference < 0) difference = -difference;
    _test.assertTrue(difference <= 0.001);
}
