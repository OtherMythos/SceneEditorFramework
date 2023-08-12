::SceneEditorFramework.SceneTree <- class{

    mEntries_ = null;
    mParentNode_ = null;
    mBus_ = null;
    mMoveHandles_ = null;

    mCurrentSelection = -1;

    constructor(parentNode, bus){
        mEntries_ = [];
        mParentNode_ = parentNode;
        mBus_ = bus;

        bus.subscribeObject(this);

        mMoveHandles_ = ::SceneEditorFramework.SceneEditorGizmoObjectHandles(mParentNode_, mBus_);
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
            if(i.nodeType == SceneTreeEntryType.CHILD){
                indent++;
                indentString = debugPrintGetPadding_(indent);
            }
            if(i.nodeType == SceneTreeEntryType.TERM){
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
            if(c.nodeType == SceneTreeEntryType.CHILD){
                if(lastNode == null){
                    assert(i == 0);
                    lastNode = mParentNode_.createChildSceneNode();
                }
                currentNode.append(lastNode);
                //currentNode = lastNode;
                continue;
            }
            else if(c.nodeType == SceneTreeEntryType.TERM){
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
        if(entry.nodeType == SceneTreeEntryType.MESH){
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
        assert(e.nodeType != SceneTreeEntryType.CHILD && e.nodeType != SceneTreeEntryType.TERM);
        mCurrentSelection = entryId;

        mMoveHandles_.setVisible(true);
        local targetPos = mEntries_[entryId].node.getDerivedPositionVec3();
        mMoveHandles_.setPosition(targetPos);

        mBus_.transmitEvent(SceneEditorBusEvents.SCENE_TREE_SELECTION_CHANGED, e);
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
            if(entry.nodeType == SceneTreeEntryType.TERM) childCount++;
            if(entry.nodeType == SceneTreeEntryType.CHILD){
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
        if(event == SceneEditorBusEvents.SELECTED_POSITION_CHANGE){
            local e = mEntries_[mCurrentSelection];
            e.setPosition(data);
        }
    }

    function notifySelectionChanged(buttonId){
        setCurrentSelection(buttonId);
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