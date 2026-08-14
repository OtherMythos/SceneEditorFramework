::SceneEditorFramework.Actions[SceneEditorFramework_Action.OBJECT_DELETION] = class extends ::SceneEditorFramework.Action{

    mSceneTree_ = null;
    mBus_ = null;
    mSelectedEntries_ = null;
    mBeforeEntries_ = null;
    mAfterEntries_ = null;
    mDeletedEntryIds_ = null;
    mIdsRecycled_ = false;

    constructor(sceneTree, bus, selectedEntries){
        mSceneTree_ = sceneTree;
        mBus_ = bus;

        mSelectedEntries_ = clone selectedEntries;
        mBeforeEntries_ = clone sceneTree.mEntries_;
        mDeletedEntryIds_ = [];
    }

    #Override
    function performAction(){
        if(mAfterEntries_ == null){
            foreach(i in mSelectedEntries_){
                mSceneTree_.deleteObjectFromTree_(i);
            }

            mAfterEntries_ = clone mSceneTree_.mEntries_;
            recordDeletedEntryIds_();
            mIdsRecycled_ = true;
            mBus_.transmitEvent(SceneEditorFramework_BusEvents.SCENE_TREE_CONTENTS_CHANGED, null);
            return;
        }

        mSceneTree_.applyRearrangedEntries_(mAfterEntries_);
        foreach(entryId in mDeletedEntryIds_) mSceneTree_.recycleId(entryId);
        mIdsRecycled_ = true;
    }

    #Override
    function performAntiAction(){
        //Deletion puts every object id in the removed subtrees back into the
        //pool. Claim those ids before reconstructing their original entries.
        if(mIdsRecycled_){
            foreach(entryId in mDeletedEntryIds_) mSceneTree_.reserveId(entryId);
            mIdsRecycled_ = false;
        }
        mSceneTree_.applyRearrangedEntries_(mBeforeEntries_);
    }

    function recordDeletedEntryIds_(){
        local remainingIds = {};
        foreach(entry in mAfterEntries_){
            if(entry.entryId != null) remainingIds.rawset(entry.entryId, true);
        }

        foreach(entry in mBeforeEntries_){
            if(entry.entryId == null || remainingIds.rawin(entry.entryId)) continue;
            mDeletedEntryIds_.append(entry.entryId);
        }
    }

};
