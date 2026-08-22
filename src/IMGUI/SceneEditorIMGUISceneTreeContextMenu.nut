//The options shown when an object is right clicked, either in the scene tree or
//in the scene itself.
//
//The standard options shown when an object is right clicked. Editors can append
//project-specific entries with Editor's drawSceneTreeContextMenu option.
//
//Everything here is drawn at the top level of the frame rather than inside a
//panel. ImGui hashes a popup's id against the id stack it was opened in, so
//openPopup() and beginPopup() have to be called from the same place; opening one
//from inside the scene tree window and drawing it outside would never match.
//
::SceneEditorFramework.IMGUI.SceneTreeContextMenu <- class{

    //Not shown to the user - a popup has no title bar - but it still has to be
    //unique.
    MENU_POPUP_ID = "sceneEditorObjectRightClickMenu"

    mBase_ = null;
    mEditor_ = null;
    //The entry the menu was opened for. Held rather than read back from the
    //selection so the menu keeps acting on the object which was right clicked.
    //Null means the menu belongs to the scene's child wrapper rather than to an
    //object, which is what a right click hitting no entry asks for.
    mEntryId_ = null;
    //Set when something has asked for the menu, and consumed by draw(), which is
    //the only place allowed to open the popup. The id is allowed to be null, so
    //the request itself is what the flag records.
    mRequestPending_ = false;
    mRequestedEntryId_ = null;

    constructor(editor){
        mEditor_ = editor;
        mBase_ = editor.mBase_;

        //A right click in the scene tree is announced on the bus, so the menu
        //has to be listening to it to be shown for one.
        mBase_.mBus_.subscribeObject(this);
    }

    function notifyBusEvent(event, data){
        if(event == SceneEditorFramework_BusEvents.SCENE_TREE_OPTIONS_MENU_REQUEST){
            //Transmitted while the scene tree panel is drawn, and the menu is
            //drawn after the panels are, so this frame shows it.
            requestForEntry(data);
        }
    }

    /**
     * Ask for the menu to be shown for an entry. It appears where the cursor is
     * when the next frame's gui is built. A null entry shows the menu for the
     * scene's top level.
     */
    function requestForEntry(entryId){
        mRequestedEntryId_ = entryId;
        mRequestPending_ = true;
    }

    /**
     * Draw the menu. Call once per rendered frame, after the panels have been
     * drawn, so that a request made while the scene tree was drawn is acted on
     * in the same frame the user right clicked.
     */
    function draw(){
        if(mRequestPending_){
            mRequestPending_ = false;
            mEntryId_ = mRequestedEntryId_;
            mRequestedEntryId_ = null;
            //The popup remembers where the cursor was when it was opened, which
            //is what puts it under the click.
            _imgui.openPopup(MENU_POPUP_ID);
        }

        drawMenu_();
    }

    function drawMenu_(){
        if(!_imgui.beginPopup(MENU_POPUP_ID)) return;

        //A menu opened over no entry belongs to the scene's child wrapper: what
        //it creates goes at the top level, and the options which need an object
        //of their own are shown disabled rather than hidden, so the menu keeps
        //the same shape wherever it was opened.
        local rootMenu = isRootMenu_();
        local entry = getEntry_();
        if(!rootMenu && entry == null){
            //The object went away while the menu was open, so there is nothing
            //left to offer options for.
            _imgui.closeCurrentPopup();
            _imgui.endPopup();
            return;
        }

        _imgui.textDisabled(rootMenu ? "Scene" :
            ::SceneEditorFramework.getNameForSceneEntry(entry));
        _imgui.separator();

        if(_imgui.beginMenu("Add")){
            if(_imgui.menuItem("Empty")){
                insertEmptyChild_();
            }

            _imgui.separator();

            if(_imgui.menuItem("Cube")) insertPrimitiveMeshChild_("cube", "Cube");
            if(_imgui.menuItem("Sphere")) insertPrimitiveMeshChild_("sphere", "Sphere");
            if(_imgui.menuItem("Capsule")) insertPrimitiveMeshChild_("capsule", "Capsule");
            if(_imgui.menuItem("Plane")) insertPrimitiveMeshChild_("plane", "Plane");
            _imgui.endMenu();
        }

        //Everything below acts on an object, and the child wrapper is not one.
        _imgui.beginDisabled(rootMenu);
        if(_imgui.menuItem("Reparent with empty")){
            reparentWithEmpty_();
        }
        if(_imgui.menuItem("Centre on contents")){
            centreOnContents_();
        }

        _imgui.separator();

        if(_imgui.menuItem("Copy")){
            copySelection_();
        }
        if(_imgui.menuItem("Duplicate")){
            duplicateSelection_();
        }
        _imgui.endDisabled();

        if(mBase_.getClipboard().hasEntries()){
            if(_imgui.menuItem("Paste")){
                pasteClipboard_();
            }
        }

        //Editors are only offered the object menu. Their entries are written
        //against an entry, so the child wrapper has nothing to hand them.
        if(!rootMenu) mEditor_.drawSceneTreeContextMenuEntries_(entry, mEntryId_);
        _imgui.separator();

        _imgui.beginDisabled(rootMenu);
        if(_imgui.menuItem("Rename")){
            requestRename_();
        }
        if(_imgui.menuItem("Delete")){
            deleteEntry_();
        }
        _imgui.endDisabled();

        _imgui.endPopup();
    }

    //The rename itself is performed inline in the scene tree, exactly as a
    //double click on a row does, so the panel is asked to begin editing.
    function requestRename_(){
        if(!selectEntry_()) return;
        mBase_.mBus_.transmitEvent(
            SceneEditorFramework_BusEvents.SCENE_TREE_RENAME_REQUEST, mEntryId_);
    }

    function insertEmptyChild_(){
        local sceneTree = getSceneTree_();
        if(sceneTree != null) sceneTree.insertEmptyChild(mEntryId_, "Empty");
    }

    function insertPrimitiveMeshChild_(meshName, entryName){
        local sceneTree = getSceneTree_();
        if(sceneTree != null){
            sceneTree.insertPrimitiveMeshChild(mEntryId_, meshName, entryName);
        }
    }

    //Acts on the whole selection rather than only the right clicked object, so
    //a group which was built up by clicking can be gathered under one empty in
    //a single step.
    function reparentWithEmpty_(){
        if(!selectEntry_()) return;
        mBase_.getActiveSceneTree().reparentSelectionWithEmpty("Empty");
    }

    //Acts only on the object the menu was opened for, unlike the operations
    //around it: what this moves is that object and what hangs below it, and the
    //rest of a selection has nothing to do with either.
    function centreOnContents_(){
        if(!selectEntry_()) return;
        mBase_.getActiveSceneTree().centreEntryOnContents(mEntryId_);
    }

    //Copying acts on the whole selection, as reparenting does: the right
    //clicked object is made the selection first only when it was not part of
    //one already.
    function copySelection_(){
        local sceneTree = mBase_.getActiveSceneTree();
        if(sceneTree == null || getEntry_() == null) return;
        if(!sceneTree.isEntrySelected(mEntryId_)) sceneTree.notifySelectionChanged(mEntryId_);

        sceneTree.copySelectionToClipboard(mBase_.getClipboard());
    }

    //Duplicating acts on the whole selection, as copying does, and leaves the
    //copies beside what they were copied from rather than inside the right
    //clicked object: this is the same operation the Shift+D shortcut performs,
    //and the copies become the selection so they can be moved straight away.
    function duplicateSelection_(){
        local sceneTree = mBase_.getActiveSceneTree();
        if(sceneTree == null || getEntry_() == null) return;
        if(!sceneTree.isEntrySelected(mEntryId_)) sceneTree.notifySelectionChanged(mEntryId_);

        sceneTree.duplicateSelectionInPlace();
    }

    //Pasted into the object the menu was opened for, rather than beside the
    //selection: the menu belongs to the object which was right clicked, and its
    //other insertions - everything under Add - put what they create below that
    //object as well. The child wrapper's menu pastes at the top level, whatever
    //happens to be selected.
    function pasteClipboard_(){
        local sceneTree = getSceneTree_();
        if(sceneTree == null) return;
        if(isRootMenu_()){
            sceneTree.pasteFromClipboardAtTopLevel(mBase_.getClipboard());
            return;
        }
        sceneTree.pasteFromClipboard(mBase_.getClipboard(), mEntryId_,
            SceneEditorFramework_ObjectInsertionType.INTO);
    }

    //The scene tree an insertion is to be made in. The child wrapper's menu has
    //no entry to check for, and the tree's insertions take a null parent as the
    //top level, so mEntryId_ is passed to them either way.
    function getSceneTree_(){
        if(!isRootMenu_() && getEntry_() == null) return null;
        return mBase_.getActiveSceneTree();
    }

    //The menu was opened over unused hierarchy space rather than over a row.
    function isRootMenu_(){
        return mEntryId_ == null;
    }

    function deleteEntry_(){
        if(!selectEntry_()) return;
        mBase_.getActiveSceneTree().deleteCurrentSelection();
        //The id is left in place rather than cleared: a null id now means the
        //menu belongs to the child wrapper, and getEntry_() already reports the
        //deleted object as gone.
    }

    //Both operations the framework offers work on whatever is selected, so the
    //object the menu belongs to has to be the selection when they run. It
    //normally already is - it was selected when it was right clicked - but the
    //selection can have moved on while a popup was open.
    function selectEntry_(){
        if(getEntry_() == null) return false;

        local sceneTree = mBase_.getActiveSceneTree();
        if(sceneTree.mCurrentSelection != mEntryId_){
            sceneTree.notifySelectionChanged(mEntryId_);
        }

        return true;
    }

    function getEntry_(){
        if(mEntryId_ == null) return null;

        local sceneTree = mBase_.getActiveSceneTree();
        if(sceneTree == null) return null;
        if(sceneTree.findEntryIdIndexInTree_(mEntryId_) == null) return null;

        return sceneTree.getEntryForId(mEntryId_);
    }

};
