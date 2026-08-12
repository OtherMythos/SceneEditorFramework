::SceneEditorFramework.IMGUI.ObjectProperties <- class extends ::SceneEditorFramework.IMGUI.Panel{

    mWindowTitle_ = "Object Properties##SceneEditorFrameworkObjectProperties";
    mEditStates_ = null;

    constructor(baseObj, bus){
        base.constructor(baseObj, bus);
        mEditStates_ = {};
    }

    function draw(){
        if(!mVisible_) return;

        local shown = _imgui.begin(mWindowTitle_);
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
        _imgui.text(::SceneEditorFramework.getNameForSceneEntry(entry));
        _imgui.separator();

        drawVectorControl_("Position", entry, SceneEditorFramework_BasicCoordinateType.POSITION, Vec3());
        drawVectorControl_("Scale", entry, SceneEditorFramework_BasicCoordinateType.SCALE, Vec3(1, 1, 1));
        drawQuatControl_("Orientation", entry);

        drawEntryData_(entry);
    }

    function drawVectorControl_(label, entry, coordinateType, resetValue){
        local value = coordinateType == SceneEditorFramework_BasicCoordinateType.POSITION ? entry.position : entry.scale;
        local result = ::SceneEditorFramework.IMGUI.Widgets.drawVector3(label, value);
        processEdit_(coordinateType, entry, result);

        if(!vectorEquals_(value, resetValue)){
            _imgui.sameLine();
            if(_imgui.smallButton("Reset##" + label)){
                performAndPushAction_(coordinateType, entry.entryId, value, resetValue);
            }
        }
    }

    function drawQuatControl_(label, entry){
        local result = ::SceneEditorFramework.IMGUI.Widgets.drawQuat(label, entry.orientation);
        processEdit_(SceneEditorFramework_BasicCoordinateType.ORIENTATION, entry, result);

        if(!quatEquals_(entry.orientation, Quat())){
            _imgui.sameLine();
            if(_imgui.smallButton("Reset##" + label)){
                performAndPushAction_(SceneEditorFramework_BasicCoordinateType.ORIENTATION, entry.entryId, entry.orientation, Quat());
            }
        }
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
            ::SceneEditorFramework.IMGUI.ObjectPropertyEntryMesh.draw(entry);
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
