//A small editor built on the scene editor framework, laid out with imgui
//docking.
//
//The scene is not drawn to the window. It is rendered into a texture by a
//workspace the editor creates (see res/example.compositor), and that texture is
//drawn into a docked viewport window with _imgui.image. Everything else - the
//framework's scene tree and object properties panels - docks around it, so the
//editor looks like an editor rather than panels floating over the game.
//
//There can be any number of those viewports, each an ::ExampleSceneRenderWindow
//owning the camera it looks through, the texture it draws and the workspace which
//renders one into the other. The Window menu opens them and each closes itself
//from its own menu bar, taking its workspace with it.
//
//Three consequences of the scene living inside windows, all handled below:
//  * The cursor being over a viewport means it is over an imgui window, so
//    wantCaptureMouse can no longer decide whether the scene is interactable.
//    Whether a viewport itself is hovered decides that instead.
//  * Mouse positions have to be expressed relative to a viewport rather than to
//    the whole window, which is what normalisedSceneMousePosition is for.
//  * "The scene" is no longer one thing. The framework asks where the cursor is
//    in the scene and which camera the scene is seen through, and both are
//    answered for a single viewport - the one the cursor is working in - which is
//    what keeps input to one viewport at a time.
//    @see updateFocusedRenderWindow_
//  * A transform gizmo is sized by its distance from the camera so that it stays
//    the same size on screen, and there is no one size which suits every
//    viewport at once. So the framework draws a copy of it per viewport, sized
//    for that viewport's camera, and each viewport is rendered by a workspace
//    which draws its own copy and no other.
//    @see gizmoLayerCameras_ and res/example.compositor
//
//Each viewport is flown with the framework's fps camera: hold the right mouse
//button in one and it turns with the mouse and moves with WASD, QE for up and
//down, shift and alt for faster. Only the viewport the button was pressed in
//flies, and it keeps the mouse until the button is released.
//@see updateRenderWindowCameras_

//Raw SDL scancodes, which is what _input.getRawKeyScancodeInput() takes. In the
//root table rather than an enum because the framework reads KeyScancode.LSHIFT
//itself when a scale gizmo is dragged, and its scripts are compiled before this
//file - so the name has to be one that resolves at runtime.
::KeyScancode <- {
    NUMBER_1 = 30,
    NUMBER_2 = 31,

    Y = 28,
    Z = 29,

    LCTRL = 224,
    LSHIFT = 225,
    LALT = 226,
    //Command on macOS, Windows key elsewhere.
    LGUI = 227,
    RCTRL = 228,
    RSHIFT = 229,
    RGUI = 231
};

::ExampleEditor <- {
    mBase_ = null
    mSceneParent_ = null
    mSceneTreePanel_ = null
    mObjectPropertiesPanel_ = null

    //The options offered for a right clicked object. @see ExampleRightClickMenu
    mRightClickMenu_ = null
    //An object right clicked in the scene, waiting for the gui to be built. The
    //pick has to happen while the scene is clean and the menu has to be opened
    //while the gui is built, which are different points in the frame.
    mPendingSceneMenuEntry_ = null
    //Whether the right mouse button was held last time the scene was picked.
    //getMouseReleased is cleared before sceneSafeUpdate runs again, so the
    //release is found by watching the button rather than by asking for it.
    mRightMouseDown_ = false

    //Every viewport onto the scene which is currently open.
    //@see ExampleSceneRenderWindow
    mRenderWindows_ = null
    //The one of them the cursor is working in, which is the one the framework's
    //questions about the scene are answered for.
    //@see updateFocusedRenderWindow_
    mFocusedRenderWindow_ = null
    //The one whose camera is currently being flown, or null when none of them
    //is. It has the mouse until the button flying it is released, so while this
    //is set nothing else in the editor is using the cursor.
    //@see updateRenderWindowCameras_
    mFlyingRenderWindow_ = null
    //Never reused, so that a window's imgui, texture and camera names cannot
    //collide with those of one which has been closed.
    mNextRenderWindowId_ = 1

    //The display scale the gui was last set to. @see updateGuiScale_
    mGuiScale_ = 1.0

    //Which key commands the keyboard was expressing last frame, so that holding
    //a shortcut down performs it once rather than once a frame.
    //@see updateKeyCommands_
    mKeyCommandHeld_ = null

    //The dockspace, and the nodes of the default layout built inside it.
    mDockId_ = 0
    mSceneDockId_ = 0
    mSideDockId_ = 0
    mPropertiesDockId_ = 0
    mLayoutBuilt_ = false

    //Loads and saves the runtime layout separately from the scene itself.
    //@see ExampleEditorState.nut
    mEditorState_ = null

    PANEL_SCENE_TREE = 0
    PANEL_OBJECT_PROPERTIES = 1
    TRANSFORM_POSITION = 0
    TRANSFORM_SCALE = 1
    TRANSFORM_ORIENTATION = 2
    TRANSFORM_RAYCAST = 3

    KEY_COMMAND_UNDO = 0
    KEY_COMMAND_REDO = 1
    KEY_COMMAND_TRANSFORM_POSITION = 2
    KEY_COMMAND_TRANSFORM_SCALE = 3
    KEY_COMMAND_MAX = 4

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
        //Restore exactly the viewports which were open. With no state file the
        //example starts with one, as it always has; a saved empty list is kept
        //empty because closing every viewport is a valid editor layout.
        local savedRenderWindows = mEditorState_.getSavedRenderWindows();
        if(savedRenderWindows != null){
            foreach(savedWindow in savedRenderWindows){
                addRenderWindow_(savedWindow);
            }
        }else{
            addRenderWindow_();
        }

        _compositor.addWorkspace([_window.getRenderTexture()], _camera.getCamera(),
            "SceneEditorExample/ClearWindowWorkspace", true);

        //The plugin would create this itself on the first frame which uses
        //imgui, but creating it here pins it after the two workspaces above.
        //Ogre runs workspaces in the order they were added, so the gui is drawn
        //over the cleared window rather than being cleared away again.
        //
        //A viewport opened later ends up after the overlay, which only means its
        //texture is a frame behind the one the gui draws - not something which
        //can be seen, and the alternative is rebuilding every workspace whenever
        //a viewport is opened.
        _imgui.createOverlayWorkspace();
    }

    /**
     * Open another viewport onto the scene. It docks with the others the first
     * time it is drawn, and opens on a different view from the one before it so
     * that it is showing something new.
     *
     * @returns The new viewport, or null when every gizmo layer is taken and
     * there is no room for another. @see findFreeGizmoLayer_
     */
    function addRenderWindow_(savedState=null){
        local layer = null;
        if(savedState != null && typeof savedState == "table" && savedState.rawin("layer")){
            local savedLayer = savedState.rawget("layer");
            if(typeof savedLayer == "integer" && savedLayer >= 0 &&
                savedLayer < ::SceneEditorFramework.MAX_GIZMO_LAYERS &&
                isGizmoLayerFree_(savedLayer)){
                layer = savedLayer;
            }
        }
        if(layer == null) layer = findFreeGizmoLayer_();
        if(layer == null) return null;

        local id = mNextRenderWindowId_;
        if(savedState != null && typeof savedState == "table" && savedState.rawin("id") &&
            typeof savedState.rawget("id") == "integer" && savedState.rawget("id") > 0 &&
            findRenderWindowById_(savedState.rawget("id")) == null){
            id = savedState.rawget("id");
        }
        if(id >= mNextRenderWindowId_) mNextRenderWindowId_ = id + 1;
        else mNextRenderWindowId_++;

        local window = ::ExampleSceneRenderWindow(this, id, layer, mRenderWindows_.len(), savedState);

        mRenderWindows_.append(window);
        return window;
    }

    function findRenderWindowById_(id){
        foreach(window in mRenderWindows_){
            if(window.getId() == id) return window;
        }
        return null;
    }

    function isGizmoLayerFree_(layer){
        foreach(window in mRenderWindows_){
            if(window.getLayer() == layer) return false;
        }
        return true;
    }

    //A gizmo layer no open viewport is using, or null when there are none left.
    //
    //A layer is a copy of the transform gizmo and the workspace definition which
    //draws it, and the compositor declares a fixed number of those - so this is
    //what limits how many viewports the editor can have open. Layers are handed
    //back when a viewport closes, so closing one always makes room for another.
    function findFreeGizmoLayer_(){
        local used = array(::SceneEditorFramework.MAX_GIZMO_LAYERS, false);
        foreach(window in mRenderWindows_){
            used[window.getLayer()] = true;
        }

        foreach(layer,taken in used){
            if(!taken) return layer;
        }

        return null;
    }

    //Close the viewports which asked to be closed while the last frame was
    //built, giving up the camera, texture and workspace each of them owns.
    //
    //Called at the top of the frame rather than where the request was made: the
    //texture a window has handed to imgui is not drawn until the frame it was
    //handed over in is over, so this is the only point at which destroying one
    //is safe.
    function sweepClosedRenderWindows_(){
        //Backwards, so removing one does not move the next one out from under
        //the loop.
        for(local i = mRenderWindows_.len() - 1; i >= 0; i--){
            local window = mRenderWindows_[i];
            if(!window.isCloseRequested()) continue;

            //Nothing can be working in a viewport which no longer exists.
            if(mFocusedRenderWindow_ == window) mFocusedRenderWindow_ = null;
            if(mFlyingRenderWindow_ == window) mFlyingRenderWindow_ = null;

            window.shutdown();
            mRenderWindows_.remove(i);
        }

        //ImGui collapses an empty dock leaf. Until another viewport exists,
        //put a newly opened one beside the properties instead of retaining the
        //now-invalid id of the vanished scene leaf.
        if(mRenderWindows_.len() == 0) mSceneDockId_ = mPropertiesDockId_;
    }

    //Which viewport the cursor is working in. Everything the framework asks
    //about the scene - where the cursor is in it, which camera it is seen
    //through - is answered for this one, which is what keeps the editor's input
    //going to one viewport at a time however many are open.
    //
    //The focus follows the cursor, except while the left button is held: a drag
    //which began in one viewport and wandered into another is still a drag in
    //the one it began in, and the object being dragged should not start
    //following the other viewport's camera half way through.
    //
    //It stays with the last viewport the cursor was over rather than being given
    //up when the cursor leaves, so that the gizmos keep the size that viewport
    //gave them while the cursor is off editing a panel. Whether the scene can be
    //interacted with is a separate question. @see sceneEditorInteractable_
    function updateFocusedRenderWindow_(){
        if(mFocusedRenderWindow_ != null && _input.getMouseButton(_MB_LEFT)) return;
        //A viewport being flown holds the cursor still and puts it back when it
        //nears the edge of the window, so where the cursor is says nothing about
        //where the user is working until the flight is over.
        if(mFlyingRenderWindow_ != null) return;

        foreach(window in mRenderWindows_){
            if(!window.isHovered()) continue;

            mFocusedRenderWindow_ = window;
            return;
        }
    }

    //Fly whichever viewport the user is holding the right mouse button in.
    //
    //Only the viewport the cursor is over may take the mouse, and only while no
    //other one has it: a flight which began in one viewport carries on there
    //however far the cursor wanders, which is what keeps a fast turn from
    //handing the keyboard to whichever viewport the cursor crossed into.
    //
    //Called on every update rather than once per rendered frame, so that the
    //distance a camera travels is the same however fast the editor is drawing.
    function updateRenderWindowCameras_(){
        foreach(window in mRenderWindows_){
            local interactable = mFlyingRenderWindow_ == null && window.isHovered();

            if(window.updateCamera(interactable)){
                mFlyingRenderWindow_ = window;
            }else if(mFlyingRenderWindow_ == window){
                mFlyingRenderWindow_ = null;
            }
        }
    }

    //Scale the gui to the display. imgui is given the window's size in pixels
    //as its display size, so on a screen with a scale factor - a retina Mac,
    //a scaled Windows desktop - it draws at that resolution and everything in
    //it comes out that fraction of the physical size it would be at 1:1, which
    //is half size at 2x. Scaling the gui by the same factor puts it back.
    //
    //Checked every frame rather than once at startup, so moving the window to
    //a display with a different scale factor is picked up. Setting the scale
    //it already has does nothing, and the plugin applies a new one at the
    //start of the next frame - the font is re-baked at the scaled size, which
    //cannot happen part way through a frame.
    function updateGuiScale_(){
        local windowSize = _window.getSize();
        if(windowSize.x <= 0) return;

        local pixelSize = _window.getActualSize();
        local scale = pixelSize.x / windowSize.x;
        //Only ever scaled up. A window with fewer pixels than desktop units
        //would otherwise shrink the gui rather than leave it alone.
        if(scale < 1.0) scale = 1.0;

        if(scale == mGuiScale_) return;
        mGuiScale_ = scale;
        _imgui.setGlobalScale(scale);
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

    //The three questions the framework asks about the scene, all answered for
    //the viewport the cursor is working in.
    //
    //None of them may call into imgui: the framework asks them during its scene
    //update, before the gui for the frame is built, and every _imgui call begins
    //the frame - which would throw away the gui built by the previous update and
    //leave the window empty. What the viewports were told while they were drawn
    //is remembered by them for exactly this reason.

    //Whether the cursor is over the focused viewport rather than somewhere else
    //in the editor. It can be focused without being hovered - the cursor has
    //moved onto a panel, or is part way through a drag which has left it.
    function sceneCursorInViewport_(){
        if(mFocusedRenderWindow_ == null) return false;
        return mFocusedRenderWindow_.isHovered();
    }

    //Whether the framework may act on the cursor. A viewport being flown has the
    //mouse, and the cursor it is holding still is not pointing at anything the
    //user means to pick or drag.
    function sceneEditorInteractable_(){
        if(mFlyingRenderWindow_ != null) return false;
        return sceneCursorInViewport_();
    }

    //Where the cursor is within the focused viewport's image, in the 0-1 range
    //the framework wants.
    function normalisedSceneMousePosition_(){
        if(mFocusedRenderWindow_ == null) return null;
        return mFocusedRenderWindow_.normalisedMousePosition(imguiMousePosition_());
    }

    //The camera the focused viewport sees the scene through, which is the one
    //the framework casts the cursor's ray from.
    function activeSceneCamera_(){
        if(mFocusedRenderWindow_ == null) return null;
        return mFocusedRenderWindow_.getCamera();
    }

    //The cameras every open viewport sees the scene through, by the gizmo layer
    //each of them claimed.
    //
    //The framework puts a copy of the transform gizmo on each of these layers
    //and sizes it for the camera named here, which is what gives every viewport
    //a gizmo the right size for the view it is showing. A layer no viewport has
    //claimed is named as null, and the copy of the gizmo on it is given up.
    //
    //Every open viewport is named, including one which is not being drawn: its
    //workspace keeps rendering while it is tabbed out of sight, which is what
    //makes selecting its tab show a live scene rather than a stale one.
    function gizmoLayerCameras_(){
        local cameras = array(::SceneEditorFramework.MAX_GIZMO_LAYERS, null);
        foreach(window in mRenderWindows_){
            cameras[window.getLayer()] = window.getCamera();
        }

        return cameras;
    }

    //Which of those layers the cursor is working in. Only that viewport's copy
    //of the gizmo can be picked or dragged, so this is what keeps a drag going
    //to the gizmo the user can actually see under the cursor.
    function activeGizmoLayer_(){
        if(mFocusedRenderWindow_ == null) return null;
        return mFocusedRenderWindow_.getLayer();
    }

    //Perform whatever the keyboard is asking for. The engine reports the state
    //of a key rather than delivering presses, so a press is a frame where the
    //command has turned from not held to held - which is what the previous
    //frame's states are kept for.
    //
    //Called before the gui is built so that the panels drawn this frame show the
    //scene as the command left it, and once per rendered frame rather than once
    //per fixed update so that a held shortcut repeats at a visible rate.
    function updateKeyCommands_(){
        local command = readKeyCommand_();

        for(local i = 0; i < KEY_COMMAND_MAX; i++){
            local held = command == i;
            local pressed = held && !mKeyCommandHeld_[i];
            mKeyCommandHeld_[i] = held;

            if(!pressed) continue;
            if(i == KEY_COMMAND_UNDO){
                mBase_.mActionStack_.undo();
            }else if(i == KEY_COMMAND_REDO){
                mBase_.mActionStack_.redo();
            }else if(i == KEY_COMMAND_TRANSFORM_POSITION){
                mBase_.getActiveSceneTree().setObjectTransformCoordinateType(::ExampleEditor.TRANSFORM_POSITION);
            }else{
                mBase_.getActiveSceneTree().setObjectTransformCoordinateType(::ExampleEditor.TRANSFORM_SCALE);
            }
        }
    }

    //The command the keyboard is currently expressing, or null for none. Only
    //ever one: Shift turns Ctrl+Z into a redo rather than adding one to it.
    function readKeyCommand_(){
        //Ctrl+clicking a drag field in the object properties turns it into a
        //text box. Typing in one is not a request for a shortcut.
        if(_imgui.wantCaptureKeyboard()) return null;

        if(_input.getRawKeyScancodeInput(KeyScancode.NUMBER_1)) return KEY_COMMAND_TRANSFORM_POSITION;
        if(_input.getRawKeyScancodeInput(KeyScancode.NUMBER_2)) return KEY_COMMAND_TRANSFORM_SCALE;

        //Command as well as Control, as that is the shortcut on macOS. Both
        //sides of the keyboard, which is what a modifier scancode distinguishes.
        if(!anyKeyHeld_([KeyScancode.LCTRL, KeyScancode.RCTRL,
            KeyScancode.LGUI, KeyScancode.RGUI])) return null;

        //Ctrl+Y is the other redo shortcut on Windows.
        if(_input.getRawKeyScancodeInput(KeyScancode.Y)) return KEY_COMMAND_REDO;
        if(!_input.getRawKeyScancodeInput(KeyScancode.Z)) return null;

        return anyKeyHeld_([KeyScancode.LSHIFT, KeyScancode.RSHIFT]) ?
            KEY_COMMAND_REDO : KEY_COMMAND_UNDO;
    }

    function anyKeyHeld_(scancodes){
        foreach(scancode in scancodes){
            if(_input.getRawKeyScancodeInput(scancode)) return true;
        }
        return false;
    }

    //What to print next to a menu entry. The modifier is named for the platform
    //the editor is running on, so it matches the key the user has to press.
    function keyCommandLabel_(command){
        //local modifier = _settings.getPlatform() == _PLATFORM_MACOS ? "Cmd" : "Ctrl";
        //At the moment I'm just using ctrl on macos as well.
        local modifier = "Ctrl";
        if(command == KEY_COMMAND_UNDO) return modifier + "+Z";
        if(command == KEY_COMMAND_REDO) return modifier + "+Shift+Z";
        if(command == KEY_COMMAND_TRANSFORM_POSITION) return "1";
        return "2";
    }

    function start(){
        if(!("_imgui" in getroottable())){
            throw "The example requires the AvImguiPlugin. See example/plugins/README.md.";
        }

        _doFile("res://ExampleRightClickMenu.nut");
        _doFile("res://SceneRenderWindow.nut");
        _doFile("res://ExampleEditorState.nut");

        mEditorState_ = ::ExampleEditorState(this);
        mEditorState_.load();

        ::SceneEditorFramework.HelperFunctions = {
            function sceneEditorInteractable(){
                return ::ExampleEditor.sceneEditorInteractable_();
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

            //The scene is a panel now, not the whole window - and there can be
            //more than one of them.
            function normalisedSceneMousePosition(){
                return ::ExampleEditor.normalisedSceneMousePosition_();
            }

            //Each viewport has its own camera, so the framework cannot assume
            //the engine's default one is the one the user is looking through.
            function activeSceneCamera(){
                return ::ExampleEditor.activeSceneCamera_();
            }

            //A gizmo sized for one viewport's camera is the wrong size in every
            //other viewport, so the framework builds one per viewport and each
            //of these says which viewport it is sizing one for.
            function gizmoLayerCameras(){
                return ::ExampleEditor.gizmoLayerCameras_();
            }

            function activeGizmoLayer(){
                return ::ExampleEditor.activeGizmoLayer_();
            }

            //Every viewport draws the gizmo in a pass of its own, having cleared
            //the depth buffer first. That is what puts the gizmo over the scene,
            //and it lets the gizmo depth test against itself so that its arms
            //overlap in the order they are really in.
            //@see res/example.compositor
            function gizmoPassClearsDepth(){
                return true;
            }
        };

        mKeyCommandHeld_ = array(KEY_COMMAND_MAX, false);
        mRenderWindows_ = [];

        setupLights_();
        //Each viewport places its own camera, so the engine's default one is
        //left alone. Nothing looks through it: it exists for the workspace which
        //clears the window behind the gui, which draws no scene.
        setupCompositor_();

        mBase_ = ::SceneEditorFramework.Base();
        mSceneParent_ = _scene.getRootSceneNode().createChildSceneNode();
        mBase_.setActiveSceneTree(mBase_.loadSceneTree(mSceneParent_, "res://res/example.avScene"));

        mSceneTreePanel_ = mBase_.setupIMGUIWindow(PANEL_SCENE_TREE, ::SceneEditorFramework.IMGUI.SceneTree);
        mObjectPropertiesPanel_ = mBase_.setupIMGUIWindow(PANEL_OBJECT_PROPERTIES, ::SceneEditorFramework.IMGUI.ObjectProperties);

        mEditorState_.apply();

        //Subscribes itself to the bus, which is how a right click in the scene
        //tree reaches it.
        mRightClickMenu_ = ::ExampleRightClickMenu(mBase_);
    }

    function update(){
        //Before the framework's update, so that the gizmos it sizes by their
        //distance from the camera are sized for where the camera is now.
        updateRenderWindowCameras_();

        mBase_.update();
        if(!_imgui.isFirstUpdateOfFrame()) return;

        updateGuiScale_();
        //Both of these create and destroy render targets, so they come before
        //anything this frame is drawn. @see sweepClosedRenderWindows_
        sweepClosedRenderWindows_();
        foreach(window in mRenderWindows_){
            window.updateTextureSize();
        }
        updateKeyCommands_();

        //The dockspace comes first: a window submitted before the dockspace it
        //docks into is undocked again.
        mDockId_ = _imgui.dockSpaceOverViewport();
        mEditorState_.setDisplaySize(_imgui.getDisplaySize());
        buildDefaultLayout_();

        drawMenuBar_();
        //A viewport opened by the menu above is drawn from this frame onwards.
        foreach(window in mRenderWindows_){
            window.draw(mSceneDockId_);
            if(window.getDockId() != 0) mSceneDockId_ = window.getDockId();
        }
        //Straight after they are drawn, so the framework's update and the next
        //scene update are told where the cursor is now rather than where it was
        //a frame ago.
        updateFocusedRenderWindow_();
        mBase_.drawIMGUI();

        //Last, so a request made by the scene tree while it was drawn above is
        //picked up in the same frame, and so the popup is drawn over everything.
        applyPendingSceneMenuRequest_();
        mRightClickMenu_.draw();
    }

    //An object right clicked in the scene becomes the selection, the same as one
    //right clicked in the scene tree does, so that the menu's options - which
    //the framework applies to the selection - act on it.
    function applyPendingSceneMenuRequest_(){
        if(mPendingSceneMenuEntry_ == null) return;

        local entryId = mPendingSceneMenuEntry_;
        mPendingSceneMenuEntry_ = null;

        mBase_.getActiveSceneTree().notifySelectionChanged(entryId);
        mRightClickMenu_.requestForEntry(entryId);
    }

    //The layout the editor opens with: the scene filling the middle, the tree
    //down the left and the object properties down the right.
    //
    //Built once, and only after the dockspace exists, because it replaces the
    //nodes inside it. Docking a window by name works before that window has
    //ever been submitted, which is what lets the layout be described in one
    //place rather than at each window.
    function buildDefaultLayout_(forceDefault=false){
        if(mLayoutBuilt_) return;
        mLayoutBuilt_ = true;

        //A saved layout wins over the initial three-column arrangement. If it
        //is incomplete or no longer usable, fall through to the known-good
        //default instead of leaving the editor without a dockspace.
        if(!forceDefault && mEditorState_.buildSavedDockLayout(mDockId_)) return;

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

        //By title, which for the framework's panels and the viewports alike
        //includes the ## id suffix that keeps their titles unique. Only the
        //first viewport is placed here; the rest tab in beside it as they are
        //opened, since the layout cannot describe windows which do not exist yet.
        if(forceDefault){
            foreach(window in mRenderWindows_){
                _imgui.dockBuilderDockWindow(window.getTitle(), mSceneDockId_);
            }
        }else if(mRenderWindows_.len() > 0){
            _imgui.dockBuilderDockWindow(mRenderWindows_[0].getTitle(), mSceneDockId_);
        }
        _imgui.dockBuilderDockWindow(mSceneTreePanel_.mWindowTitle_, mSideDockId_);
        _imgui.dockBuilderDockWindow(mObjectPropertiesPanel_.mWindowTitle_, mPropertiesDockId_);

        _imgui.dockBuilderFinish(mDockId_);
    }

    //Recreate the example's initial three-column arrangement immediately. The
    //scene is left unchanged; existing viewports become tabs in the middle.
    function resetWindowLayout_(){
        mSceneTreePanel_.setVisible(true);
        mObjectPropertiesPanel_.setVisible(true);

        if(mRenderWindows_.len() == 0){
            addRenderWindow_();
        }else{
            foreach(window in mRenderWindows_){
                if(!window.isVisible()) window.toggleVisible();
            }
        }

        mLayoutBuilt_ = false;
        buildDefaultLayout_(true);
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
            if(_imgui.menuItem("Undo", keyCommandLabel_(KEY_COMMAND_UNDO))) mBase_.mActionStack_.undo();
            if(_imgui.menuItem("Redo", keyCommandLabel_(KEY_COMMAND_REDO))) mBase_.mActionStack_.redo();
            _imgui.separator();
            if(_imgui.menuItem("Position", keyCommandLabel_(KEY_COMMAND_TRANSFORM_POSITION))){
                mBase_.getActiveSceneTree().setObjectTransformCoordinateType(::ExampleEditor.TRANSFORM_POSITION);
            }
            if(_imgui.menuItem("Scale", keyCommandLabel_(KEY_COMMAND_TRANSFORM_SCALE))){
                mBase_.getActiveSceneTree().setObjectTransformCoordinateType(::ExampleEditor.TRANSFORM_SCALE);
            }
            _imgui.endMenu();
        }

        if(_imgui.beginMenu("Window")){
            if(_imgui.menuItem("Reset Layout")) resetWindowLayout_();
            _imgui.separator();

            //Only while there is a gizmo layer left for one to draw its gizmo
            //on. Shown all the same once there are none, so that the way to get
            //another viewport is to close one rather than to wonder where the
            //entry went. @see findFreeGizmoLayer_
            if(findFreeGizmoLayer_() != null){
                if(_imgui.menuItem("Add Render Window")) addRenderWindow_();
            }else{
                _imgui.textDisabled("Add Render Window");
            }

            //A viewport can also be closed from its own menu bar. This is the
            //way back to one which has been hidden, which its own menu bar
            //cannot offer while it is not being drawn.
            //
            //Skipped entirely when every viewport has been closed, so that the
            //separators around the list do not end up next to each other with
            //nothing between them to divide.
            if(mRenderWindows_.len() > 0){
                _imgui.separator();
                foreach(window in mRenderWindows_){
                    //Named for the window, which is unique, so the entries do
                    //not share an imgui id.
                    if(!_imgui.beginMenu(window.getName())) continue;

                    if(_imgui.menuItem("Visible", null, window.isVisible())) window.toggleVisible();
                    if(_imgui.menuItem("Close")) window.requestClose();

                    _imgui.endMenu();
                }
            }

            _imgui.separator();
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
        updateSceneRightClick_();
    }

    //Right clicking an object in the scene offers the same options right
    //clicking it in the scene tree does.
    //
    //Which object is under the cursor is a ray cast against the scene, which
    //needs the scene to be clean - so it happens here rather than while the gui
    //is built, and what it finds waits until then.
    //
    //On the release rather than the press, because the same button flies the
    //camera: until it comes back up there is no telling whether it was a click
    //asking for a menu or the beginning of a flight.
    function updateSceneRightClick_(){
        local down = _input.getMouseButton(_MB_RIGHT);
        local released = !down && mRightMouseDown_;
        mRightMouseDown_ = down;

        //Only a click in a viewport is a click on the scene, and the object it
        //finds is the one that viewport's camera sees under the cursor. Anywhere
        //else belongs to imgui, which draws its own context menus.
        //
        //Deliberately not sceneEditorInteractable_, which is false while the
        //camera still has the mouse: this runs before the update which notices
        //the button has come up, so on the frame a flight ends it would refuse
        //every release, menu-worthy or not.
        if(!released || !sceneCursorInViewport_()) return;
        //A button which flew the camera was doing that rather than asking for
        //anything. The camera keeps the answer until the next press, so it is
        //still there to be asked once the flight is over.
        if(mFocusedRenderWindow_.cameraWasFlown()) return;

        local sceneTree = mBase_.getActiveSceneTree();
        if(sceneTree == null) return;

        local entryId = sceneTree.findEntryIdAtScenePosition(::SceneEditorFramework.getNormalisedSceneMousePosition());
        //Right clicking empty space is not a request for options on anything.
        if(entryId == null) return;

        mPendingSceneMenuEntry_ = entryId;
    }

    function end(){
        if(mEditorState_ != null) mEditorState_.save();
        mBase_.shutdown();

        foreach(window in mRenderWindows_){
            window.shutdown();
        }
        mRenderWindows_.clear();
        mFocusedRenderWindow_ = null;
        mFlyingRenderWindow_ = null;
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
