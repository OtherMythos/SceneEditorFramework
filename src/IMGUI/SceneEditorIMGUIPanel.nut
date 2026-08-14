::SceneEditorFramework.IMGUI.Panel <- class{

    mBaseObj_ = null;
    mBus_ = null;
    mVisible_ = true;

    //The editor shell uses these to persist both floating-window geometry and
    //the dock leaf this panel belongs to. They are deliberately kept on the
    //generic panel so projects can save them between ImGui frames.
    mDockId_ = 0;
    mWindowPosition_ = null;
    mWindowSize_ = null;
    mWindowCollapsed_ = false;
    mTabVisible_ = true;
    mInitialWindowStatePending_ = false;

    constructor(baseObj, bus){
        mBaseObj_ = baseObj;
        mBus_ = bus;
    }

    function setup(){
    }

    function shutdown(){
    }

    function setVisible(visible){
        mVisible_ = visible;
    }

    function isVisible(){
        return mVisible_;
    }

    function toggleVisible(){
        mVisible_ = !mVisible_;
    }

    //Call immediately before begin(). A floating window has to receive its
    //saved geometry on its first submitted frame; docked panels are positioned
    //by the dock builder instead.
    function applyInitialWindowState_(){
        if(!mInitialWindowStatePending_) return;
        if(mDockId_ != 0){
            if(mTabVisible_) _imgui.setNextWindowFocus();
            mInitialWindowStatePending_ = false;
            return;
        }

        if(mWindowPosition_ != null){
            _imgui.setNextWindowPos(mWindowPosition_[0], mWindowPosition_[1],
                _imgui.Cond_FirstUseEver);
        }
        if(mWindowSize_ != null){
            _imgui.setNextWindowSize(mWindowSize_[0], mWindowSize_[1],
                _imgui.Cond_FirstUseEver);
        }
        _imgui.setNextWindowCollapsed(mWindowCollapsed_, _imgui.Cond_FirstUseEver);
        mInitialWindowStatePending_ = false;
    }

    //Call between begin() and end(), including when begin() returns false.
    function captureWindowState_(shown){
        mDockId_ = _imgui.getWindowDockId();
        mWindowPosition_ = _imgui.getWindowPos();
        mWindowSize_ = _imgui.getWindowSize();
        mWindowCollapsed_ = _imgui.isWindowCollapsed();
        mTabVisible_ = shown && !mWindowCollapsed_;
    }

    function getWindowState(){
        return {
            "title": mWindowTitle_,
            "dockId": mDockId_,
            "position": mWindowPosition_,
            "size": mWindowSize_,
            "collapsed": mWindowCollapsed_,
            "tabVisible": mTabVisible_
        };
    }

    function applyWindowState(state){
        if(state == null || typeof state != "table") return;
        if(state.rawin("dockId")) mDockId_ = state.rawget("dockId");
        if(state.rawin("position")) mWindowPosition_ = state.rawget("position");
        if(state.rawin("size")) mWindowSize_ = state.rawget("size");
        if(state.rawin("collapsed")) mWindowCollapsed_ = state.rawget("collapsed");
        if(state.rawin("tabVisible")) mTabVisible_ = state.rawget("tabVisible");
        mInitialWindowStatePending_ = true;
    }

    function draw(){
    }
};
