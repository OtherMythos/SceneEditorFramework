//Changes visibility through the action stack so the hierarchy's eye button is
//undoable just like the other scene edits.
::SceneEditorFramework.Actions[SceneEditorFramework_Action.CHANGE_SCENE_NODE_VISIBILITY] = class extends ::SceneEditorFramework.Action{

    mSceneTree_ = null;
    mBus_ = null;
    mId_ = null;
    mOldVisible_ = true;
    mNewVisible_ = true;

    constructor(sceneTree, bus, id, oldVisible, newVisible){
        mSceneTree_ = sceneTree;
        mBus_ = bus;
        mId_ = id;
        mOldVisible_ = oldVisible;
        mNewVisible_ = newVisible;
    }

    #Override
    function performAction(){
        mSceneTree_.setEntryVisibility_(mId_, mNewVisible_);
    }

    #Override
    function performAntiAction(){
        mSceneTree_.setEntryVisibility_(mId_, mOldVisible_);
    }
};
