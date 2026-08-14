//Flying and orbiting a camera through the scene.
//
//One of these belongs to one camera, so an editor with several viewports has one
//per viewport and each is flown independently. It never asks which viewport the
//cursor is in - only the editor can see them all - so whoever owns it says
//whether the camera may take the mouse when update() is called, and the camera
//says back whether it has it.
//
//Holding the right mouse button over a viewport is what flies it. The middle
//button orbits around a point in front of it, Shift-middle pans that point, and
//the wheel moves towards or away from it. Starting a button gesture in exactly
//one viewport makes it unambiguous when there is more than one: that viewport
//keeps the mouse until release, wherever the cursor wanders in the meantime.
//It also keeps the movement keys out of the way of anything else which wants
//the keyboard, since nothing is listening for them the rest of the time.
//
//The mouse is read as a position rather than as a movement, because that is what
//the engine reports, so a look is the difference between this frame's position
//and the last one's. A cursor which is about to leave the window is put back to
//where the look began, since a position which stops changing at the edge of the
//screen is a look which stops part way through a turn.

//SDL scancodes for the keys a camera is flown with. In the framework's namespace
//rather than the root table, so that a project's own list of scancodes - which
//it needs anyway, as the engine reports keys by scancode - cannot collide with
//this one. Assign over an entry to rebind that key for every camera.
::SceneEditorFramework.FPSCameraKeys <- {
    FORWARD = 26,   //W
    BACKWARD = 22,  //S
    LEFT = 4,       //A
    RIGHT = 7,      //D
    DOWN = 20,      //Q
    UP = 8,         //E

    FAST = [225, 229],      //Either shift
    FASTER = [226, 230]     //Either alt
};

::SceneEditorFramework.FPSCamera <- class{

    //Degrees turned per unit the mouse moves.
    DEFAULT_SENSITIVITY = 0.1
    //Units moved per update while a movement key is held.
    DEFAULT_SPEED = 0.3
    //The orbit point starts this far in front of a camera which has not been
    //given a more useful distance by its owner.
    DEFAULT_ORBIT_DISTANCE = 10.0
    //Pan is proportional to orbit distance so that the scene follows the mouse
    //at roughly the same screen-space speed however far away it is.
    DEFAULT_PAN_SENSITIVITY = 0.002
    //The fraction of the current orbit distance moved by one wheel step.
    DEFAULT_ZOOM_SENSITIVITY = 0.15
    MIN_ORBIT_DISTANCE = 0.05
    //What the modifiers multiply that by.
    FAST_MULTIPLIER = 3.0
    FASTER_MULTIPLIER = 16.0

    //How close to the edge of the window the cursor is allowed to get during a
    //look before it is put back. Wide enough that a fast turn cannot cross it
    //between one update and the next.
    EDGE_MARGIN = 48
    //Pitch stops short of straight up and straight down: a camera pointed along
    //the axis it measures its roll against has no way to decide which way up it
    //is, and the direction it is flown in comes from the same two angles.
    PITCH_LIMIT = 89.0

    //A movement shorter than this is the sum of two keys which cancelled out
    //rather than a direction to travel in.
    MOVEMENT_EPSILON = 0.0001

    mCamera_ = null;
    //A camera is placed by the node it is attached to, so that is what a
    //position means here. The camera itself carries the direction.
    mCameraNode_ = null;

    //Where the camera is pointed, in degrees. Kept here rather than read back
    //from the camera because pitch has to be clamped and yaw wrapped, which an
    //orientation cannot express: there is no difference between a camera which
    //has turned all the way round and one which has not moved.
    mYaw_ = 0.0;
    mPitch_ = 0.0;

    mSensitivity_ = null;
    mSpeed_ = null;

    //Orbiting, panning and zooming all share this point. FPS movement updates
    //it from the new camera transform, which makes changing navigation style
    //continuous rather than snapping to stale orbit state.
    mOrbitTarget_ = null;
    mOrbitDistance_ = null;
    mPanSensitivity_ = null;
    mZoomSensitivity_ = null;

    //A reusable transition between two camera poses. A pose is a position and
    //the point it looks at; interpolating both also leaves orbit navigation with
    //the correct target when the transition finishes.
    mTransition_ = null;

    //Whether the camera currently has the mouse.
    mLooking_ = false;
    //Right and middle drags use the same cursor capture machinery. The mode is
    //null, "look", or "orbit"; Shift chooses pan while an orbit drag is read.
    mNavigationMode_ = null;
    //The right button as it was last seen, so that a look begins on the frame
    //the button goes down rather than at any point it happens to be held - a
    //drag which began somewhere else and wandered in is not a look.
    mRightHeld_ = false;
    mMiddleHeld_ = false;
    //The cursor as it was last read, which this update's movement is measured
    //against.
    mPrevMouseX_ = 0;
    mPrevMouseY_ = 0;
    //Where the look began, which is where the cursor is left when it ends.
    mAnchorX_ = 0;
    mAnchorY_ = 0;
    //Where the cursor is put when it nears the edge of the window during a look.
    //The anchor, held far enough inside the window that being put there cannot
    //immediately trigger another warp - which for a viewport docked against the
    //side of the window the anchor itself often would.
    mReturnX_ = 0;
    mReturnY_ = 0;
    //Whether the camera has actually been flown since the look began. What tells
    //a right click apart from a right drag, which an editor needs to know
    //because a click is usually asking for a menu. @see hasMoved
    mMoved_ = false;
    //Any captured drag movement, including middle-button navigation. This is
    //kept separate because hasMoved() specifically disambiguates right-click.
    mNavigationMoved_ = false;

    /**
     * @param camera The camera to fly. It must already be attached to a scene
     * node, which is what the camera is moved by.
     */
    constructor(camera){
        mCamera_ = camera;
        mCameraNode_ = camera.getParentNode();
        if(mCameraNode_ == null) throw "An FPS camera must be attached to a scene node.";

        mSensitivity_ = DEFAULT_SENSITIVITY;
        mSpeed_ = DEFAULT_SPEED;
        mOrbitDistance_ = DEFAULT_ORBIT_DISTANCE;
        mPanSensitivity_ = DEFAULT_PAN_SENSITIVITY;
        mZoomSensitivity_ = DEFAULT_ZOOM_SENSITIVITY;

        //Start from wherever the camera was already pointed, so that placing it
        //and then handing it over does not turn it to face somewhere else.
        readDirectionFromCamera_();
        syncOrbitTarget_();
    }

    /**
     * Give up the mouse and the cursor, without moving the camera.
     *
     * Call this when the viewport the camera belongs to is going away, or when
     * the editor is taking the mouse back for something else. A camera which is
     * not looking is unaffected.
     */
    function cancel(){
        if(mNavigationMode_ == null) return;

        mLooking_ = false;
        mNavigationMode_ = null;
        _window.showCursor(true);
    }

    /**
     * Navigate the camera for one update.
     *
     * Call this once per update rather than once per rendered frame: movement is
     * per update, which is what makes the distance travelled the same however
     * fast the editor is drawing.
     *
     * @param interactable Whether the cursor is over this camera's viewport and
     * the editor is willing to hand it the mouse. Null asks the project's
     * sceneEditorInteractable helper, which is the right answer for an editor
     * with a single viewport.
     * @returns Whether the camera has the mouse, which it keeps until the button
     * is released whatever the cursor is over by then.
     */
    function update(interactable = null, deltaSeconds = 1.0 / 60.0){
        if(interactable == null){
            interactable = ::SceneEditorFramework.HelperFunctions.sceneEditorInteractable();
        }

        local right = _input.getMouseButton(_MB_RIGHT);
        local rightPressed = right && !mRightHeld_;
        mRightHeld_ = right;
        local middle = _input.getMouseButton(_MB_MIDDLE);
        local middlePressed = middle && !mMiddleHeld_;
        mMiddleHeld_ = middle;

        if(mNavigationMode_ == "look"){
            if(!right) endNavigation_();
        }else if(mNavigationMode_ == "orbit"){
            if(!middle) endNavigation_();
        }else if(interactable){
            if(rightPressed) beginNavigation_("look");
            else if(middlePressed) beginNavigation_("orbit");
        }

        //The wheel belongs only to the hovered viewport, except during a drag
        //which this camera already owns. It is deliberately independent of FPS
        //and orbit mode: both arrive at exactly the same camera transform.
        if(interactable || mNavigationMode_ != null){
            local wheel = _input.getMouseWheelValue();
            if(wheel != 0) zoom(wheel);
        }

        if(mNavigationMode_ == null) updateAnimation(deltaSeconds);

        if(mNavigationMode_ == null) return false;

        if(mNavigationMode_ == "look"){
            updateLook_();
            updateMovement_();
        }else{
            updateOrbit_();
        }

        return true;
    }

    function beginNavigation_(mode){
        cancelAnimation();
        mNavigationMode_ = mode;
        mLooking_ = mode == "look";
        mMoved_ = false;
        mNavigationMoved_ = false;

        //Rebuilding this from the current transform is what transfers any FPS
        //movement or look immediately into an orbit around the point ahead.
        syncOrbitTarget_();

        mAnchorX_ = _input.getMouseX();
        mAnchorY_ = _input.getMouseY();
        mPrevMouseX_ = mAnchorX_;
        mPrevMouseY_ = mAnchorY_;

        mReturnX_ = clampToWindow_(mAnchorX_, _window.getWidth());
        mReturnY_ = clampToWindow_(mAnchorY_, _window.getHeight());

        //There is nothing to point at while flying, and the cursor is about to
        //stop tracking the mouse anyway.
        _window.showCursor(false);
    }

    function endNavigation_(){
        mLooking_ = false;
        mNavigationMode_ = null;

        //Left where the look began rather than wherever the turns took it. Only
        //when there were turns: a button which went down and straight back up
        //never moved the cursor, and putting it back would be a jump away from
        //whatever the user has just clicked on.
        if(mNavigationMoved_) _window.warpMouseInWindow(mAnchorX_, mAnchorY_);
        _window.showCursor(true);
    }

    function clampToWindow_(value, size){
        local margin = EDGE_MARGIN * 2;
        //A window narrower than the margins it is being kept away from has
        //nowhere safe in it, so aim for the middle and accept the warping.
        if(size <= margin * 2) return size / 2;

        if(value < margin) return margin;
        if(value > size - margin) return size - margin;
        return value;
    }

    function updateLook_(){
        local movement = readMouseMovement_();
        local movedX = movement[0];
        local movedY = movement[1];

        if(movedX != 0 || movedY != 0){
            mMoved_ = true;

            //Down the screen is a downwards look, and the pitch is measured the
            //other way up.
            setYawPitch(mYaw_ + movedX * mSensitivity_, mPitch_ - movedY * mSensitivity_);
        }
    }

    function updateOrbit_(){
        local movement = readMouseMovement_();
        local movedX = movement[0];
        local movedY = movement[1];
        if(movedX == 0 && movedY == 0) return;

        if(anyKeyHeld_(::SceneEditorFramework.FPSCameraKeys.FAST)){
            pan(movedX, movedY);
        }else{
            orbit(movedX * mSensitivity_, -movedY * mSensitivity_);
        }
    }

    //Read one frame of relative movement and keep a captured cursor away from
    //the edge. Both FPS look and middle-button navigation use the same stream.
    function readMouseMovement_(){
        local mouseX = _input.getMouseX();
        local mouseY = _input.getMouseY();

        local movedX = mouseX - mPrevMouseX_;
        local movedY = mouseY - mPrevMouseY_;
        if(movedX != 0 || movedY != 0) mNavigationMoved_ = true;
        mPrevMouseX_ = mouseX;
        mPrevMouseY_ = mouseY;

        //A cursor which has reached the edge of the screen stops reporting
        //movement, which stops the turn, so it is put back before it gets there.
        //Only then, so that the position the look is measured against is
        //interfered with as rarely as possible.
        if(!cursorNearWindowEdge_(mouseX, mouseY)) return [movedX, movedY];

        _window.warpMouseInWindow(mReturnX_, mReturnY_);
        //The warp is a jump rather than a movement of the mouse, so the next
        //update measures from where the cursor was put rather than turning the
        //camera by the width of the window.
        mPrevMouseX_ = mReturnX_;
        mPrevMouseY_ = mReturnY_;

        return [movedX, movedY];
    }

    function cursorNearWindowEdge_(x, y){
        return x < EDGE_MARGIN || y < EDGE_MARGIN ||
            x > _window.getWidth() - EDGE_MARGIN ||
            y > _window.getHeight() - EDGE_MARGIN;
    }

    function updateMovement_(){
        local direction = movementDirection_();
        if(direction == null) return;

        mMoved_ = true;
        setPosition(mCameraNode_.getPositionVec3() + direction * currentSpeed_());
    }

    //Which way the keys being held add up to, as a unit vector, or null when
    //they add up to standing still.
    function movementDirection_(){
        local keys = ::SceneEditorFramework.FPSCameraKeys;

        local front = directionVector_();
        //Sideways is level with the horizon rather than with the view, so that
        //looking up and stepping left does not also fly upwards.
        local right = front.cross(Vec3(0, 1, 0));
        right.normalise();

        local direction = Vec3();
        if(_input.getRawKeyScancodeInput(keys.FORWARD)) direction += front;
        if(_input.getRawKeyScancodeInput(keys.BACKWARD)) direction -= front;
        if(_input.getRawKeyScancodeInput(keys.RIGHT)) direction += right;
        if(_input.getRawKeyScancodeInput(keys.LEFT)) direction -= right;
        //Straight up and down, whatever the camera is pointed at, which is what
        //makes them useful for getting above the scene to look at it.
        if(_input.getRawKeyScancodeInput(keys.UP)) direction.y += 1.0;
        if(_input.getRawKeyScancodeInput(keys.DOWN)) direction.y -= 1.0;

        //Normalised, so that holding two keys travels in a diagonal at the speed
        //one key travels in a straight line rather than half as fast again.
        if(direction.length() < MOVEMENT_EPSILON) return null;
        direction.normalise();

        return direction;
    }

    function currentSpeed_(){
        local keys = ::SceneEditorFramework.FPSCameraKeys;

        //Checked in this order so that holding both is the faster of the two
        //rather than whichever happens to be tested last.
        if(anyKeyHeld_(keys.FASTER)) return mSpeed_ * FASTER_MULTIPLIER;
        if(anyKeyHeld_(keys.FAST)) return mSpeed_ * FAST_MULTIPLIER;
        return mSpeed_;
    }

    function anyKeyHeld_(scancodes){
        foreach(scancode in scancodes){
            if(_input.getRawKeyScancodeInput(scancode)) return true;
        }
        return false;
    }

    //The way the camera is pointed, as a unit vector, from the two angles it is
    //kept as.
    function directionVector_(){
        local yaw = radians_(mYaw_);
        local pitch = radians_(mPitch_);

        local front = Vec3(
            cos(yaw) * cos(pitch),
            sin(pitch),
            sin(yaw) * cos(pitch)
        );
        front.normalise();

        return front;
    }

    function applyDirection_(){
        mCamera_.setDirection(directionVector_());
    }

    function syncOrbitTarget_(){
        mOrbitTarget_ = getPosition() + directionVector_() * mOrbitDistance_;
    }

    function applyOrbitPosition_(){
        mCameraNode_.setPosition(mOrbitTarget_ - directionVector_() * mOrbitDistance_);
    }

    //Take the angles from wherever the camera is already pointed. A camera looks
    //down its own negative z, so that is the direction its orientation turns
    //into the one it is facing.
    function readDirectionFromCamera_(){
        setDirection(mCamera_.getOrientation() * Vec3(0, 0, -1));
    }

    function radians_(degrees){
        return degrees * (PI / 180.0);
    }

    function degrees_(radians){
        return radians * (180.0 / PI);
    }

    /**
     * Point the camera along a direction, which does not have to be normalised.
     * A direction of no length leaves the camera pointed where it was.
     */
    function setDirection(direction){
        cancelAnimation();
        setDirection_(direction, true);
    }

    function setDirection_(direction, syncOrbit){
        local length = direction.length();
        if(length < MOVEMENT_EPSILON) return false;

        local normalised = direction / length;
        //Clamped because a direction which is a hair over one from being
        //normalised is not something asin can be asked about.
        local y = normalised.y;
        if(y > 1.0) y = 1.0;
        if(y < -1.0) y = -1.0;

        setYawPitch_(degrees_(atan2(normalised.z, normalised.x)),
            degrees_(asin(y)), syncOrbit);
        return true;
    }

    /**
     * Point the camera at a pair of angles in degrees. Pitch is clamped and yaw
     * is wrapped, so any pair of numbers is a valid place to look.
     */
    function setYawPitch(yaw, pitch){
        cancelAnimation();
        setYawPitch_(yaw, pitch, true);
    }

    function setYawPitch_(yaw, pitch, syncOrbit){
        mYaw_ = yaw % 360.0;
        if(mYaw_ < 0.0) mYaw_ += 360.0;

        mPitch_ = pitch;
        if(mPitch_ > PITCH_LIMIT) mPitch_ = PITCH_LIMIT;
        if(mPitch_ < -PITCH_LIMIT) mPitch_ = -PITCH_LIMIT;

        applyDirection_();
        if(syncOrbit) syncOrbitTarget_();
    }

    function setPosition(position){
        cancelAnimation();
        mCameraNode_.setPosition(position);
        syncOrbitTarget_();
    }

    /** Orbit around the current target by yaw and pitch deltas in degrees. */
    function orbit(yawDelta, pitchDelta){
        cancelAnimation();
        local target = mOrbitTarget_;
        setYawPitch_(mYaw_ + yawDelta, mPitch_ + pitchDelta, false);
        mOrbitTarget_ = target;
        applyOrbitPosition_();
    }

    /**
     * Pan in screen pixels. Positive x drags the scene right and positive y
     * drags it down, matching Blender's grab-style middle-mouse pan.
     */
    function pan(horizontal, vertical){
        cancelAnimation();
        local front = directionVector_();
        local right = front.cross(Vec3(0, 1, 0));
        if(right.length() < MOVEMENT_EPSILON) return;
        right.normalise();
        local up = right.cross(front);
        up.normalise();

        local scale = mOrbitDistance_ * mPanSensitivity_;
        local movement = right * (-horizontal * scale) + up * (vertical * scale);
        mOrbitTarget_ += movement;
        mCameraNode_.setPosition(getPosition() + movement);
    }

    /** Move along the view direction while retaining the current orbit point. */
    function zoom(amount){
        cancelAnimation();
        local distance = mOrbitDistance_ * (1.0 - amount * mZoomSensitivity_);
        if(distance < MIN_ORBIT_DISTANCE) distance = MIN_ORBIT_DISTANCE;
        mOrbitDistance_ = distance;
        applyOrbitPosition_();
    }

    function setOrbitDistance(distance){
        cancelAnimation();
        mOrbitDistance_ = distance;
        if(mOrbitDistance_ < MIN_ORBIT_DISTANCE) mOrbitDistance_ = MIN_ORBIT_DISTANCE;
        syncOrbitTarget_();
    }

    function getOrbitDistance(){
        return mOrbitDistance_;
    }

    /**
     * Smoothly move to a position looking at a target. This is deliberately a
     * general camera-pose operation rather than framing-specific logic, so
     * other editor actions can use the same animation.
     */
    function animateTo(position, target, duration=0.3){
        if((target - position).length() < MOVEMENT_EPSILON) return false;

        //An explicit camera command wins over a drag already in progress. The
        //held button cannot recapture until it has been released and pressed
        //again because its previous state is still tracked by update().
        if(mNavigationMode_ != null) cancel();

        if(duration <= 0.0){
            applyPose_(position, target);
            mTransition_ = null;
            return true;
        }

        mTransition_ = {
            "startPosition": getPosition(),
            "startTarget": mOrbitTarget_,
            "endPosition": position,
            "endTarget": target,
            "elapsed": 0.0,
            "duration": duration
        };
        return true;
    }

    /** Frame a target at a distance while retaining the current viewing angle. */
    function animateFrame(target, distance, duration=0.3){
        if(distance < MIN_ORBIT_DISTANCE) distance = MIN_ORBIT_DISTANCE;
        return animateTo(target - directionVector_() * distance, target, duration);
    }

    /** Advance an active transition by a number of seconds. */
    function updateAnimation(deltaSeconds){
        if(mTransition_ == null) return false;
        if(deltaSeconds < 0.0) deltaSeconds = 0.0;

        mTransition_.elapsed += deltaSeconds;
        local progress = mTransition_.elapsed / mTransition_.duration;
        if(progress > 1.0) progress = 1.0;
        //Smoothstep starts and stops without an abrupt change in velocity.
        local eased = progress * progress * (3.0 - 2.0 * progress);
        local position = lerpVec3_(mTransition_.startPosition,
            mTransition_.endPosition, eased);
        local target = lerpVec3_(mTransition_.startTarget,
            mTransition_.endTarget, eased);
        applyPose_(position, target);

        if(progress >= 1.0) mTransition_ = null;
        return true;
    }

    function applyPose_(position, target){
        mCameraNode_.setPosition(position);
        if(!setDirection_(target - position, false)) return;
        mOrbitTarget_ = target;
        mOrbitDistance_ = (target - position).length();
        if(mOrbitDistance_ < MIN_ORBIT_DISTANCE) mOrbitDistance_ = MIN_ORBIT_DISTANCE;
    }

    function lerpVec3_(from, to, amount){
        return from + (to - from) * amount;
    }

    function cancelAnimation(){
        mTransition_ = null;
    }

    function isAnimating(){
        return mTransition_ != null;
    }

    function getPosition(){
        return mCameraNode_.getPositionVec3();
    }

    function getDirection(){
        return directionVector_();
    }

    function getYaw(){
        return mYaw_;
    }

    function getPitch(){
        return mPitch_;
    }

    function setSensitivity(sensitivity){
        mSensitivity_ = sensitivity;
    }

    function getSensitivity(){
        return mSensitivity_;
    }

    function setSpeed(speed){
        mSpeed_ = speed;
    }

    function getSpeed(){
        return mSpeed_;
    }

    function setPanSensitivity(sensitivity){
        mPanSensitivity_ = sensitivity;
    }

    function getPanSensitivity(){
        return mPanSensitivity_;
    }

    function setZoomSensitivity(sensitivity){
        mZoomSensitivity_ = sensitivity;
    }

    function getZoomSensitivity(){
        return mZoomSensitivity_;
    }

    function getCamera(){
        return mCamera_;
    }

    /**
     * Whether the camera is currently using FPS look. @see update
     */
    function isLooking(){
        return mLooking_;
    }

    /**
     * Whether the camera has been turned or moved since the button which is
     * flying it went down. Stays as it was left once the button is released, so
     * that an editor which acts on a right click can ask afterwards whether the
     * click was really a click.
     */
    function hasMoved(){
        return mMoved_;
    }

};
