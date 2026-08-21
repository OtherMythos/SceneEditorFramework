::SceneEditorFramework.IMGUI.ObjectProperties <- class extends ::SceneEditorFramework.IMGUI.Panel{

    ICON_WIDTH = 14.0;
    ICON_HEIGHT = 12.0;
    ICON_CELL_WIDTH = 0.1;
    REFRESH_ICON = 6;
    //Unscaled width the tag field gives up so that the clear button beside it
    //fits: the button's icon, its frame padding, and the gap between the two.
    TAG_BUTTON_RESERVE = 24.0;

    mWindowTitle_ = "Object Properties##SceneEditorFrameworkObjectProperties";
    mEditStates_ = null;
    //Which entry the tag field is showing, what is typed into it, and whether
    //the last commit was refused. @see drawTagControl_
    mTagEntryId_ = null;
    mTagText_ = "";
    mTagEditing_ = false;
    mTagError_ = null;
    mObjectIcons_ = null;
    mVisibilityIcons_ = null;
    mResourcePicker_ = null;

    constructor(baseObj, bus){
        base.constructor(baseObj, bus);
        mEditStates_ = {};
        mObjectIcons_ = ::SceneEditorFramework.IMGUI.Textures.get(
            ::SceneEditorFramework.IMGUI.Textures.OBJECT_ICONS
        );
        mVisibilityIcons_ = ::SceneEditorFramework.IMGUI.Textures.get(
            ::SceneEditorFramework.IMGUI.Textures.VISIBLE_ICONS
        );
    }

    function setResourcePicker(picker){
        mResourcePicker_ = picker;
    }

    function draw(){
        if(!mVisible_) return;

        applyInitialWindowState_();
        local shown = _imgui.begin(mWindowTitle_);
        captureWindowState_(shown);
        if(shown){
            drawContents_();
        }
        _imgui.end();
    }

    function drawContents_(){
        local sceneTree = mBaseObj_.getActiveSceneTree();
        if(sceneTree == null || sceneTree.mCurrentSelection == -1){
            _imgui.textDisabled("No object selected");
            return;
        }

        local entry = sceneTree.getEntryForId(sceneTree.mCurrentSelection);
        drawObjectIcon_(entry.nodeType);
        _imgui.sameLine();
        _imgui.text(::SceneEditorFramework.getNameForSceneEntry(entry));
        _imgui.separator();

        drawVectorControl_("Position", entry, SceneEditorFramework_BasicCoordinateType.POSITION, Vec3());
        drawVectorControl_("Scale", entry, SceneEditorFramework_BasicCoordinateType.SCALE, Vec3(1, 1, 1));
        drawQuatControl_("Orientation", entry);

        drawTagControl_(entry);

        drawEntryData_(entry);
    }

    function drawVectorControl_(label, entry, coordinateType, resetValue){
        local value = coordinateType == SceneEditorFramework_BasicCoordinateType.POSITION ? entry.position : entry.scale;
        local result = ::SceneEditorFramework.IMGUI.Widgets.drawVector3(label, value);
        processEdit_(coordinateType, entry, result);

        if(!vectorEquals_(value, resetValue)){
            _imgui.sameLine();
            if(drawResetButton_(label)){
                performAndPushAction_(coordinateType, entry.entryId, value, resetValue);
            }
        }
    }

    function drawQuatControl_(label, entry){
        local result = ::SceneEditorFramework.IMGUI.Widgets.drawQuat(label, entry.orientation);
        processEdit_(SceneEditorFramework_BasicCoordinateType.ORIENTATION, entry, result);

        if(!quatEquals_(entry.orientation, Quat())){
            _imgui.sameLine();
            if(drawResetButton_(label)){
                performAndPushAction_(SceneEditorFramework_BasicCoordinateType.ORIENTATION, entry.entryId, entry.orientation, Quat());
            }
        }
    }

    /**
     * The tag this object is found by, which is unique within the scene.
     *
     * The field mirrors the entry whenever it is not being typed into, so undo,
     * redo and a change of selection are all shown without the panel having to
     * be told about them. A tag another object already holds is refused by the
     * tree, and the field goes back to what the entry actually carries with the
     * reason left on screen: moving the tag off the other object is not
     * something a typed field can be read as asking for.
     */
    function drawTagControl_(entry){
        _imgui.separatorText("Tag");

        if(mTagEntryId_ != entry.entryId){
            mTagEntryId_ = entry.entryId;
            mTagEditing_ = false;
            mTagError_ = null;
        }
        if(!mTagEditing_){
            mTagText_ = entry.tag == null ? "" : entry.tag;
        }

        local hasTag = entry.tag != null;
        //Leave room for the clear button beside the field when there is one.
        local reserved = (ICON_WIDTH + TAG_BUTTON_RESERVE) * _imgui.getGlobalScale();
        _imgui.setNextItemWidth(hasTag ? -reserved : -1);
        mTagText_ = _imgui.inputText("##tag", mTagText_, _imgui.InputTextFlags_EnterReturnsTrue);
        mTagEditing_ = _imgui.isItemActive();

        if(_imgui.isItemDeactivatedAfterEdit()){
            commitTag_(entry, mTagText_);
        }

        if(hasTag){
            _imgui.sameLine();
            if(drawResetButton_("Tag")){
                mBaseObj_.getActiveSceneTree().clearEntryTag(entry.entryId);
                mTagError_ = null;
            }
        }

        if(mTagError_ != null){
            _imgui.textColored(1.0, 0.4, 0.4, 1.0, mTagError_);
        }
    }

    function commitTag_(entry, newTag){
        mTagEditing_ = false;

        local sceneTree = mBaseObj_.getActiveSceneTree();
        if(!sceneTree.isTagAvailable(newTag, entry.entryId)){
            local holder = sceneTree.getEntryForId(sceneTree.getEntryIdForTag(newTag));
            mTagError_ = "'" + newTag + "' is already the tag of " +
                ::SceneEditorFramework.getNameForSceneEntry(holder);
            return;
        }

        mTagError_ = null;
        sceneTree.setEntryTag(entry.entryId, newTag);
    }

    function drawResetButton_(label){
        local guiScale = _imgui.getGlobalScale();
        local uv0 = REFRESH_ICON * ICON_CELL_WIDTH;
        return _imgui.imageButton("##reset" + label, mVisibilityIcons_,
            ICON_WIDTH * guiScale, ICON_HEIGHT * guiScale,
            uv0, 0.0, uv0 + ICON_CELL_WIDTH, 1.0);
    }

    function drawObjectIcon_(type){
        local cell = 0;
        if(type == SceneEditorFramework_SceneTreeEntryType.MESH){
            cell = 1;
        }else if(type == SceneEditorFramework_SceneTreeEntryType.USER0){
            cell = 2;
        }else if(type == SceneEditorFramework_SceneTreeEntryType.USER1){
            cell = 3;
        }else if(
            type == SceneEditorFramework_SceneTreeEntryType.USER2 ||
            type == SceneEditorFramework_SceneTreeEntryType.USER3
        ){
            cell = 4;
        }

        local guiScale = _imgui.getGlobalScale();
        local uv0 = cell * ICON_CELL_WIDTH;
        _imgui.image(mObjectIcons_, ICON_WIDTH * guiScale, ICON_HEIGHT * guiScale,
            uv0, 0.0, uv0 + ICON_CELL_WIDTH, 1.0);
    }

    //While a control is dragged, apply changes immediately. On release add one
    //action covering the full drag, so undo/redo stays at editor-operation
    //granularity instead of receiving one entry per rendered frame.
    function processEdit_(coordinateType, entry, result){
        if(result.activated && !mEditStates_.rawin(coordinateType)){
            mEditStates_.rawset(coordinateType, {
                id = entry.entryId,
                oldValue = getValueForCoordinate_(entry, coordinateType)
            });
        }

        if(result.edited){
            //A value widget normally reports activation before it reports an
            //edit. Keep this fallback for programmatic activation paths too.
            if(!mEditStates_.rawin(coordinateType)){
                mEditStates_.rawset(coordinateType, {
                    id = entry.entryId,
                    oldValue = getValueForCoordinate_(entry, coordinateType)
                });
            }
            local state = mEditStates_.rawget(coordinateType);
            local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.BASIC_COORDINATES_CHANGE];
            local preview = A(mBaseObj_.getActiveSceneTree(), mBus_, state.id, state.oldValue, result.value, coordinateType, false);
            preview.performAction();
        }

        if(result.deactivatedAfterEdit && mEditStates_.rawin(coordinateType)){
            local state = mEditStates_.rawget(coordinateType);
            local sceneTree = mBaseObj_.getActiveSceneTree();
            local finalValue = sceneTree.getValueForObjectCoordsChange_(coordinateType);
            local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.BASIC_COORDINATES_CHANGE];
            mBaseObj_.pushAction(A(sceneTree, mBus_, state.id, state.oldValue, finalValue, coordinateType, false));
            mEditStates_.rawdelete(coordinateType);
        }
    }

    function performAndPushAction_(coordinateType, entryId, oldValue, newValue){
        local sceneTree = mBaseObj_.getActiveSceneTree();
        local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.BASIC_COORDINATES_CHANGE];
        local action = A(sceneTree, mBus_, entryId, oldValue, newValue, coordinateType, false);
        mBaseObj_.pushAction(action);
        action.performAction();
    }

    function getValueForCoordinate_(entry, coordinateType){
        if(coordinateType == SceneEditorFramework_BasicCoordinateType.POSITION) return entry.position.copy();
        if(coordinateType == SceneEditorFramework_BasicCoordinateType.SCALE) return entry.scale.copy();
        return entry.orientation.copy();
    }

    function vectorEquals_(first, second){
        return first.x == second.x && first.y == second.y && first.z == second.z;
    }

    function quatEquals_(first, second){
        return first.x == second.x && first.y == second.y &&
            first.z == second.z && first.w == second.w;
    }

    function drawEntryData_(entry){
        if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.MESH){
            ::SceneEditorFramework.IMGUI.ObjectPropertyEntryMesh.draw(
                entry, mBaseObj_, mBus_, mResourcePicker_);
            return;
        }

        if(
            entry.nodeType == SceneEditorFramework_SceneTreeEntryType.USER0 ||
            entry.nodeType == SceneEditorFramework_SceneTreeEntryType.USER1 ||
            entry.nodeType == SceneEditorFramework_SceneTreeEntryType.USER2 ||
            entry.nodeType == SceneEditorFramework_SceneTreeEntryType.USER3
        ){
            local userId = entry.nodeType - SceneEditorFramework_SceneTreeEntryType.USER0;
            if("drawIMGUIObjectPropertiesForUserEntry" in ::SceneEditorFramework.HelperFunctions){
                ::SceneEditorFramework.HelperFunctions.drawIMGUIObjectPropertiesForUserEntry(userId, entry);
            }
        }
    }
};
