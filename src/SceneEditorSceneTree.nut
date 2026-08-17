::SceneEditorFramework.SceneTree <- class{

    mEntries_ = null;
    mParentNode_ = null;
    mBus_ = null;
    mActionStack_ = null;
    mMoveHandles_ = null;
    mOutlineBox_ = null;
    mChildrenOutlineBox_ = null;
    mCurrentPopulateAction_ = null;
    //The starting positions of a drag which is moving more than the object the
    //gizmo sits on, or null when the drag moves only that one.
    //@see beginMultipleMoveChanges_
    mMultiMoveChanges_ = null;
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
    //Whether the deferred selection joins the current one rather than replacing
    //it, which is what a shift click in the scene asks for.
    mCurrentSelectionDeferredAdditive_ = false;

    //The hits of the previous scene click, and which of them it selected.
    //Tapping the same spot again finds the same objects, and stepping along
    //this list is what gives an object behind a larger one a way of being
    //picked without a modifier.
    mQueryCycleEntryIds_ = null;
    mQueryCycleIndex_ = 0;

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
        mOutlineBox_ = ::SceneEditorFramework.SceneEditorGizmoOutlineLayers(mParentNode_, mBus_);
        //Orange rather than the selected object's own white, so the box which
        //encloses everything the selection covers reads as the larger of the
        //two when both are drawn.
        mChildrenOutlineBox_ = ::SceneEditorFramework.SceneEditorGizmoOutlineLayers(
            mParentNode_, mBus_, "SceneEditorFramework/childrenOutline");
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
        mOutlineBox_.update();
        mChildrenOutlineBox_.update();

        if(mCurrentSelectionDeferred == -1){
            setCurrentSelection(null);
        }else if(mCurrentSelectionDeferred != null){
            if(mCurrentSelectionDeferredAdditive_){
                toggleEntrySelection(mCurrentSelectionDeferred);
            }else{
                setCurrentSelection(mCurrentSelectionDeferred);
            }
        }
        mCurrentSelectionDeferred = null;
        mCurrentSelectionDeferredAdditive_ = false;

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
    /**
     * Build an entry's scene object again, after a change to what the entry
     * describes rather than to where it sits.
     *
     * Destroying a node destroys everything below it, so an entry with children
     * cannot have its own node replaced without taking theirs with it. The whole
     * framework-owned root is rebuilt instead, which leaves every entry - this
     * one and its descendants - with a node of its own and the lookup from node
     * back to entry rebuilt along with them.
     */
    function regenerateSceneEntry(entryId){
        local idx = findEntryIdIndexInTree_(entryId);
        if(idx == null || mEntries_[idx].node == null) return;

        rebuildSceneTree_();
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

    /**
     * Fresh world bounds for an entry and, by default, everything below it.
     * Empty hierarchy entries therefore remain useful framing targets while a
     * mesh entry simply returns the bounds of its attached renderable.
     */
    function getEntryAABB(entryId, includeChildren=true){
        local entryIndex = findEntryIdIndexInTree_(entryId);
        if(entryIndex == null) return null;

        local result = null;
        local node = mEntries_[entryIndex].node;
        for(local objectIndex = 0;
                objectIndex < node.getNumAttachedObjects(); objectIndex++){
            local bounds = node.getAttachedObject(objectIndex).getWorldAabbUpdated();
            if(result == null){
                result = AABB(bounds.getCentre(), bounds.getHalfSize());
            }else{
                result.merge(bounds);
            }
        }

        if(includeChildren){
            local children = getChildrenAABB_(entryIndex);
            if(result == null){
                result = children;
            }else if(children != null){
                result.merge(children);
            }
        }
        return result;
    }

    function clearAllSelection(){
        setCurrentSelection(null);
    }

    function setSingleSelection(entryId){
        setCurrentSelection(entryId);
    }

    /**
     * Add an entry to the selection, or take it back out when it is already in
     * it, leaving the rest of the selection alone.
     *
     * A scene has no ordering for a click to select a range along, so this is
     * what a shift click in a viewport does, while the tree's shift click
     * continues to select a range.
     */
    function toggleEntrySelection(entryId){
        if(entryId == null || findEntryIdIndexInTree_(entryId) == null) return;

        if(!isEntrySelected(entryId)){
            mSelectedIds_.rawset(entryId, true);
            mMostRecentSelection_ = entryId;
            setPrimarySelection_(entryId);
            return;
        }

        mSelectedIds_.rawdelete(entryId);
        if(mMostRecentSelection_ == entryId) mMostRecentSelection_ = null;

        //The primary selection is what the gizmo and the properties panel act
        //on, so one of the entries which is still selected has to take it over.
        //Reassigning it even when it has not changed is what tells those panels
        //the selection is now a different size.
        local primary = mCurrentSelection == entryId ?
            getFirstSelection() : mCurrentSelection;
        setPrimarySelection_(primary == -1 ? null : primary);
    }

    /**
     * Select exactly the entries named, in one step.
     *
     * An action which creates several entries at once - a paste - has a
     * selection to hand back rather than one entry, and building it here means
     * the panels are told about it once rather than once per entry.
     */
    function setSelectionToIds(entryIds){
        mSelectedIds_.clear();
        mMostRecentSelection_ = null;
        foreach(entryId in entryIds){
            if(findEntryIdIndexInTree_(entryId) == null) continue;
            mSelectedIds_.rawset(entryId, true);
            mMostRecentSelection_ = entryId;
        }

        setPrimarySelection_(mMostRecentSelection_);
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

    /**
     * Add an empty scene node as a child of an existing entry, or, with a null
     * parent, at the end of the scene's top level.
     */
    function insertEmptyChild(parentId, name="Empty"){
        return insertEntry_(parentId, SceneEditorFramework_ObjectInsertionType.INTO,
            SceneEditorFramework_SceneTreeEntryType.EMPTY, null, name);
    }

    /**
     * Add one of the engine's built-in primitive meshes as a child. A null
     * parent puts it at the end of the scene's top level.
     */
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
     *
     * A null target has nothing to be relative to, so the object goes at the
     * end of the scene's top level and the insertion type is not used.
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

        local targetIndex = null;
        if(targetId != null){
            targetIndex = findEntryIdIndexInTree_(targetId);
            if(targetIndex == null || !isObjectEntry_(mEntries_[targetIndex])) return null;
        }
        if(
            insertionType != SceneEditorFramework_ObjectInsertionType.INTO &&
            insertionType != SceneEditorFramework_ObjectInsertionType.ABOVE &&
            insertionType != SceneEditorFramework_ObjectInsertionType.BELOW
        ) return null;
        //Every scene has the root CHILD/TERM pair, so anything shorter has no
        //top level for a targetless insertion to go in.
        if(targetIndex == null && mEntries_.len() < 2) return null;

        local entry = ::SceneEditorFramework.SceneTreeEntry();
        entry.reset();
        entry.entryId = getId();
        entry.nodeType = nodeType;
        entry.data = data;
        entry.name = name;

        local insertedEntries = targetIndex != null ?
            buildEntriesWithInsertion_(targetIndex, insertionType, [entry]) :
            insertEntriesAt_(mEntries_, mEntries_.len() - 1, [entry]);
        local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.OBJECT_INSERTION];
        local action = A(this, mEntries_, insertedEntries, entry.entryId);
        mActionStack_.pushAction_(action);
        action.performAction();
        return entry.entryId;
    }

    //Place an already built run of entries relative to one target. The run is a
    //layout of its own - a pasted object brings its descendants with it - so
    //everything here works on the whole of it rather than on a single entry.
    function buildEntriesWithInsertion_(targetIndex, insertionType, newEntries){
        local insertIndex = targetIndex;
        local inserted = newEntries;

        if(insertionType == SceneEditorFramework_ObjectInsertionType.BELOW){
            insertIndex = getEntrySectionEndInEntries_(mEntries_, targetIndex);
        }else if(insertionType == SceneEditorFramework_ObjectInsertionType.INTO){
            if(entryHasChildrenInEntries_(mEntries_, targetIndex)){
                insertIndex = getTerminatorForChildInEntries_(mEntries_, targetIndex + 1) - 1;
            }else{
                inserted = [::SceneEditorFramework.FileParser.CHILD_ENTRY];
                foreach(entry in newEntries) inserted.append(entry);
                inserted.append(::SceneEditorFramework.FileParser.TERM_ENTRY);
                insertIndex = targetIndex + 1;
            }
        }

        return insertEntriesAt_(mEntries_, insertIndex, inserted);
    }

    /**
     * Copy the current selection into a clipboard.
     *
     * @returns true when something was copied.
     * @see SceneEditorFramework.SceneTreeClipboard
     */
    function copySelectionToClipboard(clipboard){
        if(clipboard == null) return false;
        return clipboard.copyFromTree(this);
    }

    /**
     * Insert a clipboard's contents into this tree as one undoable action.
     *
     * The clipboard holds descriptions rather than objects, so this is where
     * they become entries: each one is instantiated with an id of this tree's
     * own, which is what allows the same clipboard to be pasted repeatedly and
     * into a tree other than the one it was copied from.
     *
     * The paste lands below the target by default, so copying an object and
     * pasting it leaves the duplicate beside the original rather than inside it.
     * Without a target - nothing is selected, or the selection has since gone
     * away - it goes at the end of the scene's top level.
     *
     * @returns The ids of the pasted objects which are not below another pasted
     * one, or null when there was nothing to paste.
     */
    function pasteFromClipboard(clipboard, targetId=null,
        insertionType=SceneEditorFramework_ObjectInsertionType.BELOW){
        if(clipboard == null || !clipboard.hasEntries()) return null;
        if(targetId == null && mCurrentSelection != -1) targetId = mCurrentSelection;

        return pasteEntries_(clipboard.getEntries(), targetId, insertionType);
    }

    /**
     * Insert a clipboard's contents at the end of the scene's top level,
     * whatever is selected. This is what a paste asked for by the child wrapper
     * rather than by an object does.
     *
     * @returns The ids of the pasted objects which are not below another pasted
     * one, or null when there was nothing to paste.
     */
    function pasteFromClipboardAtTopLevel(clipboard){
        if(clipboard == null || !clipboard.hasEntries()) return null;

        return pasteEntries_(clipboard.getEntries(), null,
            SceneEditorFramework_ObjectInsertionType.INTO);
    }

    function pasteEntries_(sourceEntries, targetId, insertionType){
        if(sourceEntries == null || sourceEntries.len() == 0) return null;
        if(
            insertionType != SceneEditorFramework_ObjectInsertionType.INTO &&
            insertionType != SceneEditorFramework_ObjectInsertionType.ABOVE &&
            insertionType != SceneEditorFramework_ObjectInsertionType.BELOW
        ) return null;

        //A target which is not an object entry, or which is no longer in the
        //tree, leaves the paste to go in at the top level.
        local targetIndex = targetId == null ? null : findEntryIdIndexInTree_(targetId);
        if(targetIndex != null && !isObjectEntry_(mEntries_[targetIndex])) targetIndex = null;

        //Every scene has the root CHILD/TERM pair, so anything shorter is not a
        //tree a paste can be placed in.
        if(targetIndex == null && mEntries_.len() < 2) return null;

        local newEntries = [];
        local createdIds = [];
        local topLevelIds = [];
        local depth = 0;
        foreach(entry in sourceEntries){
            if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
                depth++;
                newEntries.append(::SceneEditorFramework.FileParser.CHILD_ENTRY);
                continue;
            }
            if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.TERM){
                depth--;
                newEntries.append(::SceneEditorFramework.FileParser.TERM_ENTRY);
                continue;
            }

            local copied = ::SceneEditorFramework.copySceneTreeEntry(entry);
            copied.entryId = getId();
            createdIds.append(copied.entryId);
            if(depth == 0) topLevelIds.append(copied.entryId);
            newEntries.append(copied);
        }
        if(createdIds.len() == 0) return null;

        local pastedEntries = targetIndex != null ?
            buildEntriesWithInsertion_(targetIndex, insertionType, newEntries) :
            insertEntriesAt_(mEntries_, mEntries_.len() - 1, newEntries);

        local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.OBJECT_PASTE];
        local action = A(this, mEntries_, pastedEntries, createdIds, topLevelIds);
        mActionStack_.pushAction_(action);
        action.performAction();
        return topLevelIds;
    }

    /**
     * Put the current selection under a new empty entry.
     *
     * The empty takes the place of the most recently selected object, so the
     * group ends up where the user was working rather than at the end of that
     * object's parent. Creating the empty and moving the selection into it are
     * one layout change, which is what makes them one undo step.
     *
     * @returns The id of the new empty, or null when there is nothing to
     * reparent.
     */
    function reparentSelectionWithEmpty(name="Empty"){
        local selected = getReducedSelection();
        if(selected.len() == 0) return null;

        local anchorId = getReparentAnchorId_(selected);
        local anchorIndex = findEntryIdIndexInTree_(anchorId);
        if(anchorIndex == null) return null;

        local entry = ::SceneEditorFramework.SceneTreeEntry();
        entry.reset();
        entry.entryId = getId();
        entry.nodeType = SceneEditorFramework_SceneTreeEntryType.EMPTY;
        entry.name = name;

        //Placing the empty before the anchor and then moving the selection out
        //of the tree around it is what leaves it at the index the anchor had.
        local withEmpty = insertEntriesAt_(mEntries_, anchorIndex, [entry]);
        local rearranged = buildRearrangedEntriesInEntries_(withEmpty, selected,
            entry.entryId, SceneEditorFramework_ObjectInsertionType.INTO);
        if(rearranged == null){
            recycleId(entry.entryId);
            return null;
        }

        //The empty is created as well as moved into, so this is an insertion:
        //undo has to give its id back rather than leave it in use.
        local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.OBJECT_INSERTION];
        local action = A(this, mEntries_, rearranged, entry.entryId);
        mActionStack_.pushAction_(action);
        action.performAction();
        return entry.entryId;
    }

    /**
     * Move an entry onto the middle of what hangs below it, without any of that
     * moving in the world.
     *
     * A group whose objects were placed before it was made sits at the origin
     * with everything below it holding a position which describes where it is in
     * the scene rather than where it is in the group. This puts the entry in the
     * middle of what it contains and takes that offset back out of each of its
     * direct children, so the group can be moved, and reads, as one object while
     * looking exactly as it did.
     *
     * Descendants below those children are already described against them, so
     * they need no change of their own.
     *
     * @returns true when the entry was moved.
     */
    function centreEntryOnContents(entryId){
        local index = findEntryIdIndexInTree_(entryId);
        if(index == null || !isObjectEntry_(mEntries_[index])) return false;

        local childIndices = getDirectChildIndices_(index);
        if(childIndices.len() == 0) return false;

        local centre = getContentsCentre_(index);
        if(centre == null) return false;

        //Where each child is in the world, read before anything has moved: that
        //is what it has to be put back to once its parent has moved out from
        //under it.
        local childPositions = [];
        foreach(childIndex in childIndices){
            childPositions.append(mEntries_[childIndex].node.getDerivedPositionVec3());
        }

        //A position describes an object's place in its parent, and a parent can
        //be rotated and scaled, so the local positions this ends up with are
        //read back from nodes which have been put where they are wanted rather
        //than worked out here. Everything is put back afterwards, leaving the
        //action to be what moves the objects.
        local entry = mEntries_[index];
        local entryPosition = entry.position.copy();
        entry.node.setDerivedPosition(centre);
        local entryCentred = entry.node.getPositionVec3();

        local changes = [{
            "id": entryId,
            "old": entryPosition,
            "new": entryCentred
        }];
        foreach(childNumber, childIndex in childIndices){
            local child = mEntries_[childIndex];
            local childPosition = child.position.copy();
            child.node.setDerivedPosition(childPositions[childNumber]);

            changes.append({
                "id": child.entryId,
                "old": childPosition,
                "new": child.node.getPositionVec3()
            });
        }

        foreach(change in changes){
            getEntryForId(change.id).setPosition(change.old);
        }
        //An entry which is already in the middle of its contents has nothing to
        //move, and an edit which changes nothing is not worth an undo step.
        if(positionsEqual_(entryPosition, entryCentred)) return false;

        local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.MULTIPLE_POSITIONS_CHANGE];
        local action = A(this, mBus_, changes);
        mActionStack_.pushAction_(action);
        action.performAction();
        return true;
    }

    //The middle of what hangs below an entry, in world space. What the user sees
    //is the descendants' renderables, so their bounds are what is centred on. A
    //group of empties shows nothing to take bounds from, and there the middle of
    //the descendants' own positions stands in for them.
    function getContentsCentre_(entryIndex){
        local bounds = getChildrenAABB_(entryIndex);
        if(bounds != null) return bounds.getCentre();

        local descendants = getDescendantIndices_(entryIndex);
        if(descendants.len() == 0) return null;

        local minimum = null;
        local maximum = null;
        foreach(descendantIndex in descendants){
            local position = mEntries_[descendantIndex].node.getDerivedPositionVec3();
            if(minimum == null){
                minimum = position.copy();
                maximum = position.copy();
                continue;
            }

            if(position.x < minimum.x) minimum.x = position.x;
            if(position.y < minimum.y) minimum.y = position.y;
            if(position.z < minimum.z) minimum.z = position.z;
            if(position.x > maximum.x) maximum.x = position.x;
            if(position.y > maximum.y) maximum.y = position.y;
            if(position.z > maximum.z) maximum.z = position.z;
        }

        return Vec3(
            (minimum.x + maximum.x) * 0.5,
            (minimum.y + maximum.y) * 0.5,
            (minimum.z + maximum.z) * 0.5
        );
    }

    //The entries directly below one, without the descendants of those.
    function getDirectChildIndices_(entryIndex){
        return getDescendantIndices_(entryIndex, true);
    }

    function getDescendantIndices_(entryIndex, directOnly=false){
        local result = [];
        if(!entryHasChildrenInEntries_(mEntries_, entryIndex)) return result;

        local childMarker = entryIndex + 1;
        local endIndex = getTerminatorForChildInEntries_(mEntries_, childMarker);
        if(endIndex == -1) return result;

        local depth = 0;
        for(local index = childMarker + 1; index < endIndex - 1; index++){
            local entry = mEntries_[index];
            if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
                depth++;
                continue;
            }
            if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.TERM){
                depth--;
                continue;
            }
            if(directOnly && depth != 0) continue;

            result.append(index);
        }
        return result;
    }

    function positionsEqual_(first, second){
        return first.x == second.x && first.y == second.y && first.z == second.z;
    }

    //The most recent selection is what the empty stands in for. It is not
    //always one of the entries which move - it can have been reduced away as a
    //descendant of another selected entry - in which case the first of them in
    //tree order is the closest thing to where the user was.
    function getReparentAnchorId_(selected){
        foreach(entryId in selected){
            if(entryId == mMostRecentSelection_) return entryId;
        }
        return selected[0];
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
        return buildRearrangedEntriesInEntries_(mEntries_, selectedIds,
            destinationId, insertionType);
    }

    //Rearrangement of any layout rather than only the live one, so a caller
    //which has already added an entry can move the selection into it without
    //that intermediate state ever reaching the tree.
    function buildRearrangedEntriesInEntries_(entries, selectedIds, destinationId, insertionType){
        if(
            insertionType != SceneEditorFramework_ObjectInsertionType.INTO &&
            insertionType != SceneEditorFramework_ObjectInsertionType.ABOVE &&
            insertionType != SceneEditorFramework_ObjectInsertionType.BELOW
        ) return null;

        local destinationIndex = findEntryIdIndexInEntries_(entries, destinationId);
        if(destinationIndex == null || !isObjectEntry_(entries[destinationIndex])) return null;

        local rangesByStart = {};
        foreach(entryId in selectedIds){
            local startIndex = findEntryIdIndexInEntries_(entries, entryId);
            if(startIndex == null) return null;
            local endIndex = getEntrySectionEndInEntries_(entries, startIndex);
            if(destinationIndex >= startIndex && destinationIndex < endIndex) return null;

            local range = { "start": startIndex, "end": endIndex };
            rangesByStart.rawset(startIndex, range);
        }

        local moved = [];
        local remaining = [];
        local index = 0;
        while(index < entries.len()){
            if(rangesByStart.rawin(index)){
                local range = rangesByStart.rawget(index);
                for(local i = range.start; i < range.end; i++) moved.append(entries[i]);
                index = range.end;
            }else{
                remaining.append(entries[index]);
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
        return entryLayoutsEqual_(entries, result) ? null : result;
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
        mOutlineBox_.setVisible(false);
        mChildrenOutlineBox_.setVisible(false);
        if(mEntries_ == null || entryId == null || mCurrentSelectionIdx == -1){
            return;
        }
        local node = mEntries_[mCurrentSelectionIdx].node;
        local num = node.getNumAttachedObjects();
        if(num > 0){
            local aabb = node.getAttachedObject(0).getWorldAabbUpdated();
            mOutlineBox_.setBounds(aabb.getCentre(), aabb.getHalfSize());
            mOutlineBox_.setVisible(true);
        }

        //The second outline encloses everything the selection covers: the other
        //selected entries as well as the descendants which move with them. One
        //childless entry has nothing to add to the box above, so nothing is
        //drawn for it.
        local encompassingAabb = getSelectionAABB_();
        if(encompassingAabb == null) return;

        mChildrenOutlineBox_.setBounds(encompassingAabb.getCentre(),
            encompassingAabb.getHalfSize());
        mChildrenOutlineBox_.setVisible(true);
    }

    //Merged bounds of every selected entry and its descendants. Null when the
    //selection is a single entry with nothing below it, whose own outline
    //already says everything this one would.
    function getSelectionAABB_(){
        local selectedIds = getSelectedIds();
        if(selectedIds.len() <= 1) return getChildrenAABB_(mCurrentSelectionIdx);

        local result = null;
        foreach(entryId in selectedIds){
            local bounds = getEntryAABB(entryId);
            if(bounds == null) continue;

            if(result == null){
                result = bounds;
            }else{
                result.merge(bounds);
            }
        }
        return result;
    }

    //The flattened tree puts a CHILD marker immediately after an entry which
    //has descendants. Merge every renderable below that marker, including
    //nested descendants, into the second selection outline.
    function getChildrenAABB_(entryIndex){
        if(!entryHasChildrenInEntries_(mEntries_, entryIndex)) return null;

        local childMarker = entryIndex + 1;
        local endIndex = getTerminatorForChildInEntries_(mEntries_, childMarker);
        if(endIndex == -1) return null;

        local result = null;
        for(local index = childMarker + 1; index < endIndex - 1; index++){
            local entry = mEntries_[index];
            if(!isObjectEntry_(entry)) continue;

            local node = entry.node;
            for(local objectIndex = 0;
                    objectIndex < node.getNumAttachedObjects(); objectIndex++){
                local bounds = node.getAttachedObject(objectIndex).
                    getWorldAabbUpdated();
                if(result == null){
                    result = AABB(bounds.getCentre(), bounds.getHalfSize());
                }else{
                    result.merge(bounds);
                }
            }
        }
        return result;
    }

    function positionTransformGizmo_(){
        mMoveHandles_.setVisible(true);
        mMoveHandles_.setPosition(getTransformGizmoAnchor_());
    }

    /**
     * Where the transform gizmo sits, and so what a drag of it is about.
     *
     * A move of a multiple selection is about the selection as a whole - every
     * entry travels the same distance - so the handles belong at the centre of
     * the bounds the orange outline draws around it, not on whichever entry was
     * clicked last. That entry is an arbitrary member of the group as far as the
     * move is concerned, and putting the handles on it leaves them off to one
     * side of the box being dragged, or outside it.
     *
     * A scale or a rotation is about the entry the gizmo sits on rather than
     * about the group (@see beginMultipleMoveChanges_), so those keep the
     * handles on the object itself; the anchor would otherwise claim a centre
     * the operation does not use. The raycast gizmo places an object at a point
     * found on a surface, which is likewise about the one entry.
     *
     * Callers which move the selection must measure their delta from here too,
     * since this is the point the gizmo hands back a new position for.
     */
    function getTransformGizmoAnchor_(){
        if(getSelectedCount() > 1 &&
            mCurrentObjectTransformCoordinateType_ ==
                SceneEditorFramework_BasicCoordinateType.POSITION){
            //Null for a selection of entries which draw nothing - a group of
            //empties has no bounds to find a centre in - which falls through to
            //the primary entry the same as a single selection.
            local aabb = getSelectionAABB_();
            if(aabb != null) return aabb.getCentre();
        }

        return mEntries_[mCurrentSelectionIdx].node.getDerivedPositionVec3();
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

    /**
     * Move the selection so that the gizmo's anchor is at a world position.
     *
     * A drag names one place for one point - wherever the gizmo sits - so the
     * selection keeps the arrangement it was in by every entry moving the same
     * distance through the world. The distance is measured from the anchor and
     * not from the primary entry, because for a multiple selection those are
     * two different points: the anchor is the centre of the selection's bounds.
     * @see getTransformGizmoAnchor_
     *
     * A selected entry's descendants move with it rather than being moved
     * themselves, which is what the reduced selection describes.
     */
    function setSelectedNodePosition(position){
        if(mCurrentSelectionIdx == -1){
            return;
        }

        local p = getPositionWithMagnet(position);
        local e = mEntries_[mCurrentSelectionIdx];
        if(getSelectedCount() <= 1){
            e.setPosition(p, true);
        }else{
            local delta = p - getTransformGizmoAnchor_();
            foreach(entryId in getReducedSelection()){
                local entry = getEntryForId(entryId);
                if(entry == null) continue;

                entry.setPosition(entry.getPositionDerived() + delta, true);
            }
        }

        //Read back rather than assuming the drag's position: the primary entry
        //is moved by its selected parent instead of on its own when one of its
        //ancestors is selected as well, and the anchor of a multiple selection
        //is a centre which has to be measured again now everything has moved.
        mMoveHandles_.positionGizmo(getTransformGizmoAnchor_());

        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE, e);
    }

    function positionMoveHandles(){
        //An object can be moved while nothing is selected - an edit which moves
        //more than one object moves those it was not asked for - and then there
        //is no gizmo on show to be put anywhere.
        if(mCurrentSelectionIdx == -1) return;

        mMoveHandles_.positionGizmo(getTransformGizmoAnchor_());
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
        else if(event == SceneEditorFramework_BusEvents.SELECTED_ORIENTATION_CHANGE){
            assert(mCurrentPopulateAction_ != null);
            setSelectedNodeOrientationFromWorldDelta_(data);
            setOutlineBox(mCurrentSelectionIdx);
        }
        else if(event == SceneEditorFramework_BusEvents.HANDLES_GIZMO_INTERACTION_BEGAN){
            mMultiMoveChanges_ = beginMultipleMoveChanges_(data);

            local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.BASIC_COORDINATES_CHANGE];
            mCurrentPopulateAction_ = A(this, mBus_, mCurrentSelection, getValueForObjectCoordsChange_(data), null, data, false);
        }
        else if(event == SceneEditorFramework_BusEvents.HANDLES_GIZMO_INTERACTION_ENDED){
            if(mMultiMoveChanges_ != null){
                pushMultipleMoveAction_();
            }else{
                mCurrentPopulateAction_.mNew_ = getValueForObjectCoordsChange_(data);

                mActionStack_.pushAction_(mCurrentPopulateAction_);
            }
        }
        else if(event == SceneEditorFramework_BusEvents.OBJECT_POSITION_CHANGE){
            positionMoveHandles();
            setOutlineBox(mCurrentSelectionIdx);
            if(data.id == mCurrentSelection){
                mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE, mEntries_[mCurrentSelectionIdx]);
            }
        }
        else if(event == SceneEditorFramework_BusEvents.OBJECT_SCALE_CHANGE){
            setOutlineBox(mCurrentSelection);
            if(data.id == mCurrentSelection){
                mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE, mEntries_[mCurrentSelectionIdx]);
            }
        }
        else if(event == SceneEditorFramework_BusEvents.OBJECT_ORIENTATION_CHANGE){
            setOutlineBox(mCurrentSelectionIdx);
            if(data.id == mCurrentSelection){
                mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE, mEntries_[mCurrentSelectionIdx]);
            }
        }
        else if(event == SceneEditorFramework_BusEvents.OBJECT_VISIBILITY_CHANGE){
            setOutlineBox(mCurrentSelection);
        }
    }
    /**
     * The positions a drag which is about to begin would have to put back, or
     * null when one BasicCoordinatesChangeAction still describes it.
     *
     * Only a move widens to the rest of the selection - a scale or a rotation
     * is about the object the gizmo sits on - and a move of a single object is
     * left as the single-object action it has always been.
     */
    function beginMultipleMoveChanges_(coordsType){
        if(coordsType != SceneEditorFramework_BasicCoordinateType.POSITION) return null;
        if(getSelectedCount() <= 1) return null;

        local changes = [];
        foreach(entryId in getReducedSelection()){
            local entry = getEntryForId(entryId);
            if(entry == null) continue;

            changes.append({
                "id": entryId,
                "old": entry.position.copy(),
                "new": null
            });
        }
        return changes.len() == 0 ? null : changes;
    }

    //One undo step for the whole drag, however many objects it moved.
    function pushMultipleMoveAction_(){
        local changes = mMultiMoveChanges_;
        mMultiMoveChanges_ = null;

        local moved = [];
        foreach(change in changes){
            //An object which has left the tree since the drag began is not one
            //an undo step can put back where it was.
            local index = findEntryIdIndexInTree_(change.id);
            if(index == null) continue;

            change["new"] = mEntries_[index].position.copy();
            moved.append(change);
        }
        if(moved.len() == 0) return;

        local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.MULTIPLE_POSITIONS_CHANGE];
        mActionStack_.pushAction_(A(this, mBus_, moved));
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

    //A ring rotates around a world axis. Convert that world-space delta into
    //the selected entry's local space so nested objects rotate correctly too.
    function setSelectedNodeOrientationFromWorldDelta_(worldDelta){
        if(mCurrentSelectionIdx == -1) return;

        local entry = mEntries_[mCurrentSelectionIdx];
        local parentOrientation = entry.node.getParent().getDerivedOrientation();
        local localDelta = parentOrientation.inverse() * worldDelta * parentOrientation;
        entry.setOrientation(localDelta * mCurrentPopulateAction_.mOld_);
        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE, entry);
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
     * with renameCurrentSelection.
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
                mChildrenOutlineBox_.setVisible(false);
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
        local entries = findEntryIdsAtScenePosition(mousePos);
        return entries.len() > 0 ? entries[0] : null;
    }

    /**
     * Every scene entry intersected at a position, nearest first.
     *
     * A node can have more than one queryable object attached, so entry ids are
     * returned only once. Objects carrying the scene query flag but not owned by
     * this tree are ignored.
     *
     * Ray queries need a clean scene, so call this from sceneSafeUpdate().
     *
     * @param mousePos Position within the scene viewport in the 0-1 range, as
     * ::SceneEditorFramework.getNormalisedSceneMousePosition() returns.
     * @returns An array of entry ids, empty when there is no viewport or hit.
     */
    function findEntryIdsAtScenePosition(mousePos){
        local entries = [];
        if(mousePos == null) return entries;

        //The position is within whichever viewport the cursor is in, so the ray
        //has to be cast through that viewport's camera to reach what is under it.
        local camera = ::SceneEditorFramework.getActiveSceneCamera();
        if(camera == null) return entries;

        local ray = camera.getCameraToViewportRay(mousePos.x, mousePos.y);
        local result = _scene.testRayForObjectArray(ray, SceneEditorFramework_QueryFlag.SCENE_OBJECT);
        return entryIdsForQueryResult_(result);
    }

    //Turn the objects a scene query found into the entry ids they belong to,
    //nearest first and each id only once.
    function entryIdsForQueryResult_(result){
        local entries = [];
        if(result == null) return entries;

        local found = {};
        foreach(object in result){
            //Objects the framework did not construct can share the query mask,
            //so a node without an entry is skipped rather than being an error.
            local nodeId = object.getParentNode().getId();
            if(!mNodesForEntry_.rawin(nodeId)) continue;

            local entryId = mNodesForEntry_.rawget(nodeId);
            if(found.rawin(entryId)) continue;
            found.rawset(entryId, true);
            entries.append(entryId);
        }

        return entries;
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
        local result = mMoveHandles_.usesObjectQuery() ?
            _scene.testRayForObjectArray(ray, SceneEditorFramework_QueryFlag.GIZMO_HANDLE) : null;
        local interactedWithGizmo = mMoveHandles_.notifyNewQueryResults(result);

        //Only the press selects. A tap is what asks for an object, and cycling
        //through what is under the cursor would otherwise run for every frame
        //the button stayed down.
        if(interactedWithGizmo && _input.getMousePressed(_MB_LEFT)){
            local sceneResult = _scene.testRayForObjectArray(ray, SceneEditorFramework_QueryFlag.SCENE_OBJECT);
            local entryIds = entryIdsForQueryResult_(sceneResult);
            //Shift adds the object under the cursor to the selection. The
            //nearest one is taken: cycling needs the click to keep selecting
            //the same single object, which a growing selection is not.
            if(shiftSelectionModifierHeld_()){
                //Shift clicking nothing is not a request to lose the selection
                //which was being built up.
                if(entryIds.len() > 0){
                    mCurrentSelectionDeferred = entryIds[0];
                    mCurrentSelectionDeferredAdditive_ = true;
                    //An addition leaves more than one entry selected, so the
                    //next plain click starts a new cycle at the nearest object.
                    mQueryCycleEntryIds_ = null;
                }
            }else{
                local picked = pickEntryFromQuery_(entryIds);
                mCurrentSelectionDeferred = picked == null ? -1 : picked;
            }
        }
    }

    function shiftSelectionModifierHeld_(){
        return _input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.LSHIFT) ||
            _input.getRawKeyScancodeInput(SceneEditorFramework_KeyScancode.RSHIFT);
    }

    /**
     * Choose which of the objects under the cursor a click selects.
     *
     * The nearest is taken normally. Tapping again without moving finds the
     * same objects in the same order, and each of those taps steps one further
     * along the list, so an object hidden behind a larger one can be reached by
     * tapping rather than by having to be picked out of a menu.
     *
     * @param entryIds The entry ids under the cursor, nearest first.
     * @returns The entry id to select, or null when nothing was hit.
     */
    function pickEntryFromQuery_(entryIds){
        if(entryIds.len() == 0){
            mQueryCycleEntryIds_ = null;
            return null;
        }

        local index = 0;
        if(queryContinuesCycle_(entryIds)){
            index = (mQueryCycleIndex_ + 1) % entryIds.len();
        }

        mQueryCycleEntryIds_ = entryIds;
        mQueryCycleIndex_ = index;
        return entryIds[index];
    }

    //A tap continues the previous one when it found exactly the same objects in
    //the same order, and what that tap selected is still what is selected. A
    //selection made anywhere else in the meantime starts the cycle again, so a
    //click always selects what is actually in front.
    function queryContinuesCycle_(entryIds){
        if(mQueryCycleEntryIds_ == null) return false;
        if(mQueryCycleEntryIds_.len() != entryIds.len()) return false;
        if(mCurrentSelection != mQueryCycleEntryIds_[mQueryCycleIndex_]) return false;
        if(getSelectedCount() != 1) return false;

        foreach(c, entryId in entryIds){
            if(mQueryCycleEntryIds_[c] != entryId) return false;
        }

        return true;
    }

}
