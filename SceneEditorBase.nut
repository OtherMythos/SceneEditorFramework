

::SceneEditorFramework.getNameForSceneEntryType <- function(t){
    switch(t){
        case SceneEditorFramework_SceneTreeEntryType.NONE: return "none";
        case SceneEditorFramework_SceneTreeEntryType.CHILD: return "child";
        case SceneEditorFramework_SceneTreeEntryType.TERM: return "term";
        case SceneEditorFramework_SceneTreeEntryType.EMPTY: return "empty";
        case SceneEditorFramework_SceneTreeEntryType.MESH: return "mesh";
        case SceneEditorFramework_SceneTreeEntryType.USER0:{
            return ::SceneEditorFramework.HelperFunctions.getNameForUserEntry(0);
        }
        case SceneEditorFramework_SceneTreeEntryType.USER1:{
            return ::SceneEditorFramework.HelperFunctions.getNameForUserEntry(1);
        }
        case SceneEditorFramework_SceneTreeEntryType.USER2:{
            return ::SceneEditorFramework.HelperFunctions.getNameForUserEntry(2);
        }
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

    function loadSceneTree(parentNode, filePath){
        local tree = ::SceneEditorFramework.SceneTree(parentNode, mActionStack_, mBus_);

        local parser = ::SceneEditorFramework.FileParser();
        parser.parseForSceneTree(filePath, tree);

        mCurrentFilePath_ = filePath;

        return tree;
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
    }

    function setActiveSceneTree(sceneTree){
        mActiveTree_ = sceneTree;
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
        local mousePositionValid = !::guiFrameworkBase.mouseInteracting();
        local interact = ::SceneEditorFramework.HelperFunctions.sceneEditorInteractable();
        local mouseTarget = null;
        if(mousePositionValid){
            local mousePos = Vec2(_input.getMouseX(), _input.getMouseY());
            mouseTarget = mousePos / _window.getSize();
        }

        mActiveTree_.updateSceneSafeMousePosition(mouseTarget);
    }


};
