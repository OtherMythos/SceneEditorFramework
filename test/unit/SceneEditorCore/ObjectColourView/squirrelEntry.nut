//The per-pass switch behind the flat per-object colouring. What the shader makes
//of the property is left to the integration test, which renders through it; what
//is checked here is that a view can be aimed at one pass, that it starts off, and
//that two of them do not stand on each other - the whole point of the setting
//being per pass is that one viewport can be in this mode while another is not.

function start(){
    local baseId = ::SceneEditorFramework.SCENE_PASS_IDENTIFIER_BASE;

    local first = ::SceneEditorFramework.ObjectColourView(baseId);
    _test.assertTrue(first.isAvailable());

    //Off until it is asked for: a viewport opens on the lit scene.
    _test.assertFalse(first.isEnabled());
    first.toggleEnabled();
    _test.assertTrue(first.isEnabled());

    //Setting what it already is is not an error, and does not flip it back.
    first.setEnabled(true);
    _test.assertTrue(first.isEnabled());
    first.setEnabled(false);
    _test.assertFalse(first.isEnabled());

    local second = ::SceneEditorFramework.ObjectColourView(baseId + 1);
    first.setEnabled(true);
    _test.assertTrue(first.isEnabled());
    _test.assertFalse(second.isEnabled());

    //A gizmo layer is handed back when a viewport closes and reused by the next
    //one, so a view built for a pass another view had switched on must start from
    //its own setting rather than from whatever was left on the pass.
    local reused = ::SceneEditorFramework.ObjectColourView(baseId);
    _test.assertFalse(reused.isEnabled());

    _test.endTest();
}
