::SceneEditorFramework.IMGUI.SceneTree <- class extends ::SceneEditorFramework.IMGUI.Panel{

    mSceneTree_ = null;
    mWindowTitle_ = "Scene Tree##SceneEditorFrameworkSceneTree";
    mItemClicked_ = false;

    constructor(baseObj, bus){
        base.constructor(baseObj, bus);
        mSceneTree_ = baseObj.getActiveSceneTree();
    }

    function draw(){
        if(!mVisible_) return;

        local shown = _imgui.begin(mWindowTitle_);
        if(shown){
            mItemClicked_ = false;
            if(!mSceneTree_.sceneTreePopulated()){
                _imgui.textDisabled("Scene tree empty");
            }else{
                drawEntries_(0);
            }

            //Match the retained panel's transparent reset button: clicking
            //unused space clears the current selection.
            if(_imgui.isWindowHovered() && _input.getMousePressed(_MB_LEFT) && !mItemClicked_){
                mSceneTree_.notifySelectionChanged(null);
            }
        }
        _imgui.end();
    }

    //Entries are stored as a flattened tree, with CHILD and TERM markers.
    //Return the index immediately after the current sibling group.
    function drawEntries_(startIndex){
        local entries = mSceneTree_.mEntries_;
        local index = startIndex;
        while(index < entries.len()){
            local entry = entries[index];
            if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.TERM){
                return index + 1;
            }
            if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
                index++;
                continue;
            }

            local hasChildren = index + 1 < entries.len() &&
                entries[index + 1].nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD;
            local flags = _imgui.TreeNodeFlags_SpanAvailWidth |
                _imgui.TreeNodeFlags_OpenOnArrow |
                _imgui.TreeNodeFlags_OpenOnDoubleClick;
            if(entry.entryId == mSceneTree_.mCurrentSelection){
                flags = flags | _imgui.TreeNodeFlags_Selected;
            }
            if(!hasChildren){
                flags = flags | _imgui.TreeNodeFlags_Leaf |
                    _imgui.TreeNodeFlags_NoTreePushOnOpen;
            }

            local label = ::SceneEditorFramework.getNameForSceneEntry(entry) + "##" + entry.entryId;
            local open = _imgui.treeNodeEx(label, flags);
            if(_imgui.isItemClicked()){
                mItemClicked_ = true;
                mSceneTree_.notifySelectionChanged(entry.entryId);
            }

            if(hasChildren){
                if(open){
                    index = drawEntries_(index + 2);
                    _imgui.treePop();
                }else{
                    index = skipEntries_(index + 1);
                }
            }else{
                index++;
            }
        }

        return index;
    }

    //Skip a CHILD/TERM group without drawing it when its parent is collapsed.
    function skipEntries_(childIndex){
        local entries = mSceneTree_.mEntries_;
        local depth = 0;
        for(local index = childIndex; index < entries.len(); index++){
            if(entries[index].nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
                depth++;
            }else if(entries[index].nodeType == SceneEditorFramework_SceneTreeEntryType.TERM){
                depth--;
                if(depth == 0) return index + 1;
            }
        }

        return entries.len();
    }
};
