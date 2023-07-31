::SceneEditorFramework.SceneEditorGizmoObjectHandles <- class extends ::SceneEditorFramework.SceneEditorGizmo{

    mPositionHandles_ = null;
    mPositionNodes_ = null;
    mOperationInPlace_ = false;
    mHighlightAxis_ = null;

    constructor(parent){
        base.constructor(parent);

        setup(mParentNode_);
    }

    function setup(parent){
        local orientationVals = [
            Quat(-PI/2, Vec3(0, 0, 1)),
            Quat(),
            Quat(PI/2, Vec3(1, 0, 0))
        ];
        mPositionHandles_ = array(3);
        mPositionNodes_ = array(3);
        for(local i = 0; i < 3; i++){
            local newNode = parent.createChildSceneNode();
            local item = _scene.createItem("arrow.mesh");
            item.setRenderQueueGroup(30);
            item.setQueryFlags(1 << 10);
            newNode.attachObject(item);

            local targetDatablock = _hlms.getDatablock("SceneEditorFramework/handle"+i);
            item.setDatablock(targetDatablock);
            newNode.setOrientation(orientationVals[i]);

            mPositionHandles_[i] = item;
            mPositionNodes_[i] = newNode;
        }
    }

    function update(ray){
    }

    function notifyNewQueryResults(results){
        local axis = getAxisForSceneNodeArray(results);
        if(axis != null){
            if(mOperationInPlace_){

            }else{
                //Just perform a highlight
                if(mHighlightAxis_ != null){
                    resetHighlightForAxis_(mHighlightAxis_);
                }
                mPositionHandles_[axis].setDatablock("SceneEditorFramework/handleHighlight"+axis);
                mHighlightAxis_ = axis;
            }
        }else{
            if(mHighlightAxis_ != null){
                //Reset the highlight.
                //mPositionHandles_[mHighlightAxis_].setDatablock("SceneEditorFramework/handle"+mHighlightAxis_);
                //mHighlightAxis_ = null;
                resetHighlightForAxis_(axis);
            }
        }
    }
    function resetHighlightForAxis_(axis){
        mPositionHandles_[mHighlightAxis_].setDatablock("SceneEditorFramework/handle"+mHighlightAxis_);
        mHighlightAxis_ = null;
    }

    function getAxisForSceneNodeArray(a){
        if(a == null) return null;
        foreach(i in a){
            foreach(c,y in mPositionNodes_){
                if(i.getParentNode().getId() == y.getId()){
                    return c;
                }
            }
        }
        return null;
    }

};