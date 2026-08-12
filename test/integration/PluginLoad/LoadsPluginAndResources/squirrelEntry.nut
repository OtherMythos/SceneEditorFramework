function start(){
    _test.assertTrue(_plugin.isLoaded("avEngineSceneEditorPlugin"));
    _test.assertTrue("SceneEditorFramework" in ::getroottable());
    _test.assertEqual("class", typeof ::SceneEditorFramework.ActionStack);
    _test.assertEqual("class", typeof ::SceneEditorFramework.SceneTree);

    _test.assertEqual("SceneEditor/general", _resources.findGroupContainingResource("arrow.obj"));
    _test.assertEqual("SceneEditor/general", _resources.findGroupContainingResource("scaleHandle.obj"));

    _test.endTest();
}
