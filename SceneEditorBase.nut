
enum SceneTreeEntryType{
    NONE,

    CHILD,
    TERM,

    EMPTY,
    MESH
};

enum SceneEditorGUIPanelId{
    SCENE_TREE,
    OBJECT_PROPERTIES,

    USER_CUSTOM_1 = 1000,
    USER_CUSTOM_2 = 1001,
    USER_CUSTOM_3 = 1002,

};

enum SceneEditorBusEvents{
    NONE,
    SCENE_TREE_SELECTION_CHANGED,
    SELECTED_POSITION_CHANGE,

    REQUEST_SAVE
};


::SceneEditorFramework.getNameForSceneEntryType <- function(t){
    switch(t){
        case SceneTreeEntryType.NONE: return "none";
        case SceneTreeEntryType.CHILD: return "child";
        case SceneTreeEntryType.TERM: return "term";
        case SceneTreeEntryType.EMPTY: return "empty";
        case SceneTreeEntryType.MESH: return "mesh";
        default: return "unknown";
    }
};

::SceneEditorFramework.Base <- class{

    mActiveTree_ = null;
    mActiveGUI_ = null;
    mBus_ = null;

    mCurrentFilePath_ = null;

    constructor(){
        mActiveGUI_ = {};
        mBus_ = ::SceneEditorFramework.SceneEditorBus();
        setupDatablocks();

        mBus_.subscribeObject(this);
    }

    function loadSceneTree(parentNode, filePath){
        local tree = ::SceneEditorFramework.SceneTree(parentNode, mBus_);

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
        if(event == SceneEditorBusEvents.REQUEST_SAVE){
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
            case SceneEditorGUIPanelId.SCENE_TREE:{
                assert(mActiveTree_);
                guiInstance = ::SceneEditorFramework.GUISceneTree(window, mActiveTree_, this, mBus_);
                break;
            }
            case SceneEditorGUIPanelId.OBJECT_PROPERTIES:{
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

    function checkIntersect_(x, y, widget){
        local start = widget.getPosition();
        local end = widget.getSize();
        return (x >= start.x && y >= start.y && x < end.x+start.x && y < end.y+start.y);
    }
    function checkMousePositionValid(mousePos){
        foreach(i in mActiveGUI_){
            if(checkIntersect_(mousePos.x, mousePos.y, i)) return false;
        }
        return true;
    }

    function sceneSafeUpdate(){
        if(!mActiveTree_) return;

        //Determine the mouse position and whether to pass that over.
        local mousePos = Vec2(_input.getMouseX(), _input.getMouseY());
        local mousePositionValid = checkMousePositionValid(mousePos);

        mActiveTree_.updateSceneSafeMousePosition(mousePositionValid ? (mousePos / _window.getSize()) : null);
    }


};
