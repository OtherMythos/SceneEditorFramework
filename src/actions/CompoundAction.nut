//Several actions treated as one undoable step.
//
//An edit which has to change two different things at once has no single action
//to describe it: a scale drag anchored to one side of an object resizes it and
//moves it, and half of that undone would leave the object the size the drag
//made it in a place the drag never put it. Grouping the two keeps them
//together on the stack, so one undo takes back the whole edit.
//@see SceneEditorFramework.SceneTree.setSelectedNodeScaleOneSided
::SceneEditorFramework.Actions[SceneEditorFramework_Action.COMPOUND] = class extends ::SceneEditorFramework.Action{

    mActions_ = null;

    constructor(actions){
        mActions_ = clone actions;
    }

    #Override
    function performAction(){
        foreach(action in mActions_){
            action.performAction();
        }
    }

    //Backwards, so an action which was performed against what the one before it
    //had already done is taken back before that one is.
    #Override
    function performAntiAction(){
        for(local i = mActions_.len() - 1; i >= 0; i--){
            mActions_[i].performAntiAction();
        }
    }
};
