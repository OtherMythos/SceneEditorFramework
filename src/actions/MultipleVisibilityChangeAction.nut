//Show or hide several objects at once as one undoable step.
//
//ChangeSceneNodeVisibilityAction describes a single object, which is what the
//hierarchy's eye button asks for. One keypress hiding a whole selection has to
//leave one entry in the undo stack rather than one per object, or taking a group
//out of the way would have to be undone a piece at a time.
::SceneEditorFramework.Actions[SceneEditorFramework_Action.MULTIPLE_VISIBILITY_CHANGE] = class extends ::SceneEditorFramework.Action{

    mSceneTree_ = null;
    mBus_ = null;
    //One entry per object, each {"id", "old", "new"}.
    mChanges_ = null;

    constructor(sceneTree, bus, changes){
        mSceneTree_ = sceneTree;
        mBus_ = bus;
        mChanges_ = clone changes;
    }

    #Override
    function performAction(){
        perform_("new");
    }

    #Override
    function performAntiAction(){
        perform_("old");
    }

    function perform_(key){
        foreach(change in mChanges_){
            //An object which has left the tree since is not one this can put
            //back, and the deletion which took it is its own undo step.
            if(mSceneTree_.findEntryIdIndexInTree_(change.id) == null) continue;

            mSceneTree_.setEntryVisibility_(change.id, change[key]);
        }
    }
};
