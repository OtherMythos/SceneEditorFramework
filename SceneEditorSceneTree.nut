::SceneEditorFramework.SceneTree <- class{

    mEntries_ = null;
    mParentNode_ = null;
    mBus_ = null;
    mActionStack_ = null;
    mMoveHandles_ = null;
    mCurrentPopulateAction_ = null;

    mCurrentSelection = -1;

    constructor(parentNode, actionStack, bus){
        mEntries_ = [];
        mParentNode_ = parentNode;
        mActionStack_ = actionStack;
        mBus_ = bus;

        bus.subscribeObject(this);

        mMoveHandles_ = ::SceneEditorFramework.SceneEditorGizmoObjectHandles(mParentNode_, SceneEditorFramework_BasicCoordinateType.POSITION, mBus_);
        mMoveHandles_.setVisible(false);
    }

    function update(){
        //TODO move out.
        mMoveHandles_.update();

        mMoveHandles_.updateCameraDist(_camera.getPosition());
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
        if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.MESH){
            local item = _scene.createItem(entry.data.meshName);

            newNode.setPosition(entry.position);
            newNode.setScale(entry.scale);
            newNode.setOrientation(entry.orientation);

            item.setRenderQueueGroup(30);
            newNode.attachObject(item);
        }

        return newNode;
    }

    function setCurrentSelection(entryId){
        if(mEntries_ == null) return;
        local e = mEntries_[entryId];
        assert(e.nodeType != SceneEditorFramework_SceneTreeEntryType.CHILD && e.nodeType != SceneEditorFramework_SceneTreeEntryType.TERM);
        mCurrentSelection = entryId;

        mMoveHandles_.setVisible(true);
        local targetPos = mEntries_[entryId].node.getDerivedPositionVec3();
        mMoveHandles_.setPosition(targetPos);

        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SCENE_TREE_SELECTION_CHANGED, e);
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

    function notifyBusEvent(event, data){
        if(event == SceneEditorFramework_BusEvents.SELECTED_POSITION_CHANGE){
            local e = mEntries_[mCurrentSelection];
            e.setPosition(data);
            mMoveHandles_.positionGizmo(data);
        }
        else if(event == SceneEditorFramework_BusEvents.SELECTED_SCALE_CHANGE){
            local e = mEntries_[mCurrentSelection];
            assert(mCurrentPopulateAction_ != null);
            e.setScale(mCurrentPopulateAction_.mOld_ - data*0.2);
        }
        else if(event == SceneEditorFramework_BusEvents.HANDLES_GIZMO_INTERACTION_BEGAN){
            local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.BASIC_COORDINATES_CHANGE];
            mCurrentPopulateAction_ = A(this, mCurrentSelection, getValueForObjectCoordsChange_(data), null, data);
        }
        else if(event == SceneEditorFramework_BusEvents.HANDLES_GIZMO_INTERACTION_ENDED){
            mCurrentPopulateAction_.mNew_ = getValueForObjectCoordsChange_(data);

            mActionStack_.pushAction_(mCurrentPopulateAction_);
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