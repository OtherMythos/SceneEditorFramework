//Which camera the framework casts the cursor's ray from.
//
//An editor with more than one viewport has a camera per viewport, and only it
//knows which one the cursor is working in, so it says with activeSceneCamera. One
//with a single viewport says nothing and gets the engine's default camera, which
//is the only one it has.
function start(){
    local defaultHelpers = ::SceneEditorFramework.HelperFunctions;

    { //With no hook the scene is seen through the default camera.
        _test.assertFalse("activeSceneCamera" in defaultHelpers);

        _test.assertNotEqual(null, ::SceneEditorFramework.getActiveSceneCamera());

        local expected = _camera.getPosition();
        local found = ::SceneEditorFramework.getActiveSceneCameraPosition();
        _test.assertEqual(expected.x, found.x);
        _test.assertEqual(expected.y, found.y);
        _test.assertEqual(expected.z, found.z);
    }

    local cameraNode = _scene.getRootSceneNode().createChildSceneNode();
    local camera = _scene.createCamera("sceneEditorTest/camera");
    cameraNode.attachObject(camera);
    cameraNode.setPosition(Vec3(4, 5, 6));

    { //A project which supplies the hook is asked instead, and the camera it
      //names is placed by the node it is attached to.
        ::SceneEditorFramework.HelperFunctions = {
            function activeSceneCamera(){
                return camera;
            }
        };

        _test.assertNotEqual(null, ::SceneEditorFramework.getActiveSceneCamera());

        local found = ::SceneEditorFramework.getActiveSceneCameraPosition();
        _test.assertEqual(4, found.x);
        _test.assertEqual(5, found.y);
        _test.assertEqual(6, found.z);
    }

    { //Null means no viewport is showing the scene - every one of them has been
      //closed - which the framework treats as there being nothing to cast a ray
      //through rather than as an error.
        ::SceneEditorFramework.HelperFunctions = {
            function activeSceneCamera(){
                return null;
            }
        };

        _test.assertEqual(null, ::SceneEditorFramework.getActiveSceneCamera());
        _test.assertEqual(null, ::SceneEditorFramework.getActiveSceneCameraPosition());
    }

    { //Nothing can be under the cursor when there is no camera to look for it
      //with, and asking is not an error either.
      //
      //Through a Base, which is what creates the datablocks the gizmos a scene
      //tree builds are drawn with.
        local editorBase = ::SceneEditorFramework.Base();
        local tree = ::SceneEditorFramework.SceneTree(
            _scene.getRootSceneNode().createChildSceneNode(),
            editorBase.mActionStack_, editorBase.mBus_);

        _test.assertEqual(null, tree.findEntryIdAtScenePosition(Vec2(0.5, 0.5)));
        _test.assertEqual(0, tree.findEntryIdsAtScenePosition(Vec2(0.5, 0.5)).len());
    }

    ::SceneEditorFramework.HelperFunctions = defaultHelpers;
    cameraNode.destroyNodeAndChildren();

    _test.endTest();
}
