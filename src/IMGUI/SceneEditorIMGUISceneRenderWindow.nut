//One viewport onto the scene, drawn as a docked imgui window.
//
//Everything a viewport needs to be independent of the others belongs to an
//instance of this: its own camera, its own render texture, and the workspace
//which renders that camera into that texture. Each shows the same scene from
//wherever its own camera is.
//
//It also claims a gizmo layer, which is the framework's name for one viewport's
//copy of the transform gizmo. The copy is sized for this window's camera, and
//the workspace which draws it is the one belonging to that layer - so the gizmo
//is the right size in every viewport at once rather than in one of them. There
//are a fixed number of layers, and that is what limits how many of these the
//editor can open. @see ::SceneEditorFramework.MAX_GIZMO_LAYERS
//
//Nothing here decides whether it is the window the cursor is working in. That is
//a decision only the editor can make - it is the only thing which can see them
//all - so a window records whether it was hovered while it was drawn and answers
//questions about positions inside it, and the editor picks which one to believe.
//The camera reads the mouse only once the editor has said it may. @see
//updateCamera
//
::SceneEditorFramework.IMGUI.SceneRenderWindow <- class{

    //Cells in the framework's visibleIcon.png sheet.
    TOOL_ICON_POSITION = 3
    TOOL_ICON_SURFACE = 4
    TOOL_ICON_SCALE = 5
    TOOL_ICON_ORIENTATION = 6
    ICON_WIDTH = 14.0
    ICON_HEIGHT = 12.0
    ICON_CELL_WIDTH = 0.1

    //Views a window can be set to. A new window opens on the next one along, so
    //that opening a second viewport shows something the first one does not.
    VIEW_PERSPECTIVE = 0
    VIEW_TOP = 1
    VIEW_FRONT = 2
    VIEW_SIDE = 3
    VIEW_MAX = 4

    //The window has no size before its first frame, so the texture starts at
    //something usable and is re-created once the window has been laid out.
    INITIAL_WIDTH = 1280
    INITIAL_HEIGHT = 720
    //Re-creating the texture means re-creating the workspace with it, so a
    //resize is not something to do on every frame of a splitter drag. The size
    //has to hold still for this many rendered frames first.
    RESIZE_SETTLE_FRAMES = 8

    //Unique among the windows which have ever been opened, so that the names
    //below never collide with one belonging to a window which has been closed.
    mId_ = null;
    mName_ = null;
    mTitle_ = null;
    mEditor_ = null;
    mToolIcons_ = null;
    mAxisIndicator_ = null;

    //Which gizmo layer this window has claimed, which is both the copy of the
    //transform gizmo it draws and the workspace definition which draws it.
    //Unlike the id it is reused: a closed window gives its layer back, since
    //there are only so many of them. @see ::SceneEditorFramework.MAX_GIZMO_LAYERS
    mLayer_ = null;

    mCamera_ = null;
    mCameraNode_ = null;
    mView_ = null;
    //Flies the camera above. Each window has its own, so each is flown
    //separately and only the one the cursor is in moves.
    mFPSCamera_ = null;

    //The texture the scene is rendered into, and the workspace which does it.
    mTexture_ = null;
    mWorkspace_ = null;
    mTextureWidth_ = 0;
    mTextureHeight_ = 0;
    //The size the window last asked for, and how many frames it has been asking
    //for it. @see updateTextureSize
    mRequestedWidth_ = 0;
    mRequestedHeight_ = 0;
    mRequestedFrames_ = 0;

    //Where the scene image ended up on screen last frame, in imgui coordinates,
    //as [x, y, width, height]. Null when the window is not being drawn.
    mRect_ = null;
    //Whether the cursor was over the window when it was last drawn.
    mHovered_ = false;
    mVisible_ = true;
    //Set when the window has asked to be closed, and acted on by the editor.
    mCloseRequested_ = false;

    //Last ImGui placement. Docked windows are reconstructed by the editor's
    //dock builder; a floating window applies its saved rectangle on first use.
    mDockId_ = 0;
    mWindowPosition_ = null;
    mWindowSize_ = null;
    mWindowCollapsed_ = false;
    mTabVisible_ = true;
    mInitialWindowStatePending_ = false;

    /**
     * @param editor The editor which owns this window and its shared scene tree.
     * @param id A number no other render window has used, which the window's
     * imgui, texture and camera names are all built from.
     * @param layer A gizmo layer no other open render window is using, which
     * decides which workspace definition draws this window and so which copy of
     * the transform gizmo it shows.
     * @param viewIndex Which view the window opens on. Wrapped, so the editor
     * can pass a plain count of the windows it has open.
     */
    constructor(editor, id, layer, viewIndex, savedState=null){
        mEditor_ = editor;
        mId_ = id;
        mLayer_ = layer;
        mName_ = "Scene " + id;
        //imgui identifies a window by everything after the ##, and the dock
        //builder places windows by the whole string, so both halves matter.
        mTitle_ = mName_ + "##sceneEditorViewport" + id;

        mCameraNode_ = _scene.getRootSceneNode().createChildSceneNode();
        mCamera_ = _scene.createCamera(mEditor_.resourceName_("camera" + id));
        mCameraNode_.attachObject(mCamera_);
        //Created before the view is set, since it is what places the camera:
        //the angles it flies by have to be the ones the view left it at, or the
        //first turn would snap the view somewhere else.
        mFPSCamera_ = ::SceneEditorFramework.FPSCamera(mCamera_);
        setView(viewIndex % VIEW_MAX);

        mToolIcons_ = ::SceneEditorFramework.IMGUI.Textures.get(
            ::SceneEditorFramework.IMGUI.Textures.VISIBLE_ICONS
        );
        mAxisIndicator_ = ::SceneEditorFramework.IMGUI.AxisIndicator();

        createTexture_(INITIAL_WIDTH, INITIAL_HEIGHT);
        applyState(savedState);
    }

    /**
     * Give up everything the window owns. The window is no use afterwards.
     */
    function shutdown(){
        destroyTexture_();

        //A window can be closed part way through a flight, and the cursor it
        //hid has to come back whether or not the camera it was flying survives.
        mFPSCamera_.cancel();
        mFPSCamera_ = null;

        //Destroying the node destroys the camera attached to it, which the
        //workspace destroyed above was rendering through.
        if(mCameraNode_ != null){
            mCameraNode_.destroyNodeAndChildren();
            mCameraNode_ = null;
            mCamera_ = null;
        }
    }

    function createTexture_(width, height){
        mTexture_ = _graphics.createTexture(mEditor_.resourceName_("sceneTexture" + mId_));
        mTexture_.setPixelFormat(_PFG_RGBA8_UNORM_SRGB);
        mTexture_.setResolution(width, height);
        mTexture_.scheduleTransitionTo(_GPU_RESIDENCY_RESIDENT);

        //One workspace per window, each an instance of the definition belonging
        //to the layer this window claimed - so each renders its own camera into
        //its own texture, and draws the copy of the gizmo which was sized for
        //that camera. @see res/SceneEditor.compositor
        mWorkspace_ = _compositor.addWorkspace([mTexture_], mCamera_,
            mEditor_.sceneWorkspaceName_(mLayer_), true);

        mTextureWidth_ = width;
        mTextureHeight_ = height;

        //Nothing else sets this now the scene has left the window: without it
        //the scene is stretched to the window's shape rather than the panel's,
        //and the rays cast for picking and the gizmos miss.
        mCamera_.setAspectRatio(width.tofloat() / height.tofloat());
    }

    function destroyTexture_(){
        //The workspace renders into the texture, so it has to stop first.
        if(mWorkspace_ != null){
            _compositor.removeWorkspace(mWorkspace_);
            mWorkspace_ = null;
        }
        if(mTexture_ != null){
            _graphics.destroyTexture(mTexture_);
            mTexture_ = null;
        }
    }

    /**
     * Re-create the render target once the window has settled on a size. Call at
     * the top of the frame, before anything is drawn: the texture handed to
     * imgui is not drawn until the frame is over, so this is the only point in
     * the frame at which destroying one is safe.
     */
    function updateTextureSize(){
        if(mRect_ == null) return;

        local width = mRect_[2].tointeger();
        local height = mRect_[3].tointeger();
        //A collapsed or newly docked window can report nothing usable.
        if(width <= 0 || height <= 0) return;
        if(width == mTextureWidth_ && height == mTextureHeight_) return;

        if(width != mRequestedWidth_ || height != mRequestedHeight_){
            mRequestedWidth_ = width;
            mRequestedHeight_ = height;
            mRequestedFrames_ = 0;
            return;
        }

        mRequestedFrames_++;
        if(mRequestedFrames_ < RESIZE_SETTLE_FRAMES) return;

        destroyTexture_();
        createTexture_(width, height);
    }

    /**
     * Point the window's camera at the scene from one of the preset views.
     *
     * Through the fps camera rather than around it, so that flying continues
     * from the view rather than snapping back to wherever the camera was last
     * flown to.
     */
    function setView(view){
        mView_ = view;

        local placement = viewPlacement_(view);
        mFPSCamera_.setPosition(placement[0]);
        mFPSCamera_.setDirection(placement[1]);
        mFPSCamera_.setOrbitDistance(placement[2]);
    }

    /**
     * Fly the window's camera for one update. Call once per update rather than
     * once per rendered frame, so that the distance flown does not depend on how
     * fast the editor is drawing.
     *
     * @param interactable Whether the editor is willing to let this window take
     * the mouse, which it is for the one the cursor is over and no other.
     * @returns Whether the camera has taken it, which it keeps until the button
     * is released however far the cursor wanders in the meantime.
     */
    function updateCamera(interactable){
        return mFPSCamera_.update(interactable);
    }

    //Where each view puts the camera, as a position and the direction it faces
    //from there.
    function viewPlacement_(view){
        switch(view){
            //Deliberately not straight down: a camera pointed along the axis it
            //measures its roll against has no way to decide which way up it is.
            case VIEW_TOP: return [Vec3(0, 24, 0), Vec3(0, -1, -0.001), 24.0];
            case VIEW_FRONT: return [Vec3(0, 4, 24), Vec3(0, 0, -1), 24.0];
            case VIEW_SIDE: return [Vec3(24, 4, 0), Vec3(-1, 0, 0), 24.0];
            case VIEW_PERSPECTIVE:
            default: return [Vec3(12, 8, 15), Vec3(-12, -8, -15), 20.8087];
        }
    }

    /**
     * Draw the window and the scene inside it.
     *
     * @param defaultDockId Where the window docks the first time it is drawn.
     */
    function draw(defaultDockId){
        if(!mVisible_){
            notifyNotDrawn_();
            return;
        }

        local restoringFloatingWindow = mInitialWindowStatePending_ && mDockId_ == 0;
        applyInitialWindowState_();
        if(!restoringFloatingWindow){
            _imgui.setNextWindowDockId(defaultDockId, _imgui.Cond_FirstUseEver);
        }
        //No padding, so the image meets the edges of the panel like a viewport.
        //Popped straight after begin so the rest of the window is normal.
        _imgui.pushStyleVar(_imgui.StyleVar_WindowPadding, 0, 0);
        local state = begin_();
        _imgui.popStyleVar();

        //These queries are valid even when the window is collapsed or hidden
        //behind another tab, and must happen before end().
        mDockId_ = _imgui.getWindowDockId();
        mWindowPosition_ = _imgui.getWindowPos();
        mWindowSize_ = _imgui.getWindowSize();
        mWindowCollapsed_ = _imgui.isWindowCollapsed();
        mTabVisible_ = state[0] && !mWindowCollapsed_;

        local visible = state[0];
        //The X, which is only false on the frame it was clicked. Acted on by the
        //editor at the top of the next frame: the texture handed to imgui below
        //is not drawn until this one is over, so it cannot be destroyed now.
        if(!state[1]) mCloseRequested_ = true;

        if(!visible){
            //Collapsed or tabbed out of sight. The workspace keeps rendering,
            //which is what makes the tab show a live scene the moment it is
            //selected again, but nothing on screen can be interacted with.
            notifyNotDrawn_();
            _imgui.end();
            return;
        }

        //ImGui's initial cursor is the real content origin. Its y coordinate
        //already includes the title/tab bar, so forcing it to (0, 0) puts the
        //scene behind that bar and makes every mouse coordinate appear offset.
        local cursorX = _imgui.getCursorPosX();
        local cursorY = _imgui.getCursorPosY();
        local pos = _imgui.getCursorScreenPos();
        local size = _imgui.getContentRegionAvail();
        mRect_ = [pos[0], pos[1], size[0], size[1]];

        //Whether a drag which began in this window's scene is still going, read
        //from the invisible button below - which is the item imgui hands such a
        //drag to, and holds until the button comes back up.
        local sceneItemActive = false;
        local toolbarHovered = false;

        if(size[0] > 0 && size[1] > 0){
            //Drawn at the panel's size rather than the texture's, so a resize
            //shows a stretched scene for the few frames before the texture
            //catches up rather than a gap.
            _imgui.image(mTexture_, size[0], size[1]);

            //Drawn after the image but before its invisible interaction target.
            //The toolbar therefore appears over the scene and claims the ImGui
            //hover id first, preventing the target below from swallowing clicks.
            toolbarHovered = drawToolbar_(cursorX, cursorY);

            //An invisible button over the image, so that dragging in the scene
            //is a drag on an item rather than on the window's empty space -
            //which imgui reads as dragging the window itself, and which here
            //would drag the panel out of the layout every time an object is
            //dragged. An image is not an item, so without this the whole panel
            //is empty space as far as imgui is concerned.
            //
            //Deliberately not WindowFlags_NoMove, which would also stop the
            //panel being dragged by its tab. The tab bar sets its own hovered
            //item, so it is unaffected by this and still re-docks normally.
            _imgui.setCursorPos(cursorX, cursorY);
            _imgui.invisibleButton("##sceneViewport", size[0], size[1]);
            sceneItemActive = _imgui.isItemActive();

            //Placed after the scene interaction target so the lines render on
            //top. The indicator itself is disabled and remains click-through.
            if(mEditor_.option_("showAxisIndicator", true)){
                mAxisIndicator_.draw(mCamera_, cursorX, cursorY, size[0], size[1]);
            }
            _imgui.setCursorPos(cursorX, cursorY + size[1]);
        }

        //The scene is inside an imgui window, so wantCaptureMouse is true
        //whenever the cursor is over it and cannot be what decides this. Being
        //over this window, and no other, is what makes the scene interactable.
        //AllowWhenBlockedByActiveItem keeps a drag alive while a gizmo is held.
        mHovered_ = _imgui.isWindowHovered(_imgui.HoveredFlags_AllowWhenBlockedByActiveItem);

        //That flag allows it whoever the active item belongs to, though, and a
        //drag on a control in another panel - a coordinate box in the object
        //properties - is one the cursor may well cross this window during.
        //Whatever grabbed the mouse keeps it until it is released, so the window
        //is only hovered while something is active if that something is its own.
        if(toolbarHovered || (!sceneItemActive && _imgui.isAnyItemActive())){
            mHovered_ = false;
        }

        _imgui.end();
    }

    //Begin the window with a close button in its title bar - and on its tab once
    //it is docked - as [visible, open].
    //
    //Handing imgui somewhere to write the open state is the only way to get one;
    //there is no window flag for it.
    function begin_(){
        local flags = _imgui.WindowFlags_NoScrollbar |
            _imgui.WindowFlags_NoScrollWithMouse;

        return _imgui.beginClosable(mTitle_, flags);
    }

    //The active transform belongs to the shared scene tree, so every viewport
    //shows the same selected button and changing it in any one updates them all.
    function drawToolbar_(sceneCursorX, sceneCursorY){
        if(!mEditor_.option_("showViewportToolbar", true)) return false;
        local sceneTree = mEditor_.mBase_.getActiveSceneTree();
        if(sceneTree == null) return false;

        local scale = _imgui.getGlobalScale();
        local inset = 10.0 * scale;
        _imgui.setCursorPos(sceneCursorX + inset, sceneCursorY + inset);

        _imgui.pushStyleVar(_imgui.StyleVar_ItemSpacing, 4.0 * scale, 4.0 * scale);

        local hovered = drawToolButton_(sceneTree, SceneEditorFramework_BasicCoordinateType.POSITION,
            TOOL_ICON_POSITION, "Position");
        _imgui.sameLine();
        hovered = drawToolButton_(sceneTree, SceneEditorFramework_BasicCoordinateType.SCALE,
            TOOL_ICON_SCALE, "Scale") || hovered;
        _imgui.sameLine();
        hovered = drawToolButton_(sceneTree, SceneEditorFramework_BasicCoordinateType.ORIENTATION,
            TOOL_ICON_ORIENTATION, "Rotate") || hovered;

        _imgui.popStyleVar();
        return hovered;
    }

    function drawToolButton_(sceneTree, coordinateType, iconCell, tooltip){
        local active = sceneTree.mCurrentObjectTransformCoordinateType_ == coordinateType;
        if(active){
            //The binding does not expose the current ButtonActive colour. This
            //is ImGui's standard selected blue and makes the persistent tool
            //state visible without changing the icon itself.
            _imgui.pushStyleColor(_imgui.Col_Button, 0.20, 0.47, 0.78, 1.0);
        }

        local scale = _imgui.getGlobalScale();
        local uv0 = iconCell * ICON_CELL_WIDTH;
        local pressed = _imgui.imageButton("##transformTool" + coordinateType,
            mToolIcons_, ICON_WIDTH * scale, ICON_HEIGHT * scale,
            uv0, 0.0, uv0 + ICON_CELL_WIDTH, 1.0);

        if(active) _imgui.popStyleColor();
        local hovered = _imgui.isItemHovered();
        if(hovered) _imgui.setTooltip(tooltip);
        if(pressed) sceneTree.setObjectTransformCoordinateType(coordinateType);
        return hovered;
    }

    //Nothing is showing the scene, so there is no viewport to map the mouse into
    //and nothing to interact with.
    function notifyNotDrawn_(){
        mRect_ = null;
        mHovered_ = false;
    }

    /**
     * Where a position in imgui's coordinates falls within the scene image, in
     * the 0-1 range the framework wants.
     *
     * Deliberately not clamped: a drag which wanders out of the window is still
     * a drag, and the framework decides what to do with a position outside the
     * viewport.
     *
     * @param mouse The cursor in imgui coordinates as [x, y], or null.
     * @returns A Vec2, or null when there is nothing to measure against.
     */
    function normalisedMousePosition(mouse){
        if(mouse == null || mRect_ == null) return null;
        if(mRect_[2] <= 0 || mRect_[3] <= 0) return null;

        return Vec2(
            (mouse[0] - mRect_[0]) / mRect_[2],
            (mouse[1] - mRect_[1]) / mRect_[3]
        );
    }

    function getName(){
        return mName_;
    }

    function getId(){
        return mId_;
    }

    function getTitle(){
        return mTitle_;
    }

    function getCamera(){
        return mCamera_;
    }

    function getLayer(){
        return mLayer_;
    }

    function getDockId(){
        return mDockId_;
    }

    function getState(){
        local position = mFPSCamera_.getPosition();
        local direction = mFPSCamera_.getDirection();
        return {
            "id": mId_,
            "layer": mLayer_,
            "visible": mVisible_,
            "view": mView_,
            "cameraPosition": [position.x, position.y, position.z],
            "cameraDirection": [direction.x, direction.y, direction.z],
            "cameraOrbitDistance": mFPSCamera_.getOrbitDistance(),
            "window": {
                "title": mTitle_,
                "dockId": mDockId_,
                "position": mWindowPosition_,
                "size": mWindowSize_,
                "collapsed": mWindowCollapsed_,
                "tabVisible": mTabVisible_
            }
        };
    }

    function applyState(state){
        if(state == null || typeof state != "table") return;

        if(state.rawin("visible")) mVisible_ = state.rawget("visible");
        if(state.rawin("view")) setView(state.rawget("view"));
        if(state.rawin("cameraPosition")){
            local p = state.rawget("cameraPosition");
            if(typeof p == "array" && p.len() >= 3){
                mFPSCamera_.setPosition(Vec3(p[0], p[1], p[2]));
            }
        }
        if(state.rawin("cameraDirection")){
            local d = state.rawget("cameraDirection");
            if(typeof d == "array" && d.len() >= 3){
                mFPSCamera_.setDirection(Vec3(d[0], d[1], d[2]));
            }
        }
        if(state.rawin("cameraOrbitDistance")){
            mFPSCamera_.setOrbitDistance(state.rawget("cameraOrbitDistance"));
        }

        if(!state.rawin("window") || typeof state.rawget("window") != "table") return;
        local window = state.rawget("window");
        if(window.rawin("dockId")) mDockId_ = window.rawget("dockId");
        if(window.rawin("position")) mWindowPosition_ = window.rawget("position");
        if(window.rawin("size")) mWindowSize_ = window.rawget("size");
        if(window.rawin("collapsed")) mWindowCollapsed_ = window.rawget("collapsed");
        if(window.rawin("tabVisible")) mTabVisible_ = window.rawget("tabVisible");
        mInitialWindowStatePending_ = true;
    }

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

    function isHovered(){
        return mHovered_;
    }

    /**
     * Whether the camera was flown by the right button which is being held, or
     * by the one which was last released. What tells a right click in the scene
     * apart from a right drag which flew the camera.
     */
    function cameraWasFlown(){
        return mFPSCamera_.hasMoved();
    }

    function isVisible(){
        return mVisible_;
    }

    function toggleVisible(){
        mVisible_ = !mVisible_;
    }

    function requestClose(){
        mCloseRequested_ = true;
    }

    function isCloseRequested(){
        return mCloseRequested_;
    }

};
