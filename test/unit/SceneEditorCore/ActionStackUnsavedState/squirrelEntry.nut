//Whether the action stack knows the scene has been changed since it was last
//written to disk, which is what the editor marks its window title with.
function start(){
    local TestAction = class extends ::SceneEditorFramework.Action{
        function performAction(){}
        function performAntiAction(){}
    };

    local actionStack = ::SceneEditorFramework.ActionStack();

    //A stack which has never had anything done to it is a scene which matches
    //the file it was parsed from.
    _test.assertFalse(actionStack.hasUnsavedChanges());

    actionStack.pushAction_(TestAction());
    _test.assertTrue(actionStack.hasUnsavedChanges());

    actionStack.markSaved();
    _test.assertFalse(actionStack.hasUnsavedChanges());

    //Undoing past the save is a scene which no longer matches the file, and
    //redoing back to it is one which matches again.
    actionStack.undo();
    _test.assertTrue(actionStack.hasUnsavedChanges());
    actionStack.redo();
    _test.assertFalse(actionStack.hasUnsavedChanges());

    //Undoing the saved action and then doing something else reaches the same
    //stack depth by a different route, which is a scene that does not match.
    actionStack.undo();
    actionStack.pushAction_(TestAction());
    _test.assertTrue(actionStack.hasUnsavedChanges());

    //Saving with nothing on the stack at all, which is what undoing everything
    //back to a freshly loaded scene and saving it looks like.
    local emptyStack = ::SceneEditorFramework.ActionStack();
    emptyStack.pushAction_(TestAction());
    emptyStack.undo();
    emptyStack.markSaved();
    _test.assertFalse(emptyStack.hasUnsavedChanges());
    emptyStack.redo();
    _test.assertTrue(emptyStack.hasUnsavedChanges());

    _test.endTest();
}
