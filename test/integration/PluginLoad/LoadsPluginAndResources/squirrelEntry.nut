function start(){
    _test.assertTrue(_plugin.isLoaded("avEngineSceneEditorPlugin"));
    _test.assertTrue("SceneEditorFramework" in ::getroottable());
    _test.assertEqual("class", typeof ::SceneEditorFramework.ActionStack);
    _test.assertEqual("class", typeof ::SceneEditorFramework.SceneTree);

    _test.assertEqual("SceneEditor/general", _resources.findGroupContainingResource("arrow.mesh"));
    _test.assertEqual("SceneEditor/general", _resources.findGroupContainingResource("scaleHandle.mesh"));

    _test.endTest();
}
