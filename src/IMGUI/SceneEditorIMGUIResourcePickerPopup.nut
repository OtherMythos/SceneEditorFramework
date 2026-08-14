/** Shared modal resource selector opened by ResourceButton widgets. */
::SceneEditorFramework.IMGUI.ResourcePickerPopup <- class{

    POPUP_TITLE = "Select a resource##SceneEditorFrameworkResourcePicker";

    mBrowser_ = null;
    mOpenPending_ = false;
    mOnSelected_ = null;

    constructor(baseObj, bus, rootPath, backend=null, modelClass=null){
        if(modelClass == null) modelClass = ::SceneEditorFramework.FileBrowserModel;
        local model = modelClass(rootPath, backend);
        mBrowser_ = ::SceneEditorFramework.IMGUI.FileBrowser(baseObj, bus);
        local popup = this;
        mBrowser_.configure(model, {
            kindFilter = null,
            onFileActivated = function(entry){ popup.complete_(entry); }
        });
    }

    function request(kind, onSelected){
        mBrowser_.setKindFilter(kind);
        mOnSelected_ = onSelected;
        mOpenPending_ = true;
    }

    function draw(){
        if(mOpenPending_){
            _imgui.setNextWindowSize(720, 680, _imgui.Cond_Appearing);
            _imgui.openPopup(POPUP_TITLE);
            mOpenPending_ = false;
        }
        if(!_imgui.beginPopupModal(POPUP_TITLE)) return;

        local available = _imgui.getContentRegionAvail();
        if(_imgui.beginChild("##resourcePickerBrowser", 0, available[1] - 42.0, 0)){
            mBrowser_.drawContents_();
        }
        _imgui.endChild();
        _imgui.separator();

        if(_imgui.button("Cancel")) _imgui.closeCurrentPopup();
        _imgui.sameLine();
        local selected = selectedEntry_();
        _imgui.beginDisabled(selected == null);
        if(_imgui.button("Select") && selected != null) complete_(selected);
        _imgui.endDisabled();

        _imgui.endPopup();
    }

    function selectedEntry_(){
        local selectedPath = mBrowser_.getModel().getSelectedPath();
        if(selectedPath == null) return null;
        foreach(entry in mBrowser_.getModel().getEntries()){
            if(entry.path == selectedPath && !entry.isDirectory &&
                (mBrowser_.getKindFilter() == null ||
                    entry.kind == mBrowser_.getKindFilter())){
                return entry;
            }
        }
        return null;
    }

    function complete_(entry){
        if(entry == null || entry.isDirectory ||
            (mBrowser_.getKindFilter() != null &&
                entry.kind != mBrowser_.getKindFilter())) return;
        local callback = mOnSelected_;
        mOnSelected_ = null;
        if(callback != null) callback(entry);
        _imgui.closeCurrentPopup();
    }
};
