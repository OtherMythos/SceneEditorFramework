

::SceneEditorFramework.getNameForSceneEntry <- function(e){
    if(e.name != null){
        return e.name;
    }

    local t = e.nodeType;
    switch(t){
        case SceneEditorFramework_SceneTreeEntryType.NONE: return "none";
        case SceneEditorFramework_SceneTreeEntryType.CHILD: return "child";
        case SceneEditorFramework_SceneTreeEntryType.TERM: return "term";
        case SceneEditorFramework_SceneTreeEntryType.EMPTY: return "empty";
        case SceneEditorFramework_SceneTreeEntryType.MESH: return "mesh";
        case SceneEditorFramework_SceneTreeEntryType.USER0:{
            return ::SceneEditorFramework.HelperFunctions.getNameForUserEntry(0, e);
        }
        case SceneEditorFramework_SceneTreeEntryType.USER1:{
            return ::SceneEditorFramework.HelperFunctions.getNameForUserEntry(1, e);
        }
        case SceneEditorFramework_SceneTreeEntryType.USER2:{
            return ::SceneEditorFramework.HelperFunctions.getNameForUserEntry(2, e);
        }
        case SceneEditorFramework_SceneTreeEntryType.USER3:{
            return ::SceneEditorFramework.HelperFunctions.getNameForUserEntry(3, e);
        }
        default: return "unknown";
    }
};
::SceneEditorFramework.getStringValueForSceneEntryType <- function(t){
    switch(t){
        case SceneEditorFramework_SceneTreeEntryType.NONE: return "none";
        case SceneEditorFramework_SceneTreeEntryType.CHILD: return "child";
        case SceneEditorFramework_SceneTreeEntryType.TERM: return "term";
        case SceneEditorFramework_SceneTreeEntryType.EMPTY: return "empty";
        case SceneEditorFramework_SceneTreeEntryType.MESH: return "mesh";
        case SceneEditorFramework_SceneTreeEntryType.USER0: return "user0";
        case SceneEditorFramework_SceneTreeEntryType.USER1: return "user1";
        case SceneEditorFramework_SceneTreeEntryType.USER2: return "user2";
        case SceneEditorFramework_SceneTreeEntryType.USER3: return "user3";
        default: return "unknown";
    }
};

//Helper functions for the user to re-implement
//This approach helps keep the framework flexible.
::SceneEditorFramework.HelperFunctions <- {
    //Called to check if the scene is interactable, for instance the cursor is not interacting with any gui elements.
    function sceneEditorInteractable(){
        //Stub to be implemented by the user.
        return true;
    }

    function sceneTreeConstructObjectForUserEntry(userId, parentNode, entryData){

    }

    function getNameForUserEntry(userId){
        return "User" + userId;
    }

    function raycastForMovementGizmo(){
        return Vec3();
    }

    function basicMouseInteractionEnabled(){
        return true;
    }

    //Optional extension point for the immediate-mode object-properties panel.
    function drawIMGUIObjectPropertiesForUserEntry(userId, entry){

    }
}

/**
Get the mouse position within the scene viewport, in the 0-1 range, or null when
it is outside it.

Everything which turns the cursor into a ray through the scene goes through
here, so a project only has to describe its viewport once.
*/
::SceneEditorFramework.getNormalisedSceneMousePosition <- function(){
    //Optional, so a project written against an earlier version of the framework
    //keeps working: without it the scene fills the window.
    if("normalisedSceneMousePosition" in ::SceneEditorFramework.HelperFunctions){
        return ::SceneEditorFramework.HelperFunctions.normalisedSceneMousePosition();
    }

    local mouse = _imgui.getMousePos();
    local display = _imgui.getDisplaySize();
    if(display[0] <= 0 || display[1] <= 0) return null;
    return Vec2(mouse[0] / display[0], mouse[1] / display[1]);
}

/**
Get the camera the scene is being viewed through, or null when nothing is
showing it.

Everything which turns the cursor into a ray through the scene needs a camera to
cast it from, and an editor with more than one viewport has more than one to
choose from. This names the one whose viewport the cursor is working in, so that
a click picks what the user is looking at rather than what some other viewport
sees.
*/
::SceneEditorFramework.getActiveSceneCamera <- function(){
    //Optional, so a project written against an earlier version of the framework
    //keeps working: without it the scene is viewed through the engine's default
    //camera, which is the only one such a project has.
    if("activeSceneCamera" in ::SceneEditorFramework.HelperFunctions){
        return ::SceneEditorFramework.HelperFunctions.activeSceneCamera();
    }

    return _camera.getCamera();
}

/**
Where a camera is in the world, or null when there is no telling.

A camera is placed by the node it is attached to, so that is what has the
position. One which is attached to nothing - or no camera at all - is somewhere
unknowable rather than at the origin.
*/
::SceneEditorFramework.getCameraPosition <- function(camera){
    if(camera == null) return null;

    local node = camera.getParentNode();
    return node == null ? null : node.getDerivedPositionVec3();
}

/**
Where the active scene camera is in the world, or null when there is no viewport.

Gizmos size themselves by their distance from it, so that they stay the same size
on screen however far the view is from the object they belong to.
*/
::SceneEditorFramework.getActiveSceneCameraPosition <- function(){
    if(!("activeSceneCamera" in ::SceneEditorFramework.HelperFunctions)){
        return _camera.getPosition();
    }

    return ::SceneEditorFramework.getCameraPosition(
        ::SceneEditorFramework.HelperFunctions.activeSceneCamera());
}

/**
The cameras which are showing the scene, one per gizmo layer.

The transform gizmo sizes itself by its distance from the camera, so that it
stays the same size on screen however far the view is from the object it belongs
to. One set of scene nodes can only be one size, and an editor with more than one
viewport needs a different size in each - so the framework builds a copy of the
gizmo per layer, and sizes each copy for the camera of the layer it belongs to.

A layer is drawn only by the viewport which claimed it, which is what keeps each
copy in the viewport it was sized for. The framework gives the copy on layer n
the visibility flag 1 << n and draws it in the gizmo render queue, so a project
which uses more than one layer has to give each of its viewports a compositor
which draws that queue with the matching visibility mask.
@see SceneEditorFramework_RenderQueue
@see ::SceneEditorFramework.MAX_GIZMO_LAYERS

@returns An array indexed by layer, no longer than MAX_GIZMO_LAYERS. A null entry
is a layer no viewport is using, and so one with no copy of the gizmo on it.
*/
::SceneEditorFramework.getGizmoLayerCameras <- function(){
    //Optional, so a project written against an earlier version of the framework
    //keeps working: without it the scene is shown by a single viewport, which
    //puts its gizmo on the only layer such a project knows about.
    if("gizmoLayerCameras" in ::SceneEditorFramework.HelperFunctions){
        return ::SceneEditorFramework.HelperFunctions.gizmoLayerCameras();
    }

    return [::SceneEditorFramework.getActiveSceneCamera()];
}

/**
Which gizmo layer the cursor is working in, or null when it is in none of them.

Only that layer's copy of the gizmo answers the mouse. The others follow the
object the gizmo is on and show its axes at a size which suits the view they are
in, but they cannot be picked or dragged: a copy sized for a distant view is
enormous next to one sized for a near view, and a ray cast from the near view
would hit it long before reaching the arm the cursor is actually over.
*/
::SceneEditorFramework.getActiveGizmoLayer <- function(){
    if("activeGizmoLayer" in ::SceneEditorFramework.HelperFunctions){
        return ::SceneEditorFramework.HelperFunctions.activeGizmoLayer();
    }

    //A project with a single viewport has the cursor in the only layer there is.
    return 0;
}

/**
Whether the project's compositor draws the gizmo in a pass of its own, having
cleared the depth buffer first.

The gizmo has to be drawn over the scene rather than inside it. A pass of its own
gets that from a cleared depth buffer, which leaves the gizmo free to depth test
against itself - so its arms overlap in the order they are actually in.

A project which draws the whole scene in one pass has nowhere to clear the depth
buffer, so its gizmo is drawn with no depth testing at all. That still puts it on
top, but its arms cannot sort against each other and are left overlapping in
whatever order they happen to be drawn in.
@see SceneEditorFramework_RenderQueue
*/
::SceneEditorFramework.gizmoPassClearsDepth <- function(){
    if("gizmoPassClearsDepth" in ::SceneEditorFramework.HelperFunctions){
        return ::SceneEditorFramework.HelperFunctions.gizmoPassClearsDepth();
    }

    return false;
}

/**
Whether the modifier which makes a transform gizmo drag move in steps is held.

Shift, and either of them: a keyboard has two and an editor should not care which
one a hand fell on. Read live during a drag rather than latched when it began, so
that a drag can be snapped part way through and let go of again.
@see SceneEditorFramework_GizmoSnap for the steps themselves.
*/
::SceneEditorFramework.gizmoSnapModifierHeld <- function(){
    return _input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.LSHIFT) ||
        _input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.RSHIFT);
}

/**
Whether the modifier which keeps a scale drag uniform across the three axes is
held.

Alt rather than shift, which snapping has taken over: snapping applies to all
three kinds of drag and this applies to one, so shift is the one which reads the
same wherever the gizmo is used.
*/
::SceneEditorFramework.gizmoUniformScaleModifierHeld <- function(){
    return _input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.LALT) ||
        _input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.RALT);
}

/**
Whether the modifier which anchors a scale drag to one side of what it is
resizing is held.

Without it a scale grows an object evenly about its own middle, since that is
what a scene node's scale does - both sides of every axis move, and the object
appears to grow out of or shrink into its centre. With it the side opposite the
handle being dragged is held where it is and only the dragged side moves, which
is what putting an object against a wall or a floor asks for. Ogre has no such
scale, so the framework moves the object as it resizes it to leave that side
where it was. @see SceneEditorFramework.SceneTree.setSelectedNodeScaleOneSided

Control, which the transform gizmo has nothing else to do with: shift snaps and
alt keeps a scale uniform, and both of those still apply while this is held.

Held while the drag begins rather than while it runs, unlike the other two. The
three extra handles this puts on the scale gizmo - one for the negative
direction of each axis, so every side of an object has a handle of its own -
exist only while it is held, so letting go part way through a drag would take
away the arm being dragged and turn the drag it began into a different one.
@see SceneEditorFramework.SceneEditorGizmoObjectHandles
*/
::SceneEditorFramework.gizmoOneSidedScaleModifierHeld <- function(){
    return _input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.LCTRL) ||
        _input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.RCTRL);
}

/**
Round a value to the nearest multiple of a step.

Halves round upward, on both sides of zero, so that a drag crossing the origin
does not find a step twice the size of the others waiting for it there.
*/
::SceneEditorFramework.snapValueToStep <- function(value, step){
    return floor(value / step + 0.5) * step;
}

::SceneEditorFramework.snapVec3ToStep <- function(value, step){
    return Vec3(
        ::SceneEditorFramework.snapValueToStep(value.x, step),
        ::SceneEditorFramework.snapValueToStep(value.y, step),
        ::SceneEditorFramework.snapValueToStep(value.z, step));
}

::SceneEditorFramework.Base <- class{

    mActiveTree_ = null;
    //sceneSafeUpdate runs before the window dispatches the current frame's
    //input. Querying ImGui there would begin its frame too early, so the mouse
    //state it uses is sampled during the preceding fixed update instead.
    mSceneSafeMousePosition_ = null;
    mSceneSafeLeftMouseDown_ = false;
    mActiveIMGUIPanels_ = null;
    mBus_ = null;
    mEditorHelperFunctions_ = null;
    mActionStack_ = null;
    //What a copy left behind. Owned here rather than by a scene tree, so that a
    //copy taken from one tree can be pasted into another.
    //@see SceneEditorFramework.SceneTreeClipboard
    mClipboard_ = null;

    mCurrentFilePath_ = null;

    constructor(){
        mActiveIMGUIPanels_ = {};
        mBus_ = ::SceneEditorFramework.SceneEditorBus();
        mActionStack_ = ::SceneEditorFramework.ActionStack();
        mClipboard_ = ::SceneEditorFramework.SceneTreeClipboard();
        setupDatablocks();

        mBus_.subscribeObject(this);
    }

    function shutdown(){
        //The editor can close before a scene has been selected and loaded.
        if(mActiveTree_ != null) mActiveTree_.shutdown();
    }

    function loadSceneTree(parentNode, filePath){
        local tree = ::SceneEditorFramework.SceneTree(parentNode, mActionStack_, mBus_);

        local parser = ::SceneEditorFramework.FileParser();
        parser.parseForSceneTree(filePath, tree);

        mCurrentFilePath_ = filePath;
        //The tree as parsed is exactly what is on disk, and a scene loaded over
        //another one leaves that one's actions behind on the stack.
        mActionStack_.markSaved();

        return tree;
    }

    function createBaseSceneTreeFile(filePath){
        _system.createBlankFile(filePath);

        local doc = XMLDocument();

        local root = doc.newElement("scene");

        doc.writeFile(filePath);
    }

    function writeSceneFile(filePath){
        if(mActiveTree_ == null) throw "No active scene tree";
        local writer = ::SceneEditorFramework.FileWriter();
        writer.writeToFile(filePath, mActiveTree_);
        //After the write rather than before it, so a write which throws leaves
        //the scene marked as still having something unsaved in it.
        mActionStack_.markSaved();
    }

    /**
     * Whether the scene has been changed since it was last written to disk.
     * @see SceneEditorFramework.ActionStack.hasUnsavedChanges
     */
    function hasUnsavedChanges(){
        return mActionStack_.hasUnsavedChanges();
    }

    function notifyBusEvent(event, data){
        if(event == SceneEditorFramework_BusEvents.REQUEST_SAVE){
            writeSceneFile(mCurrentFilePath_);
        }
    }

    function update(){
        local mousePositionValid =
            ::SceneEditorFramework.HelperFunctions.sceneEditorInteractable();
        mSceneSafeMousePosition_ = mousePositionValid ?
            ::SceneEditorFramework.getNormalisedSceneMousePosition() : null;
        mSceneSafeLeftMouseDown_ =
            _imgui.isMouseDown(_imgui.MouseButton_Left);

        if(mActiveTree_ != null){
            mActiveTree_.update();
        }

    }

    function getActiveSceneTree(){
        return mActiveTree_;
    }

    function setActiveSceneTree(sceneTree){
        mActiveTree_ = sceneTree;
    }

    /** The clipboard copy and paste work through. */
    function getClipboard(){
        return mClipboard_;
    }

    function pushAction(action){
        mActionStack_.pushAction_(action);
    }

    /** Register a panel which is drawn by drawIMGUI() each frame. */
    function setupIMGUIWindow(winType, guiClass){
        if(mActiveIMGUIPanels_.rawin(winType)) throw "ImGui window type already registered.";

        local guiInstance = guiClass(this, mBus_);
        mActiveIMGUIPanels_.rawset(winType, guiInstance);
        guiInstance.setup();

        return guiInstance;
    }

    function closeIMGUIWindow(winType){
        if(!mActiveIMGUIPanels_.rawin(winType)) return;
        mActiveIMGUIPanels_[winType].shutdown();
        mActiveIMGUIPanels_.rawdelete(winType);
    }

    /**
     * Draw every registered panel. Call this once after the application has
     * checked _imgui.isFirstUpdateOfFrame().
     */
    function drawIMGUI(){
        foreach(i in mActiveIMGUIPanels_){
            i.draw();
        }
    }

    function setupDatablocks(){
        local handleColours = [
            //Regular
            [ColourValue(0.95, 0.20, 0.20, 1), ColourValue(0.20, 0.90, 0.30, 1), ColourValue(0.25, 0.55, 1.00, 1)],
            //Highlighted
            [ColourValue(0.57, 0.12, 0.12, 1), ColourValue(0.12, 0.54, 0.18, 1), ColourValue(0.15, 0.33, 0.60, 1)]
        ];
        local bases = [
            "SceneEditorFramework/handle",
            "SceneEditorFramework/handleHighlight"
        ];

        //Depth testing the gizmo is only of use when the depth buffer it is
        //tested against has been cleared for it, which is something only the
        //project's compositor can do. Without that the gizmo has to ignore depth
        //altogether to stay on top of the scene.
        //@see ::SceneEditorFramework.gizmoPassClearsDepth
        local depthTest = ::SceneEditorFramework.gizmoPassClearsDepth();
        local macroblock = _hlms.getMacroblock({
            "depthCheck": depthTest,
            "depthWrite": depthTest,
        });
        foreach(cc,i in handleColours){
            local targetBase = bases[cc];
            foreach(c,y in i){
                local datablock = _hlms.unlit.createDatablock(targetBase + c.tostring(), null, macroblock);
                datablock.setColour(y);
            }
        }

        //The movement-plane handles represent the pair of axes they allow the
        //user to move on: YZ is cyan, XZ magenta and XY yellow.
        local planeColours = [
            [ColourValue(0.20, 0.75, 0.95, 1), ColourValue(0.85, 0.30, 0.95, 1), ColourValue(0.95, 0.80, 0.15, 1)],
            [ColourValue(0.12, 0.45, 0.57, 1), ColourValue(0.51, 0.18, 0.57, 1), ColourValue(0.57, 0.48, 0.09, 1)]
        ];
        local planeBases = [
            "SceneEditorFramework/planeHandle",
            "SceneEditorFramework/planeHandleHighlight"
        ];
        foreach(cc, colours in planeColours){
            foreach(axis, colour in colours){
                local datablock = _hlms.unlit.createDatablock(
                    planeBases[cc] + axis, null, macroblock);
                datablock.setColour(colour);
            }
        }

        //The selection brackets belong to the scene rather than the transform
        //gizmo, so leave their ordinary depth settings alone and only tint them.
        local outline = _hlms.unlit.createDatablock(
            "SceneEditorFramework/selectionOutline", null);
        outline.setColour(ColourValue(0.55, 0.55, 0.55, 1));

        //The outline around everything the selection covers is drawn at the same
        //time as the one above and is always the larger of the two, so it is
        //given a colour of its own rather than a second white box.
        local childrenOutline = _hlms.unlit.createDatablock(
            "SceneEditorFramework/childrenOutline", null);
        childrenOutline.setColour(ColourValue(0.95, 0.55, 0.10, 1));
    }

    function sceneSafeUpdate(){
        if(!mActiveTree_) return;

        mActiveTree_.updateSceneSafeMousePosition(
            mSceneSafeMousePosition_, mSceneSafeLeftMouseDown_);
    }


};
