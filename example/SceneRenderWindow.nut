//One viewport onto the scene, drawn as a docked imgui window.
//
//Everything a viewport needs to be independent of the others belongs to an
//instance of this: its own camera, its own render texture, and the workspace
//which renders that camera into that texture. The editor can open as many as it
//likes, and each shows the same scene from wherever its own camera is.
//
//Nothing here reads the mouse. Which viewport the cursor is working in is a
//decision only the editor can make - it is the only thing which can see them all
//- so a window records whether it was hovered while it was drawn and answers
//questions about positions inside it, and the editor picks which one to believe.
//
//This is loaded with _doFile from the editor's start function, alongside
//ExampleRightClickMenu.nut.
::ExampleSceneRenderWindow <- class{

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

    mCamera_ = null;
    mCameraNode_ = null;
    mView_ = null;

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

    /**
     * @param id A number no other render window has used, which the window's
     * imgui, texture and camera names are all built from.
     * @param viewIndex Which view the window opens on. Wrapped, so the editor
     * can pass a plain count of the windows it has open.
     */
    constructor(id, viewIndex){
        mId_ = id;
        mName_ = "Scene " + id;
        //imgui identifies a window by everything after the ##, and the dock
        //builder places windows by the whole string, so both halves matter.
        mTitle_ = mName_ + "##exampleSceneViewport" + id;

        mCameraNode_ = _scene.getRootSceneNode().createChildSceneNode();
        mCamera_ = _scene.createCamera("sceneEditorExample/camera" + id);
        mCameraNode_.attachObject(mCamera_);
        setView(viewIndex % VIEW_MAX);

        createTexture_(INITIAL_WIDTH, INITIAL_HEIGHT);
    }

    /**
     * Give up everything the window owns. The window is no use afterwards.
     */
    function shutdown(){
        destroyTexture_();

        //Destroying the node destroys the camera attached to it, which the
        //workspace destroyed above was rendering through.
        if(mCameraNode_ != null){
            mCameraNode_.destroyNodeAndChildren();
            mCameraNode_ = null;
            mCamera_ = null;
        }
    }

    function createTexture_(width, height){
        mTexture_ = _graphics.createTexture("sceneEditorExample/sceneTexture" + mId_);
        mTexture_.setPixelFormat(_PFG_RGBA8_UNORM_SRGB);
        mTexture_.setResolution(width, height);
        mTexture_.scheduleTransitionTo(_GPU_RESIDENCY_RESIDENT);

        //One workspace per window, all built from the same definition: a
        //workspace is an instance of it, so each renders its own camera into its
        //own texture.
        mWorkspace_ = _compositor.addWorkspace([mTexture_], mCamera_,
            "SceneEditorExample/SceneToTextureWorkspace", true);

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
     */
    function setView(view){
        mView_ = view;

        local placement = viewPlacement_(view);
        mCameraNode_.setPosition(placement[0]);
        mCamera_.setDirection(placement[1]);
    }

    //Where each view puts the camera, as a position and the direction it faces
    //from there.
    function viewPlacement_(view){
        switch(view){
            //Deliberately not straight down: a camera pointed along the axis it
            //measures its roll against has no way to decide which way up it is.
            case VIEW_TOP: return [Vec3(0, 24, 0), Vec3(0, -1, -0.001)];
            case VIEW_FRONT: return [Vec3(0, 4, 24), Vec3(0, 0, -1)];
            case VIEW_SIDE: return [Vec3(24, 4, 0), Vec3(-1, 0, 0)];
            case VIEW_PERSPECTIVE:
            default: return [Vec3(12, 8, 15), Vec3(-12, -8, -15)];
        }
    }

    function viewName_(view){
        switch(view){
            case VIEW_TOP: return "Top";
            case VIEW_FRONT: return "Front";
            case VIEW_SIDE: return "Side";
            case VIEW_PERSPECTIVE:
            default: return "Perspective";
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

        _imgui.setNextWindowDockId(defaultDockId, _imgui.Cond_FirstUseEver);
        //No padding, so the image meets the edges of the panel like a viewport.
        //Popped straight after begin so the rest of the window is normal.
        _imgui.pushStyleVar(_imgui.StyleVar_WindowPadding, 0, 0);
        local visible = _imgui.begin(mTitle_, _imgui.WindowFlags_NoScrollbar |
            _imgui.WindowFlags_NoScrollWithMouse | _imgui.WindowFlags_MenuBar);
        _imgui.popStyleVar();

        if(!visible){
            //Collapsed or tabbed out of sight. The workspace keeps rendering,
            //which is what makes the tab show a live scene the moment it is
            //selected again, but nothing on screen can be interacted with.
            notifyNotDrawn_();
            _imgui.end();
            return;
        }

        drawMenuBar_();

        //Read before anything is drawn: the cursor sits at the top left of the
        //content region until something moves it.
        local cursorX = _imgui.getCursorPosX();
        local cursorY = _imgui.getCursorPosY();
        local pos = _imgui.getCursorScreenPos();
        local size = _imgui.getContentRegionAvail();
        mRect_ = [pos[0], pos[1], size[0], size[1]];

        if(size[0] > 0 && size[1] > 0){
            //Drawn at the panel's size rather than the texture's, so a resize
            //shows a stretched scene for the few frames before the texture
            //catches up rather than a gap.
            _imgui.image(mTexture_, size[0], size[1]);

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
        }

        //The scene is inside an imgui window, so wantCaptureMouse is true
        //whenever the cursor is over it and cannot be what decides this. Being
        //over this window, and no other, is what makes the scene interactable.
        //AllowWhenBlockedByActiveItem keeps a drag alive while a gizmo is held.
        mHovered_ = _imgui.isWindowHovered(_imgui.HoveredFlags_AllowWhenBlockedByActiveItem);

        _imgui.end();
    }

    function drawMenuBar_(){
        if(!_imgui.beginMenuBar()) return;

        if(_imgui.beginMenu("View")){
            for(local i = 0; i < VIEW_MAX; i++){
                if(_imgui.menuItem(viewName_(i), null, mView_ == i)) setView(i);
            }
            _imgui.endMenu();
        }

        //Only asked for here. The texture this window has already handed to
        //imgui is not drawn until the frame is over, so the editor closes the
        //window at the top of the next one.
        if(_imgui.menuItem("Close")) mCloseRequested_ = true;

        _imgui.endMenuBar();
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

    function getTitle(){
        return mTitle_;
    }

    function getCamera(){
        return mCamera_;
    }

    function isHovered(){
        return mHovered_;
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
