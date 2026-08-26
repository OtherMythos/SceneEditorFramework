/** Process-wide resource drag state for the single ImGui context. */
::SceneEditorFramework.IMGUI.ResourceDragDrop <- class{

    static DRAG_THRESHOLD = 8.0;
    static mState_ = {
        candidate = null,
        startMouse = null,
        draggedEntry = null,
        dropCallback = null
    };

    static function beginCandidate(entry){
        if(entry == null || entry.isDirectory) return;
        mState_.candidate = entry;
        mState_.startMouse = _imgui.getMousePos();
    }

    //Called before panels are submitted so every target sees the same state.
    static function update(){
        mState_.dropCallback = null;
        if(mState_.draggedEntry != null || mState_.candidate == null) return;
        if(!_imgui.isMouseDown(_imgui.MouseButton_Left)){
            mState_.candidate = null;
            mState_.startMouse = null;
            return;
        }

        local mouse = _imgui.getMousePos();
        local x = mouse[0] - mState_.startMouse[0];
        local y = mouse[1] - mState_.startMouse[1];
        if(x * x + y * y >= DRAG_THRESHOLD * DRAG_THRESHOLD){
            mState_.draggedEntry = mState_.candidate;
            mState_.candidate = null;
        }
    }

    static function isDragging(){ return mState_.draggedEntry != null; }
    static function getDraggedEntry(){ return mState_.draggedEntry; }

    static function getMousePosition(){
        return _imgui.getMousePos();
    }

    static function offerTarget(kind, callback){
        if(mState_.draggedEntry == null || mState_.draggedEntry.kind != kind) return false;
        mState_.dropCallback = callback;
        return true;
    }

    //Called after all panels so the target hovered on the release frame wins.
    static function finishFrame(){
        if(mState_.draggedEntry != null &&
            _imgui.isMouseReleased(_imgui.MouseButton_Left)){
            local entry = mState_.draggedEntry;
            local callback = mState_.dropCallback;
            clear();
            if(callback != null) callback(entry);
            return;
        }
        if(mState_.draggedEntry == null &&
            _imgui.isMouseReleased(_imgui.MouseButton_Left)){
            mState_.candidate = null;
            mState_.startMouse = null;
        }
    }

    static function drawFeedback(){
        if(mState_.draggedEntry == null) return;
        if(_imgui.beginTooltip()){
            _imgui.text("Dragging " + mState_.draggedEntry.name);
            _imgui.textDisabled(mState_.draggedEntry.kind);
            _imgui.endTooltip();
        }
    }

    static function clear(){
        mState_.candidate = null;
        mState_.startMouse = null;
        mState_.draggedEntry = null;
        mState_.dropCallback = null;
    }
};
