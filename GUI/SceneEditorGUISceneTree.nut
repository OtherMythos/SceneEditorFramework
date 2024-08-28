::SceneEditorFramework.GUISceneTree <- class extends ::SceneEditorFramework.GUIPanel{

    mSceneTree_ = null;
    mContainerWin_ = null;

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
        local indent = -1;
        local height = 0;
        foreach(c,entry in activeTree.mEntries_){
            local nodeType = entry.nodeType;
            if(nodeType == SceneTreeEntryType.CHILD){
                indent++;
                continue;
            }
            else if(nodeType == SceneTreeEntryType.TERM){
                indent--;
                continue;
            }
            local entry = mContainerWin_.createButton();
            local testText = ::SceneEditorFramework.getNameForSceneEntryType(nodeType);
            entry.setText(testText);
            entry.setPosition(indent * 30, height);
            entry.setUserId(c);
            entry.attachListenerForEvent(buttonSelected, _GUI_ACTION_PRESSED, this);
            height += entry.getSize().y;
        }

        mContainerWin_.sizeScrollToFit();
    }

    function buttonSelected(widget, action){
        local buttonId = widget.getUserId();
        mSceneTree_.notifySelectionChanged(buttonId);
    }

};