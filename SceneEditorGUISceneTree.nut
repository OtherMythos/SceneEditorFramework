::SceneEditorFramework.GUISceneTree <- class extends ::SceneEditorFramework.GUIPanel{

    mSceneTree_ = null;

    constructor(parent, tree, baseObj, bus){
        base.constructor(parent, baseObj, bus);

        mSceneTree_ = tree;

        setup();
    }

    function setup(){
        local label = mParent_.createLabel();
        label.setText("Scene Tree");

        local saveButton = mParent_.createButton();
        saveButton.setText("Save");
        saveButton.attachListenerForEvent(function(widget, action){
            mBus_.transmitEvent(SceneEditorBusEvents.REQUEST_SAVE, null);
        }, _GUI_ACTION_PRESSED, this);

        local containerWin = mParent_.createWindow();
        local startY = label.getPosition().y + label.getSize().y;
        containerWin.setPosition(0, startY);
        local parentSize = mParent_.getSizeAfterClipping();
        containerWin.setSize(parentSize.x, parentSize.y - startY);

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
            local entry = containerWin.createButton();
            local testText = ::SceneEditorFramework.getNameForSceneEntryType(nodeType);
            entry.setText(testText);
            entry.setPosition(indent * 30, height);
            entry.setUserId(c);
            entry.attachListenerForEvent(buttonSelected, _GUI_ACTION_PRESSED, this);
            height += entry.getSize().y;
        }

        containerWin.sizeScrollToFit();
    }

    function buttonSelected(widget, action){
        local buttonId = widget.getUserId();
        mSceneTree_.notifySelectionChanged(buttonId);
    }

};