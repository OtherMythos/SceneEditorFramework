function start(){
    local TestAction = class extends ::SceneEditorFramework.Action{
        mValue_ = null;

        constructor(value){
            mValue_ = value;
        }

        function performAction(){
            mValue_[0]++;
        }

        function performAntiAction(){
            mValue_[0]--;
        }
    };
    local TestListener = class{
        events = null;

        constructor(){
            events = [];
        }

        function notifyBusEvent(event, data){
            events.append([event, data]);
        }
    };

    local actionStack = ::SceneEditorFramework.ActionStack();
    local value = [0];
    local action = TestAction(value);

    actionStack.pushAction_(action);
    _test.assertEqual(1, actionStack.mUndoStack_.len());
    _test.assertEqual(0, actionStack.mRedoStack_.len());

    actionStack.undo();
    _test.assertEqual(-1, value[0]);
    _test.assertEqual(0, actionStack.mUndoStack_.len());
    _test.assertEqual(1, actionStack.mRedoStack_.len());

    actionStack.redo();
    _test.assertEqual(0, value[0]);
    _test.assertEqual(1, actionStack.mUndoStack_.len());
    _test.assertEqual(0, actionStack.mRedoStack_.len());

    actionStack.undo();
    actionStack.pushAction_(TestAction(value));
    actionStack.redo();
    _test.assertEqual(-1, value[0]);

    actionStack.markSaved();
    actionStack.undo();
    actionStack.clear();
    _test.assertEqual(0, actionStack.mUndoStack_.len());
    _test.assertEqual(0, actionStack.mRedoStack_.len());
    _test.assertFalse(actionStack.hasUnsavedChanges());

    local bus = ::SceneEditorFramework.SceneEditorBus();
    local firstListener = TestListener();
    local secondListener = TestListener();
    bus.subscribeObject(firstListener);
    bus.subscribeObject(secondListener);

    bus.transmitEvent(17, "first");
    _test.assertEqual(1, firstListener.events.len());
    _test.assertEqual(1, secondListener.events.len());
    _test.assertEqual(17, firstListener.events[0][0]);
    _test.assertEqual("first", secondListener.events[0][1]);

    bus.unsubscribeObject(firstListener);
    bus.transmitEvent(18, "second");
    _test.assertEqual(1, firstListener.events.len());
    _test.assertEqual(2, secondListener.events.len());
    _test.assertEqual(18, secondListener.events[1][0]);

    _test.endTest();
}
