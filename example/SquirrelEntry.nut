//A small editor built on the scene editor framework, laid out with imgui
//docking.
//
//The scene is not drawn to the window. It is rendered into a texture by a
//workspace the editor creates (see res/example.compositor), and that texture is
//drawn into a docked "Scene" window with _imgui.image. Everything else - the
//framework's scene tree and object properties panels - docks around it, so the
//editor looks like an editor rather than panels floating over the game.
//
//Two consequences of the scene living inside a window, both handled below:
//  * The cursor being over the scene means it is over an imgui window, so
//    wantCaptureMouse can no longer decide whether the scene is interactable.
//    Whether the scene window itself is hovered decides that instead.
//  * Mouse positions have to be expressed relative to the scene window rather
//    than the whole window, which is what normalisedSceneMousePosition is for.
::ExampleEditor <- {
    mBase_ = null
    mSceneParent_ = null
    mSceneTreePanel_ = null
    mObjectPropertiesPanel_ = null
    //sceneSafeUpdate runs before the next ImGui frame is built. Keep the
    //previous frame's result so that asking the framework whether the scene is
    //interactable never starts an ImGui frame too early.
    mSceneEditorInteractable_ = true

    //The texture the scene is rendered into, and the workspace which does it.
    mSceneTexture_ = null
    mSceneWorkspace_ = null
    mSceneTextureWidth_ = 0
    mSceneTextureHeight_ = 0
    //The size the scene window last asked for, and how many frames it has been
    //asking for it. @see updateSceneTextureSize_
    mRequestedWidth_ = 0
    mRequestedHeight_ = 0
    mRequestedFrames_ = 0

    //Where the scene image ended up on screen last frame, in imgui coordinates,
    //as [x, y, width, height]. Null when the scene window is not being drawn.
    mSceneRect_ = null

    //The dockspace, and the nodes of the default layout built inside it.
    mDockId_ = 0
    mSceneDockId_ = 0
    mSideDockId_ = 0
    mPropertiesDockId_ = 0
    mLayoutBuilt_ = false
    mScenePanelVisible_ = true

    PANEL_SCENE_TREE = 0
    PANEL_OBJECT_PROPERTIES = 1
    TRANSFORM_POSITION = 0
    TRANSFORM_SCALE = 1

    //The dock builder places windows by title, so the scene window's has to be
    //the same string in both places.
    SCENE_WINDOW_TITLE = "Scene"
    SCENE_TEXTURE_NAME = "sceneEditorExample/sceneTexture"
    //The scene window has no size before its first frame, so the texture starts
    //at something usable and is re-created once the window has been laid out.
    INITIAL_SCENE_WIDTH = 1280
    INITIAL_SCENE_HEIGHT = 720
    //Re-creating the texture means re-creating the workspace with it, so a
    //resize is not something to do on every frame of a splitter drag. The size
    //has to hold still for this many rendered frames first.
    RESIZE_SETTLE_FRAMES = 8

    function setupLights_(){
        local light = _scene.createLight();
        local lightNode = _scene.getRootSceneNode().createChildSceneNode();
        lightNode.attachObject(light);

        light.setType(_LIGHT_DIRECTIONAL);
        light.setDirection(-1, -1, -1);
        light.setPowerScale(PI);
        _scene.setAmbientLight(ColourValue(0.7, 0.7, 0.7, 1), ColourValue(0.7, 0.7, 0.7, 1), Vec3(0, 1, 0));
    }

    //avSetup.cfg turns the default compositor off, so nothing renders until
    //these exist. Order matters: Ogre executes workspaces in the order they were
    //added, and the imgui plugin appends its overlay to the end the first time a
    //frame uses imgui - after both of these.
    function setupCompositor_(){
        createSceneTexture_(INITIAL_SCENE_WIDTH, INITIAL_SCENE_HEIGHT);

        _compositor.addWorkspace([_window.getRenderTexture()], _camera.getCamera(),
            "SceneEditorExample/ClearWindowWorkspace", true);

        //The plugin would create this itself on the first frame which uses
        //imgui, but creating it here pins it after the two workspaces above.
        //Ogre runs workspaces in the order they were added, so the gui is drawn
        //over the cleared window rather than being cleared away again.
        _imgui.createOverlayWorkspace();
    }

    function createSceneTexture_(width, height){
        mSceneTexture_ = _graphics.createTexture(SCENE_TEXTURE_NAME);
        mSceneTexture_.setPixelFormat(_PFG_RGBA8_UNORM_SRGB);
        mSceneTexture_.setResolution(width, height);
        mSceneTexture_.scheduleTransitionTo(_GPU_RESIDENCY_RESIDENT);

        mSceneWorkspace_ = _compositor.addWorkspace([mSceneTexture_], _camera.getCamera(),
            "SceneEditorExample/SceneToTextureWorkspace", true);

        mSceneTextureWidth_ = width;
        mSceneTextureHeight_ = height;

        //Nothing else sets this now the scene has left the window: without it
        //the scene is stretched to the window's shape rather than the panel's,
        //and the rays cast for picking and the gizmos miss.
        _camera.setAspectRatio(width.tofloat() / height.tofloat());
    }

    function destroySceneTexture_(){
        if(mSceneWorkspace_ != null){
            _compositor.removeWorkspace(mSceneWorkspace_);
            mSceneWorkspace_ = null;
        }
        if(mSceneTexture_ != null){
            _graphics.destroyTexture(mSceneTexture_);
            mSceneTexture_ = null;
        }
    }

    //Re-create the render target once the scene window has settled on a size.
    //Called at the top of the frame, before anything is drawn, so the texture
    //the scene was rendered into this frame is the one about to be shown.
    function updateSceneTextureSize_(){
        if(mSceneRect_ == null) return;

        local width = mSceneRect_[2].tointeger();
        local height = mSceneRect_[3].tointeger();
        //A collapsed or newly docked window can report nothing usable.
        if(width <= 0 || height <= 0) return;
        if(width == mSceneTextureWidth_ && height == mSceneTextureHeight_) return;

        if(width != mRequestedWidth_ || height != mRequestedHeight_){
            mRequestedWidth_ = width;
            mRequestedHeight_ = height;
            mRequestedFrames_ = 0;
            return;
        }

        mRequestedFrames_++;
        if(mRequestedFrames_ < RESIZE_SETTLE_FRAMES) return;

        destroySceneTexture_();
        createSceneTexture_(width, height);
    }

    //The mouse in imgui's coordinates. The engine reports it in window units,
    //which are not imgui's on a display with a scale factor, so it is scaled by
    //the same ratio the plugin uses when it feeds the mouse to imgui: imgui's
    //display size is the window's render target, which is its size in pixels.
    //
    //Deliberately asks the window rather than imgui. This runs during the
    //framework's scene update, before the gui for the frame is built, and every
    //_imgui call begins the frame - which would throw away the gui built by the
    //previous update and leave the window empty.
    function imguiMousePosition_(){
        local windowSize = _window.getSize();
        if(windowSize.x <= 0 || windowSize.y <= 0) return null;

        local pixelSize = _window.getActualSize();
        return [
            _input.getMouseX() * (pixelSize.x / windowSize.x),
            _input.getMouseY() * (pixelSize.y / windowSize.y)
        ];
    }

    //Where the cursor is within the scene image, in the 0-1 range the framework
    //wants. Deliberately not clamped: a drag which wanders out of the panel is
    //still a drag, and the framework decides what to do with a position outside
    //the viewport.
    function normalisedSceneMousePosition_(){
        if(mSceneRect_ == null) return null;
        if(mSceneRect_[2] <= 0 || mSceneRect_[3] <= 0) return null;

        local mouse = imguiMousePosition_();
        if(mouse == null) return null;

        return Vec2(
            (mouse[0] - mSceneRect_[0]) / mSceneRect_[2],
            (mouse[1] - mSceneRect_[1]) / mSceneRect_[3]
        );
    }

    function start(){
        if(!("_imgui" in getroottable())){
            throw "The example requires the AvImguiPlugin. See example/plugins/README.md.";
        }

        ::SceneEditorFramework.HelperFunctions = {
            function sceneEditorInteractable(){
                return ::ExampleEditor.mSceneEditorInteractable_;
            }

            function sceneTreeConstructObjectForUserEntry(userId, parentNode, entryData){}

            function getNameForUserEntry(userId){
                return "User" + userId;
            }

            function raycastForMovementGizmo(){
                return Vec3();
            }

            function basicMouseInteractionEnabled(){
                return true;
            }

            function drawIMGUIObjectPropertiesForUserEntry(userId, entry){
            }

            //The scene is a panel now, not the whole window.
            function normalisedSceneMousePosition(){
                return ::ExampleEditor.normalisedSceneMousePosition_();
            }
        };

        setupLights_();
        setupCompositor_();
        _camera.setPosition(12, 8, 15);
        _camera.setDirection(Vec3(-12, -8, -15));

        mBase_ = ::SceneEditorFramework.Base();
        mSceneParent_ = _scene.getRootSceneNode().createChildSceneNode();
        mBase_.setActiveSceneTree(mBase_.loadSceneTree(mSceneParent_, "res://res/example.avScene"));

        mSceneTreePanel_ = mBase_.setupIMGUIWindow(PANEL_SCENE_TREE, ::SceneEditorFramework.IMGUI.SceneTree);
        mObjectPropertiesPanel_ = mBase_.setupIMGUIWindow(PANEL_OBJECT_PROPERTIES, ::SceneEditorFramework.IMGUI.ObjectProperties);
    }

    function update(){
        mBase_.update();
        if(!_imgui.isFirstUpdateOfFrame()) return;

        updateSceneTextureSize_();

        //The dockspace comes first: a window submitted before the dockspace it
        //docks into is undocked again.
        mDockId_ = _imgui.dockSpaceOverViewport();
        buildDefaultLayout_();

        drawMenuBar_();
        drawSceneWindow_();
        mBase_.drawIMGUI();
    }

    //The layout the editor opens with: the scene filling the middle, the tree
    //down the left and the object properties down the right.
    //
    //Built once, and only after the dockspace exists, because it replaces the
    //nodes inside it. Docking a window by name works before that window has
    //ever been submitted, which is what lets the layout be described in one
    //place rather than at each window.
    function buildDefaultLayout_(){
        if(mLayoutBuilt_) return;
        mLayoutBuilt_ = true;

        //Start from nothing, so the layout is the one described here rather
        //than this on top of whatever the dockspace already had.
        _imgui.dockBuilderRemoveNode(mDockId_);
        _imgui.dockBuilderAddNode(mDockId_, _imgui.DockNodeFlags_DockSpace);
        local size = _imgui.getDisplaySize();
        //Splits are proportional to the node's size, so it needs one first.
        _imgui.dockBuilderSetNodeSize(mDockId_, size[0], size[1]);

        //Each split returns both halves: the one on the side split off, and
        //what is left of the node, which is what the next split works on.
        local left = _imgui.dockBuilderSplitNode(mDockId_, _imgui.Dir_Left, 0.2);
        local right = _imgui.dockBuilderSplitNode(left[1], _imgui.Dir_Right, 0.25);

        mSideDockId_ = left[0];
        mPropertiesDockId_ = right[0];
        mSceneDockId_ = right[1];

        //By title, which for the framework's panels includes the ## id suffix
        //that keeps their titles unique.
        _imgui.dockBuilderDockWindow(SCENE_WINDOW_TITLE, mSceneDockId_);
        _imgui.dockBuilderDockWindow(mSceneTreePanel_.mWindowTitle_, mSideDockId_);
        _imgui.dockBuilderDockWindow(mObjectPropertiesPanel_.mWindowTitle_, mPropertiesDockId_);

        _imgui.dockBuilderFinish(mDockId_);
    }

    function drawSceneWindow_(){
        if(!mScenePanelVisible_){
            notifySceneNotDrawn_();
            return;
        }

        _imgui.setNextWindowDockId(mSceneDockId_, _imgui.Cond_FirstUseEver);
        //No padding, so the image meets the edges of the panel like a viewport.
        //Popped straight after begin so the rest of the window is normal.
        _imgui.pushStyleVar(_imgui.StyleVar_WindowPadding, 0, 0);
        local visible = _imgui.begin(SCENE_WINDOW_TITLE,
            _imgui.WindowFlags_NoScrollbar | _imgui.WindowFlags_NoScrollWithMouse);
        _imgui.popStyleVar();

        if(!visible){
            //Collapsed or tabbed out of sight. The workspace keeps rendering,
            //which is what makes the tab show a live scene the moment it is
            //selected again, but nothing on screen can be interacted with.
            notifySceneNotDrawn_();
            _imgui.end();
            return;
        }

        //Read before anything is drawn: the cursor sits at the top left of the
        //content region until something moves it.
        local cursorX = _imgui.getCursorPosX();
        local cursorY = _imgui.getCursorPosY();
        local pos = _imgui.getCursorScreenPos();
        local size = _imgui.getContentRegionAvail();
        mSceneRect_ = [pos[0], pos[1], size[0], size[1]];

        if(size[0] > 0 && size[1] > 0){
            //Drawn at the panel's size rather than the texture's, so a resize
            //shows a stretched scene for the few frames before the texture
            //catches up rather than a gap.
            _imgui.image(mSceneTexture_, size[0], size[1]);

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

        //The scene is inside an imgui window now, so wantCaptureMouse is true
        //whenever the cursor is over it and cannot be what decides this. Being
        //over this window, and no other, is what makes the scene interactable.
        //AllowWhenBlockedByActiveItem keeps a drag alive while a gizmo is held.
        mSceneEditorInteractable_ = _imgui.isWindowHovered(_imgui.HoveredFlags_AllowWhenBlockedByActiveItem);

        _imgui.end();
    }

    //Nothing is showing the scene, so there is no viewport to map the mouse
    //into and nothing to interact with.
    function notifySceneNotDrawn_(){
        mSceneRect_ = null;
        mSceneEditorInteractable_ = false;
    }

    function drawMenuBar_(){
        if(!_imgui.beginMainMenuBar()) return;

        if(_imgui.beginMenu("File")){
            if(_imgui.menuItem("Save")){
                mBase_.writeSceneFile("res://res/example.avScene");
            }
            _imgui.endMenu();
        }

        if(_imgui.beginMenu("Edit")){
            if(_imgui.menuItem("Undo")) mBase_.mActionStack_.undo();
            if(_imgui.menuItem("Redo")) mBase_.mActionStack_.redo();
            _imgui.separator();
            if(_imgui.menuItem("Position")){
                mBase_.getActiveSceneTree().setObjectTransformCoordinateType(::ExampleEditor.TRANSFORM_POSITION);
            }
            if(_imgui.menuItem("Scale")){
                mBase_.getActiveSceneTree().setObjectTransformCoordinateType(::ExampleEditor.TRANSFORM_SCALE);
            }
            _imgui.endMenu();
        }

        if(_imgui.beginMenu("Window")){
            if(_imgui.menuItem("Scene", null, mScenePanelVisible_)){
                mScenePanelVisible_ = !mScenePanelVisible_;
            }
            if(_imgui.menuItem("Scene Tree", null, mSceneTreePanel_.isVisible())){
                mSceneTreePanel_.toggleVisible();
            }
            if(_imgui.menuItem("Object Properties", null, mObjectPropertiesPanel_.isVisible())){
                mObjectPropertiesPanel_.toggleVisible();
            }
            _imgui.endMenu();
        }

        _imgui.endMainMenuBar();
    }

    function sceneSafeUpdate(){
        mBase_.sceneSafeUpdate();
    }

    function end(){
        mBase_.shutdown();
        destroySceneTexture_();
    }
};

function start(){
    ::ExampleEditor.start();
}

function update(){
    ::ExampleEditor.update();
}

function sceneSafeUpdate(){
    ::ExampleEditor.sceneSafeUpdate();
}

function end(){
    ::ExampleEditor.end();
}
