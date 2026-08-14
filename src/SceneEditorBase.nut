

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

    return Vec2(_input.getMouseX(), _input.getMouseY()) / _window.getSize();
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

::SceneEditorFramework.Base <- class{

    mActiveTree_ = null;
    mActiveGUI_ = null;
    mBus_ = null;
    mEditorHelperFunctions_ = null;
    mActionStack_ = null;

    mCurrentFilePath_ = null;

    constructor(){
        mActiveGUI_ = {};
        mBus_ = ::SceneEditorFramework.SceneEditorBus();
        mActionStack_ = ::SceneEditorFramework.ActionStack();
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
    }

    function notifyBusEvent(event, data){
        if(event == SceneEditorFramework_BusEvents.REQUEST_SAVE){
            writeSceneFile(mCurrentFilePath_);
        }
    }

    function update(){
        if(mActiveTree_ != null){
            mActiveTree_.update();
        }

        foreach(i in mActiveGUI_){
            i.update();
        }
    }

    function getActiveSceneTree(){
        return mActiveTree_;
    }

    function setActiveSceneTree(sceneTree){
        mActiveTree_ = sceneTree;
    }

    function pushAction(action){
        mActionStack_.pushAction_(action);
    }

    function setupGUIWindow(winType, window){
        if(mActiveGUI_.rawin(winType)) throw "GUI window type already registered.";

        //local newInstance = ::SceneEditorFramework.GUIPanel;
        local guiInstance = null;
        switch(winType){
            case SceneEditorFramework_GUIPanelId.SCENE_TREE:{
                assert(mActiveTree_);
                guiInstance = ::SceneEditorFramework.GUISceneTree(window, mActiveTree_, this, mBus_);
                break;
            }
            case SceneEditorFramework_GUIPanelId.OBJECT_PROPERTIES:{
                guiInstance = ::SceneEditorFramework.GUIObjectProperties(window, this, mBus_);
                break;
            }
        }

        setupGUIWindowForInstance(winType, guiInstance);
    }

    function setupGUIWindowForClass(winType, window, guiClass){
        if(mActiveGUI_.rawin(winType)) throw "GUI window type already registered.";
        local guiInstance = guiClass(window, this, mBus_);

        setupGUIWindowForInstance(winType, guiInstance);

        return guiInstance;
    }

    /**
     * Register an immediate-mode panel. Unlike setupGUIWindow(), it does not
     * receive a retained engine GUI window; the panel creates its ImGui window
     * while drawIMGUI() is called each frame.
     */
    function setupIMGUIWindow(winType, guiClass){
        if(mActiveGUI_.rawin(winType)) throw "GUI window type already registered.";

        local guiInstance = guiClass(this, mBus_);
        setupGUIWindowForInstance(winType, guiInstance);

        return guiInstance;
    }

    function setupGUIWindowForInstance(winType, instance){
        mActiveGUI_.rawset(winType, instance);
        instance.setup();
    }

    function closeGUIWindow(winType){
        if(!mActiveGUI_.rawin(winType)) return;
        mActiveGUI_[winType].shutdown();
        mActiveGUI_.rawdelete(winType);
    }

    function resizeGUIWindow(winType, newSize){
        if(!mActiveGUI_.rawin(winType)) return;
        mActiveGUI_[winType].resize(newSize);
    }

    /**
     * Draw every registered immediate-mode panel. Call this once after the
     * application has checked _imgui.isFirstUpdateOfFrame(). Retained GUI
     * panels continue to be updated by update().
     */
    function drawIMGUI(){
        foreach(i in mActiveGUI_){
            if("draw" in i){
                i.draw();
            }
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
    }

    function sceneSafeUpdate(){
        if(!mActiveTree_) return;

        //Determine the mouse position and whether to pass that over.
        //The active UI implementation owns this decision. This used to reach
        //into the legacy guiFrameworkBase directly, which prevented a project
        //from using the framework with any other UI backend.
        local mousePositionValid = ::SceneEditorFramework.HelperFunctions.sceneEditorInteractable();
        local mouseTarget = null;
        if(mousePositionValid){
            mouseTarget = ::SceneEditorFramework.getNormalisedSceneMousePosition();
        }

        mActiveTree_.updateSceneSafeMousePosition(mouseTarget);
    }


};
