//The object chooser shown by Alt-clicking a scene viewport. The ray query is
//performed by the editor during sceneSafeUpdate; this class owns only the ImGui
//popup and the selection made from it.
::SceneEditorFramework.IMGUI.RaycastSelectionMenu <- class{

    POPUP_ID = "sceneEditorRaycastSelectionMenu"

    mBase_ = null;
    mEntryIds_ = null;
    mRequestedEntryIds_ = null;

    constructor(baseObj){
        mBase_ = baseObj;
        mEntryIds_ = [];
    }

    //An empty ray leaves the current selection alone and opens no menu.
    function requestForEntries(entryIds){
        if(entryIds == null || entryIds.len() == 0) return;
        mRequestedEntryIds_ = entryIds;
    }

    function draw(){
        if(mRequestedEntryIds_ != null){
            mEntryIds_ = mRequestedEntryIds_;
            mRequestedEntryIds_ = null;
            //ImGui remembers the cursor position at OpenPopup, placing the list
            //at the Alt-click which requested it.
            _imgui.openPopup(POPUP_ID);
        }

        if(!_imgui.beginPopup(POPUP_ID)) return;

        _imgui.textDisabled("Objects under cursor");
        _imgui.separator();

        local sceneTree = mBase_.getActiveSceneTree();
        if(sceneTree == null){
            _imgui.closeCurrentPopup();
            _imgui.endPopup();
            return;
        }

        foreach(entryId in mEntryIds_){
            //The scene can change while the popup is open.
            if(sceneTree.findEntryIdIndexInTree_(entryId) == null) continue;

            local entry = sceneTree.getEntryForId(entryId);
            local label = ::SceneEditorFramework.getNameForSceneEntry(entry) +
                "##raycastEntry" + entryId;
            //The checked state is rendered as a tick in the popup's right-hand
            //column, so an Alt-click chooser shows which hits are already part
            //of the current multi-selection.
            if(_imgui.menuItem(label, null, sceneTree.isEntrySelected(entryId))){
                sceneTree.notifySelectionChanged(entryId);
            }
        }

        _imgui.endPopup();
    }
};
