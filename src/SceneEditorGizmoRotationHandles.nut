//Three world-axis rings used to rotate the selected scene entry. Like the
//position/scale handles, each viewport owns a copy sized for its camera.
::SceneEditorFramework.SceneEditorGizmoRotationHandles <- class extends ::SceneEditorFramework.SceneEditorGizmo{

    RING_MESH = "rotationRing.obj";
    RING_RADIUS = 2.15;
    PICK_RADIUS = 0.24;
    PICK_SEGMENTS = 64;

    mBus_ = null;
    mHandles_ = null;
    mHandleNodes_ = null;
    mHighlightAxis_ = null;
    mPerformingAction_ = false;
    mTestingPlane_ = null;
    mStartVector_ = null;
    mLayer_ = null;
    mQueryable_ = false;

    constructor(parent, handleType, bus, layer){
        base.constructor(parent);

        mBus_ = bus;
        mLayer_ = layer;
        setup_();
    }

    function setup_(){
        //The mesh lies in XZ with Y as its normal. Rotate that normal onto the
        //world X, Y and Z axes in the same order as the handle colour palette.
        local orientations = [
            Quat(-PI / 2, Vec3(0, 0, 1)),
            Quat(),
            Quat(PI / 2, Vec3(1, 0, 0))
        ];

        mHandles_ = array(3);
        mHandleNodes_ = array(3);
        for(local axis = 0; axis < 3; axis++){
            local node = mParentNode_.createChildSceneNode();
            local item = _scene.createItem(RING_MESH);
            item.setRenderQueueGroup(SceneEditorFramework_RenderQueue.GIZMO);
            item.setVisibilityFlags(1 << mLayer_);
            item.setQueryFlags(0);
            item.setDatablock(_hlms.getDatablock("SceneEditorFramework/handle" + axis));
            node.attachObject(item);
            node.setOrientation(orientations[axis]);

            mHandles_[axis] = item;
            mHandleNodes_[axis] = node;
        }
    }

    function shutdown(){
        mParentNode_.destroyNodeAndChildren();
    }

    function setQueryable(queryable){
        //The rings' boxes overlap too much to identify one another. They remain
        //absent from the object query and are picked analytically instead.
        mQueryable_ = queryable;
        foreach(handle in mHandles_) handle.setQueryFlags(0);
    }

    function update(){
        local mouseDown = _input.getMouseButton(_MB_LEFT);
        if(!mPerformingAction_ && mouseDown && mHighlightAxis_ != null){
            mPerformingAction_ = true;
            mStartVector_ = null;
            mTestingPlane_ = Plane(axisVector_(mHighlightAxis_),
                centre_());
        }

        if(!mPerformingAction_) return;
        if(!mouseDown){
            finishInteraction_();
            return;
        }

        local mousePos = ::SceneEditorFramework.getNormalisedSceneMousePosition();
        local camera = ::SceneEditorFramework.getActiveSceneCamera();
        if(mousePos == null || camera == null){
            finishInteraction_();
            return;
        }

        local ray = camera.getCameraToViewportRay(mousePos.x, mousePos.y);
        local intersection = ray.intersects(mTestingPlane_);
        if(intersection == false) return;

        local mouseVector = ray.getPoint(intersection) - centre_();
        if(mouseVector.length() < 0.0001) return;
        mouseVector.normalise();

        if(mStartVector_ == null){
            mStartVector_ = mouseVector;
            mBus_.transmitEvent(SceneEditorFramework_BusEvents.HANDLES_GIZMO_INTERACTION_BEGAN,
                SceneEditorFramework_BasicCoordinateType.ORIENTATION);
            return;
        }

        local axis = axisVector_(mHighlightAxis_);
        local sine = axis.dot(mStartVector_.cross(mouseVector));
        local cosine = mStartVector_.dot(mouseVector);
        local angle = atan2(sine, cosine);
        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_ORIENTATION_CHANGE,
            Quat(angle, axis));
    }

    function finishInteraction_(){
        if(mStartVector_ != null){
            mBus_.transmitEvent(SceneEditorFramework_BusEvents.HANDLES_GIZMO_INTERACTION_ENDED,
                SceneEditorFramework_BasicCoordinateType.ORIENTATION);
        }
        mPerformingAction_ = false;
        mTestingPlane_ = null;
        mStartVector_ = null;
    }

    function updateCameraDist(cameraPos){
        local distance = cameraPos.distance(mParentNode_.getPositionVec3());
        distance *= 0.015;
        mParentNode_.setScale(distance, distance, distance);
    }

    function positionGizmo(pos){
        mParentNode_.setPosition(pos);
    }

    function notifyNewQueryResults(results){
        if(mPerformingAction_) return false;

        local axis = mQueryable_ ? pickAxis_() : null;
        if(axis == null){
            clearHighlight();
            return true;
        }

        if(mHighlightAxis_ == axis) return false;
        clearHighlight();
        mHandles_[axis].setDatablock("SceneEditorFramework/handleHighlight" + axis);
        mHighlightAxis_ = axis;
        return false;
    }

    function clearHighlight(){
        if(mHighlightAxis_ == null) return;
        mHandles_[mHighlightAxis_].setDatablock(
            "SceneEditorFramework/handle" + mHighlightAxis_);
        mHighlightAxis_ = null;
    }

    function pickAxis_(){
        local mousePos = ::SceneEditorFramework.getNormalisedSceneMousePosition();
        local camera = ::SceneEditorFramework.getActiveSceneCamera();
        if(mousePos == null || camera == null) return null;

        return pickAxisForRay_(camera.getCameraToViewportRay(mousePos.x, mousePos.y));
    }

    //Pick the actual circular paths rather than their heavily overlapping
    //bounding boxes. The gizmo has a uniform distance-dependent scale, so
    //dividing by it keeps the grab radius approximately constant on screen.
    //Sampling the circle also keeps an edge-on ring selectable, where a
    //ray/plane intersection would have no result.
    function pickAxisForRay_(ray){
        local scale = mParentNode_.getDerivedScale().x;
        if(scale <= 0.0001) return null;

        local origin = ray.getOrigin();
        local direction = ray.getDirection();
        direction.normalise();

        local centre = centre_();
        local radius = RING_RADIUS * scale;
        local bestDistance = PICK_RADIUS;
        local bestAxis = null;

        for(local axis = 0; axis < 3; axis++){
            for(local sample = 0; sample < PICK_SEGMENTS; sample++){
                local angle = 2.0 * PI * sample / PICK_SEGMENTS;
                local point = centre + circlePoint_(axis,
                    cos(angle) * radius, sin(angle) * radius);
                local fromOrigin = point - origin;
                local alongRay = fromOrigin.dot(direction);
                if(alongRay < 0.0) continue;

                local closest = origin + direction * alongRay;
                local distance = point.distance(closest) / scale;
                if(distance < bestDistance){
                    bestDistance = distance;
                    bestAxis = axis;
                }
            }
        }

        return bestAxis;
    }

    function circlePoint_(axis, first, second){
        if(axis == 0) return Vec3(0, first, second);
        if(axis == 1) return Vec3(first, 0, second);
        return Vec3(first, second, 0);
    }

    function axisVector_(axis){
        if(axis == 0) return Vec3(1, 0, 0);
        if(axis == 1) return Vec3(0, 1, 0);
        return Vec3(0, 0, 1);
    }

    //Camera rays and the rotation plane are in world space. This differs from
    //getPositionVec3() whenever an editor puts its gizmo beneath a transformed
    //scene node.
    function centre_(){
        return mParentNode_.getDerivedPositionVec3();
    }
};
