::SceneEditorFramework.Actions[SceneEditorFramework_Action.BASIC_COORDINATES_CHANGE] = class extends ::SceneEditorFramework.Action{

    mSceneTree_ = null;
    mBus_ = null;
    mId_ = null;
    mOld_ = null;
    mNew_ = null;
    mCoordType_ = null;

    constructor(sceneTree, bus, id, oldVal, newVal, coordType){
        mSceneTree_ = sceneTree;
        mBus_ = bus;
        mId_ = id;
        mOld_ = oldVal;
        mNew_ = newVal;
        mCoordType_ = coordType;
    }

    #Override
    function performAction(){
        perform_(mNew_);
    }

    #Override
    function performAntiAction(){
        perform_(mOld_);
    }

    function perform_(targetData){

        if(mCoordType_ == SceneEditorFramework_BasicCoordinateType.POSITION){
            mSceneTree_.getEntryForId(mId_).setPosition(targetData);

            local data = {
                "id": mId_,
                "pos": targetData
            }
            mBus_.transmitEvent(SceneEditorFramework_BusEvents.OBJECT_POSITION_CHANGE, data);
        }
        else if(mCoordType_ == SceneEditorFramework_BasicCoordinateType.SCALE){
            mSceneTree_.getEntryForId(mId_).setScale(targetData);

            local data = {
                "id": mId_,
                "scale": targetData
            }
            mBus_.transmitEvent(SceneEditorFramework_BusEvents.OBJECT_SCALE_CHANGE, data);
        }
    }
};

