//One copy of the transform gizmo, belonging to a single viewport.
//
//An editor with more than one viewport has one of these per viewport rather than
//one between them, because the size a gizmo has to be depends on the view it is
//being looked at through. The layer is what keeps them apart: it decides which
//viewport draws this copy, and only the copy in the viewport the cursor is
//working in answers the mouse.
//@see SceneEditorFramework.SceneEditorGizmoLayers
::SceneEditorFramework.SceneEditorGizmoObjectHandles <- class extends ::SceneEditorFramework.SceneEditorGizmo{

    mBus_ = null;
    mPositionHandles_ = null;
    mPositionNodes_ = null;
    mOperationInPlace_ = false;
    mHighlightAxis_ = null;
    mMovementOffset_ = null;
    mStartPosition_ = null;
    mStartScale_ = null;

    mPerformingAction_ = null;
    mTestingPlane_ = null;
    mHandleType_ = null;
    mLayer_ = null;

    /**
     * @param layer Which gizmo layer this copy is on, which is the viewport
     * which draws it. @see ::SceneEditorFramework.getGizmoLayerCameras
     */
    constructor(parent, handleType, bus, layer){
        base.constructor(parent);

        mBus_ = bus;
        mHandleType_ = handleType;
        mLayer_ = layer;

        setup(mParentNode_);
    }

    function setup(parent){
        local orientationVals = [
            Quat(-PI/2, Vec3(0, 0, 1)),
            Quat(),
            Quat(PI/2, Vec3(1, 0, 0))
        ];
        local NUM_HANDLES = getNumHandles_();
        mPositionHandles_ = array(NUM_HANDLES);
        mPositionNodes_ = array(NUM_HANDLES);
        for(local i = 0; i < NUM_HANDLES; i++){
            local newNode = parent.createChildSceneNode();
            local item = _scene.createItem(getObjectForHandle_());
            //Its own render queue, so that a compositor can draw the gizmo apart
            //from the scene, and its own visibility flag, so that only the
            //viewport this copy belongs to draws it.
            item.setRenderQueueGroup(SceneEditorFramework_RenderQueue.GIZMO);
            item.setVisibilityFlags(1 << mLayer_);
            //Not queryable until the cursor is in the viewport which draws this
            //copy. @see setQueryable
            item.setQueryFlags(0);
            newNode.attachObject(item);
            local scaleSize = getScaleObjectForHandle_()
            newNode.setScale(scaleSize, scaleSize, scaleSize);

            local targetDatablock = _hlms.getDatablock("SceneEditorFramework/handle"+i);
            item.setDatablock(targetDatablock);
            newNode.setOrientation(orientationVals[i]);

            mPositionHandles_[i] = item;
            mPositionNodes_[i] = newNode;
        }
    }

    function shutdown(){
        mParentNode_.destroyNodeAndChildren();
    }

    /**
     * Whether a ray cast for the gizmo may find this copy of it.
     *
     * Only the copy in the viewport the cursor is working in may. The others are
     * sized for views the ray was not cast from, so what they cover on screen
     * says nothing about what the cursor is over.
     */
    function setQueryable(queryable){
        local flags = queryable ? SceneEditorFramework_QueryFlag.GIZMO_HANDLE : 0;
        foreach(i in mPositionHandles_){
            i.setQueryFlags(flags);
        }
    }

    function update(){
        beginActionState(_input.getMouseButton(_MB_LEFT));

        //A drag which leaves the scene viewport is still a drag, so the position
        //is used whether or not it falls inside it. Null means there is no
        //scene viewport at all, which there is nothing sensible to drag against.
        //
        //The camera is the one belonging to the viewport being dragged in, which
        //is what keeps a drag pointing into the view it began in when the cursor
        //crosses into another viewport. Null means that viewport has gone -
        //closed part way through a drag - so the drag ends with it.
        local mousePos = ::SceneEditorFramework.getNormalisedSceneMousePosition();
        local camera = ::SceneEditorFramework.getActiveSceneCamera();
        if(mPerformingAction_ && mTestingPlane_ != null && mousePos != null && camera != null){
            local ray = camera.getCameraToViewportRay(mousePos.x, mousePos.y);
            local point = ray.intersects(mTestingPlane_);
            if(point != false){
                local worldPoint = ray.getPoint(point);
                local oldPos = mParentNode_.getPositionVec3();
                if(mHighlightAxis_ == 0){
                    worldPoint = Vec3(worldPoint.x, oldPos.y, oldPos.z);
                }
                else if(mHighlightAxis_ == 1){
                    worldPoint = Vec3(oldPos.x, worldPoint.y, oldPos.z);
                }
                else if(mHighlightAxis_ == 2){
                    worldPoint = Vec3(oldPos.x, oldPos.y, worldPoint.z);
                }

                if(mMovementOffset_ == null){
                    mMovementOffset_ = oldPos - worldPoint;
                    mStartPosition_ = oldPos;
                    mBus_.transmitEvent(SceneEditorFramework_BusEvents.HANDLES_GIZMO_INTERACTION_BEGAN, getHandleType_());
                }
                worldPoint += mMovementOffset_;
                if(mHandleType_ == SceneEditorFramework_BasicCoordinateType.POSITION){
                    setPositionForSelectedObject_(worldPoint);
                }
                else if(mHandleType_ == SceneEditorFramework_BasicCoordinateType.SCALE){
                    local diff = mStartPosition_ - worldPoint;
                    setScaleForSelectedObject_(diff);
                }
                else if(mHandleType_ == SceneEditorFramework_BasicCoordinateType.RAYCAST){
                    local foundPos = ::SceneEditorFramework.HelperFunctions.raycastForMovementGizmo();
                    if(foundPos != null){
                        setPositionForSelectedObject_(foundPos);
                    }
                }
            }
        }else{
            if(mMovementOffset_ != null){
                mBus_.transmitEvent(SceneEditorFramework_BusEvents.HANDLES_GIZMO_INTERACTION_ENDED, getHandleType_());
            }
            mMovementOffset_ = null;
            mStartPosition_ = null;
        }
    }

    function applyMaxForVec3(vec){
        local biggest = 0.0;
        if(vec.x != 0.0) biggest = vec.x;
        if(vec.y != 0.0) biggest = vec.y;
        if(vec.z != 0.0) biggest = vec.z;

        vec.x = biggest;
        vec.y = biggest;
        vec.z = biggest;

        return vec;
    }

    function setScaleForSelectedObject_(newScale){
        print(newScale);
        //mParentNode_.setScale(newScale);

        if(_input.getRawKeyScancodeInput(KeyScancode.LSHIFT)){
            newScale = applyMaxForVec3(newScale);
        }
        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_SCALE_CHANGE, newScale);
    }

    function setPositionForSelectedObject_(newPos){
        //mParentNode_.setPosition(newPos);

        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_POSITION_CHANGE, newPos);
    }

    function positionGizmo(pos){
        mParentNode_.setPosition(pos);
    }

    function beginActionState(starting){
        if(mPerformingAction_ != starting && mHighlightAxis_ != null){
            if(starting){
                if(mHighlightAxis_ != null){
                    if(mHighlightAxis_ == 1){
                        mTestingPlane_ = Plane(Vec3(0, 0, 1), mParentNode_.getPositionVec3().z);
                    }else{
                        mTestingPlane_ = Plane(Vec3(0, 1, 0), mParentNode_.getPositionVec3().y);
                    }
                }
            }else{
                mTestingPlane_ = null;
            }
            mPerformingAction_ = starting;
        }
    }

    function updateCameraDist(cameraPos){
        local dist = cameraPos.distance(mParentNode_.getPositionVec3());
        dist *= 0.015;

        mParentNode_.setScale(dist, dist, dist);
    }

    function notifyNewQueryResults(results){
        if(mPerformingAction_) return false;
        local axis = getAxisForSceneNodeArray(results);
        if(axis != null){
            if(mOperationInPlace_){

            }else{
                //Just perform a highlight
                clearHighlight();
                mPositionHandles_[axis].setDatablock("SceneEditorFramework/handleHighlight"+axis);
                mHighlightAxis_ = axis;
            }
        }else{
            clearHighlight();
            return true;
        }
        return false;
    }

    /**
     * Put whichever arm the cursor was over back to its usual colour.
     *
     * Also what a copy which is losing the cursor to another viewport is told,
     * since nothing else would take the highlight off an arm the cursor has
     * stopped being over.
     */
    function clearHighlight(){
        if(mHighlightAxis_ == null) return;

        mPositionHandles_[mHighlightAxis_].setDatablock("SceneEditorFramework/handle"+mHighlightAxis_);
        mHighlightAxis_ = null;
    }

    function getAxisForSceneNodeArray(a){
        if(a == null) return null;
        foreach(i in a){
            foreach(c,y in mPositionNodes_){
                if(i.getParentNode().getId() == y.getId()){
                    return c;
                }
            }
        }
        return null;
    }

    function getHandleType_(){
        return mHandleType_ == SceneEditorFramework_BasicCoordinateType.RAYCAST ? SceneEditorFramework_BasicCoordinateType.POSITION : mHandleType_
    }

    function getNumHandles_(){
        switch(mHandleType_){
            case SceneEditorFramework_BasicCoordinateType.RAYCAST:{
                return 1;
            }
            default: {
                return 3;
            }
        }
    }

    function getObjectForHandle_(){
        switch(mHandleType_){
            case SceneEditorFramework_BasicCoordinateType.SCALE:{
                return "scaleHandle.obj";
            }
            case SceneEditorFramework_BasicCoordinateType.RAYCAST:{
                return "cube";
            }
            case SceneEditorFramework_BasicCoordinateType.POSITION:
            case SceneEditorFramework_BasicCoordinateType.ORIENTATION:
            default: {
                return "arrow.obj";
            }
        }
    }

    function getScaleObjectForHandle_(){
        switch(mHandleType_){
            case SceneEditorFramework_BasicCoordinateType.RAYCAST:{
                return 0.7;
            }
            default: {
                return 1.0;
            }
        }
    }

};