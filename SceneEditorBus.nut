::SceneEditorFramework.SceneEditorBus <- class{

    mSubscribed_ = null;

    constructor(){
        mSubscribed_ = [];
    }

    function subscribeObject(object){
        mSubscribed_.append(object);
    }

    function unsubscribeObject(object){
        foreach(c,i in mSubscribed_){
            if(object == i){
                mSubscribed_.remove(c);
                return;
            }
        }
        throw "Object could not be found in the subscribed bus";
    }

    function transmitEvent(event, data){
        foreach(i in mSubscribed_){
            i.notifyBusEvent(event, data);
        }
    }

};