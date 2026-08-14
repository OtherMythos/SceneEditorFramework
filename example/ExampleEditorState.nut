//Persistence for the example editor's runtime state. Scene contents remain in
//example.avScene; this writes the way the editor is viewing those contents to a
//JSON sidecar beside avSetup.cfg.
::ExampleEditorState <- class{

    STATE_PATH = "res://.editorState.json";
    STATE_VERSION = 1;
    DOCK_EDGE_EPSILON = 4.0;

    mEditor_ = null;
    mSavedState_ = null;
    mHasSavedState_ = false;
    mLastDisplaySize_ = null;
    mRestoredDockIdsByTitle_ = null;
    mRestoredDockIdsBySavedId_ = null;

    constructor(editor){
        mEditor_ = editor;
    }

    //Load before any viewport is created, since saved ids and gizmo layers are
    //part of the names of its cameras, textures and ImGui windows.
    function load(){
        mSavedState_ = null;
        mHasSavedState_ = false;
        if(!_system.exists(STATE_PATH)) return;

        try{
            local state = _system.readJSONAsTable(STATE_PATH);
            if(typeof state != "table" || !state.rawin("version") ||
                state.rawget("version") != STATE_VERSION){
                printf("Ignoring unsupported editor state at '%s'.", STATE_PATH);
                return;
            }

            mSavedState_ = state;
            mHasSavedState_ = true;
        }catch(error){
            //A hand-edited or interrupted state file must never stop the scene
            //it accompanies from opening.
            printf("Unable to load editor state at '%s': %s", STATE_PATH, error);
        }
    }

    //Null means there is no usable saved list and the editor should create its
    //normal initial viewport. An empty array deliberately restores no windows.
    function getSavedRenderWindows(){
        if(!mHasSavedState_ || !mSavedState_.rawin("renderWindows") ||
            typeof mSavedState_.rawget("renderWindows") != "array") return null;
        return mSavedState_.rawget("renderWindows");
    }

    function setDisplaySize(size){
        mLastDisplaySize_ = size;
    }

    //Panels and the scene tree do not exist when load() runs, so apply their
    //state after the framework has constructed them.
    function apply(){
        if(!mHasSavedState_) return;

        if(mSavedState_.rawin("panels") &&
            typeof mSavedState_.rawget("panels") == "table"){
            local panels = mSavedState_.rawget("panels");
            applyPanel_(mEditor_.mSceneTreePanel_, panels, "sceneTree");
            applyPanel_(mEditor_.mObjectPropertiesPanel_, panels, "objectProperties");
        }

        if(mSavedState_.rawin("sceneTree") &&
            typeof mSavedState_.rawget("sceneTree") == "table"){
            applySceneTree_(mSavedState_.rawget("sceneTree"));
        }

        if(mSavedState_.rawin("focusedRenderWindow")){
            mEditor_.mFocusedRenderWindow_ = mEditor_.findRenderWindowById_(
                mSavedState_.rawget("focusedRenderWindow"));
        }
    }

    function applyPanel_(panel, panels, name){
        if(!panels.rawin(name) || typeof panels.rawget(name) != "table") return;
        local state = panels.rawget(name);
        if(state.rawin("visible")) panel.setVisible(state.rawget("visible"));
        if(state.rawin("window") && typeof state.rawget("window") == "table"){
            panel.applyWindowState(state.rawget("window"));
        }
    }

    function applySceneTree_(savedTree){
        if(savedTree.rawin("expansion")){
            mEditor_.mSceneTreePanel_.applyExpansionState(savedTree.rawget("expansion"));
        }

        local tree = mEditor_.mBase_.getActiveSceneTree();
        if(savedTree.rawin("transformCoordinateType") &&
            typeof savedTree.rawget("transformCoordinateType") == "integer"){
            local coordinateType = savedTree.rawget("transformCoordinateType");
            if(coordinateType == mEditor_.TRANSFORM_POSITION ||
                coordinateType == mEditor_.TRANSFORM_SCALE ||
                coordinateType == mEditor_.TRANSFORM_ORIENTATION ||
                coordinateType == mEditor_.TRANSFORM_RAYCAST){
                tree.setObjectTransformCoordinateType(coordinateType);
            }
        }

        if(!savedTree.rawin("selection") ||
            typeof savedTree.rawget("selection") != "array") return;

        tree.mSelectedIds_.clear();
        foreach(reference in savedTree.rawget("selection")){
            local entryId = resolveSceneEntryReference_(tree, reference);
            if(entryId != null) tree.setSelectedId_(entryId);
        }

        local primary = savedTree.rawin("primarySelection") ?
            resolveSceneEntryReference_(tree, savedTree.rawget("primarySelection")) : null;
        if(primary != null){
            tree.setSelectedId_(primary);
            tree.mMostRecentSelection_ = primary;
            tree.setPrimarySelection_(primary);
        }else{
            tree.mMostRecentSelection_ = null;
            tree.setPrimarySelection_(null);
        }
    }

    function sceneEntryReference_(tree, entryId){
        if(entryId == null) return null;
        local index = tree.findEntryIdIndexInTree_(entryId);
        if(index == null) return null;

        local entry = tree.mEntries_[index];
        return {
            "entryIndex": index,
            "name": ::SceneEditorFramework.getNameForSceneEntry(entry),
            "nodeType": entry.nodeType
        };
    }

    function resolveSceneEntryReference_(tree, reference){
        if(reference == null || typeof reference != "table" ||
            !reference.rawin("entryIndex") ||
            typeof reference.rawget("entryIndex") != "integer") return null;

        local index = reference.rawget("entryIndex");
        if(index < 0 || index >= tree.mEntries_.len()) return null;
        local entry = tree.mEntries_[index];
        if(entry.entryId == null) return null;
        if(reference.rawin("name") && reference.rawget("name") !=
            ::SceneEditorFramework.getNameForSceneEntry(entry)) return null;
        if(reference.rawin("nodeType") && reference.rawget("nodeType") !=
            entry.nodeType) return null;
        return entry.entryId;
    }

    function save(){
        //start() may have failed before the editor was fully constructed.
        if(mEditor_.mBase_ == null || mEditor_.mSceneTreePanel_ == null ||
            mEditor_.mObjectPropertiesPanel_ == null ||
            mEditor_.mRenderWindows_ == null) return;

        local renderWindows = [];
        foreach(window in mEditor_.mRenderWindows_){
            renderWindows.append(window.getState());
        }

        local tree = mEditor_.mBase_.getActiveSceneTree();
        local selection = [];
        foreach(entryId in tree.getSelectedIds()){
            local reference = sceneEntryReference_(tree, entryId);
            if(reference != null) selection.append(reference);
        }
        local primary = tree.mCurrentSelection == -1 ? null :
            sceneEntryReference_(tree, tree.mCurrentSelection);
        local state = {
            "version": STATE_VERSION,
            "renderWindows": renderWindows,
            "focusedRenderWindow": mEditor_.mFocusedRenderWindow_ == null ? null :
                mEditor_.mFocusedRenderWindow_.getId(),
            "panels": {
                "sceneTree": {
                    "visible": mEditor_.mSceneTreePanel_.isVisible(),
                    "window": mEditor_.mSceneTreePanel_.getWindowState()
                },
                "objectProperties": {
                    "visible": mEditor_.mObjectPropertiesPanel_.isVisible(),
                    "window": mEditor_.mObjectPropertiesPanel_.getWindowState()
                }
            },
            "sceneTree": {
                "expansion": mEditor_.mSceneTreePanel_.getExpansionState(),
                "selection": selection,
                "primarySelection": primary,
                "transformCoordinateType": tree.mCurrentObjectTransformCoordinateType_
            },
            "docking": captureDockLayout_(renderWindows)
        };

        try{
            //Six decimal places keeps camera directions smooth while leaving
            //the sidecar readable and stable enough to inspect in a diff.
            _system.writeJsonAsFile(STATE_PATH, state, true, 6);
        }catch(error){
            printf("Unable to save editor state at '%s': %s", STATE_PATH, error);
        }
    }

    //Represent a dock layout as its rectangular leaves and the window titles
    //tabbed into each one. ImGui does not expose its settings blob to Squirrel,
    //but it does expose these facts while every window is drawn; a binary dock
    //tree can be reconstructed from the leaf rectangles on the next run.
    function captureDockLayout_(renderWindowStates){
        local leavesById = {};
        local windowStates = [
            mEditor_.mSceneTreePanel_.getWindowState(),
            mEditor_.mObjectPropertiesPanel_.getWindowState()
        ];
        foreach(state in renderWindowStates) windowStates.append(state.window);

        foreach(window in windowStates){
            if(window == null || typeof window != "table" ||
                !window.rawin("dockId") || window.rawget("dockId") == 0 ||
                !validRectangle_(window)) continue;

            local dockId = window.rawget("dockId");
            local key = dockId.tostring();
            if(!leavesById.rawin(key)){
                leavesById.rawset(key, {
                    "dockId": dockId,
                    "position": window.rawget("position"),
                    "size": window.rawget("size"),
                    "windows": []
                });
            }
            leavesById.rawget(key).windows.append(window.rawget("title"));
        }

        local leaves = [];
        foreach(key, leaf in leavesById) leaves.append(leaf);
        return {
            "displaySize": mLastDisplaySize_,
            "sceneDockId": mEditor_.mSceneDockId_,
            "leaves": leaves
        };
    }

    function validRectangle_(window){
        if(!window.rawin("position") || !window.rawin("size")) return false;
        local position = window.rawget("position");
        local size = window.rawget("size");
        return typeof position == "array" && position.len() >= 2 &&
            typeof size == "array" && size.len() >= 2 && size[0] > 0 && size[1] > 0;
    }

    function buildSavedDockLayout(dockId){
        if(!mHasSavedState_ || !mSavedState_.rawin("docking") ||
            typeof mSavedState_.rawget("docking") != "table") return false;

        local docking = mSavedState_.rawget("docking");
        if(!docking.rawin("leaves") || typeof docking.rawget("leaves") != "array"){
            return false;
        }

        local leaves = [];
        foreach(leaf in docking.rawget("leaves")){
            if(typeof leaf != "table" || !leaf.rawin("windows") ||
                typeof leaf.rawget("windows") != "array" ||
                !validRectangle_(leaf)) continue;
            leaves.append(leaf);
        }
        _imgui.dockBuilderRemoveNode(dockId);
        _imgui.dockBuilderAddNode(dockId, _imgui.DockNodeFlags_DockSpace);
        local size = _imgui.getDisplaySize();
        _imgui.dockBuilderSetNodeSize(dockId, size[0], size[1]);

        mRestoredDockIdsByTitle_ = {};
        mRestoredDockIdsBySavedId_ = {};
        if(leaves.len() > 0) buildSavedDockGroup_(dockId, leaves);
        _imgui.dockBuilderFinish(dockId);

        mEditor_.mSideDockId_ = restoredDockIdForTitle_(
            mEditor_.mSceneTreePanel_.mWindowTitle_, dockId);
        mEditor_.mPropertiesDockId_ = restoredDockIdForTitle_(
            mEditor_.mObjectPropertiesPanel_.mWindowTitle_, dockId);
        mEditor_.mSceneDockId_ = mEditor_.mPropertiesDockId_;
        if(docking.rawin("sceneDockId")){
            local savedSceneDockKey = docking.rawget("sceneDockId").tostring();
            if(mRestoredDockIdsBySavedId_.rawin(savedSceneDockKey)){
                mEditor_.mSceneDockId_ =
                    mRestoredDockIdsBySavedId_.rawget(savedSceneDockKey);
            }
        }
        return true;
    }

    function restoredDockIdForTitle_(title, fallback){
        return mRestoredDockIdsByTitle_.rawin(title) ?
            mRestoredDockIdsByTitle_.rawget(title) : fallback;
    }

    //Turn a slicing floorplan back into a dock-builder tree. Every layout ImGui
    //creates is a binary sequence of horizontal or vertical splits, so one of
    //the saved rectangle edges separates the leaves at each level.
    function buildSavedDockGroup_(dockId, leaves){
        if(leaves.len() <= 1){
            dockSavedWindowsInto_(dockId, leaves);
            return;
        }

        local split = findSavedDockSplit_(leaves);
        if(split == null){
            //Rounded coordinates or a future ImGui layout shape may make the
            //geometry ambiguous. Keeping the windows together as tabs is a
            //safe degradation and still makes all of them reachable.
            dockSavedWindowsInto_(dockId, leaves);
            return;
        }

        local children = _imgui.dockBuilderSplitNode(
            dockId, split.direction, split.ratio);
        buildSavedDockGroup_(children[0], split.first);
        buildSavedDockGroup_(children[1], split.second);
    }

    function dockSavedWindowsInto_(dockId, leaves){
        foreach(leaf in leaves){
            if(leaf.rawin("dockId")){
                mRestoredDockIdsBySavedId_.rawset(
                    leaf.rawget("dockId").tostring(), dockId);
            }
            foreach(title in leaf.rawget("windows")){
                if(typeof title != "string") continue;
                _imgui.dockBuilderDockWindow(title, dockId);
                mRestoredDockIdsByTitle_.rawset(title, dockId);
            }
        }
    }

    function findSavedDockSplit_(leaves){
        local bounds = dockBounds_(leaves);
        for(local axis = 0; axis < 2; axis++){
            foreach(leaf in leaves){
                local position = leaf.rawget("position");
                local size = leaf.rawget("size");
                local candidates = [position[axis], position[axis] + size[axis]];
                foreach(edge in candidates){
                    if(edge <= bounds[axis] + DOCK_EDGE_EPSILON ||
                        edge >= bounds[axis + 2] - DOCK_EDGE_EPSILON) continue;

                    local first = [];
                    local second = [];
                    local valid = true;
                    foreach(candidate in leaves){
                        local candidatePosition = candidate.rawget("position");
                        local candidateSize = candidate.rawget("size");
                        local start = candidatePosition[axis];
                        local finish = start + candidateSize[axis];
                        local centre = (start + finish) * 0.5;

                        if(centre < edge){
                            if(finish > edge + DOCK_EDGE_EPSILON){
                                valid = false;
                                break;
                            }
                            first.append(candidate);
                        }else{
                            if(start < edge - DOCK_EDGE_EPSILON){
                                valid = false;
                                break;
                            }
                            second.append(candidate);
                        }
                    }

                    if(!valid || first.len() == 0 || second.len() == 0) continue;
                    local span = bounds[axis + 2] - bounds[axis];
                    if(span <= 0) continue;
                    local ratio = (edge - bounds[axis]) / span;
                    if(ratio <= 0.02 || ratio >= 0.98) continue;

                    return {
                        "direction": axis == 0 ? _imgui.Dir_Left : _imgui.Dir_Up,
                        "ratio": ratio,
                        "first": first,
                        "second": second
                    };
                }
            }
        }
        return null;
    }

    //As [min x, min y, max x, max y].
    function dockBounds_(leaves){
        local firstPosition = leaves[0].rawget("position");
        local firstSize = leaves[0].rawget("size");
        local bounds = [
            firstPosition[0], firstPosition[1],
            firstPosition[0] + firstSize[0], firstPosition[1] + firstSize[1]
        ];

        foreach(leaf in leaves){
            local position = leaf.rawget("position");
            local size = leaf.rawget("size");
            if(position[0] < bounds[0]) bounds[0] = position[0];
            if(position[1] < bounds[1]) bounds[1] = position[1];
            if(position[0] + size[0] > bounds[2]) bounds[2] = position[0] + size[0];
            if(position[1] + size[1] > bounds[3]) bounds[3] = position[1] + size[1];
        }
        return bounds;
    }
};
