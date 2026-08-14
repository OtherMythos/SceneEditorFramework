/** A dockable, filesystem-backed resource browser. */
::SceneEditorFramework.IMGUI.FileBrowser <- class extends ::SceneEditorFramework.IMGUI.Panel{

    DOUBLE_CLICK_TIME = 0.35;

    mWindowTitle_ = "File Browser##SceneEditorFrameworkFileBrowser";
    mModel_ = null;
    mSearch_ = "";
    mPathInput_ = "";
    mLastClickedPath_ = null;
    mLastClickTime_ = -100.0;
    mOnSelectionChanged_ = null;
    mOnFileActivated_ = null;

    constructor(baseObj, bus){
        base.constructor(baseObj, bus);
    }

    function configure(model, options=null){
        mModel_ = model;
        mPathInput_ = model.getCurrentPath();
        if(options == null) return;
        if(options.rawin("onSelectionChanged")){
            mOnSelectionChanged_ = options.rawget("onSelectionChanged");
        }
        if(options.rawin("onFileActivated")){
            mOnFileActivated_ = options.rawget("onFileActivated");
        }
    }

    function getModel(){ return mModel_; }

    function draw(){
        if(!mVisible_ || mModel_ == null) return;

        applyInitialWindowState_();
        local shown = _imgui.begin(mWindowTitle_);
        captureWindowState_(shown);
        if(shown) drawContents_();
        _imgui.end();
    }

    function drawContents_(){
        if(_imgui.button("Up##fileBrowserUp")){
            if(mModel_.goUp()) pathChanged_();
        }
        _imgui.sameLine();
        if(_imgui.button("Refresh##fileBrowserRefresh")) mModel_.refresh();
        _imgui.sameLine();
        drawBreadcrumbs_();

        _imgui.textDisabled("Path");
        _imgui.setNextItemWidth(-1);
        mPathInput_ = _imgui.inputText("##fileBrowserPath", mPathInput_,
            _imgui.InputTextFlags_EnterReturnsTrue);
        if(_imgui.isItemDeactivatedAfterEdit()){
            if(mModel_.setCurrentPath(mPathInput_)) pathChanged_();
            else mPathInput_ = mModel_.getCurrentPath();
        }

        _imgui.textDisabled("Search");
        _imgui.setNextItemWidth(-1);
        mSearch_ = _imgui.inputText("##fileBrowserSearch", mSearch_);
        _imgui.separator();

        local error = mModel_.getError();
        if(error != null){
            _imgui.textDisabled("Unable to read directory: " + error);
            return;
        }

        local flags = _imgui.TableFlags_RowBg | _imgui.TableFlags_BordersInnerH |
            _imgui.TableFlags_ScrollY | _imgui.TableFlags_Resizable;
        if(!_imgui.beginTable("##fileBrowserEntries", 2, flags, 0, 0)) return;
        _imgui.tableSetupColumn("Name", _imgui.TableColumnFlags_WidthStretch);
        _imgui.tableSetupColumn("Type", _imgui.TableColumnFlags_WidthFixed, 80);
        _imgui.tableHeadersRow();

        local filter = mSearch_.tolower();
        foreach(entry in mModel_.getEntries()){
            if(filter.len() > 0 && entry.name.tolower().find(filter) == null) continue;
            drawEntry_(entry);
        }
        _imgui.endTable();
    }

    function drawBreadcrumbs_(){
        if(_imgui.smallButton(mModel_.getRootPath() + "##fileBrowserRoot")){
            mModel_.goToDepth(0);
            pathChanged_();
        }
        local segments = mModel_.getSegments();
        for(local i = 0; i < segments.len(); i++){
            _imgui.sameLine();
            _imgui.textDisabled("/");
            _imgui.sameLine();
            if(_imgui.smallButton(segments[i] + "##fileBrowserCrumb" + i)){
                mModel_.goToDepth(i + 1);
                pathChanged_();
            }
        }
    }

    function drawEntry_(entry){
        _imgui.tableNextRow();
        _imgui.tableNextColumn();
        local prefix = entry.isDirectory ? "[D] " : "[F] ";
        local selected = mModel_.getSelectedPath() == entry.path;
        if(_imgui.selectable(prefix + entry.name + "##" + entry.path, selected,
            _imgui.SelectableFlags_AllowDoubleClick)){
            mModel_.select(entry);
            if(mOnSelectionChanged_ != null) mOnSelectionChanged_(entry);

            local now = _imgui.getTime();
            local doubleClicked = mLastClickedPath_ == entry.path &&
                now - mLastClickTime_ <= DOUBLE_CLICK_TIME;
            mLastClickedPath_ = entry.path;
            mLastClickTime_ = now;
            if(doubleClicked){
                if(entry.isDirectory){
                    if(mModel_.enter(entry)) pathChanged_();
                }else if(mOnFileActivated_ != null){
                    mOnFileActivated_(entry);
                }
            }
        }
        _imgui.tableNextColumn();
        _imgui.textDisabled(entry.isDirectory ? "Folder" : "File");
    }

    function pathChanged_(){
        mPathInput_ = mModel_.getCurrentPath();
        mLastClickedPath_ = null;
    }
};
