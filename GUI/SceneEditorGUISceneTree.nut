::SceneEditorFramework.GUISceneTree <- class extends ::SceneEditorFramework.GUIPanel{

    mSceneTree_ = null;
    mContainerWin_ = null;
    mGuiEntries_ = null;
    mHoverPanel_ = null;
    mHighlightPanel_ = null;
    mSelectionResetButton_ = null;

    mHighlightId_ = null;

    GUISceneTreeEntry = class{

        mBackgroundButton_ = null;
        mNodeType_ = null;
        mParent_ = null;
        mHoverPanel_ = null;
        mHighlightPanel_ = null;
        mLabel_ = null;
        mId_ = null;

        constructor(parent, win, hoverPanel, highlightPanel){
            mHoverPanel_ = hoverPanel;
            mHighlightPanel_ = highlightPanel;
            mParent_ = parent;
            local button = win.createButton();
            //button.setPosition(indent * 30, height);
            //button.setUserId(c);
            button.setVisualsEnabled(false);
            button.attachListener(buttonSelected, this);

            local label = win.createLabel();
            label.setText(" ");

            mLabel_ = label;
            mBackgroundButton_ = button;
        }

        function populateData(entry){
            if(entry == null){
                mId_ = null;
                mNodeType_ = SceneEditorFramework_SceneTreeEntryType.NONE;
                mLabel_.setText(" ");
                mBackgroundButton_.setDisabled(true);

                return;
            }

            mId_ = entry.entryId;
            mNodeType_ = entry.nodeType;

            local testText = ::SceneEditorFramework.getNameForSceneEntry(entry);
            mLabel_.setText(testText);
            mBackgroundButton_.setUserId(mId_);
            mBackgroundButton_.setSize(mParent_.mContainerWin_.getSizeAfterClipping().x, mLabel_.getSize().y);
            mBackgroundButton_.setDisabled(false);
        }

        function buttonSelected(widget, action){
            if(action == _GUI_ACTION_PRESSED){
                if(mNodeType_ == null) return;
                local buttonId = widget.getUserId();
                mParent_.mSceneTree_.notifySelectionChanged(buttonId);
            }
            else if(action == _GUI_ACTION_HIGHLIGHTED){
                local id = widget.getUserId();
                notifyButtonHoverChange_(id, true);
            }
            else if(action == _GUI_ACTION_CANCEL){
                local id = widget.getUserId();
                notifyButtonHoverChange_(id, false);
            }
        }

        function notifyButtonHoverChange_(id, hovered){
            if(hovered){
                mHoverPanel_.setPosition(mBackgroundButton_.getPosition());
                mHoverPanel_.setSize(mBackgroundButton_.getSize());
            }
            mHoverPanel_.setVisible(hovered);

            mParent_.setHoveredEntry(id, hovered);
        }

        function getSize(){
            return mBackgroundButton_.getSize();
        }

        function getPosition(){
            return mBackgroundButton_.getPosition();
        }

        function setPosition(x, y){
            mBackgroundButton_.setPosition(x, y);
            mLabel_.setPosition(x, y);
        }

    }

    constructor(parent, tree, baseObj, bus){
        base.constructor(parent, baseObj, bus);

        mSceneTree_ = tree;
        mGuiEntries_ = [];

        bus.subscribeObject(this);
    }

    function shutdown(){
        mBus_.unsubscribeObject(this);
    }

    function notifyBusEvent(event, data){

        if(event == SceneEditorFramework_BusEvents.SCENE_TREE_SELECTION_CHANGED){
            if(data == null){
                mHighlightPanel_.setVisible(false);
            }else{
                local e = data.entry.entryId;
                foreach(c,i in mGuiEntries_){
                    if(i.mId_ == e){
                        mHighlightPanel_.setVisible(true);
                        mHighlightPanel_.setPosition(i.getPosition());
                        mHighlightPanel_.setSize(i.getSize());
                    }
                }
            }
        }
        else if(event == SceneEditorFramework_BusEvents.SCENE_TREE_CONTENTS_CHANGED){
            local activeTree = mBaseObj_.mActiveTree_;

            populateForData(activeTree.mEntries_);
        }
    }

    function setup(){
        mContainerWin_ = mParent_.createWindow();
        mContainerWin_.setVisualsEnabled(false);
        mContainerWin_.setPosition(0, 0);
        mContainerWin_.setSize(mParent_.getSizeAfterClipping());
        mContainerWin_.setSkin("internal/WindowNoBorder");

        mSelectionResetButton_ = mContainerWin_.createButton();
        mSelectionResetButton_.setVisualsEnabled(false);
        mSelectionResetButton_.attachListenerForEvent(function(widget, action){
            mSceneTree_.notifySelectionChanged(null);
        }, _GUI_ACTION_PRESSED, this);

        mHoverPanel_ = mContainerWin_.createPanel();
        mHoverPanel_.setVisible(false);
        mHoverPanel_.setDatablock("EditorGUIFramework_FrameBg");

        mHighlightPanel_ = mContainerWin_.createPanel();
        mHighlightPanel_.setVisible(false);
        mHighlightPanel_.setDatablock("EditorGUIFramework_FrameBgActive");

        //TODO find a better way to get this.
        local activeTree = mBaseObj_.mActiveTree_;

        if(!activeTree.sceneTreePopulated()){
            local label = mContainerWin_.createLabel();
            label.setText("Scene tree empty");
            return;
        }

        populateForData(activeTree.mEntries_);
    }

    function populateForData(entries){
        local cc = 0;
        foreach(c,entry in entries){
            local nodeType = entry.nodeType;
            if(
                nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD ||
                nodeType == SceneEditorFramework_SceneTreeEntryType.TERM
            ){
                continue;
            }


            local guiEntry = null;
            if(cc >= mGuiEntries_.len()){
                guiEntry = GUISceneTreeEntry(this, mContainerWin_, mHoverPanel_, mHighlightPanel_);
                mGuiEntries_.append(guiEntry);
            }else{
                guiEntry = mGuiEntries_[cc];
            }

            guiEntry.populateData(entry);

            cc++;

        }

        for(local i = cc; i < mGuiEntries_.len(); i++){
            mGuiEntries_[i].populateData(null);
        }

        positionEntries();
    }

    function setHoveredEntry(id, hovered){
        if(!hovered){
            mHighlightId_ = null;
            return;
        }
        mHighlightId_ = id;
    }

    function positionEntries(){
        local activeTree = mBaseObj_.mActiveTree_;

        local indent = -1;
        local height = 0;
        local c = 0;
        foreach(entry in activeTree.mEntries_){
            local nodeType = entry.nodeType;
            if(nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
                indent++;
                continue;
            }
            else if(nodeType == SceneEditorFramework_SceneTreeEntryType.TERM){
                indent--;
                continue;
            }
            local guiEntry = mGuiEntries_[c];
            guiEntry.populateData(entry);
            guiEntry.setPosition(indent * 30, height);
            height += guiEntry.getSize().y;
            c++;
        }
    }

    function resize(newSize){
        local parentSize = mParent_.getSizeAfterClipping();
        mContainerWin_.setSize(parentSize);
        mContainerWin_.sizeScrollToFit();

        mSelectionResetButton_.setSize(parentSize);

        positionEntries();
    }

    function update(){
        if(mHighlightId_ != null){
            if(_input.getMousePressed(_MB_RIGHT)){
                mBus_.transmitEvent(SceneEditorFramework_BusEvents.SCENE_TREE_OPTIONS_MENU_REQUEST, mHighlightId_);
            }
        }
    }

};