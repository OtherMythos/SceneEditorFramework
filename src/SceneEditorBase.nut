

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
            [ColourValue(1, 0, 1, 1), ColourValue(0, 1, 0, 1), ColourValue(0, 0, 1, 1)],
            //Highlighted
            [ColourValue(0.6, 0, 0.6, 1), ColourValue(0, 0.6, 0, 1), ColourValue(0, 0, 0.6, 1)]
        ];
        local bases = [
            "SceneEditorFramework/handle",
            "SceneEditorFramework/handleHighlight"
        ];

        local macroblock = _hlms.getMacroblock({
            "depthCheck": false,
            "depthWrite": false,
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
