//The options shown when an object is right clicked, either in the scene tree or
//in the scene itself.
//
//This lives in the example rather than the framework on purpose: which options
//an editor offers for an object is the editor's business. The framework only
//says which object was right clicked - by transmitting
//SCENE_TREE_OPTIONS_MENU_REQUEST for the scene tree, and by answering
//findEntryIdAtScenePosition() for the scene - and this decides what to do about
//it.
//
//Everything here is drawn at the top level of the frame rather than inside a
//panel. ImGui hashes a popup's id against the id stack it was opened in, so
//openPopup() and beginPopup() have to be called from the same place; opening one
//from inside the scene tree window and drawing it outside would never match.
//
//This is loaded with _doFile from the editor's start function rather than
//alongside the entry file. The framework's bus events are squirrel constants,
//which exist from the moment the plugin's scripts have run - after the entry
//file was compiled, but before anything calls start.
::ExampleRightClickMenu <- class{

    //Not shown to the user - a popup has no title bar - but it still has to be
    //unique, and the modal's title is displayed.
    MENU_POPUP_ID = "exampleObjectRightClickMenu"
    RENAME_POPUP_ID = "Rename object"

    mBase_ = null;
    //The entry the menu was opened for. Held rather than read back from the
    //selection so the menu keeps acting on the object which was right clicked.
    mEntryId_ = null;
    //Set when something has asked for the menu, and consumed by draw(), which is
    //the only place allowed to open the popup.
    mRequestedEntryId_ = null;
    //Rename is asked for from inside the menu popup, and its modal has to be
    //opened after that popup has been closed off.
    mRenameRequested_ = false;
    mRenameText_ = "";
    mRenameFocusPending_ = false;

    constructor(baseObj){
        mBase_ = baseObj;

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
        drawRenamePopup_();
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

        if(_imgui.menuItem("Rename")){
            mRenameText_ = ::SceneEditorFramework.getNameForSceneEntry(entry);
            mRenameRequested_ = true;
        }
        if(_imgui.menuItem("Delete")){
            deleteEntry_();
        }

        _imgui.endPopup();

        //Out here, where the id stack is the one the rename modal is drawn in.
        if(mRenameRequested_){
            mRenameRequested_ = false;
            mRenameFocusPending_ = true;
            _imgui.openPopup(RENAME_POPUP_ID);
        }
    }

    function drawRenamePopup_(){
        if(!_imgui.beginPopupModal(RENAME_POPUP_ID, _imgui.WindowFlags_AlwaysAutoResize)) return;

        _imgui.text("Enter new node name");
        if(mRenameFocusPending_){
            mRenameFocusPending_ = false;
            _imgui.setKeyboardFocusHere();
        }
        mRenameText_ = _imgui.inputText("##exampleRenameInput", mRenameText_);

        //A node with no name is the framework's way of saying "use the type's
        //name", which is not something to arrive at by accident.
        local nameValid = mRenameText_.len() > 0;
        _imgui.beginDisabled(!nameValid);
        if(_imgui.button("Accept")){
            renameEntry_(mRenameText_);
            _imgui.closeCurrentPopup();
        }
        _imgui.endDisabled();

        _imgui.sameLine();
        if(_imgui.button("Close")){
            _imgui.closeCurrentPopup();
        }

        _imgui.endPopup();
    }

    function deleteEntry_(){
        if(!selectEntry_()) return;
        mBase_.getActiveSceneTree().deleteCurrentSelection();
        mEntryId_ = null;
    }

    function renameEntry_(newName){
        if(!selectEntry_()) return;
        mBase_.getActiveSceneTree().renameCurrentSelection(newName);
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
