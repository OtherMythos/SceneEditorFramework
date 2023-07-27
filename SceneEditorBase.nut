::SceneEditorFramework <- {};

enum SceneTreeEntryType{
    NONE,

    CHILD,
    TERM,

    EMPTY,
    MESH
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

    constructor(){

    }

    function loadSceneTree(parentNode, filePath){
        local tree = ::SceneEditorFramework.SceneTree();

        local parser = ::SceneEditorFramework.FileParser();
        parser.parseForSceneTree(filePath, tree);

        //Add XML scene parsing, make it work suitably well.
        //Parse a file and creat the directory tree.

        return tree;
    }

    function setActiveSceneTree(sceneTree){
        mActiveTree_ = sceneTree;
    }


};

_doFile("res://sceneEditorFramework/SceneEditorSceneTreeEntry.nut");
_doFile("res://sceneEditorFramework/SceneEditorSceneTree.nut");
_doFile("res://sceneEditorFramework/SceneEditorSceneFileParser.nut");