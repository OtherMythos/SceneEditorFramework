/** A dockable, filesystem-backed resource browser. */
::SceneEditorFramework.IMGUI.FileBrowser <- class extends ::SceneEditorFramework.IMGUI.Panel{

    DOUBLE_CLICK_TIME = 0.35;
    TILE_WIDTH = 112.0;
    TILE_HEIGHT = 132.0;
    TILE_GAP = 8.0;
    ICON_SIZE = 76.0;
    MAX_LABEL_CHARACTERS = 18;

    mWindowTitle_ = "File Browser##SceneEditorFrameworkFileBrowser";
    mModel_ = null;
    mSearch_ = "";
    mPathInput_ = "";
    mLastClickedPath_ = null;
    mLastClickTime_ = -100.0;
    mOnSelectionChanged_ = null;
    mOnFileActivated_ = null;
    //Return { texture, uv0=[x,y], uv1=[x,y] } for an entry, or null to use
    //the atlas icon. A future asynchronous thumbnail cache plugs in here.
    mPreviewProvider_ = null;
    mKindFilter_ = null;
    mIconTexture_ = null;

    constructor(baseObj, bus){
        base.constructor(baseObj, bus);
        mIconTexture_ = ::SceneEditorFramework.IMGUI.Textures.get(
            ::SceneEditorFramework.IMGUI.Textures.FILE_BROWSER_ICONS);
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
        if(options.rawin("previewProvider")){
            mPreviewProvider_ = options.rawget("previewProvider");
        }
        if(options.rawin("kindFilter")) mKindFilter_ = options.rawget("kindFilter");
    }

    function getModel(){ return mModel_; }

    function setKindFilter(kind){
        mKindFilter_ = kind;
        if(mModel_ != null) mModel_.select(null);
    }

    function getKindFilter(){ return mKindFilter_; }

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

        drawIconGrid_();
    }

    function drawBreadcrumbs_(){
        if(_imgui.button(mModel_.getRootPath() + "##fileBrowserRoot")){
            mModel_.goToDepth(0);
            pathChanged_();
        }
        local segments = mModel_.getSegments();
        for(local i = 0; i < segments.len(); i++){
            _imgui.sameLine();
            _imgui.textDisabled("/");
            _imgui.sameLine();
            if(_imgui.button(segments[i] + "##fileBrowserCrumb" + i)){
                mModel_.goToDepth(i + 1);
                pathChanged_();
            }
        }
    }

    function drawIconGrid_(){
        local guiScale = _imgui.getGlobalScale();
        local tileWidth = TILE_WIDTH * guiScale;
        local tileHeight = TILE_HEIGHT * guiScale;
        local gap = TILE_GAP * guiScale;
        local available = _imgui.getContentRegionAvail();
        local columns = ((available[0] + gap) / (tileWidth + gap)).tointeger();
        if(columns < 1) columns = 1;

        local filter = mSearch_.tolower();
        local visibleIndex = 0;
        if(!_imgui.beginChild("##fileBrowserIconGrid", 0, 0, 0)){
            _imgui.endChild();
            return;
        }
        foreach(entry in mModel_.getEntries()){
            if(mKindFilter_ != null && !entry.isDirectory && entry.kind != mKindFilter_) continue;
            if(filter.len() > 0 && entry.name.tolower().find(filter) == null) continue;
            if(visibleIndex % columns != 0) _imgui.sameLine();
            drawTile_(entry, tileWidth, tileHeight, guiScale);
            visibleIndex++;
        }
        if(visibleIndex == 0) _imgui.textDisabled("No matching files");
        _imgui.endChild();
    }

    function drawTile_(entry, tileWidth, tileHeight, guiScale){
        local selected = mModel_.getSelectedPath() == entry.path;
        if(selected) _imgui.pushStyleColor(_imgui.Col_ChildBg, 0.22, 0.38, 0.58, 0.65);
        _imgui.pushStyleVar(_imgui.StyleVar_ChildRounding, 4.0 * guiScale);
        _imgui.pushStyleColor(_imgui.Col_Button, 0.0, 0.0, 0.0, 0.0);
        _imgui.pushStyleColor(_imgui.Col_ButtonHovered, 0.35, 0.35, 0.35, 0.55);
        _imgui.pushStyleColor(_imgui.Col_ButtonActive, 0.5, 0.5, 0.5, 0.65);

        local open = _imgui.beginChild("##fileBrowserTile" + entry.path,
            tileWidth, tileHeight, _imgui.ChildFlags_Borders,
            _imgui.WindowFlags_NoScrollbar | _imgui.WindowFlags_NoScrollWithMouse);
        if(open){
            local iconSize = ICON_SIZE * guiScale;
            local currentY = _imgui.getCursorPosY();
            _imgui.setCursorPos((tileWidth - iconSize) * 0.5, currentY);
            local preview = previewForEntry_(entry);
            local clicked = _imgui.imageButton("##fileBrowserIcon" + entry.path,
                preview.texture, iconSize, iconSize,
                preview.uv0[0], preview.uv0[1], preview.uv1[0], preview.uv1[1]);
            local iconHovered = _imgui.isItemHovered();
            if(_imgui.isItemClicked()){
                ::SceneEditorFramework.IMGUI.ResourceDragDrop.beginCandidate(entry);
            }
            drawLabel_(entry.name, tileWidth, guiScale);
            if(iconHovered) _imgui.setTooltip(entry.path);
            if(clicked) handleEntryClick_(entry);
        }
        _imgui.endChild();

        _imgui.popStyleColor(3);
        _imgui.popStyleVar();
        if(selected) _imgui.popStyleColor();
    }

    function drawLabel_(name, tileWidth, guiScale){
        local label = name;
        if(label.len() > MAX_LABEL_CHARACTERS){
            label = label.slice(0, MAX_LABEL_CHARACTERS - 3) + "...";
        }
        local textSize = _imgui.calcTextSize(label);
        local x = (tileWidth - textSize[0]) * 0.5;
        if(x < 0) x = 0;
        _imgui.setCursorPos(x, _imgui.getCursorPosY());
        _imgui.text(label);
    }

    function handleEntryClick_(entry){
        mModel_.select(entry);
        if(mOnSelectionChanged_ != null) mOnSelectionChanged_(entry);

        local now = _imgui.getTime();
        local doubleClicked = mLastClickedPath_ == entry.path &&
            now - mLastClickTime_ <= DOUBLE_CLICK_TIME;
        mLastClickedPath_ = entry.path;
        mLastClickTime_ = now;
        if(!doubleClicked) return;

        if(entry.isDirectory){
            if(mModel_.enter(entry)) pathChanged_();
        }else if(mOnFileActivated_ != null){
            mOnFileActivated_(entry);
        }
    }

    function previewForEntry_(entry){
        if(mPreviewProvider_ != null){
            local preview = mPreviewProvider_(entry);
            if(preview != null && typeof preview == "table" &&
                preview.rawin("texture")){
                return {
                    texture = preview.texture,
                    uv0 = preview.rawin("uv0") ? preview.uv0 : [0.0, 0.0],
                    uv1 = preview.rawin("uv1") ? preview.uv1 : [1.0, 1.0]
                };
            }
        }

        local uv0 = [0.0, 0.358];
        local uv1 = [0.225, 0.83];
        if(entry.kind == "directory"){
            uv0 = [0.0, 0.0]; uv1 = [0.225, 0.358];
        }else if(entry.kind == "texture"){
            uv0 = [0.235, 0.358]; uv1 = [0.5, 0.83];
        }else if(entry.kind == "mesh"){
            uv0 = [0.46, 0.358]; uv1 = [0.71, 0.83];
        }else if(entry.kind == "script"){
            uv0 = [0.685, 0.358]; uv1 = [0.94, 0.83];
        }
        return { texture = mIconTexture_, uv0 = uv0, uv1 = uv1 };
    }

    function pathChanged_(){
        mPathInput_ = mModel_.getCurrentPath();
        mLastClickedPath_ = null;
    }
};
