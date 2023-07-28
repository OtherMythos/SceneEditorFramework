::SceneEditorFramework <- {};

enum SceneTreeEntryType{
    NONE,

    CHILD,
    TERM,

    EMPTY,
    MESH
};

enum SceneEditorGUIPanelId{
    SCENE_TREE

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
        mBus_ = SceneEditorBus();
    }

    function loadSceneTree(parentNode, filePath){
        local tree = ::SceneEditorFramework.SceneTree(parentNode);

        local parser = ::SceneEditorFramework.FileParser();
        parser.parseForSceneTree(filePath, tree);

        return tree;
    }

    function setActiveSceneTree(sceneTree){
        mActiveTree_ = sceneTree;
    }

    function setupGUIWindow(winType, window){
        if(mActiveGUI_.rawin(winType)) throw "GUI window type already registered.";

        local targetClass = ::SceneEditorFramework.GUIPanel;
        switch(winType){
            case SceneEditorGUIPanelId.SCENE_TREE:{
                targetClass = ::SceneEditorFramework.GUISceneTree;
                break;
            }
        }

        local guiInstance = targetClass(window, this);
        mActiveGUI_.rawset(winType, guiInstance);
    }


};

_doFile("res://sceneEditorFramework/SceneEditorSceneTreeEntry.nut");
_doFile("res://sceneEditorFramework/SceneEditorSceneTree.nut");
_doFile("res://sceneEditorFramework/SceneEditorSceneFileParser.nut");
_doFile("res://sceneEditorFramework/SceneEditorBus.nut");

_doFile("res://sceneEditorFramework/SceneEditorGUIPanel.nut");
_doFile("res://sceneEditorFramework/SceneEditorGUISceneTree.nut");