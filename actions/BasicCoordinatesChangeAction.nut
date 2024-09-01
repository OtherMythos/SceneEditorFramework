::SceneEditorFramework.Actions[SceneEditorFramework_Action.BASIC_COORDINATES_CHANGE] = class extends ::SceneEditorFramework.Action{

    mSceneTree_ = null;
    mId_ = null;
    mOld_ = null;
    mNew_ = null;
    mCoordType_ = null;

    constructor(sceneTree, id, oldVal, newVal, coordType){
        mSceneTree_ = sceneTree;
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
        }
        else if(mCoordType_ == SceneEditorFramework_BasicCoordinateType.SCALE){
            mSceneTree_.getEntryForId(mId_).setScale(targetData);
        }
    }
};

