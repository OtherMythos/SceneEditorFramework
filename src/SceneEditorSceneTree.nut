::SceneEditorFramework.SceneTree <- class{

    mEntries_ = null;
    mParentNode_ = null;
    mBus_ = null;
    mActionStack_ = null;
    mMoveHandles_ = null;
    mOutlineBox_ = null;
    mCurrentPopulateAction_ = null;
    mCurrentObjectTransformCoordinateType_ = null;
    mNodesForEntry_ = null;
    mSceneRootNode_ = null;
    mMagneticEdit_ = false;

    //Entry ids are keys so selection membership remains independent of tree
    //position. Public helpers return ids in tree order, which is what later
    //tree rearrangement actions need.
    mSelectedIds_ = null;
    mMostRecentSelection_ = null;

    mCurrentSelection = -1;
    mCurrentSelectionIdx = -1;
    mCurrentSelectionDeferred = null;

    mIdPool_ = null;

    IdPool = class{

        mIdPool_ = null;
        mCount_ = 0;

        constructor(){
            mIdPool_ = [];
        }

        function getId(){
            if(mIdPool_.len() > 0){
                local id = mIdPool_.top();
                mIdPool_.pop();
                return id;
            }

            return mCount_++;
        }

        function recycleId(id){
            mIdPool_.append(id);
        }

        function reserveId(id){
            foreach(index, pooledId in mIdPool_){
                if(pooledId != id) continue;
                mIdPool_.remove(index);
                return;
            }
            assert(false);
        }

    };

    constructor(parentNode, actionStack, bus){
        mEntries_ = [];
        mParentNode_ = parentNode;
        mActionStack_ = actionStack;
        mBus_ = bus;
        mNodesForEntry_ = {};
        mIdPool_ = IdPool();
        mSelectedIds_ = {};

        bus.subscribeObject(this);

        setObjectTransformCoordinateType(SceneEditorFramework_BasicCoordinateType.POSITION);
        mOutlineBox_ = ::SceneEditorFramework.SceneEditorGizmoOutlineBox(mParentNode_, mBus_);
        mMoveHandles_.setVisible(false);
    }

    function shutdown(){
        mParentNode_.destroyNodeAndChildren();
        mParentNode_ = null;
        mEntries_.clear();
    }

    function update(){
        //TODO move out.
        //Also what notices a viewport being opened or closed, since that is a
        //copy of the gizmo appearing or going away.
        mMoveHandles_.update();

        if(mCurrentSelectionDeferred == -1){
            setCurrentSelection(null);
        }else if(mCurrentSelectionDeferred != null){
            local idx = findEntryIdIndexInTree_(mCurrentSelectionDeferred);
            setCurrentSelection(mCurrentSelectionDeferred);
        }
        mCurrentSelectionDeferred = null;

        //After the selection above, so a gizmo which has just been put on
        //another object is sized for where it now is.
        mMoveHandles_.updateScales();
    }

    function getId(){
        return mIdPool_.getId();
    }
    function recycleId(id){
        return mIdPool_.recycleId(id);
    }
    function reserveId(id){
        return mIdPool_.reserveId(id);
    }

    function sceneTreePopulated(){
        return mEntries_.len() > 2;
    }

    function setMagneticEdit(magnetic){
        mMagneticEdit_ = magnetic;
    }

    function setObjectTransformCoordinateType(coordType){
        if(mCurrentObjectTransformCoordinateType_ == coordType){
            return;
        }

        if(mMoveHandles_ != null) mMoveHandles_.shutdown();
        mCurrentObjectTransformCoordinateType_ = coordType;
        mMoveHandles_ = ::SceneEditorFramework.SceneEditorGizmoLayers(mParentNode_, mCurrentObjectTransformCoordinateType_, mBus_);
        if(mCurrentSelection != -1){
            positionTransformGizmo_();
        }
    }

    function debugPrintGetPadding_(indent){
        local out = "";
        for(local i = 0; i < indent; i++) out += "    ";
        return out;
    }
    function debugPrint(){
        local indent = 0;
        local indentString = "";
        foreach(c,i in mEntries_){
            if(i.nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
                indent++;
                indentString = debugPrintGetPadding_(indent);
            }
            if(i.nodeType == SceneEditorFramework_SceneTreeEntryType.TERM){
                indent--;
                assert(indent >= 0);
                indentString = debugPrintGetPadding_(indent);
            }
            printf("%s %s", indentString, ::SceneEditorFramework.getStringValueForSceneEntryType(i.nodeType));
        }
    }

    function setEntries(entries){
        mEntries_ = entries;
        mSelectedIds_.clear();
        mMostRecentSelection_ = null;

        constructSceneTree_();
    }

    function constructSceneTree_(){
        local currentNode = [mParentNode_];
        local lastNode = null;
        for(local i = 0; i < mEntries_.len(); i++){
            local c = mEntries_[i];
            if(c.nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
                if(lastNode == null){
                    assert(i == 0);
                    lastNode = mParentNode_.createChildSceneNode();
                    mSceneRootNode_ = lastNode;
                }
                currentNode.append(lastNode);
                //currentNode = lastNode;
                continue;
            }
            else if(c.nodeType == SceneEditorFramework_SceneTreeEntryType.TERM){
                assert(currentNode.len() > 0);
                currentNode.pop();
                continue;
            }

            lastNode = constructObjectForEntry(c, currentNode.top());
            assert(!mNodesForEntry_.rawin(lastNode.getId()));
            mNodesForEntry_.rawset(lastNode.getId(), c.entryId);
            c.node = lastNode;
        }
        assert(currentNode.len() == 1);
    }

    //The engine's Squirrel scene-node API has no reparent operation. Rebuild
    //the framework-owned root after a hierarchy change so every entry node is
    //created under the parent described by the flattened tree. Gizmos are
    //siblings of this root and are therefore left intact.
    function rebuildSceneTree_(){
        foreach(entry in mEntries_){
            if(isObjectEntry_(entry)) entry.node = null;
        }
        mNodesForEntry_.clear();

        if(mSceneRootNode_ != null){
            mSceneRootNode_.destroyNodeAndChildren();
            mSceneRootNode_ = null;
        }

        constructSceneTree_();
    }
    function regenerateSceneEntry(entryId){
        local idx = findEntryIdIndexInTree_(entryId);
        local e = mEntries_[idx];
        if(e.node != null){
            local parent = e.node.getParent();
            e.node.destroyNodeAndChildren();
            e.node = constructObjectForEntry(e, parent);

            mNodesForEntry_.rawset(e.node.getId(), e.entryId);
        }
    }
    function constructObjectForEntry(entry, parent){
        local newNode = parent.createChildSceneNode();
        local nodeType = entry.nodeType;
        local entryData = entry.data;
        if(nodeType == SceneEditorFramework_SceneTreeEntryType.MESH){
            local item = _scene.createItem(entryData.meshName);

            item.setRenderQueueGroup(SceneEditorFramework_RenderQueue.SCENE);
            item.setQueryFlags(SceneEditorFramework_QueryFlag.SCENE_OBJECT);
            newNode.attachObject(item);
        }
        else if(nodeType == SceneEditorFramework_SceneTreeEntryType.USER0){
            ::SceneEditorFramework.HelperFunctions.sceneTreeConstructObjectForUserEntry(0, newNode, entryData);
        }
        else if(nodeType == SceneEditorFramework_SceneTreeEntryType.USER1){
            ::SceneEditorFramework.HelperFunctions.sceneTreeConstructObjectForUserEntry(1, newNode, entryData);
        }
        else if(nodeType == SceneEditorFramework_SceneTreeEntryType.USER2){
            ::SceneEditorFramework.HelperFunctions.sceneTreeConstructObjectForUserEntry(2, newNode, entryData);
        }
        else if(nodeType == SceneEditorFramework_SceneTreeEntryType.USER3){
            ::SceneEditorFramework.HelperFunctions.sceneTreeConstructObjectForUserEntry(3, newNode, entryData);
        }

        newNode.setPosition(entry.position);
        newNode.setScale(entry.scale);
        newNode.setOrientation(entry.orientation);
        newNode.setVisible(entry.visible);

        return newNode;
    }

    function determineAABB(){
        local aabb = AABB(Vec3(), Vec3());
        foreach(c,i in mEntries_){
            if(
                i.nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD ||
                i.nodeType == SceneEditorFramework_SceneTreeEntryType.TERM
            ){
                continue;
            }

            if(i.node.getNumAttachedObjects() <= 0){
                continue;
            }
            local box = i.node.getAttachedObject(0).getWorldAabb();
            aabb.merge(box);
        }

        return aabb;
    }

    //Set exactly one selected entry. Call notifySelectionChanged for the
    //modifier-aware behavior used by scene-tree rows.
    function setCurrentSelection(entryId){
        mSelectedIds_.clear();
        mMostRecentSelection_ = entryId;
        if(entryId != null) mSelectedIds_.rawset(entryId, true);
        setPrimarySelection_(entryId);
    }

    //The primary selection is the most recently clicked entry. Existing gizmo
    //and properties code continues to act on it while mSelectedIds_ represents
    //the complete selection.
    function setPrimarySelection_(entryId){
        if(mEntries_ == null) return;
        local newSelection = null;
        local newIdx = null;
        if(entryId != null){
            local idx = findEntryIdIndexInTree_(entryId);
            local e = mEntries_[idx];
            assert(e.nodeType != SceneEditorFramework_SceneTreeEntryType.CHILD && e.nodeType != SceneEditorFramework_SceneTreeEntryType.TERM);
            mCurrentSelectionIdx = idx;
            mCurrentSelection = entryId;
            newSelection = e;
            newIdx = idx;

            positionTransformGizmo_();
        }else{
            mCurrentSelection = -1;
            mCurrentSelectionIdx = -1;
            mMoveHandles_.setVisible(false);
        }

        setOutlineBox(entryId);

        local data = null;
        if(newSelection != null){
            data = {
                "idx": newIdx,
                "entry": newSelection,
                "selectedIds": getSelectedIds(),
                "selectionCount": getSelectedCount()
            };
        }
        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SCENE_TREE_SELECTION_CHANGED, data);
    }

    function isEntrySelected(entryId){
        return mSelectedIds_.rawin(entryId);
    }

    function getSelectedCount(){
        return mSelectedIds_.len();
    }

    //Return a copy so actions can retain the selection they were created for.
    function getSelectedIds(){
        local result = [];
        foreach(entry in mEntries_){
            if(entry.entryId != null && isEntrySelected(entry.entryId)){
                result.append(entry.entryId);
            }
        }
        return result;
    }

    function getFirstSelection(){
        local selected = getSelectedIds();
        return selected.len() == 0 ? -1 : selected[0];
    }

    function clearAllSelection(){
        setCurrentSelection(null);
    }

    function setSingleSelection(entryId){
        setCurrentSelection(entryId);
    }

    function setSelectionById(entryId){
        if(findEntryIdIndexInTree_(entryId) == null) return;
        setCurrentSelection(entryId);
    }

    //For setup/restoration callers which need to build a selection before one
    //selection-changed notification is sent.
    function setSelectedId_(entryId){
        if(findEntryIdIndexInTree_(entryId) == null) return;
        mSelectedIds_.rawset(entryId, true);
    }

    function selectAll(){
        mSelectedIds_.clear();
        foreach(entry in mEntries_){
            if(isObjectEntry_(entry)) mSelectedIds_.rawset(entry.entryId, true);
        }

        local first = getFirstSelection();
        mMostRecentSelection_ = first == -1 ? null : first;
        setPrimarySelection_(mMostRecentSelection_);
    }

    //Selecting a parent already encompasses its descendants for deletion and
    //rearrangement, so remove those descendants from the actionable selection.
    function getReducedSelection(){
        local result = [];
        foreach(entryId in getSelectedIds()){
            local index = findEntryIdIndexInTree_(entryId);
            if(!isParentSelected_(index)) result.append(entryId);
        }
        return result;
    }

    function isParentSelected_(entryIndex){
        local parentIndex = getIndexOfParentForEntry_(entryIndex);
        while(parentIndex != null){
            if(isEntrySelected(mEntries_[parentIndex].entryId)) return true;
            parentIndex = getIndexOfParentForEntry_(parentIndex);
        }
        return false;
    }

    function isObjectEntry_(entry){
        return entry.nodeType != SceneEditorFramework_SceneTreeEntryType.CHILD &&
            entry.nodeType != SceneEditorFramework_SceneTreeEntryType.TERM;
    }

    /** Add an empty scene node as a child of an existing entry. */
    function insertEmptyChild(parentId, name="Empty"){
        return insertEntry_(parentId, SceneEditorFramework_ObjectInsertionType.INTO,
            SceneEditorFramework_SceneTreeEntryType.EMPTY, null, name);
    }

    /** Add one of the engine's built-in primitive meshes as a child. */
    function insertPrimitiveMeshChild(parentId, meshName, name=null){
        local data = ::SceneEditorFramework.SceneTreeMeshData();
        data.meshName = meshName;
        if(name == null) name = meshName;

        return insertEntry_(parentId, SceneEditorFramework_ObjectInsertionType.INTO,
            SceneEditorFramework_SceneTreeEntryType.MESH, data, name);
    }

    /**
     * Insert a new object relative to a target through the action stack.
     * This is kept generic so editor-specific USER entries can use the same
     * hierarchy and undo behavior as the framework's built-in entries.
     */
    function insertEntry(targetId, insertionType, nodeType, data=null, name=null){
        return insertEntry_(targetId, insertionType, nodeType, data, name);
    }

    function insertEntry_(targetId, insertionType, nodeType, data, name){
        if(
            nodeType == SceneEditorFramework_SceneTreeEntryType.NONE ||
            nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD ||
            nodeType == SceneEditorFramework_SceneTreeEntryType.TERM
        ) return null;

        local targetIndex = findEntryIdIndexInTree_(targetId);
        if(targetIndex == null || !isObjectEntry_(mEntries_[targetIndex])) return null;
        if(
            insertionType != SceneEditorFramework_ObjectInsertionType.INTO &&
            insertionType != SceneEditorFramework_ObjectInsertionType.ABOVE &&
            insertionType != SceneEditorFramework_ObjectInsertionType.BELOW
        ) return null;

        local entry = ::SceneEditorFramework.SceneTreeEntry();
        entry.reset();
        entry.entryId = getId();
        entry.nodeType = nodeType;
        entry.data = data;
        entry.name = name;

        local insertedEntries = buildEntriesWithInsertion_(targetIndex, insertionType, entry);
        local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.OBJECT_INSERTION];
        local action = A(this, mEntries_, insertedEntries, entry.entryId);
        mActionStack_.pushAction_(action);
        action.performAction();
        return entry.entryId;
    }

    function buildEntriesWithInsertion_(targetIndex, insertionType, entry){
        local insertIndex = targetIndex;
        local inserted = [entry];

        if(insertionType == SceneEditorFramework_ObjectInsertionType.BELOW){
            insertIndex = getEntrySectionEndInEntries_(mEntries_, targetIndex);
        }else if(insertionType == SceneEditorFramework_ObjectInsertionType.INTO){
            if(entryHasChildrenInEntries_(mEntries_, targetIndex)){
                insertIndex = getTerminatorForChildInEntries_(mEntries_, targetIndex + 1) - 1;
            }else{
                inserted = [::SceneEditorFramework.FileParser.CHILD_ENTRY, entry,
                    ::SceneEditorFramework.FileParser.TERM_ENTRY];
                insertIndex = targetIndex + 1;
            }
        }

        return insertEntriesAt_(mEntries_, insertIndex, inserted);
    }

    /**
     * Move the reduced current selection relative to one destination entry.
     * Returns false for a destination inside the moved subtree or a no-op.
     */
    function rearrangeCurrentSelection(destinationId, insertionType){
        local selected = getReducedSelection();
        if(selected.len() == 0) return false;

        local rearranged = buildRearrangedEntries_(selected, destinationId, insertionType);
        if(rearranged == null) return false;

        local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.TREE_REARRANGE];
        local action = A(this, mEntries_, rearranged);
        mActionStack_.pushAction_(action);
        action.performAction();
        return true;
    }

    function canRearrangeCurrentSelection(destinationId, insertionType){
        local selected = getReducedSelection();
        return selected.len() > 0 &&
            buildRearrangedEntries_(selected, destinationId, insertionType) != null;
    }

    //Build the result without changing the live tree. This makes validation
    //side-effect free and gives TreeRearrangeAction stable before/after states.
    function buildRearrangedEntries_(selectedIds, destinationId, insertionType){
        if(
            insertionType != SceneEditorFramework_ObjectInsertionType.INTO &&
            insertionType != SceneEditorFramework_ObjectInsertionType.ABOVE &&
            insertionType != SceneEditorFramework_ObjectInsertionType.BELOW
        ) return null;

        local destinationIndex = findEntryIdIndexInTree_(destinationId);
        if(destinationIndex == null || !isObjectEntry_(mEntries_[destinationIndex])) return null;

        local rangesByStart = {};
        foreach(entryId in selectedIds){
            local startIndex = findEntryIdIndexInTree_(entryId);
            if(startIndex == null) return null;
            local endIndex = getEntrySectionEndInEntries_(mEntries_, startIndex);
            if(destinationIndex >= startIndex && destinationIndex < endIndex) return null;

            local range = { "start": startIndex, "end": endIndex };
            rangesByStart.rawset(startIndex, range);
        }

        local moved = [];
        local remaining = [];
        local index = 0;
        while(index < mEntries_.len()){
            if(rangesByStart.rawin(index)){
                local range = rangesByStart.rawget(index);
                for(local i = range.start; i < range.end; i++) moved.append(mEntries_[i]);
                index = range.end;
            }else{
                remaining.append(mEntries_[index]);
                index++;
            }
        }

        removeEmptyChildGroups_(remaining);
        destinationIndex = findEntryIdIndexInEntries_(remaining, destinationId);
        if(destinationIndex == null) return null;

        local insertIndex = destinationIndex;
        local inserted = moved;
        if(insertionType == SceneEditorFramework_ObjectInsertionType.BELOW){
            insertIndex = getEntrySectionEndInEntries_(remaining, destinationIndex);
        }else if(insertionType == SceneEditorFramework_ObjectInsertionType.INTO){
            if(entryHasChildrenInEntries_(remaining, destinationIndex)){
                insertIndex = getTerminatorForChildInEntries_(remaining, destinationIndex + 1) - 1;
            }else{
                inserted = [::SceneEditorFramework.FileParser.CHILD_ENTRY];
                foreach(entry in moved) inserted.append(entry);
                inserted.append(::SceneEditorFramework.FileParser.TERM_ENTRY);
                insertIndex = destinationIndex + 1;
            }
        }

        local result = insertEntriesAt_(remaining, insertIndex, inserted);
        return entryLayoutsEqual_(mEntries_, result) ? null : result;
    }

    function applyRearrangedEntries_(entries){
        mEntries_ = clone entries;
        rebuildSceneTree_();
        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SCENE_TREE_CONTENTS_CHANGED, null);

        if(mCurrentSelection != -1 && findEntryIdIndexInTree_(mCurrentSelection) != null){
            setPrimarySelection_(mCurrentSelection);
        }else{
            clearAllSelection();
        }
    }

    function getEntrySectionEndInEntries_(entries, startIndex){
        if(entryHasChildrenInEntries_(entries, startIndex)){
            return getTerminatorForChildInEntries_(entries, startIndex + 1);
        }
        return startIndex + 1;
    }

    function entryHasChildrenInEntries_(entries, index){
        return index + 1 < entries.len() &&
            entries[index + 1].nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD;
    }

    function getTerminatorForChildInEntries_(entries, childIndex){
        if(entries[childIndex].nodeType != SceneEditorFramework_SceneTreeEntryType.CHILD) return -1;

        local depth = 0;
        for(local index = childIndex + 1; index < entries.len(); index++){
            local type = entries[index].nodeType;
            if(type == SceneEditorFramework_SceneTreeEntryType.CHILD){
                depth++;
            }else if(type == SceneEditorFramework_SceneTreeEntryType.TERM){
                if(depth == 0) return index + 1;
                depth--;
            }
        }
        return -1;
    }

    function removeEmptyChildGroups_(entries){
        local index = 1; //Index zero is the root CHILD marker and must remain.
        while(index < entries.len() - 1){
            if(
                entries[index].nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD &&
                entries[index + 1].nodeType == SceneEditorFramework_SceneTreeEntryType.TERM
            ){
                entries.remove(index);
                entries.remove(index);
                if(index > 1) index--;
            }else{
                index++;
            }
        }
    }

    function findEntryIdIndexInEntries_(entries, entryId){
        foreach(index, entry in entries){
            if(entry.entryId == entryId) return index;
        }
        return null;
    }

    function insertEntriesAt_(entries, insertIndex, inserted){
        local result = [];
        for(local index = 0; index <= entries.len(); index++){
            if(index == insertIndex){
                foreach(entry in inserted) result.append(entry);
            }
            if(index < entries.len()) result.append(entries[index]);
        }
        return result;
    }

    function entryLayoutsEqual_(first, second){
        if(first.len() != second.len()) return false;
        for(local index = 0; index < first.len(); index++){
            if(first[index].nodeType != second[index].nodeType) return false;
            if(first[index].entryId != second[index].entryId) return false;
        }
        return true;
    }

    function setOutlineBox(entryId){
        if(mEntries_ == null || entryId == null){
            mOutlineBox_.setVisible(false);
            return;
        }
        local node = mEntries_[mCurrentSelectionIdx].node;
        local num = node.getNumAttachedObjects();
        if(num == 0){
            mOutlineBox_.setVisible(false);
            return;
        }

        local aabb = node.getAttachedObject(0).getWorldAabbUpdated();
        local centre = aabb.getCentre();
        local halfSize = aabb.getHalfSize();
        mOutlineBox_.setPosition(centre);
        mOutlineBox_.setScale(halfSize);
        mOutlineBox_.setVisible(true);
    }

    function positionTransformGizmo_(){
        mMoveHandles_.setVisible(true);
        local targetPos = mEntries_[mCurrentSelectionIdx].node.getDerivedPositionVec3();
        mMoveHandles_.setPosition(targetPos);
    }

    function getIndexOfParentForEntry_(index){
        local parent = getParentChildIndexForEntry_(index) - 1;
        return parent <= 0 ? null : parent;
    }
    function getParentChildIndexForEntry_(index){
        local itIndex = index;

        local childCount = 0;
        do{
            local entry = mEntries_[itIndex];
            if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.TERM) childCount++;
            if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
                if(childCount == 0){
                    return itIndex;
                }
                childCount--;
            }

            itIndex--;
        }while(itIndex != 0);

        //If we're at index 0 and child count 0 then the root node was found as the parent.
        if(childCount == 0){
            return 0;
        }

        //Nothing was found, and this most likely means a malformed scene tree.
        return -1;
    }

    function setSelectedNodeScale(scale){
        if(mCurrentSelectionIdx == -1){
            return;
        }

        local e = mEntries_[mCurrentSelectionIdx];
        e.setScale(scale);

        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE, e);
    }

    function getPositionWithMagnet(position){

        if(mMagneticEdit_){
            local p = position.copy();
            p.x = ceil(p.x);
            p.y = ceil(p.y);
            p.z = ceil(p.z);

            return p;
        }

        return position;
    }

    function setSelectedNodePosition(position){
        if(mCurrentSelectionIdx == -1){
            return;
        }

        local p = getPositionWithMagnet(position);
        local e = mEntries_[mCurrentSelectionIdx];
        e.setPosition(p, true);
        mMoveHandles_.positionGizmo(p);

        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE, e);
    }

    function positionMoveHandles(){
        local e = mEntries_[mCurrentSelectionIdx];
        local derived = e.getPositionDerived();

        mMoveHandles_.positionGizmo(derived);
    }

    function notifyBusEvent(event, data){
        if(event == SceneEditorFramework_BusEvents.SELECTED_POSITION_CHANGE){
            assert(mCurrentPopulateAction_ != null);
            setSelectedNodePosition(data);
            setOutlineBox(mCurrentSelectionIdx);
        }
        else if(event == SceneEditorFramework_BusEvents.SELECTED_SCALE_CHANGE){
            assert(mCurrentPopulateAction_ != null);
            setSelectedNodeScale(mCurrentPopulateAction_.mOld_ - data*0.2);
            setOutlineBox(mCurrentSelectionIdx);
        }
        else if(event == SceneEditorFramework_BusEvents.HANDLES_GIZMO_INTERACTION_BEGAN){
            local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.BASIC_COORDINATES_CHANGE];
            mCurrentPopulateAction_ = A(this, mBus_, mCurrentSelection, getValueForObjectCoordsChange_(data), null, data, false);
        }
        else if(event == SceneEditorFramework_BusEvents.HANDLES_GIZMO_INTERACTION_ENDED){
            mCurrentPopulateAction_.mNew_ = getValueForObjectCoordsChange_(data);

            mActionStack_.pushAction_(mCurrentPopulateAction_);
        }
        else if(event == SceneEditorFramework_BusEvents.OBJECT_POSITION_CHANGE){
            positionMoveHandles();
            setOutlineBox(mCurrentSelectionIdx);
            if(data.id == mCurrentSelection){
                mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE, mEntries_[mCurrentSelectionIdx]);
            }
        }
        else if(event == SceneEditorFramework_BusEvents.OBJECT_SCALE_CHANGE){
            if(data.id == mCurrentSelection){
                mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE, mEntries_[mCurrentSelectionIdx]);
                setOutlineBox(mCurrentSelectionIdx);
            }
        }
        else if(event == SceneEditorFramework_BusEvents.OBJECT_ORIENTATION_CHANGE){
            setOutlineBox(mCurrentSelectionIdx);
            if(data.id == mCurrentSelection){
                mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE, mEntries_[mCurrentSelectionIdx]);
            }
        }
    }
    function getValueForObjectCoordsChange_(coordsType){
        local endValue = null;
        local e = mEntries_[mCurrentSelectionIdx];
        if(coordsType == SceneEditorFramework_BasicCoordinateType.POSITION){
            endValue = e.position.copy();
        }
        else if(coordsType == SceneEditorFramework_BasicCoordinateType.SCALE){
            endValue = e.scale.copy();
        }
        else if(coordsType == SceneEditorFramework_BasicCoordinateType.ORIENTATION){
            endValue = e.orientation.copy();
        }else{
            assert(false);
        }
        return endValue;
    }

    function deleteCurrentSelection(){
        local selected = getReducedSelection();
        assert(selected.len() > 0);

        local action = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.OBJECT_DELETION](this, mBus_, selected);
        mActionStack_.pushAction_(action);
        action.performAction();

        //The entry the selection named has just been removed from the tree, so
        //the selection cannot keep naming it.
        setCurrentSelection(null);
    }

    function renameCurrentSelection(newName){
        assert(mCurrentSelectionIdx != -1);

        renameEntry(mCurrentSelection, newName);
    }

    /**
     * Rename one entry without requiring the caller to change selection first.
     * This is what allows an inline tree editor to commit the name it is
     * editing, while keeping the action stack and undo behaviour consistent
     * with the context-menu rename.
     */
    function renameEntry(entryId, newName){
        local idx = findEntryIdIndexInTree_(entryId);
        assert(idx != null);

        local entry = mEntries_[idx];
        local oldVal = entry.name;
        if(oldVal == null){
            oldVal = ::SceneEditorFramework.getNameForSceneEntry(entry);
        }

        local action = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.RENAME_SCENE_NODE](this, mBus_, entryId, oldVal, newName);
        mActionStack_.pushAction_(action);
        action.performAction();
    }

    /** Set an entry's scene-node visibility through an undoable action. */
    function setEntryVisibility(entryId, visible){
        local idx = findEntryIdIndexInTree_(entryId);
        assert(idx != null);

        local entry = mEntries_[idx];
        if(entry.visible == visible) return;

        local action = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.CHANGE_SCENE_NODE_VISIBILITY](this, mBus_, entryId, entry.visible, visible);
        mActionStack_.pushAction_(action);
        action.performAction();
    }

    //Called by ChangeSceneNodeVisibilityAction. Keeping the engine-node write
    //here makes visibility work for every caller, not only the imgui panel.
    function setEntryVisibility_(entryId, visible){
        local idx = findEntryIdIndexInTree_(entryId);
        assert(idx != null);

        local entry = mEntries_[idx];
        entry.visible = visible;
        entry.node.setVisible(visible);

        if(mCurrentSelection == entryId){
            if(visible){
                positionTransformGizmo_();
                setOutlineBox(entryId);
            }else{
                mMoveHandles_.setVisible(false);
                mOutlineBox_.setVisible(false);
            }
        }

        mBus_.transmitEvent(SceneEditorFramework_BusEvents.OBJECT_VISIBILITY_CHANGE, {
            "id": entryId,
            "visible": visible
        });
    }

    function deleteObjectFromTree_(id){
        local idx = findEntryIdIndexInTree_(id);
        assert(idx != null);
        recursiveDeleteInTree_(idx);
    }

    function recursiveDeleteInTree_(idx){
        assert(isObjectEntry_(mEntries_[idx]));

        local endIndex = getEntrySectionEndInEntries_(mEntries_, idx);
        local removedEntries = [];
        for(local i = idx; i < endIndex; i++){
            local entry = mEntries_[i];
            if(!isObjectEntry_(entry)) continue;

            removedEntries.append({
                "entry": entry,
                "nodeId": entry.node == null ? null : entry.node.getId()
            });
        }

        //Destroying the subtree root also destroys all descendant nodes. Keep
        //their entry data long enough to clean the lookup and ID pool safely.
        mEntries_[idx].destroy();
        foreach(removed in removedEntries){
            if(removed.nodeId != null && mNodesForEntry_.rawin(removed.nodeId)){
                mNodesForEntry_.rawdelete(removed.nodeId);
            }
            removed.entry.node = null;
            recycleId(removed.entry.entryId);
        }

        //Squirrel arrays have no range erase, so repeatedly remove at the
        //fixed start index while the remaining entries shift down.
        for(local i = idx; i < endIndex; i++) mEntries_.remove(idx);
        removeEmptyChildGroups_(mEntries_);

        return removedEntries.len();
    }

    function getTerminatorForChild(idx){
        if(mEntries_[idx].nodeType != SceneEditorFramework_SceneTreeEntryType.CHILD) return -1;

        //A counter of how many child values have been encountered.
        local childIndex = 0;

        local countIndex = idx + 1; //+1 should be child, so we start from +1 of that.
        while(countIndex < mEntries_.len()){
            local current = mEntries_[countIndex];

            if(current.nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD) childIndex++;
            if(current.nodeType == SceneEditorFramework_SceneTreeEntryType.TERM){
                if(childIndex == 0){
                    //This is the terminator for the provided entry.
                    return countIndex + 1;
                }

                childIndex--;
            }

            countIndex++;
        }

        return -1;
    }

    function itemHasChildren_(idx){
        local targetIdx = idx + 1;
        if(targetIdx >= mEntries_.len()) return false;

        return (mEntries_[targetIdx].nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD);
    }

    function findEntryIdIndexInTree_(id){
        foreach(c,i in mEntries_){
            if(i.entryId == id) return c;
        }

        return null;
    }

    function notifySelectionChanged(buttonId, controlModifier=false, shiftModifier=false){
        if(buttonId == null){
            clearAllSelection();
            return;
        }

        local entryIndex = findEntryIdIndexInTree_(buttonId);
        assert(entryIndex != null);
        assert(isObjectEntry_(mEntries_[entryIndex]));

        //Clicking an already-selected item keeps the rest of
        //the selection intact so beginning a drag does not collapse the group.
        if(!controlModifier && !shiftModifier && !isEntrySelected(buttonId)){
            mSelectedIds_.clear();
        }

        if(shiftModifier && mMostRecentSelection_ != null){
            local anchorIndex = findEntryIdIndexInTree_(mMostRecentSelection_);
            if(anchorIndex != null){
                local startIndex = entryIndex < anchorIndex ? entryIndex : anchorIndex;
                local endIndex = entryIndex < anchorIndex ? anchorIndex : entryIndex;
                for(local i = startIndex; i <= endIndex; i++){
                    local entry = mEntries_[i];
                    if(isObjectEntry_(entry)) mSelectedIds_.rawset(entry.entryId, true);
                }
            }
        }

        mSelectedIds_.rawset(buttonId, true);
        mMostRecentSelection_ = buttonId;
        setPrimarySelection_(buttonId);
    }

    function getEntryForId(id){
        return mEntries_[findEntryIdIndexInTree_(id)];
    }

    /**
     * Which entry, if any, sits under a position in the scene viewport.
     *
     * The framework picks objects itself for the left mouse button. This exists
     * for everything else a project might want to do with the object under the
     * cursor - a context menu, say - without it having to know how entries are
     * mapped to scene nodes.
     *
     * Ray queries need a clean scene, so call this from sceneSafeUpdate().
     *
     * @param mousePos Position within the scene viewport in the 0-1 range, as
     * ::SceneEditorFramework.getNormalisedSceneMousePosition() returns. Null when
     * there is no viewport, in which case there is nothing under the cursor.
     * @returns The entry id under the position, or null when it is over nothing.
     */
    function findEntryIdAtScenePosition(mousePos){
        if(mousePos == null) return null;

        //The position is within whichever viewport the cursor is in, so the ray
        //has to be cast through that viewport's camera to reach what is under it.
        local camera = ::SceneEditorFramework.getActiveSceneCamera();
        if(camera == null) return null;

        local ray = camera.getCameraToViewportRay(mousePos.x, mousePos.y);
        local result = _scene.testRayForObjectArray(ray, SceneEditorFramework_QueryFlag.SCENE_OBJECT);
        if(result == null || result.len() <= 0) return null;

        //Objects the framework did not construct can share the query mask, so
        //a node without an entry is a miss rather than an error.
        local nodeId = result[0].getParentNode().getId();
        if(!mNodesForEntry_.rawin(nodeId)) return null;

        return mNodesForEntry_.rawget(nodeId);
    }

    /**
     *
     * @param mousePos Position of the mouse in screen space. Can be null if the current position is invalid and the editor can respond in some way as a result of that.
     */
    function updateSceneSafeMousePosition(mousePos){
        //No camera means no viewport for the cursor to be in, which is the same
        //situation as it being outside one.
        local camera = ::SceneEditorFramework.getActiveSceneCamera();
        if(mousePos == null || camera == null){
            mMoveHandles_.notifyNewQueryResults(null);
            return;
        }

        if(!::SceneEditorFramework.HelperFunctions.basicMouseInteractionEnabled()){
            return;
        }

        local ray = camera.getCameraToViewportRay(mousePos.x, mousePos.y);
        local result = _scene.testRayForObjectArray(ray, SceneEditorFramework_QueryFlag.GIZMO_HANDLE);
        local interactedWithGizmo = mMoveHandles_.notifyNewQueryResults(result);

        if(interactedWithGizmo && _input.getMouseButton(_MB_LEFT)){
            local result = _scene.testRayForObjectArray(ray, SceneEditorFramework_QueryFlag.SCENE_OBJECT);
            if(result != null){
                if(result.len() > 0){
                    //Otherwise take the first item and highlight it.
                    local targetId = result[0].getParentNode().getId();
                    print("highlighting " + targetId);
                    local entryId = mNodesForEntry_.rawget(targetId);

                    mCurrentSelectionDeferred = entryId;
                }
            }else{
                mCurrentSelectionDeferred = -1;
            }
        }
    }

}
