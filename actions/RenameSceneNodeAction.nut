::SceneEditorFramework.Actions[SceneEditorFramework_Action.RENAME_SCENE_NODE] = class extends ::SceneEditorFramework.Action{

    mSceneTree_ = null;
    mBus_ = null;
    mId_ = null;
    mOld_ = null;
    mNew_ = null;

    constructor(sceneTree, bus, id, oldVal, newVal){
        mSceneTree_ = sceneTree;
        mBus_ = bus;
        mId_ = id;
        mOld_ = oldVal;
        mNew_ = newVal;
    }

    #Override
    function performAction(){
        perform_(mNew_);
    }

    #Override
    function performAntiAction(){
        perform_(mOld_);
    }

    function perform_(targetName){
        mSceneTree_.getEntryForId(mId_).setName(targetName);

        local data = {
            "id": mId_,
            "name": targetName
        }
        mBus_.transmitEvent(SceneEditorFramework_BusEvents.OBJECT_NAME_CHANGE, data);
    }
};

