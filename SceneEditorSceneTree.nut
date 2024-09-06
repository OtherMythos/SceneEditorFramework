::SceneEditorFramework.SceneTree <- class{

    mEntries_ = null;
    mParentNode_ = null;
    mBus_ = null;
    mActionStack_ = null;
    mMoveHandles_ = null;
    mCurrentPopulateAction_ = null;
    mCurrentObjectTransformCoordinateType_ = null;

    mCurrentSelection = -1;

    constructor(parentNode, actionStack, bus){
        mEntries_ = [];
        mParentNode_ = parentNode;
        mActionStack_ = actionStack;
        mBus_ = bus;

        bus.subscribeObject(this);

        setObjectTransformCoordinateType(SceneEditorFramework_BasicCoordinateType.POSITION);
        mMoveHandles_.setVisible(false);
    }

    function update(){
        //TODO move out.
        mMoveHandles_.update();

        mMoveHandles_.updateCameraDist(_camera.getPosition());
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
            printf("%s %s", indentString, ::SceneEditorFramework.getNameForSceneEntryType(i.nodeType));
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
            c.node = lastNode;
        }
        assert(currentNode.len() == 1);
    }
    function constructObjectForEntry(entry, parent){
        local newNode = parent.createChildSceneNode();
        local nodeType = entry.nodeType;
        local entryData = entry.data;
        if(nodeType == SceneEditorFramework_SceneTreeEntryType.MESH){
            local item = _scene.createItem(entryData.meshName);

            item.setRenderQueueGroup(30);
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

        newNode.setPosition(entry.position);
        newNode.setScale(entry.scale);
        newNode.setOrientation(entry.orientation);

        return newNode;
    }

    function setCurrentSelection(entryId){
        if(mEntries_ == null) return;
        local e = mEntries_[entryId];
        assert(e.nodeType != SceneEditorFramework_SceneTreeEntryType.CHILD && e.nodeType != SceneEditorFramework_SceneTreeEntryType.TERM);
        mCurrentSelection = entryId;

        positionTransformGizmo_();

        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SCENE_TREE_SELECTION_CHANGED, e);
    }

    function positionTransformGizmo_(){
        mMoveHandles_.setVisible(true);
        local targetPos = mEntries_[mCurrentSelection].node.getDerivedPositionVec3();
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
        if(mCurrentSelection == -1){
            return;
        }

        local e = mEntries_[mCurrentSelection];
        e.setScale(scale);

        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE, e);
    }

    function setSelectedNodePosition(position){
        if(mCurrentSelection == -1){
            return;
        }

        local e = mEntries_[mCurrentSelection];
        e.setPosition(position);
        mMoveHandles_.positionGizmo(position);

        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE, e);
    }

    function notifyBusEvent(event, data){
        if(event == SceneEditorFramework_BusEvents.SELECTED_POSITION_CHANGE){
            assert(mCurrentPopulateAction_ != null);
            setSelectedNodePosition(data);
        }
        else if(event == SceneEditorFramework_BusEvents.SELECTED_SCALE_CHANGE){
            assert(mCurrentPopulateAction_ != null);
            setSelectedNodeScale(mCurrentPopulateAction_.mOld_ - data*0.2);
        }
        else if(event == SceneEditorFramework_BusEvents.HANDLES_GIZMO_INTERACTION_BEGAN){
            local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.BASIC_COORDINATES_CHANGE];
            mCurrentPopulateAction_ = A(this, mBus_, mCurrentSelection, getValueForObjectCoordsChange_(data), null, data);
        }
        else if(event == SceneEditorFramework_BusEvents.HANDLES_GIZMO_INTERACTION_ENDED){
            mCurrentPopulateAction_.mNew_ = getValueForObjectCoordsChange_(data);

            mActionStack_.pushAction_(mCurrentPopulateAction_);
        }
        else if(event == SceneEditorFramework_BusEvents.OBJECT_POSITION_CHANGE){
            if(data.id == mCurrentSelection){
                mMoveHandles_.positionGizmo(data.pos);
                mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE, mEntries_[mCurrentSelection]);
            }
        }
        else if(event == SceneEditorFramework_BusEvents.OBJECT_SCALE_CHANGE){
            if(data.id == mCurrentSelection){
                mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE, mEntries_[mCurrentSelection]);
            }
        }
    }
    function getValueForObjectCoordsChange_(coordsType){
        local endValue = null;
        local e = mEntries_[mCurrentSelection];
        if(coordsType == SceneEditorFramework_BasicCoordinateType.POSITION){
            endValue = e.position.copy();
        }
        else if(coordsType == SceneEditorFramework_BasicCoordinateType.SCALE){
            endValue = e.scale.copy();
        }else{
            assert(false);
        }
        return endValue;
    }

    function notifySelectionChanged(buttonId){
        setCurrentSelection(buttonId);
    }

    function getEntryForId(id){
        return mEntries_[id];
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
        local ray = _camera.getCameraToViewportRay(mousePos.x, mousePos.y);
        local result = _scene.testRayForObjectArray(ray, 1 << 10);
        mMoveHandles_.notifyNewQueryResults(result);
    }

}