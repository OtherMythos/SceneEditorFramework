//One copy of the transform gizmo, belonging to a single viewport.
//
//An editor with more than one viewport has one of these per viewport rather than
//one between them, because the size a gizmo has to be depends on the view it is
//being looked at through. The layer is what keeps them apart: it decides which
//viewport draws this copy, and only the copy in the viewport the cursor is
//working in answers the mouse.
//@see SceneEditorFramework.SceneEditorGizmoLayers
::SceneEditorFramework.SceneEditorGizmoObjectHandles <- class extends ::SceneEditorFramework.SceneEditorGizmo{

    //Where the negative-direction handles of the scale gizmo begin. The handles
    //before them are the three positive arms and the three plane handles, which
    //every position and scale gizmo has; from here on are the three arms and
    //the three plane handles which face the other way.
    //@see isDirectionalHandle_
    FIRST_DIRECTIONAL_HANDLE = 6;
    //Where the plane handles of that second set begin.
    FIRST_DIRECTIONAL_PLANE_HANDLE = 9;

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

    //Whether a ray cast for the gizmo may find this copy at all, which the
    //per-handle flags are then worked out from.
    //@see setQueryable
    mQueryable_ = false;
    //Whether the negative-direction arms are on show, which is what the
    //one-sided scale modifier puts them there for.
    //@see updateHandleModifiers
    mDirectionalHandlesShown_ = false;
    //Which way the drag in progress is growing what it is resizing, or null
    //when it grows it evenly about its own middle as a scale always used to.
    //Decided when the drag begins and kept for as long as it runs.
    //@see ::SceneEditorFramework.gizmoOneSidedScaleModifierHeld
    mOneSidedDirection_ = null;

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
            Quat(PI/2, Vec3(1, 0, 0)),

            //The plane mesh is in XY. These put its positive quadrant beside
            //the matching pair of axis arms: YZ, XZ and XY respectively.
            Quat(-PI/2, Vec3(0, 1, 0)),
            Quat(PI/2, Vec3(1, 0, 0)),
            Quat(),

            //The same three arms turned to point the other way, which is what
            //gives every side of an object a handle of its own.
            Quat(PI/2, Vec3(0, 0, 1)),
            Quat(PI, Vec3(0, 0, 1)),
            Quat(-PI/2, Vec3(1, 0, 0)),

            //And the same three plane handles turned half way round within
            //their own plane, which puts each of them in the quadrant opposite
            //the one it was in - so a pair of axes can be taken by their
            //negative corner as well as by their positive one.
            Quat(-PI/2, Vec3(0, 1, 0)) * Quat(PI, Vec3(0, 0, 1)),
            Quat(PI/2, Vec3(1, 0, 0)) * Quat(PI, Vec3(0, 0, 1)),
            Quat(PI, Vec3(0, 0, 1))
        ];
        local NUM_HANDLES = getNumHandles_();
        mPositionHandles_ = array(NUM_HANDLES);
        mPositionNodes_ = array(NUM_HANDLES);
        for(local i = 0; i < NUM_HANDLES; i++){
            local newNode = parent.createChildSceneNode();
            local item = _scene.createItem(getObjectForHandle_(i));
            //Its own render queue, so that a compositor can draw the gizmo apart
            //from the scene, and its own visibility flag, so that only the
            //viewport this copy belongs to draws it.
            item.setRenderQueueGroup(SceneEditorFramework_RenderQueue.GIZMO);
            item.setVisibilityFlags(visibilityFlagsForHandle_(i));
            //Not queryable until the cursor is in the viewport which draws this
            //copy. @see setQueryable
            item.setQueryFlags(0);
            newNode.attachObject(item);
            local scaleSize = getScaleObjectForHandle_()
            newNode.setScale(scaleSize, scaleSize, scaleSize);

            local targetDatablock = _hlms.getDatablock(datablockName_(i));
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
        mQueryable_ = queryable;
        foreach(c,i in mPositionHandles_){
            i.setQueryFlags(queryFlagsForHandle_(c));
        }
    }

    /**
     * Put the negative-direction arms of a scale gizmo on show, or take them
     * away, according to whether the one-sided scale modifier is held.
     *
     * A handle which is not on show cannot be picked either, so the cursor
     * cannot find an arm which is not there to be seen.
     * @see ::SceneEditorFramework.gizmoOneSidedScaleModifierHeld
     */
    #Override
    function updateHandleModifiers(){
        if(!hasDirectionalHandles_()) return;

        //A drag holds on to the arm it began against for as long as it runs,
        //since letting go of the modifier part way through one would otherwise
        //take away the arm being dragged.
        local shown = mPerformingAction_ ?
            mDirectionalHandlesShown_ :
            ::SceneEditorFramework.gizmoOneSidedScaleModifierHeld();
        if(shown == mDirectionalHandlesShown_) return;

        mDirectionalHandlesShown_ = shown;
        //Nothing else would take the highlight off an arm which has just been
        //taken away from under the cursor.
        if(!shown && mHighlightAxis_ != null &&
                isDirectionalHandle_(mHighlightAxis_)){
            clearHighlight();
        }

        for(local i = FIRST_DIRECTIONAL_HANDLE; i < mPositionHandles_.len(); i++){
            mPositionHandles_[i].setVisibilityFlags(visibilityFlagsForHandle_(i));
            mPositionHandles_[i].setQueryFlags(queryFlagsForHandle_(i));
        }
    }

    function update(){
        beginActionState(_imgui.isMouseDown(_imgui.MouseButton_Left));

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
                worldPoint = constrainMovement_(worldPoint, oldPos,
                    mHighlightAxis_);

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
                    if(mOneSidedDirection_ == null){
                        setScaleForSelectedObject_(diff);
                    }else{
                        //A handle which faces the negative way grows what it
                        //is dragging when it is pulled that way, the same as the
                        //one opposite it does, so the drag is read backwards
                        //along the axes it belongs to. Every axis such a handle
                        //takes is a negative one, and the drag leaves the rest
                        //at nothing, so the whole of it is turned round.
                        if(isDirectionalHandle_(mHighlightAxis_)){
                            diff = worldPoint - mStartPosition_;
                        }
                        setOneSidedScaleForSelectedObject_(diff, mOneSidedDirection_);
                    }
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

    //Put the furthest the drag went along any one axis on all three of them,
    //which is what makes a scale drag uniform.
    //
    //Furthest rather than last: a single-axis drag has only one axis to take,
    //but a plane handle drag has two, and the one which moved less is the one
    //the user was less clear about. Its sign is kept, so a uniform drag inward
    //still shrinks.
    function applyMaxForVec3(vec){
        local biggest = 0.0;
        local biggestSize = 0.0;
        foreach(value in [vec.x, vec.y, vec.z]){
            local size = value < 0.0 ? -value : value;
            if(size <= biggestSize) continue;

            biggestSize = size;
            biggest = value;
        }

        vec.x = biggest;
        vec.y = biggest;
        vec.z = biggest;

        return vec;
    }

    function setScaleForSelectedObject_(newScale){
        if(::SceneEditorFramework.gizmoUniformScaleModifierHeld()){
            newScale = applyMaxForVec3(newScale);
        }
        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_SCALE_CHANGE, newScale);
    }

    //The same drag as the one above, with the direction it is growing in
    //carried along beside it: the amount says how much bigger the object is to
    //be, and the direction says which of its sides is to move to make it so.
    //
    //The uniform modifier still applies, and applies to the amount alone - all
    //three axes are given the drag, and the side named by the direction is
    //still the only one held still.
    function setOneSidedScaleForSelectedObject_(newScale, direction){
        if(::SceneEditorFramework.gizmoUniformScaleModifierHeld()){
            newScale = applyMaxForVec3(newScale);
        }
        mBus_.transmitEvent(
            SceneEditorFramework_BusEvents.SELECTED_SCALE_ONE_SIDED_CHANGE, {
                "amount": newScale,
                "direction": direction
            });
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
                mTestingPlane_ = movementPlane_(mHighlightAxis_);
                mOneSidedDirection_ = oneSidedDirectionForDrag_(mHighlightAxis_);
            }else{
                mTestingPlane_ = null;
                mOneSidedDirection_ = null;
            }
            mPerformingAction_ = starting;
        }
    }

    //Which way a drag of this handle grows what it is resizing, or null when it
    //grows it evenly about its own middle.
    //
    //Read as the drag begins rather than while it runs: the arms which only
    //exist while the modifier is held are the ones this is most often used
    //with, and a drag cannot go on against an arm which has been taken away.
    function oneSidedDirectionForDrag_(handle){
        if(mHandleType_ != SceneEditorFramework_BasicCoordinateType.SCALE) return null;
        if(!isDirectionalHandle_(handle) &&
            !::SceneEditorFramework.gizmoOneSidedScaleModifierHeld()){
            return null;
        }

        return handleDirection_(handle);
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
                mPositionHandles_[axis].setDatablock(datablockName_(axis, true));
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

        mPositionHandles_[mHighlightAxis_].setDatablock(
            datablockName_(mHighlightAxis_));
        mHighlightAxis_ = null;
    }

    /**
     * Give up the highlight the cursor left on an arm, which is what a copy
     * whose gizmo has stopped being on show is told.
     *
     * A drag keeps the arm it began against: beginActionState reads the
     * highlight to know a drag is running against that arm, and to know how to
     * end it, so a drag in progress is left holding its own.
     */
    function clearIdleHighlight(){
        if(mPerformingAction_) return;

        clearHighlight();
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
            case SceneEditorFramework_BasicCoordinateType.SCALE:{
                //Three arms and the YZ, XZ and XY plane handles, and then the
                //same six facing the other way: an arm down the negative end of
                //each axis, and a plane handle in the negative quadrant of each
                //pair of them.
                return 12;
            }
            case SceneEditorFramework_BasicCoordinateType.POSITION:{
                //Three arms followed by the YZ, XZ and XY plane handles.
                return 6;
            }
            case SceneEditorFramework_BasicCoordinateType.RAYCAST:{
                return 1;
            }
            default: {
                return 3;
            }
        }
    }

    function getObjectForHandle_(handle){
        if(isPlaneHandle_(handle)) return "planeHandle.obj";

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

    //Handles three, four and five of a gizmo which has them, and nine, ten and
    //eleven of a scale gizmo. A position gizmo moves along the pair of axes the
    //handle stands for; a scale gizmo resizes along that same pair, which is
    //what makes a box wider and deeper without making it taller. Neither the
    //mesh nor the drag differs between the two - only what the axes it produces
    //are then used for.
    function isPlaneHandle_(handle){
        if(mHandleType_ != SceneEditorFramework_BasicCoordinateType.POSITION &&
            mHandleType_ != SceneEditorFramework_BasicCoordinateType.SCALE){
            return false;
        }

        return (handle >= 3 && handle < FIRST_DIRECTIONAL_HANDLE) ||
            handle >= FIRST_DIRECTIONAL_PLANE_HANDLE;
    }

    //Whether a scale gizmo has the second set of handles: the three arms which
    //point down the negative end of each axis, and the three plane handles in
    //the negative quadrant of each pair of them. They are what makes the far
    //side of an object reachable: an object is grown from whichever side its
    //handle was dragged, so a side with no handle on it could not be the one to
    //move.
    function hasDirectionalHandles_(){
        return mHandleType_ == SceneEditorFramework_BasicCoordinateType.SCALE;
    }

    function isDirectionalHandle_(handle){
        return hasDirectionalHandles_() && handle >= FIRST_DIRECTIONAL_HANDLE;
    }

    //Which of the six drags a handle makes: the three single-axis ones followed
    //by the YZ, XZ and XY plane ones. A handle which faces the negative way
    //makes the same drag as the one it is opposite, along the same axes.
    function dragForHandle_(handle){
        return isDirectionalHandle_(handle) ?
            handle - FIRST_DIRECTIONAL_HANDLE : handle;
    }

    //Which axis, or which pair of them, a handle belongs to - which is what
    //colours it. A handle facing the negative way is the same axes, and so the
    //same colour, as the one it is opposite.
    function axisForHandle_(handle){
        local drag = dragForHandle_(handle);
        return isPlaneHandle_(handle) ? drag - 3 : drag;
    }

    /**
     * Which way a drag of a handle points, as a component per axis.
     *
     * An arm has the one axis it points along, and a plane handle has the two
     * it lies between - both positive, since the plane handles sit in the
     * positive quadrant of the pair they belong to.
     *
     * This is the side of an object a one-sided scale grows: the opposite side
     * is the one held where it is.
     */
    function handleDirection_(handle){
        local sign = isDirectionalHandle_(handle) ? -1 : 1;

        local drag = dragForHandle_(handle);
        if(drag == 0) return Vec3(sign, 0, 0);
        if(drag == 1) return Vec3(0, sign, 0);
        if(drag == 2) return Vec3(0, 0, sign);
        if(drag == 3) return Vec3(0, sign, sign);
        if(drag == 4) return Vec3(sign, 0, sign);
        return Vec3(sign, sign, 0);
    }

    //A handle nothing is drawing is one with no visibility flag at all, rather
    //than one on another layer: the negative-direction arms come and go with a
    //modifier, and they do so in every viewport at once.
    function visibilityFlagsForHandle_(handle){
        if(isDirectionalHandle_(handle) && !mDirectionalHandlesShown_) return 0;
        return 1 << mLayer_;
    }

    //An arm which is not on show is not one the cursor can be over either.
    function queryFlagsForHandle_(handle){
        if(!mQueryable_) return 0;
        if(isDirectionalHandle_(handle) && !mDirectionalHandlesShown_) return 0;
        return SceneEditorFramework_QueryFlag.GIZMO_HANDLE;
    }

    function datablockName_(handle, highlighted = false){
        local datablockBase = isPlaneHandle_(handle) ?
            "SceneEditorFramework/planeHandle" :
            "SceneEditorFramework/handle";
        return datablockBase + (highlighted ? "Highlight" : "") +
            axisForHandle_(handle);
    }

    //Keep the coordinate which is perpendicular to the selected plane fixed.
    //The first three handles are single-axis drags and the next three are the
    //YZ, XZ and XY plane handles in that order; the six after them are the same
    //six drags again, made by the handles which face the other way.
    //
    //A scale drag reads the same result as a distance from where the drag began
    //rather than as a place to be, so an axis held fixed here is one the scale
    //is not changed along - the same thing this means for a move.
    function constrainMovement_(point, reference, handle){
        handle = dragForHandle_(handle);

        if(handle == 0) return Vec3(point.x, reference.y, reference.z);
        if(handle == 1) return Vec3(reference.x, point.y, reference.z);
        if(handle == 2) return Vec3(reference.x, reference.y, point.z);
        if(handle == 3) return Vec3(reference.x, point.y, point.z);
        if(handle == 4) return Vec3(point.x, reference.y, point.z);
        return Vec3(point.x, point.y, reference.z);
    }

    function movementPlane_(handle){
        local centre = mParentNode_.getPositionVec3();
        handle = dragForHandle_(handle);

        //Plane-handle drags raycast directly against the selected world plane.
        if(handle == 3) return Plane(Vec3(1, 0, 0), centre.x);
        if(handle == 4) return Plane(Vec3(0, 1, 0), centre.y);
        if(handle == 5) return Plane(Vec3(0, 0, 1), centre.z);

        //Keep the established axis-drag planes for the existing handles.
        if(handle == 1) return Plane(Vec3(0, 0, 1), centre.z);
        return Plane(Vec3(0, 1, 0), centre.y);
    }

};
