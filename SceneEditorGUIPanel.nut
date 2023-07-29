::SceneEditorFramework.GUIPanel <- class{

    mParent_ = null;
    mBaseObj_ = null;
    mBus_ = null;

    constructor(parent, baseObj, bus){
        mParent_ = parent;
        mBaseObj_ = baseObj;
        mBus_ = bus;
    }

};