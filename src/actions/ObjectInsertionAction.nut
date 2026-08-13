//Adds one scene entry through stable before/after layouts. Rebuilding the
//framework-owned scene root makes the same action work for inserting into an
//existing child group and for creating a parent's first CHILD/TERM group.
::SceneEditorFramework.Actions[SceneEditorFramework_Action.OBJECT_INSERTION] = class extends ::SceneEditorFramework.Action{

    mSceneTree_ = null;
    mBeforeEntries_ = null;
    mAfterEntries_ = null;
    mCreatedEntryId_ = null;
    mIdRecycled_ = false;

    constructor(sceneTree, beforeEntries, afterEntries, createdEntryId){
        mSceneTree_ = sceneTree;
        mBeforeEntries_ = clone beforeEntries;
        mAfterEntries_ = clone afterEntries;
        mCreatedEntryId_ = createdEntryId;
    }

    #Override
    function performAction(){
        if(mIdRecycled_){
            mSceneTree_.reserveId(mCreatedEntryId_);
            mIdRecycled_ = false;
        }
        mSceneTree_.applyRearrangedEntries_(mAfterEntries_);
    }

    #Override
    function performAntiAction(){
        mSceneTree_.applyRearrangedEntries_(mBeforeEntries_);
        mSceneTree_.recycleId(mCreatedEntryId_);
        mIdRecycled_ = true;
    }
};
