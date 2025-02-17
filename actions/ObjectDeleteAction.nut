::SceneEditorFramework.Actions[SceneEditorFramework_Action.OBJECT_DELETION] = class extends ::SceneEditorFramework.Action{

    mSceneTree_ = null;
    mBus_ = null;
    mSelectedEntries_ = null;

    constructor(sceneTree, bus, selectedEntries){
        mSceneTree_ = sceneTree;
        mBus_ = bus;

        mSelectedEntries_ = clone selectedEntries;
    }

    #Override
    function performAction(){
        foreach(i in mSelectedEntries_){
            mSceneTree_.deleteObjectFromTree_(i);
        }

        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SCENE_TREE_CONTENTS_CHANGED, null);
    }

    #Override
    function performAntiAction(){

    }

};

