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
    mMagneticEdit_ = false;

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

    };

    constructor(parentNode, actionStack, bus){
        mEntries_ = [];
        mParentNode_ = parentNode;
        mActionStack_ = actionStack;
        mBus_ = bus;
        mNodesForEntry_ = {};
        mIdPool_ = IdPool();

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
        mMoveHandles_.update();

        if(mCurrentSelectionDeferred == -1){
            setCurrentSelection(null);
        }else if(mCurrentSelectionDeferred != null){
            local idx = findEntryIdIndexInTree_(mCurrentSelectionDeferred);
            setCurrentSelection(mCurrentSelectionDeferred);
        }
        mCurrentSelectionDeferred = null;

        mMoveHandles_.updateCameraDist(_camera.getPosition());
    }

    function getId(){
        return mIdPool_.getId();
    }
    function recycleId(id){
        return mIdPool_.recycleId(id);
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
        mMoveHandles_ = ::SceneEditorFramework.SceneEditorGizmoObjectHandles(mParentNode_, mCurrentObjectTransformCoordinateType_, mBus_);
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

            item.setRenderQueueGroup(30);
            item.setQueryFlags(1 << 20);
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

    function setCurrentSelection(entryId){
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
            mMoveHandles_.setVisible(false);
        }

        setOutlineBox(entryId);

        local data = null;
        if(newSelection != null){
            data = {
                "idx": newIdx,
                "entry": newSelection
            };
        }
        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SCENE_TREE_SELECTION_CHANGED, data);
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
        assert(mCurrentSelectionIdx != -1);

        local action = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.OBJECT_DELETION](this, mBus_, [mCurrentSelection]);
        mActionStack_.pushAction_(action);
        action.performAction();
    }

    function renameCurrentSelection(newName){
        assert(mCurrentSelectionIdx != -1);

        local entry = mEntries_[mCurrentSelectionIdx];
        local oldVal = entry.name;
        if(oldVal == null){
            oldVal = ::SceneEditorFramework.getNameForSceneEntry(entry);
        }

        local action = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.RENAME_SCENE_NODE](this, mBus_, mCurrentSelection, oldVal, newName);
        mActionStack_.pushAction_(action);
        action.performAction();
    }

    function deleteObjectFromTree_(id){
        debugPrint();

        local idx = findEntryIdIndexInTree_(id);
        print(id);
        assert(idx != null);
        //mEntries_[idx].destroy();
        //mEntries_.remove(idx);

        recursiveDeleteInTree_(idx);

        debugPrint();
    }

    function recursiveDeleteInTree_(idx){
        local isTerminator = (mEntries_[idx].nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD);
        local hasChildren = itemHasChildren_(idx);

        local entriesDeleted = 0;

        local itemIndex = idx;
        if(!isTerminator){
            //If the item does have children switch the index to check to that.
            if(hasChildren) itemIndex++;
        }

        local targetIdx = getTerminatorForChild(itemIndex) - 1;
        if(targetIdx < 0){ //This will be true if the item has no children, as the terminator was not found.
            targetIdx = idx;
            assert(!hasChildren);
        }
        if(hasChildren) assert(mEntries_[targetIdx].nodeType == SceneEditorFramework_SceneTreeEntryType.TERM);

        //Go through and recycle all the entry ids between the terminators.
        local selectedItemDeleted = false;
        for(local i = idx; i <= targetIdx; i++){
            if(mEntries_[idx].nodeType == SceneEditorFramework_SceneTreeEntryType.TERM || mEntries_[idx].nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
                continue;
            }
            /*
            //Check if that item is part of the selected list. If it is it should be removed.
            local it = mSelectedIds.find(mSceneTree[i].id);
            if(it != mSelectedIds.end()){
                mSelectedIds.erase(it);
                selectedItemDeleted = true;
            }
            */

            entriesDeleted++;
            recycleId(mEntries_[i].entryId);
        }

        local indentCount = 0;
        for(local i = idx; i < targetIdx + 1; i++){
            //NOTE index the list by idx because .remove will shift the list while it removes.
            //Unfortunately in Squirrel I can't remove a range from the array.
            if(mEntries_[idx].nodeType == SceneEditorFramework_SceneTreeEntryType.TERM){
                indentCount--;
            }
            else if(mEntries_[idx].nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
                indentCount++;
            }

            if(indentCount == 0){
                mEntries_[idx].destroy();
            }
            mEntries_.remove(idx);
        }

        return entriesDeleted;
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

    function notifySelectionChanged(buttonId){
        setCurrentSelection(buttonId);
    }

    function getEntryForId(id){
        return mEntries_[findEntryIdIndexInTree_(id)];
    }

    /**
     *
     * @param mousePos Position of the mouse in screen space. Can be null if the current position is invalid and the editor can respond in some way as a result of that.
     */
    function updateSceneSafeMousePosition(mousePos){
        if(mousePos == null){
            mMoveHandles_.notifyNewQueryResults(null);
            return;
        }

        if(!::SceneEditorFramework.HelperFunctions.basicMouseInteractionEnabled()){
            return;
        }

        local ray = _camera.getCameraToViewportRay(mousePos.x, mousePos.y);
        local result = _scene.testRayForObjectArray(ray, 1 << 10);
        local interactedWithGizmo = mMoveHandles_.notifyNewQueryResults(result);

        if(interactedWithGizmo && _input.getMouseButton(_MB_LEFT)){
            local result = _scene.testRayForObjectArray(ray, 1 << 20);
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