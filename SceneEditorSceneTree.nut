::SceneEditorFramework.SceneTree <- class{

    mEntries_ = null;
    mParentNode_ = null;
    mBus_ = null;

    mCurrentSelection = -1;

    constructor(parentNode, bus){
        mEntries_ = [];
        mParentNode_ = parentNode;
        mBus_ = bus;
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
                print("removing");
                continue;
            }

            lastNode = constructObjectForEntry(c, currentNode.top());
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

        mBus_.transmitEvent(SceneEditorBusEvents.SCENE_TREE_SELECTION_CHANGED, e);
    }

    function notifySelectionChanged(buttonId){
        setCurrentSelection(buttonId);
    }

}