//A ready-to-configure scene editor laid out with ImGui docking.
//
//The scene is not drawn to the window. It is rendered into a texture by a
//workspace the editor creates (see res/SceneEditor.compositor), and that texture is
//drawn into a docked viewport window with _imgui.image. Everything else - the
//framework's scene tree and object properties panels - docks around it, so the
//editor looks like an editor rather than panels floating over the game.
//
//There can be any number of those viewports, each an IMGUI.SceneRenderWindow
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
//    @see gizmoLayerCameras_ and res/SceneEditor.compositor
//
//Each viewport is flown with the framework's fps camera: hold the right mouse
//button in one and it turns with the mouse and moves with WASD, QE for up and
//down, shift and alt for faster. Only the viewport the button was pressed in
//flies, and it keeps the mouse until the button is released.
//@see updateRenderWindowCameras_

::SceneEditorFramework.IMGUI.Editor <- class{
    mOptions_ = null
    mScenePath_ = null
    mStatePath_ = null
    mBase_ = null
    mSceneParent_ = null
    mLightNode_ = null
    mClearWorkspace_ = null
    mSceneTreePanel_ = null
    mObjectPropertiesPanel_ = null
    mFileBrowserPanel_ = null
    mResourcePickerPopup_ = null

    //The options offered for a right clicked object.
    mRightClickMenu_ = null
    //The list of every object under an alt+right click.
    mRaycastSelectionMenu_ = null
    //An object right clicked in the scene, waiting for the gui to be built. The
    //pick has to happen while the scene is clean and the menu has to be opened
    //while the gui is built, which are different points in the frame.
    mPendingSceneMenuEntry_ = null
    //Whether the right mouse button was held last time the scene was picked.
    //getMouseReleased is cleared before sceneSafeUpdate runs again, so the
    //release is found by watching the button rather than by asking for it.
    mRightMouseDown_ = false
    //The same, watched where the cameras are updated instead, which is a
    //different point in the frame. @see updateRightHoldGesture_
    mRightHeldForCameras_ = false
    //Whether alt was held when the right button went down, which is what makes
    //the hold the object chooser's rather than the camera's.
    mRightHoldWasAlt_ = false

    //Every viewport onto the scene which is currently open.
    //@see SceneEditorFramework.IMGUI.SceneRenderWindow
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
    //@see SceneEditorFramework.IMGUI.EditorState
    mEditorState_ = null

    //The title the window was created with - avSetup.cfg's WindowTitle, or the
    //project name in its absence. The unsaved marker is appended to it rather
    //than replacing it, so the window is still recognisably the application it
    //was. @see updateWindowTitle_
    mBaseWindowTitle_ = null
    //Whether the title currently on the window is the unsaved one, or null
    //before it has been set at all. Kept so the title is set when the answer
    //changes rather than once a frame, since setting it goes to the platform.
    mTitleShowsUnsaved_ = null

    PANEL_SCENE_TREE = 0
    PANEL_OBJECT_PROPERTIES = 1
    PANEL_FILE_BROWSER = 2
    KEY_COMMAND_UNDO = 0
    KEY_COMMAND_REDO = 1
    KEY_COMMAND_TRANSFORM_POSITION = 2
    KEY_COMMAND_TRANSFORM_SCALE = 3
    KEY_COMMAND_TRANSFORM_ORIENTATION = 4
    KEY_COMMAND_FRAME_SELECTION = 5
    KEY_COMMAND_DELETE_SELECTION = 6
    KEY_COMMAND_COPY_SELECTION = 7
    KEY_COMMAND_PASTE = 8
    KEY_COMMAND_SAVE = 9
    KEY_COMMAND_TOGGLE_VISIBILITY = 10
    KEY_COMMAND_MAX = 11

    constructor(options){
        mOptions_ = options == null ? {} : options;
        mScenePath_ = option_("scenePath", null);
        if(mScenePath_ == null) throw "IMGUI.Editor requires a scenePath option.";
        mStatePath_ = option_("statePath", "res://.editorState.json");
    }

    //Read an option without making every caller repeat Squirrel's raw lookup.
    function option_(name, fallback=null){
        return mOptions_.rawin(name) ? mOptions_.rawget(name) : fallback;
    }

    function resourceName_(suffix){
        return option_("resourcePrefix", "sceneEditorFramework") + "/" + suffix;
    }

    function sceneWorkspaceName_(layer){
        return option_("sceneWorkspacePrefix",
            "SceneEditorFramework/SceneToTextureWorkspace") + layer;
    }

    function drawSceneTreeContextMenuEntries_(entry, entryId){
        local callback = option_("drawSceneTreeContextMenu", null);
        if(callback != null) callback(this, entry, entryId);
    }

    function getBase(){
        return mBase_;
    }

    function getSceneTree(){
        return mBase_ == null ? null : mBase_.getActiveSceneTree();
    }

    function getRenderWindows(){
        return mRenderWindows_;
    }

    function getFileBrowser(){
        return mFileBrowserPanel_;
    }

    function addRenderWindow(savedState=null){
        return addRenderWindow_(savedState);
    }

    function resetWindowLayout(){
        resetWindowLayout_();
    }

    /** Frame the whole selection in the viewport the user last worked in. */
    function frameSelection(){
        return frameSelection_();
    }

    function setupLights_(){
        local light = _scene.createLight();
        mLightNode_ = _scene.getRootSceneNode().createChildSceneNode();
        mLightNode_.attachObject(light);

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
        //editor starts with one; a saved empty list is kept
        //empty because closing every viewport is a valid editor layout.
        local savedRenderWindows = mEditorState_ == null ? null :
            mEditorState_.getSavedRenderWindows();
        if(savedRenderWindows != null){
            foreach(savedWindow in savedRenderWindows){
                addRenderWindow_(savedWindow);
            }
        }else{
            local initialViewportCount = option_("initialViewportCount", 1);
            for(local i = 0; i < initialViewportCount; i++) addRenderWindow_();
        }

        mClearWorkspace_ = _compositor.addWorkspace(
            [_window.getRenderTexture()], _camera.getCamera(),
            option_("clearWindowWorkspace",
                "SceneEditorFramework/ClearWindowWorkspace"), true);

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

        local windowClass = option_("sceneRenderWindowClass",
            ::SceneEditorFramework.IMGUI.SceneRenderWindow);
        local window = windowClass(this, id, layer, mRenderWindows_.len(), savedState);

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
    function updateRenderWindowCameras_(deltaSeconds){
        updateRightHoldGesture_();

        foreach(window in mRenderWindows_){
            //A hold which belongs to the object chooser is not offered to any
            //camera, so alt+right clicking a viewport cannot begin a flight it
            //would then have to be told apart from.
            local interactable = !mRightHoldWasAlt_ &&
                mFlyingRenderWindow_ == null && window.isHovered();

            if(window.updateCamera(interactable, deltaSeconds)){
                mFlyingRenderWindow_ = window;
            }else if(mFlyingRenderWindow_ == window){
                mFlyingRenderWindow_ = null;
            }
        }
    }

    /**
     * Work out which gesture the right button being held is.
     *
     * Alt held as it went down makes the hold the object chooser's, and no
     * camera is given it. The right button otherwise flies the camera, and a
     * flight is what the chooser's release would be mistaken for: the cursor is
     * hidden and taken over the moment the button goes down, and the smallest
     * drift of it while the button is held is a turn of the camera, which is
     * enough for the release to be read as the end of a flight rather than as a
     * click.
     *
     * Decided at the press and left alone for the rest of the hold. Letting go
     * of alt part way through does not hand the hold to the camera, and alt
     * taken up during a flight is the camera's own speed modifier rather than a
     * request for the list.
     *
     * Here rather than beside the release which reads it, because this has to
     * have happened before the cameras are updated and those two run at
     * different points in the frame.
     */
    function updateRightHoldGesture_(){
        local down = _input.getMouseButton(_MB_RIGHT);
        local pressed = down && !mRightHeldForCameras_;
        mRightHeldForCameras_ = down;

        //Not cleared when the button comes up: the release is what opens the
        //chooser, and it has to still be able to tell what the hold was.
        if(pressed) mRightHoldWasAlt_ = altSelectionModifierHeld_();
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
            //A hidden gizmo layer has no copy for SceneEditorGizmoLayers to
            //size, render, or pick. The viewport's regular scene camera stays
            //alive; only its editor overlays are absent.
            if(window.showsGizmos()) cameras[window.getLayer()] = window.getCamera();
        }

        return cameras;
    }

    //Which of those layers the cursor is working in. Only that viewport's copy
    //of the gizmo can be picked or dragged, so this is what keeps a drag going
    //to the gizmo the user can actually see under the cursor.
    function activeGizmoLayer_(){
        if(mFocusedRenderWindow_ == null) return null;
        if(!mFocusedRenderWindow_.showsGizmos()) return null;
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
                mBase_.getActiveSceneTree().setObjectTransformCoordinateType(SceneEditorFramework_BasicCoordinateType.POSITION);
            }else if(i == KEY_COMMAND_TRANSFORM_SCALE){
                mBase_.getActiveSceneTree().setObjectTransformCoordinateType(SceneEditorFramework_BasicCoordinateType.SCALE);
            }else if(i == KEY_COMMAND_TRANSFORM_ORIENTATION){
                mBase_.getActiveSceneTree().setObjectTransformCoordinateType(SceneEditorFramework_BasicCoordinateType.ORIENTATION);
            }else if(i == KEY_COMMAND_FRAME_SELECTION){
                frameSelection_();
            }else if(i == KEY_COMMAND_COPY_SELECTION){
                copySelection_();
            }else if(i == KEY_COMMAND_PASTE){
                pasteClipboard_();
            }else if(i == KEY_COMMAND_SAVE){
                saveScene_();
            }else if(i == KEY_COMMAND_TOGGLE_VISIBILITY){
                toggleSelectionVisibility_();
            }else{
                deleteSelection_();
            }
        }
    }

    //Delete whatever is selected, if anything is. The scene tree requires a
    //selection to delete, so an empty one is a shortcut pressed with nothing to
    //act on rather than a mistake.
    function deleteSelection_(){
        if(mBase_ == null) return false;
        local tree = mBase_.getActiveSceneTree();
        if(tree == null) return false;
        if(tree.getReducedSelection().len() == 0) return false;

        tree.deleteCurrentSelection();
        return true;
    }

    //Take whatever is selected out of sight, or bring it back. As with
    //deletion, a shortcut pressed with nothing selected is nothing to act on
    //rather than a mistake.
    function toggleSelectionVisibility_(){
        local tree = activeSceneTree_();
        if(tree == null) return false;
        return tree.toggleSelectionVisibility();
    }

    //Take a copy of whatever is selected. As with deletion, a shortcut pressed
    //with nothing selected is nothing to act on rather than a mistake, and it
    //leaves the previous copy in the clipboard.
    function copySelection_(){
        local tree = activeSceneTree_();
        if(tree == null) return false;
        return mBase_.getClipboard().copyFromTree(tree);
    }

    //Paste beside the selection, or at the end of the scene when nothing is
    //selected. The pasted objects become the selection, so a paste can be
    //dragged or transformed straight away.
    function pasteClipboard_(){
        local tree = activeSceneTree_();
        if(tree == null) return false;
        return tree.pasteFromClipboard(mBase_.getClipboard()) != null;
    }

    //Write the scene back over the file it was loaded from. An editor started
    //without a scene has nothing to write, which is a shortcut pressed with
    //nothing to act on rather than a mistake.
    function saveScene_(){
        if(mBase_ == null || mScenePath_ == null) return false;
        if(mBase_.getActiveSceneTree() == null) return false;

        mBase_.writeSceneFile(mScenePath_);
        return true;
    }

    function activeSceneTree_(){
        return mBase_ == null ? null : mBase_.getActiveSceneTree();
    }

    //Bring the selection into view. A multiple selection is framed as a whole
    //rather than on whichever entry was selected last, since that entry is an
    //arbitrary member of the group as far as the camera is concerned.
    function frameSelection_(){
        if(mFocusedRenderWindow_ == null || mBase_ == null) return false;
        local tree = mBase_.getActiveSceneTree();
        if(tree == null || tree.mCurrentSelection == -1) return false;

        local bounds = tree.getFullSelectionAABB();
        if(bounds == null) return false;
        return mFocusedRenderWindow_.frameBounds(bounds,
            option_("cameraFocusDuration", 0.3));
    }

    //The command the keyboard is currently expressing, or null for none. Only
    //ever one: Shift turns Ctrl+Z into a redo rather than adding one to it.
    function readKeyCommand_(){
        //Ctrl+clicking a drag field in the object properties turns it into a
        //text box. Typing in one is not a request for a shortcut.
        if(_imgui.wantCaptureKeyboard()) return null;

        local shift = anyKeyHeld_([SceneEditorFramework_KeyScancode.LSHIFT,
            SceneEditorFramework_KeyScancode.RSHIFT]);
        if(shift && _input.getRawKeyScancodeInput(
            SceneEditorFramework_KeyScancode.C)) return KEY_COMMAND_FRAME_SELECTION;

        //Backspace as well as Delete, as a keyboard without a delete key is
        //still expected to be able to remove an object.
        if(anyKeyHeld_([SceneEditorFramework_KeyScancode.DELETE,
            SceneEditorFramework_KeyScancode.BACKSPACE])) return KEY_COMMAND_DELETE_SELECTION;

        if(_input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.NUMBER_1)) return KEY_COMMAND_TRANSFORM_POSITION;
        if(_input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.NUMBER_2)) return KEY_COMMAND_TRANSFORM_SCALE;
        if(_input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.NUMBER_3)) return KEY_COMMAND_TRANSFORM_ORIENTATION;
        if(_input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.H)) return KEY_COMMAND_TOGGLE_VISIBILITY;

        //Command as well as Control, as that is the shortcut on macOS. Both
        //sides of the keyboard, which is what a modifier scancode distinguishes.
        if(!anyKeyHeld_([SceneEditorFramework_KeyScancode.LCTRL, SceneEditorFramework_KeyScancode.RCTRL,
            SceneEditorFramework_KeyScancode.LGUI, SceneEditorFramework_KeyScancode.RGUI])) return null;

        if(_input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.C)) return KEY_COMMAND_COPY_SELECTION;
        if(_input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.V)) return KEY_COMMAND_PASTE;
        if(_input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.S)) return KEY_COMMAND_SAVE;

        //Ctrl+Y is the other redo shortcut on Windows.
        if(_input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.Y)) return KEY_COMMAND_REDO;
        if(!_input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.Z)) return null;

        return shift ? KEY_COMMAND_REDO : KEY_COMMAND_UNDO;
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
        if(command == KEY_COMMAND_TRANSFORM_SCALE) return "2";
        if(command == KEY_COMMAND_FRAME_SELECTION) return "Shift+C";
        if(command == KEY_COMMAND_DELETE_SELECTION) return "Del";
        if(command == KEY_COMMAND_COPY_SELECTION) return modifier + "+C";
        if(command == KEY_COMMAND_PASTE) return modifier + "+V";
        if(command == KEY_COMMAND_SAVE) return modifier + "+S";
        if(command == KEY_COMMAND_TOGGLE_VISIBILITY) return "H";
        return "3";
    }

    function start(){
        //Read before the editor sets a title of its own, so the marker is
        //appended to the title the window was created with rather than to one
        //already carrying a marker. @see updateWindowTitle_
        mBaseWindowTitle_ = _window.getTitle();

        if(mStatePath_ != null){
            local stateClass = option_("editorStateClass",
                ::SceneEditorFramework.IMGUI.EditorState);
            mEditorState_ = stateClass(this, mStatePath_);
            mEditorState_.load();
        }

        installHelperFunctions_();
        mKeyCommandHeld_ = array(KEY_COMMAND_MAX, false);
        mRenderWindows_ = [];

        if(option_("createDefaultLight", true)) setupLights_();
        local setupScene = option_("setupScene", null);
        if(setupScene != null) setupScene(this);

        //Each viewport places its own camera, so the engine's default one is
        //left alone. Nothing looks through it: it exists for the workspace which
        //clears the window behind the gui, which draws no scene.
        setupCompositor_();

        mBase_ = ::SceneEditorFramework.Base();
        mSceneParent_ = _scene.getRootSceneNode().createChildSceneNode();
        mBase_.setActiveSceneTree(mBase_.loadSceneTree(mSceneParent_, mScenePath_));

        mSceneTreePanel_ = mBase_.setupIMGUIWindow(PANEL_SCENE_TREE,
            option_("sceneTreePanelClass", ::SceneEditorFramework.IMGUI.SceneTree));
        mObjectPropertiesPanel_ = mBase_.setupIMGUIWindow(PANEL_OBJECT_PROPERTIES,
            option_("objectPropertiesPanelClass",
                ::SceneEditorFramework.IMGUI.ObjectProperties));
        local fileBrowserModelClass = option_("fileBrowserModelClass",
            ::SceneEditorFramework.FileBrowserModel);
        local fileBrowserModel = fileBrowserModelClass(
            option_("fileBrowserRoot", "res://"),
            option_("fileBrowserBackend", null));
        mFileBrowserPanel_ = mBase_.setupIMGUIWindow(PANEL_FILE_BROWSER,
            option_("fileBrowserPanelClass", ::SceneEditorFramework.IMGUI.FileBrowser));
        mFileBrowserPanel_.configure(fileBrowserModel,
            option_("fileBrowserCallbacks", null));
        mResourcePickerPopup_ = ::SceneEditorFramework.IMGUI.ResourcePickerPopup(
            mBase_, mBase_.mBus_, option_("fileBrowserRoot", "res://"),
            option_("fileBrowserBackend", null), fileBrowserModelClass);
        if("setResourcePicker" in mObjectPropertiesPanel_){
            mObjectPropertiesPanel_.setResourcePicker(mResourcePickerPopup_);
        }

        if(mEditorState_ != null) mEditorState_.apply();

        if(option_("enableSceneTreeContextMenu", true)){
            //Subscribes itself to the bus, which is how a right click in the
            //scene tree reaches it.
            local contextMenuClass = option_("sceneTreeContextMenuClass",
                ::SceneEditorFramework.IMGUI.SceneTreeContextMenu);
            mRightClickMenu_ = contextMenuClass(this);
        }
        if(option_("enableRaycastSelectionMenu", true)){
            local raycastMenuClass = option_("raycastSelectionMenuClass",
                ::SceneEditorFramework.IMGUI.RaycastSelectionMenu);
            mRaycastSelectionMenu_ = raycastMenuClass(mBase_);
        }

        local onStarted = option_("onStarted", null);
        if(onStarted != null) onStarted(this);
    }

    function installHelperFunctions_(){
        local editor = this;
        local helpers = {
            function sceneEditorInteractable(){
                return editor.sceneEditorInteractable_();
            }

            function sceneTreeConstructObjectForUserEntry(userId, parentNode, entryData){}

            function getNameForUserEntry(userId){
                return "User" + userId;
            }

            function raycastForMovementGizmo(){
                return Vec3();
            }

            function basicMouseInteractionEnabled(){
                //Alt+click belongs to the all-hits chooser rather than the
                //framework's normal nearest-object selection.
                return editor.mRaycastSelectionMenu_ == null ||
                    !editor.altSelectionModifierHeld_();
            }

            function drawIMGUIObjectPropertiesForUserEntry(userId, entry){
            }

            //The scene is a panel now, not the whole window - and there can be
            //more than one of them.
            function normalisedSceneMousePosition(){
                return editor.normalisedSceneMousePosition_();
            }

            //Each viewport has its own camera, so the framework cannot assume
            //the engine's default one is the one the user is looking through.
            function activeSceneCamera(){
                return editor.activeSceneCamera_();
            }

            //A gizmo sized for one viewport's camera is the wrong size in every
            //other viewport, so the framework builds one per viewport and each
            //of these says which viewport it is sizing one for.
            function gizmoLayerCameras(){
                return editor.gizmoLayerCameras_();
            }

            function activeGizmoLayer(){
                return editor.activeGizmoLayer_();
            }

            //Every viewport draws the gizmo in a pass of its own, having cleared
            //the depth buffer first. That is what puts the gizmo over the scene,
            //and it lets the gizmo depth test against itself so that its arms
            //overlap in the order they are really in.
            //@see res/SceneEditor.compositor
            function gizmoPassClearsDepth(){
                return true;
            }
        };

        local customHelpers = option_("helperFunctions", null);
        if(customHelpers != null){
            foreach(name, callback in customHelpers) helpers.rawset(name, callback);
        }
        ::SceneEditorFramework.HelperFunctions = helpers;
    }

    function update(deltaSeconds=1.0 / 60.0){
        //Before the framework's update, so that the gizmos it sizes by their
        //distance from the camera are sized for where the camera is now.
        updateRenderWindowCameras_(deltaSeconds);
        //This call does not begin an ImGui frame. The plugin applies Dear
        //ImGui's global NoMouse configuration before NewFrame determines
        //hovered widgets, so a hidden FPS/orbit cursor cannot interact with any
        //window—including custom panels—wherever its absolute position moves.
        _imgui.setMouseInputEnabled(mFlyingRenderWindow_ == null);

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
        if(mEditorState_ != null){
            mEditorState_.setDisplaySize(_imgui.getDisplaySize());
        }
        buildDefaultLayout_();

        updateWindowTitle_();
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
        ::SceneEditorFramework.IMGUI.ResourceDragDrop.update();
        mBase_.drawIMGUI();
        mResourcePickerPopup_.draw();
        ::SceneEditorFramework.IMGUI.ResourceDragDrop.drawFeedback();
        ::SceneEditorFramework.IMGUI.ResourceDragDrop.finishFrame();

        //Last, so a request made by the scene tree while it was drawn above is
        //picked up in the same frame, and so the popup is drawn over everything.
        applyPendingSceneMenuRequest_();
        if(mRightClickMenu_ != null) mRightClickMenu_.draw();
        if(mRaycastSelectionMenu_ != null) mRaycastSelectionMenu_.draw();
    }

    //An object right clicked in the scene becomes the selection, the same as one
    //right clicked in the scene tree does, so that the menu's options - which
    //the framework applies to the selection - act on it.
    function applyPendingSceneMenuRequest_(){
        if(mPendingSceneMenuEntry_ == null || mRightClickMenu_ == null) return;

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
        if(!forceDefault && mEditorState_ != null &&
            mEditorState_.buildSavedDockLayout(mDockId_)) return;

        //Start from nothing, so the layout is the one described here rather
        //than this on top of whatever the dockspace already had.
        _imgui.dockBuilderRemoveNode(mDockId_);
        _imgui.dockBuilderAddNode(mDockId_, _imgui.DockNodeFlags_DockSpace);
        local size = _imgui.getDisplaySize();
        //Splits are proportional to the node's size, so it needs one first.
        _imgui.dockBuilderSetNodeSize(mDockId_, size[0], size[1]);

        //Each split returns both halves: the one on the side split off, and
        //what is left of the node, which is what the next split works on.
        local bottom = _imgui.dockBuilderSplitNode(mDockId_, _imgui.Dir_Down, 0.25);
        local left = _imgui.dockBuilderSplitNode(bottom[1], _imgui.Dir_Left,
            option_("sceneTreeWidth", 0.2));
        local right = _imgui.dockBuilderSplitNode(left[1], _imgui.Dir_Right,
            option_("objectPropertiesWidth", 0.25));

        mSideDockId_ = left[0];
        mPropertiesDockId_ = right[0];
        mSceneDockId_ = right[1];
        local bottomDockId = bottom[0];

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
        _imgui.dockBuilderDockWindow(mFileBrowserPanel_.mWindowTitle_, bottomDockId);
        _imgui.dockBuilderDockWindow(mObjectPropertiesPanel_.mWindowTitle_, mPropertiesDockId_);

        _imgui.dockBuilderFinish(mDockId_);
    }

    //Recreate the editor's initial three-column arrangement immediately. The
    //scene is left unchanged; existing viewports become tabs in the middle.
    function resetWindowLayout_(){
        mSceneTreePanel_.setVisible(true);
        mObjectPropertiesPanel_.setVisible(true);
        mFileBrowserPanel_.setVisible(true);

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
        if(!option_("showMainMenuBar", true)) return;
        if(!_imgui.beginMainMenuBar()) return;

        if(_imgui.beginMenu("File")){
            if(_imgui.menuItem("Save", keyCommandLabel_(KEY_COMMAND_SAVE))){
                saveScene_();
            }
            _imgui.endMenu();
        }

        if(_imgui.beginMenu("Edit")){
            if(_imgui.menuItem("Undo", keyCommandLabel_(KEY_COMMAND_UNDO))) mBase_.mActionStack_.undo();
            if(_imgui.menuItem("Redo", keyCommandLabel_(KEY_COMMAND_REDO))) mBase_.mActionStack_.redo();
            _imgui.separator();
            if(_imgui.menuItem("Copy", keyCommandLabel_(KEY_COMMAND_COPY_SELECTION))) copySelection_();
            if(_imgui.menuItem("Paste", keyCommandLabel_(KEY_COMMAND_PASTE))) pasteClipboard_();
            if(_imgui.menuItem("Delete", keyCommandLabel_(KEY_COMMAND_DELETE_SELECTION))) deleteSelection_();
            if(_imgui.menuItem("Toggle Visibility",
                keyCommandLabel_(KEY_COMMAND_TOGGLE_VISIBILITY))) toggleSelectionVisibility_();
            _imgui.separator();
            if(_imgui.menuItem("Position", keyCommandLabel_(KEY_COMMAND_TRANSFORM_POSITION))){
                mBase_.getActiveSceneTree().setObjectTransformCoordinateType(SceneEditorFramework_BasicCoordinateType.POSITION);
            }
            if(_imgui.menuItem("Scale", keyCommandLabel_(KEY_COMMAND_TRANSFORM_SCALE))){
                mBase_.getActiveSceneTree().setObjectTransformCoordinateType(SceneEditorFramework_BasicCoordinateType.SCALE);
            }
            if(_imgui.menuItem("Rotate", keyCommandLabel_(KEY_COMMAND_TRANSFORM_ORIENTATION))){
                mBase_.getActiveSceneTree().setObjectTransformCoordinateType(SceneEditorFramework_BasicCoordinateType.ORIENTATION);
            }
            _imgui.endMenu();
        }

        if(_imgui.beginMenu("View")){
            if(_imgui.menuItem("Frame Selected",
                keyCommandLabel_(KEY_COMMAND_FRAME_SELECTION))) frameSelection_();
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
            if(_imgui.menuItem("Resource Browser", null, mFileBrowserPanel_.isVisible())){
                mFileBrowserPanel_.toggleVisible();
            }
            _imgui.endMenu();
        }

        local drawMainMenu = option_("drawMainMenu", null);
        if(drawMainMenu != null) drawMainMenu(this);

        drawUnsavedIndicator_();

        _imgui.endMainMenuBar();
    }

    //Say so in the menu bar while the scene has been changed since it was last
    //written. Last in the bar, after whatever menus the application added, so
    //it sits to the right of them rather than between them - and in a colour,
    //because a word among the menu names is easy to read past.
    function drawUnsavedIndicator_(){
        if(!option_("showUnsavedIndicator", true)) return;
        if(!hasUnsavedChanges()) return;

        _imgui.separator();
        _imgui.textColored(1.0, 0.75, 0.2, 1.0, "Unsaved changes");
    }

    /** Whether the scene has been changed since it was last saved. */
    function hasUnsavedChanges(){
        return mBase_ != null && mBase_.hasUnsavedChanges();
    }

    //Mark the window itself, so the scene is known to be unsaved from the title
    //bar and the task switcher as well as from inside the editor.
    //
    //Setting a title goes through to the platform, so it is set on the frames
    //where the answer changes rather than on all of them.
    function updateWindowTitle_(){
        if(!option_("markWindowTitleUnsaved", true)) return;

        local unsaved = hasUnsavedChanges();
        if(mTitleShowsUnsaved_ == unsaved) return;
        mTitleShowsUnsaved_ = unsaved;

        _window.setTitle(unsaved ?
            mBaseWindowTitle_ + " (unsaved)" : mBaseWindowTitle_);
    }

    function sceneSafeUpdate(){
        mBase_.sceneSafeUpdate();
        updateSceneRightClick_();
    }

    function altSelectionModifierHeld_(){
        return anyKeyHeld_([SceneEditorFramework_KeyScancode.LALT, SceneEditorFramework_KeyScancode.RALT]);
    }

    /**
     * What a right click in a viewport asks for.
     *
     * Plainly, the same options right clicking the object in the scene tree
     * offers. Pressed with alt held, which of all the objects along the cursor
     * ray should be selected - the objects behind the nearest one are reachable
     * only by asking. One release does one of the two, which is the reason they
     * are decided together rather than in a handler each.
     *
     * Which object is under the cursor is a ray cast against the scene, which
     * needs the scene to be clean - so it happens here rather than while the gui
     * is built, and what it finds waits until then.
     *
     * On the release rather than the press, because the same button flies the
     * camera: until it comes back up there is no telling whether it was a click
     * asking for a menu or the beginning of a flight.
     */
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

        local sceneTree = mBase_.getActiveSceneTree();
        if(sceneTree == null) return;

        //What the hold was was settled when the button went down, so a chooser
        //release is not refused for alt having been let go of first - and a
        //flight is not turned into a chooser by alt taken up during it.
        //@see updateRightHoldGesture_
        if(mRightHoldWasAlt_){
            //No camera was given this hold, so there is no flight it could have
            //been instead, and nothing to ask the camera about.
            //
            //A release over nothing hands over an empty list, which the chooser
            //treats as nothing to choose between and opens no popup.
            if(mRaycastSelectionMenu_ != null){
                mRaycastSelectionMenu_.requestForEntries(
                    sceneTree.findEntryIdsAtScenePosition(
                        ::SceneEditorFramework.getNormalisedSceneMousePosition()));
            }
            return;
        }

        //A button which flew the camera was doing that rather than asking for
        //anything. The camera keeps the answer until the next press, so it is
        //still there to be asked once the flight is over.
        if(mFocusedRenderWindow_.cameraWasFlown()) return;
        if(mRightClickMenu_ == null) return;

        local entryId = sceneTree.findEntryIdAtScenePosition(::SceneEditorFramework.getNormalisedSceneMousePosition());
        //Right clicking empty space is not a request for options on anything.
        if(entryId == null) return;

        mPendingSceneMenuEntry_ = entryId;
    }

    function end(){
        //The flag belongs to the process-wide ImGui context rather than this
        //editor, so never leave it disabled when the editor shuts down.
        _imgui.setMouseInputEnabled(true);
        ::SceneEditorFramework.IMGUI.ResourceDragDrop.clear();
        local onShutdown = option_("onShutdown", null);
        if(onShutdown != null) onShutdown(this);
        if(mEditorState_ != null) mEditorState_.save();
        if(mBase_ != null) mBase_.shutdown();

        foreach(window in mRenderWindows_){
            window.shutdown();
        }
        mRenderWindows_.clear();
        mFocusedRenderWindow_ = null;
        mFlyingRenderWindow_ = null;

        if(mClearWorkspace_ != null){
            _compositor.removeWorkspace(mClearWorkspace_);
            mClearWorkspace_ = null;
        }
        if(mLightNode_ != null){
            mLightNode_.destroyNodeAndChildren();
            mLightNode_ = null;
        }
    }
};
