::SceneEditorFramework.GUIPanel <- class{

    mParent_ = null;
    mBaseObj_ = null;
    mBus_ = null;

    constructor(parent, baseObj, bus){
        mParent_ = parent;
        mBaseObj_ = baseObj;
        mBus_ = bus;
    }

    function getPosition(){
        return mParent_.getPosition();
    }
    function getSize(){
        return mParent_.getSize();
    }

};