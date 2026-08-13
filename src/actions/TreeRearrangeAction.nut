::SceneEditorFramework.Actions[SceneEditorFramework_Action.TREE_REARRANGE] = class extends ::SceneEditorFramework.Action{

    mSceneTree_ = null;
    mBeforeEntries_ = null;
    mAfterEntries_ = null;

    constructor(sceneTree, beforeEntries, afterEntries){
        mSceneTree_ = sceneTree;
        mBeforeEntries_ = clone beforeEntries;
        mAfterEntries_ = clone afterEntries;
    }

    #Override
    function performAction(){
        mSceneTree_.applyRearrangedEntries_(mAfterEntries_);
    }

    #Override
    function performAntiAction(){
        mSceneTree_.applyRearrangedEntries_(mBeforeEntries_);
    }
};
