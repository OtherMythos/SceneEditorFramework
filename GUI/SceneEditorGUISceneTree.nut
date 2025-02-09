::SceneEditorFramework.GUISceneTree <- class extends ::SceneEditorFramework.GUIPanel{

    mSceneTree_ = null;
    mContainerWin_ = null;

    GUISceneTreeEntry = class{

        mBackgroundButton_ = null;
        mNodeType_ = null;
        mParent_ = null;

        constructor(parent, win){
            mParent_ = parent;
            local entry = win.createButton();
            //entry.setPosition(indent * 30, height);
            //entry.setUserId(c);
            entry.attachListenerForEvent(buttonSelected, _GUI_ACTION_PRESSED, this);

            mBackgroundButton_ = entry;
        }

        function populateData(id, nodeType){
            mNodeType_ = nodeType;

            local testText = ::SceneEditorFramework.getNameForSceneEntryType(nodeType);
            mBackgroundButton_.setText(testText);
            mBackgroundButton_.setUserId(id);
        }

        function buttonSelected(widget, action){
            if(mNodeType_ == null) return;
            local buttonId = widget.getUserId();
            mParent_.mSceneTree_.notifySelectionChanged(buttonId);
        }

        function getSize(){
            return mBackgroundButton_.getSize();
        }

        function setPosition(x, y){
            mBackgroundButton_.setPosition(x, y);
        }

    }

    constructor(parent, tree, baseObj, bus){
        base.constructor(parent, baseObj, bus);

        mSceneTree_ = tree;
    }

    function setup(){
        mContainerWin_ = mParent_.createWindow();
        mContainerWin_.setVisualsEnabled(false);
        mContainerWin_.setPosition(0, 0);
        mContainerWin_.setSize(mParent_.getSizeAfterClipping());
        mContainerWin_.setSkin("internal/WindowNoBorder");

        //TODO find a better way to get this.
        local activeTree = mBaseObj_.mActiveTree_;

        if(!activeTree.sceneTreePopulated()){
            local label = mContainerWin_.createLabel();
            label.setText("Scene tree empty");
            return;
        }

        local indent = -1;
        local height = 0;
        foreach(c,entry in activeTree.mEntries_){
            local nodeType = entry.nodeType;
            if(nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
                indent++;
                continue;
            }
            else if(nodeType == SceneEditorFramework_SceneTreeEntryType.TERM){
                indent--;
                continue;
            }
            local entry = GUISceneTreeEntry(this, mContainerWin_);
            entry.populateData(c, nodeType);
            entry.setPosition(indent * 30, height);
            height += entry.getSize().y;
        }

        mContainerWin_.sizeScrollToFit();
    }

    function resize(newSize){
        mContainerWin_.setSize(mParent_.getSizeAfterClipping());
        mContainerWin_.sizeScrollToFit();
    }

};