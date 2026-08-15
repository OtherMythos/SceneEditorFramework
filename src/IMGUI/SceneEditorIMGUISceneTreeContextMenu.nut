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
    mEntryId_ = null;
    //Set when something has asked for the menu, and consumed by draw(), which is
    //the only place allowed to open the popup.
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
     * when the next frame's gui is built.
     */
    function requestForEntry(entryId){
        mRequestedEntryId_ = entryId;
    }

    /**
     * Draw the menu. Call once per rendered frame, after the panels have been
     * drawn, so that a request made while the scene tree was drawn is acted on
     * in the same frame the user right clicked.
     */
    function draw(){
        if(mRequestedEntryId_ != null){
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

        local entry = getEntry_();
        if(entry == null){
            //The object went away while the menu was open, so there is nothing
            //left to offer options for.
            _imgui.closeCurrentPopup();
            _imgui.endPopup();
            return;
        }

        _imgui.textDisabled(::SceneEditorFramework.getNameForSceneEntry(entry));
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

        mEditor_.drawSceneTreeContextMenuEntries_(entry, mEntryId_);
        _imgui.separator();

        if(_imgui.menuItem("Rename")){
            requestRename_();
        }
        if(_imgui.menuItem("Delete")){
            deleteEntry_();
        }

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

    function getSceneTree_(){
        if(getEntry_() == null) return null;
        return mBase_.getActiveSceneTree();
    }

    function deleteEntry_(){
        if(!selectEntry_()) return;
        mBase_.getActiveSceneTree().deleteCurrentSelection();
        mEntryId_ = null;
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
