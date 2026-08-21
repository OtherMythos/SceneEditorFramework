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
    //The action which was on top of the undo stack the last time the scene was
    //written to disk, or null when that was with nothing done at all. The scene
    //on disk matches the one in the editor exactly while the stack is back at
    //that point, which is what makes this the answer to whether there is
    //anything unsaved. @see hasUnsavedChanges
    //
    //The action itself rather than a count of them, because undoing back to a
    //count and then doing something else arrives at the same depth by a
    //different route - and that is a scene which no longer matches the file.
    mSavedAction_ = null;

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
        mUndoStack_.append(action);

        clearRedoStack_();
        //TODO check if the size has exceeded.
    }

    function clearRedoStack_(){
        mRedoStack_.clear();
    }

    /** Forget every action and make the current scene the clean baseline. */
    function clear(){
        mUndoStack_.clear();
        mRedoStack_.clear();
        mSavedAction_ = null;
    }

    /**
     * Record that the scene as it stands has been written to disk, so that
     * nothing counts as unsaved until something else is done to it.
     */
    function markSaved(){
        mSavedAction_ = mUndoStack_.len() <= 0 ? null : mUndoStack_.top();
    }

    /**
     * Whether the scene has been changed since it was last saved.
     *
     * An action which was saved and has since been undone past counts as
     * unsaved, and redoing back to it counts as saved again - the file is what
     * it is regardless of which direction the stack was walked to reach it.
     */
    function hasUnsavedChanges(){
        local current = mUndoStack_.len() <= 0 ? null : mUndoStack_.top();
        return current != mSavedAction_;
    }

}
