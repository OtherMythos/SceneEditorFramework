//getNormalisedSceneMousePosition is what turns the cursor into a position in
//the scene. A project which renders the scene into part of the window - an
//imgui panel showing a render texture, say - describes that region by
//implementing normalisedSceneMousePosition; one which does not gets the whole
//window, which is where the scene is by default.
function start(){
    local defaultHelpers = ::SceneEditorFramework.HelperFunctions;

    { //With no hook the position covers the whole window, so the middle of the
      //window is the middle of the scene.
        _test.assertFalse("normalisedSceneMousePosition" in defaultHelpers);

        local windowSize = _window.getSize();
        local expected = Vec2(_input.getMouseX(), _input.getMouseY()) / windowSize;
        local found = ::SceneEditorFramework.getNormalisedSceneMousePosition();

        _test.assertEqual(expected.x, found.x);
        _test.assertEqual(expected.y, found.y);
    }

    { //A project which supplies the hook is asked instead.
        ::SceneEditorFramework.HelperFunctions = {
            function normalisedSceneMousePosition(){
                return Vec2(0.25, 0.75);
            }
        };

        local found = ::SceneEditorFramework.getNormalisedSceneMousePosition();
        _test.assertEqual(0.25, found.x);
        _test.assertEqual(0.75, found.y);
    }

    { //Null means there is no scene viewport at all, which the framework treats
      //as the mouse not being over the scene rather than as an error.
        ::SceneEditorFramework.HelperFunctions = {
            function normalisedSceneMousePosition(){
                return null;
            }
        };

        _test.assertEqual(null, ::SceneEditorFramework.getNormalisedSceneMousePosition());
    }

    ::SceneEditorFramework.HelperFunctions = defaultHelpers;

    _test.endTest();
}
