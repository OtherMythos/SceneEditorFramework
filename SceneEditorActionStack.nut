::SceneEditorFramework.Actions <- array(SceneEditorFramework_Action.MAX);

::SceneEditorFramework.Action <- class{
    function performAction(){

    }

    function performAntiAction(){

    }
}

::SceneEditorFramework.ActionStack <- class{

    mUndoStack_ = null;
    mRedoStack_ = null;

    constructor(){
        mUndoStack_ = [];
        mRedoStack_ = [];
    }

    function undo(){
        if(mUndoStack_.len() <= 0) return;

        local a = mUndoStack_.top();
        a.performAntiAction();
        mRedoStack_.append(a);
        mUndoStack_.pop();
    }

    function redo(){
        if(mRedoStack_.len() <= 0) return;

        local a = mRedoStack_.top();
        a.performAction();
        mUndoStack_.append(a);
        mRedoStack_.pop();
    }

    function pushAction_(action){
        print(mUndoStack_);
        mUndoStack_.append(action);

        clearRedoStack_();
        //TODO check if the size has exceeded.
    }

    function clearRedoStack_(){
        mRedoStack_.clear();
    }

}