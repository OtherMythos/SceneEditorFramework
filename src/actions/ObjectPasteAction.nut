//Adds a clipboard's worth of entries through stable before/after layouts.
//
//This is an insertion of more than one entry: a paste brings in every object
//which was copied along with all of their descendants, so the ids undo has to
//give back and redo has to claim again are a list rather than one id.
//@see SceneEditorFramework.SceneTreeClipboard
::SceneEditorFramework.Actions[SceneEditorFramework_Action.OBJECT_PASTE] = class extends ::SceneEditorFramework.Action{

    mSceneTree_ = null;
    mBeforeEntries_ = null;
    mAfterEntries_ = null;
    mCreatedEntryIds_ = null;
    //The pasted entries which are not below another pasted one. They become the
    //selection, so that what the user pasted is what they are then working on.
    mTopLevelEntryIds_ = null;
    mIdsRecycled_ = false;

    constructor(sceneTree, beforeEntries, afterEntries, createdEntryIds, topLevelEntryIds){
        mSceneTree_ = sceneTree;
        mBeforeEntries_ = clone beforeEntries;
        mAfterEntries_ = clone afterEntries;
        mCreatedEntryIds_ = clone createdEntryIds;
        mTopLevelEntryIds_ = clone topLevelEntryIds;
    }

    #Override
    function performAction(){
        if(mIdsRecycled_){
            foreach(entryId in mCreatedEntryIds_) mSceneTree_.reserveId(entryId);
            mIdsRecycled_ = false;
        }
        mSceneTree_.applyRearrangedEntries_(mAfterEntries_);
        mSceneTree_.setSelectionToIds(mTopLevelEntryIds_);
    }

    #Override
    function performAntiAction(){
        mSceneTree_.applyRearrangedEntries_(mBeforeEntries_);
        foreach(entryId in mCreatedEntryIds_) mSceneTree_.recycleId(entryId);
        mIdsRecycled_ = true;
    }
};
