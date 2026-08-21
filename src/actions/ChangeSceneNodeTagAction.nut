//Changes the tag a scene node is found by, through the action stack, so that
//claiming a tag and giving it up are both undoable like the other scene edits.
//
//The action itself does not police uniqueness: the tree checks that before it
//pushes one, and an undo can only put back a tag which the entry it belongs to
//already held.
//@see SceneEditorFramework.SceneTree.setEntryTag
::SceneEditorFramework.Actions[SceneEditorFramework_Action.CHANGE_SCENE_NODE_TAG] = class extends ::SceneEditorFramework.Action{

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

    function perform_(targetTag){
        mSceneTree_.getEntryForId(mId_).setTag(targetTag);

        local data = {
            "id": mId_,
            "tag": targetTag
        }
        mBus_.transmitEvent(SceneEditorFramework_BusEvents.OBJECT_TAG_CHANGE, data);
    }
};
