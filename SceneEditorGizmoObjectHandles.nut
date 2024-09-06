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

    constructor(parent, handleType, bus){
        base.constructor(parent);

        mBus_ = bus;
        mHandleType_ = handleType;

        setup(mParentNode_);
    }

    function setup(parent){
        local orientationVals = [
            Quat(-PI/2, Vec3(0, 0, 1)),
            Quat(),
            Quat(PI/2, Vec3(1, 0, 0))
        ];
        mPositionHandles_ = array(3);
        mPositionNodes_ = array(3);
        for(local i = 0; i < 3; i++){
            local newNode = parent.createChildSceneNode();
            local item = _scene.createItem(getObjectForHandle_());
            item.setRenderQueueGroup(30);
            item.setQueryFlags(1 << 10);
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

    function update(){
        beginActionState(_input.getMouseButton(0));

        if(mPerformingAction_ && mTestingPlane_ != null){
            local mousePos = Vec2(_input.getMouseX(), _input.getMouseY()) / _window.getSize();
            local ray = _camera.getCameraToViewportRay(mousePos.x, mousePos.y);
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
                    mBus_.transmitEvent(SceneEditorFramework_BusEvents.HANDLES_GIZMO_INTERACTION_BEGAN, mHandleType_);
                }
                worldPoint += mMovementOffset_;
                if(mHandleType_ == SceneEditorFramework_BasicCoordinateType.POSITION){
                    setPositionForSelectedObject_(worldPoint);
                }
                else if(mHandleType_ == SceneEditorFramework_BasicCoordinateType.SCALE){
                    local diff = mStartPosition_ - worldPoint;
                    setScaleForSelectedObject_(diff);
                }
            }
        }else{
            if(mMovementOffset_ != null){
                mBus_.transmitEvent(SceneEditorFramework_BusEvents.HANDLES_GIZMO_INTERACTION_ENDED, mHandleType_);
            }
            mMovementOffset_ = null;
            mStartPosition_ = null;
        }
    }

    function setScaleForSelectedObject_(newScale){
        print(newScale);
        //mParentNode_.setScale(newScale);

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
        if(mPerformingAction_ != starting){
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
        if(mPerformingAction_) return;
        local axis = getAxisForSceneNodeArray(results);
        if(axis != null){
            if(mOperationInPlace_){

            }else{
                //Just perform a highlight
                if(mHighlightAxis_ != null){
                    resetHighlightForAxis_(mHighlightAxis_);
                }
                mPositionHandles_[axis].setDatablock("SceneEditorFramework/handleHighlight"+axis);
                mHighlightAxis_ = axis;
            }
        }else{
            if(mHighlightAxis_ != null){
                //Reset the highlight.
                //mPositionHandles_[mHighlightAxis_].setDatablock("SceneEditorFramework/handle"+mHighlightAxis_);
                //mHighlightAxis_ = null;
                resetHighlightForAxis_(axis);
            }
        }
    }
    function resetHighlightForAxis_(axis){
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

    function getObjectForHandle_(){
        switch(mHandleType_){
            case SceneEditorFramework_BasicCoordinateType.SCALE:{
                return "scaleHandle.mesh";
            }
            case SceneEditorFramework_BasicCoordinateType.POSITION:
            case SceneEditorFramework_BasicCoordinateType.ORIENTATION:
            default: {
                return "arrow.mesh";
            }
        }
    }

    function getScaleObjectForHandle_(){
        switch(mHandleType_){
            case SceneEditorFramework_BasicCoordinateType.SCALE:{
                return 0.3;
            }
            default: {
                return 1.0;
            }
        }
    }

};