enum SceneEditorBusEvents{
    NONE,
};

::SceneEditorFramework.SceneEditorBus <- class{

    mSubscribed_ = null;

    constructor(){
        mSubscribed_ = [];
    }

    function subscribeObject(object){
        mSubscribed_.append(object);
    }

    function transmitEvent(event, data){
        foreach(i in mSubscribed_){
            i.notifyBusEvent(event, data);
        }
    }

};