::SceneEditorFramework <- {};

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

};

enum SceneEditorBusEvents{
    NONE,
    SCENE_TREE_SELECTION_CHANGED,
    SELECTED_POSITION_CHANGE
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

    constructor(){
        mActiveGUI_ = {};
        mBus_ = ::SceneEditorFramework.SceneEditorBus();
        setupDatablocks();
    }

    function loadSceneTree(parentNode, filePath){
        local tree = ::SceneEditorFramework.SceneTree(parentNode, mBus_);

        local parser = ::SceneEditorFramework.FileParser();
        parser.parseForSceneTree(filePath, tree);

        return tree;
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

        //local guiInstance = targetClass(window, this);
        mActiveGUI_.rawset(winType, guiInstance);
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

        mActiveTree_.sceneSafeUpdate();
    }


};

_doFile("res://sceneEditorFramework/SceneEditorSceneTreeEntry.nut");
_doFile("res://sceneEditorFramework/SceneEditorSceneTree.nut");
_doFile("res://sceneEditorFramework/SceneEditorSceneFileParser.nut");
_doFile("res://sceneEditorFramework/SceneEditorBus.nut");

_doFile("res://sceneEditorFramework/SceneEditorGizmo.nut");
_doFile("res://sceneEditorFramework/SceneEditorGizmoObjectHandles.nut");

_doFile("res://sceneEditorFramework/SceneEditorGUIPanel.nut");
_doFile("res://sceneEditorFramework/SceneEditorGUISceneTree.nut");
_doFile("res://sceneEditorFramework/SceneEditorGUIObjectProperties.nut");