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

        //Constructing a rotation gizmo loads the torus mesh and builds one
        //queryable ring for each axis. Two is the plugin's ORIENTATION enum;
        //the test was compiled before plugin enums were available by name.
        local rotationHandles = ::SceneEditorFramework.SceneEditorGizmoRotationHandles(
            _scene.getRootSceneNode().createChildSceneNode(), 2,
            editorBase.mBus_, 0);
        _test.assertEqual(3, rotationHandles.mHandles_.len());

        //Each ring is selected by proximity to its circular path, independently
        //of the overlapping mesh AABBs. Aim along each ring's normal at a point
        //which belongs only to that circle.
        local ringOffset = 2.15 / sqrt(2.0);
        _test.assertEqual(0, rotationHandles.pickAxisForRay_(Ray(
            Vec3(10, ringOffset, ringOffset), Vec3(-1, 0, 0))));
        _test.assertEqual(1, rotationHandles.pickAxisForRay_(Ray(
            Vec3(ringOffset, 10, ringOffset), Vec3(0, -1, 0))));
        _test.assertEqual(2, rotationHandles.pickAxisForRay_(Ray(
            Vec3(ringOffset, ringOffset, 10), Vec3(0, 0, -1))));
        _test.assertEqual(null, rotationHandles.pickAxisForRay_(Ray(
            Vec3(10, 10, 10), Vec3(0, 0, -1))));
        rotationHandles.shutdown();

        //The position gizmo has its usual three axis arms plus one plane handle
        //for each pair of axes. The plane constraints preserve only the axis
        //perpendicular to that plane.
        local positionHandles = ::SceneEditorFramework.SceneEditorGizmoObjectHandles(
            _scene.getRootSceneNode().createChildSceneNode(), 0,
            editorBase.mBus_, 0);
        _test.assertEqual(6, positionHandles.mPositionHandles_.len());
        local point = Vec3(1, 2, 3);
        local reference = Vec3(10, 20, 30);
        assertVec3(Vec3(10, 2, 3),
            positionHandles.constrainMovement_(point, reference, 3));
        assertVec3(Vec3(1, 20, 3),
            positionHandles.constrainMovement_(point, reference, 4));
        assertVec3(Vec3(1, 2, 30),
            positionHandles.constrainMovement_(point, reference, 5));
        positionHandles.shutdown();

        //The selection outline uses eight independently positioned corner
        //brackets. Its arms remain uniformly sized for non-uniform bounds.
        local outline = ::SceneEditorFramework.SceneEditorGizmoOutlineBox(
            _scene.getRootSceneNode().createChildSceneNode(), editorBase.mBus_);
        outline.setBounds(Vec3(10, 20, 30), Vec3(4, 2, 1));
        _test.assertEqual(8, outline.mCornerNodes_.len());
        _test.assertEqual(3, outline.mCornerNodes_[0].getNumChildren());
        //Corners sit just outside the AABB, which prevents depth fighting with
        //a selected cube or any other mesh which exactly matches its bounds.
        //The same distance on every axis, whatever the bounds: the gap is added
        //to the half size rather than scaling it.
        assertVec3(Vec3(-4.05, -2.05, -1.05), outline.mCornerNodes_[0].getPositionVec3());
        assertVec3(Vec3(4.05, 2.05, 1.05), outline.mCornerNodes_[7].getPositionVec3());
        _test.assertEqual(0.25, outline.mArmNodes_[0][0].getScale().y);
        _test.assertEqual(0.25, outline.mArmNodes_[7][2].getScale().y);
        outline.shutdown();
    }

    ::SceneEditorFramework.HelperFunctions = defaultHelpers;
    cameraNode.destroyNodeAndChildren();

    _test.endTest();
}

function assertVec3(expected, found){
    assertClose(expected.x, found.x);
    assertClose(expected.y, found.y);
    assertClose(expected.z, found.z);
}

function assertClose(expected, found){
    local difference = expected - found;
    if(difference < 0) difference = -difference;
    _test.assertTrue(difference <= 0.001);
}
