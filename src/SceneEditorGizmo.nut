::SceneEditorFramework.SceneEditorGizmo <- class{

    mParentNode_ = null;

    constructor(parent){
        mParentNode_ = parent.createChildSceneNode();
    }

    function setVisible(visible){
        mParentNode_.setVisible(visible);
    }
    function setPosition(pos){
        mParentNode_.setPosition(pos);
    }

};