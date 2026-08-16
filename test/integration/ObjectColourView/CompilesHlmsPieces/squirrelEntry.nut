//The object colour pieces are only ever exercised by the shader compiler, and a
//mistake in one of them is a runtime failure in whichever project loaded the
//library rather than anything a script-level test would notice. So this renders a
//PBS object through a pass the view has been switched on for: the permutation is
//built the first time that object reaches the render queue, and a piece which
//does not compile takes the engine down with it before the frames below are
//counted out.
//
//The pass identifier is 0, which is what Ogre leaves a pass at unless it names
//one - so it is the default compositor's scene pass here, standing in for the
//editor's per-viewport passes in res/SceneEditor.compositor.
//
//avSetup.cfg is what puts res/hlms/pbs on the pbs library path, exactly as a
//project using the editor has to. @see README.md
const DEFAULT_PASS_IDENTIFIER = 0;
//Enough frames for the item to have been drawn, well inside the setup's timeout.
const RENDERED_FRAMES = 5;

function start(){
    ::view <- ::SceneEditorFramework.ObjectColourView(DEFAULT_PASS_IDENTIFIER);
    _test.assertTrue(view.isAvailable());
    view.setEnabled(true);

    _camera.setPosition(0, 0, 10);
    _camera.lookAt(0, 0, 0);

    ::node <- _scene.getRootSceneNode().createChildSceneNode();
    local item = _scene.createItem("arrow.obj");
    item.setDatablock(_hlms.pbs.createDatablock("SceneEditorObjectColourTest"));
    node.attachObject(item);

    ::frames <- 0;
}

function update(){
    frames++;
    if(frames < RENDERED_FRAMES) return;

    _test.endTest();
}
