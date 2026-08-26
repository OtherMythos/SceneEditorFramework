//The transform gizmo, as every viewport showing the scene sees it.
//
//A gizmo is sized by its distance from the camera, so that it stays the same
//size on screen however far the view is from the object it belongs to. One set
//of scene nodes can only be one size, so an editor with two viewports looking at
//the same object from different distances cannot show a sensible gizmo in both
//with one of them - whichever camera sized it, the other viewport sees a gizmo
//scaled for a view it is not.
//
//So there is a copy of the gizmo per layer, each sized for the camera of the
//viewport which claimed that layer, and each drawn only by that viewport.
//Everything else about them is the same: they are all on the same object, and
//they all move together when it moves.
//@see ::SceneEditorFramework.getGizmoLayerCameras
//
//The scene tree talks to this rather than to a gizmo, and it forwards to all of
//the copies at once - except for the mouse, which belongs to the one viewport
//the cursor is working in.
//@see ::SceneEditorFramework.getActiveGizmoLayer
::SceneEditorFramework.SceneEditorGizmoLayers <- class{

    mParentNode_ = null;
    mHandleType_ = null;
    mBus_ = null;

    //One entry per layer, null where no viewport is using that layer.
    mLayers_ = null;
    //The layer the cursor is working in, or null when it is in none of them.
    mActiveLayer_ = null;

    //What the gizmo has been told, kept so that a copy created later can be
    //brought up to date with it. A viewport can be opened at any point, which is
    //long after the selection which placed the gizmo was made.
    mVisible_ = false;
    mPosition_ = null;

    constructor(parentNode, handleType, bus){
        mParentNode_ = parentNode;
        mHandleType_ = handleType;
        mBus_ = bus;

        mLayers_ = array(::SceneEditorFramework.MAX_GIZMO_LAYERS, null);
    }

    function shutdown(){
        foreach(c,i in mLayers_){
            if(i == null) continue;

            i.shutdown();
            mLayers_[c] = null;
        }
        mActiveLayer_ = null;
    }

    /**
     * Bring the copies into line with the viewports which are open, and let the
     * one the cursor is in act on the mouse.
     */
    function update(){
        syncLayers_(::SceneEditorFramework.getGizmoLayerCameras());
        setActiveLayer_(::SceneEditorFramework.getActiveGizmoLayer());

        //Every copy, since a modifier which changes what handles a gizmo has
        //changes them wherever the gizmo is drawn rather than only under the
        //cursor. @see SceneEditorGizmoObjectHandles.updateHandleModifiers
        foreach(i in mLayers_){
            if(i != null) i.updateHandleModifiers();
        }

        //A drag belongs to the viewport it began in, which is the one which stays
        //active for as long as the button is held - so a drag which wanders into
        //another viewport carries on being dragged against the view it started
        //in. @see SceneEditorGizmoObjectHandles.update
        local active = getActiveHandles_();
        if(active != null) active.update();
    }

    /**
     * Size each copy for the viewport which is showing it.
     *
     * Separate from update() so that it can be called after whatever moved the
     * gizmo this frame, since how big a gizmo has to be depends on where it now
     * is rather than on where it was.
     */
    function updateScales(){
        local cameras = ::SceneEditorFramework.getGizmoLayerCameras();
        foreach(c,i in mLayers_){
            if(i == null || c >= cameras.len()) continue;

            //Null when the camera is attached to nothing, which leaves the copy
            //the size it was rather than collapsing it to nothing.
            local cameraPos = ::SceneEditorFramework.getCameraPosition(cameras[c]);
            if(cameraPos == null) continue;

            i.updateCameraDist(cameraPos);
        }
    }

    function setVisible(visible){
        mVisible_ = visible;
        foreach(i in mLayers_){
            if(i != null){
                i.setVisible(visible);
                //A gizmo which has just gone away must not be left holding a
                //highlighted arm. The selection is what takes the gizmo away,
                //so an arm which stayed highlighted would be one the next
                //press began a drag against with nothing selected for that
                //drag to act on.
                if(!visible) i.clearIdleHighlight();
            }
        }
    }

    function setPosition(pos){
        positionGizmo(pos);
    }

    function positionGizmo(pos){
        mPosition_ = pos;
        foreach(i in mLayers_){
            if(i != null) i.positionGizmo(pos);
        }
    }

    /**
     * Hand a ray query's results to the copy the cursor is in.
     *
     * No other copy can be in them: only the active one is queryable.
     * @see SceneEditorGizmoObjectHandles.setQueryable
     *
     * @returns Whether the cursor is over something other than the gizmo, which
     * it is when there is no gizmo for it to be over.
     */
    function notifyNewQueryResults(results){
        local active = getActiveHandles_();
        if(active == null) return true;

        //An analytic picker has no hidden render object for the engine query to
        //filter out, so visibility must be enforced here explicitly. The copy
        //is still told to give up any highlight it holds, since the cursor is
        //over nothing as far as a gizmo which is not on show is concerned.
        if(!mVisible_){
            active.clearIdleHighlight();
            return true;
        }

        return active.notifyNewQueryResults(results);
    }

    //Rotation rings pick against their circular paths. Their AABBs overlap and
    //must not be allowed to choose an arbitrary axis before that test runs.
    function usesObjectQuery(){
        return mHandleType_ != SceneEditorFramework_BasicCoordinateType.ORIENTATION;
    }

    //Create a copy of the gizmo for each layer a viewport has claimed, and give
    //up the copy on any layer which has been given up since the last update -
    //the viewport which was drawing it has been closed.
    function syncLayers_(cameras){
        for(local i = 0; i < mLayers_.len(); i++){
            //A project can name fewer layers than the framework has room for,
            //and a layer past the end of the list is one nothing is using.
            local camera = i < cameras.len() ? cameras[i] : null;

            if(camera != null && mLayers_[i] == null){
                local HandleClass = mHandleType_ == SceneEditorFramework_BasicCoordinateType.ORIENTATION ?
                    ::SceneEditorFramework.SceneEditorGizmoRotationHandles :
                    ::SceneEditorFramework.SceneEditorGizmoObjectHandles;
                local handles = HandleClass(mParentNode_, mHandleType_, mBus_, i);
                handles.setVisible(mVisible_);
                if(mPosition_ != null) handles.positionGizmo(mPosition_);

                mLayers_[i] = handles;
            }
            else if(camera == null && mLayers_[i] != null){
                mLayers_[i].shutdown();
                mLayers_[i] = null;

                //Nothing can be working in a viewport which has gone.
                if(mActiveLayer_ == i) mActiveLayer_ = null;
            }
        }
    }

    function setActiveLayer_(layer){
        //A layer no viewport is using is not one the cursor can be in, whatever
        //the project says.
        if(layer != null && (layer < 0 || layer >= mLayers_.len() || mLayers_[layer] == null)){
            layer = null;
        }
        if(layer == mActiveLayer_) return;

        //The copy losing the cursor keeps whatever the cursor left highlighted,
        //and nothing else would ever take that highlight off it.
        local previous = getActiveHandles_();
        if(previous != null){
            previous.clearHighlight();
            previous.setQueryable(false);
        }

        mActiveLayer_ = layer;

        local active = getActiveHandles_();
        if(active != null) active.setQueryable(true);
    }

    function getActiveHandles_(){
        return mActiveLayer_ == null ? null : mLayers_[mActiveLayer_];
    }

};
