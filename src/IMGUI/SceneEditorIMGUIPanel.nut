::SceneEditorFramework.IMGUI.Panel <- class{

    mBaseObj_ = null;
    mBus_ = null;
    mVisible_ = true;

    constructor(baseObj, bus){
        mBaseObj_ = baseObj;
        mBus_ = bus;
    }

    function setup(){
    }

    function shutdown(){
    }

    //Kept for parity with the retained GUI panels. Immediate-mode panels have
    //no resize work because ImGui owns their layout.
    function resize(newSize){
    }

    function update(){
    }

    function setVisible(visible){
        mVisible_ = visible;
    }

    function isVisible(){
        return mVisible_;
    }

    function toggleVisible(){
        mVisible_ = !mVisible_;
    }

    function draw(){
    }
};
