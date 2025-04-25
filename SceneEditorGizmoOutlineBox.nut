::SceneEditorFramework.SceneEditorGizmoOutlineBox <- class extends ::SceneEditorFramework.SceneEditorGizmo{

    mBus_ = null;
    mItem_ = null;
    mNode_ = null;

    constructor(parent, bus){
        base.constructor(parent);

        mBus_ = bus;

        setup(mParentNode_);
    }

    function setup(parent){
        local newNode = parent.createChildSceneNode();
        local item = _scene.createItem("lineBox");
        item.setRenderQueueGroup(30);
        newNode.attachObject(item);

        mItem_ = item;
        mNode_ = newNode;
    }

    function setPosition(pos){
        mNode_.setPosition(pos);
    }

    function setScale(scale){
        mNode_.setScale(scale);
    }

    function shutdown(){
        mParentNode_.destroyNodeAndChildren();
    }

    function update(){

    }

};