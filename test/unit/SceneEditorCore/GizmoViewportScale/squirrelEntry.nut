//A gizmo is sized by its distance from the camera, which keeps it the same
//fraction of the view - and so shrinks it along with a viewport which is docked
//down small. getGizmoViewportScale is what grows it back, and
//getGizmoLayerViewportSizes is where the sizes it works from come from.
function start(){
    local defaultHelpers = ::SceneEditorFramework.HelperFunctions;
    local reference = ::SceneEditorFramework.GIZMO_REFERENCE_VIEWPORT_HEIGHT;
    local minimum = ::SceneEditorFramework.GIZMO_MIN_VIEWPORT_SCALE;
    local maximum = ::SceneEditorFramework.GIZMO_MAX_VIEWPORT_SCALE;

    { //A viewport of the reference height is the one the gizmo's world size was
      //chosen for, so it is left exactly as its distance asks for.
        assertClose(1.0, ::SceneEditorFramework.getGizmoViewportScale(
            [reference * 2.0, reference]));
    }

    { //Half the height gets twice the world size, which is the same number of
      //pixels. Width does not come into it while the viewport is wider than it
      //is tall: a perspective camera shows the same amount of the world up and
      //down whatever its aspect ratio.
        assertClose(2.0, ::SceneEditorFramework.getGizmoViewportScale(
            [reference, reference / 2.0]));
        assertClose(2.0, ::SceneEditorFramework.getGizmoViewportScale(
            [reference * 4.0, reference / 2.0]));
    }

    { //A viewport narrower than it is tall shows less of the world across than
      //up, so the gizmo comes in far enough to keep fitting inside it.
        assertClose(0.5, ::SceneEditorFramework.getGizmoViewportScale(
            [reference / 2.0, reference]));
    }

    { //Holding the pixel size exactly would leave a tiny viewport asking for a
      //gizmo big enough to swallow the scene, and a very large one with a gizmo
      //too small to see. Both stop at the bounds and go back to being a fraction
      //of the view.
        assertClose(maximum, ::SceneEditorFramework.getGizmoViewportScale(
            [reference, reference / 100.0]));
        assertClose(minimum, ::SceneEditorFramework.getGizmoViewportScale(
            [reference * 100.0, reference * 100.0]));
    }

    { //A viewport which has not been laid out yet, or one docked shut, has no
      //size worth sizing against - so the gizmo is left to its distance alone
      //rather than collapsing or blowing up.
        assertClose(1.0, ::SceneEditorFramework.getGizmoViewportScale(null));
        assertClose(1.0, ::SceneEditorFramework.getGizmoViewportScale([0, 0]));
        assertClose(1.0, ::SceneEditorFramework.getGizmoViewportScale([640, 0]));
    }

    { //With no hook the scene fills the window, so the window is the viewport
      //the single gizmo layer is drawn in.
        _test.assertFalse("gizmoLayerViewportSizes" in defaultHelpers);

        local sizes = ::SceneEditorFramework.getGizmoLayerViewportSizes();
        _test.assertEqual(1, sizes.len());

        local windowSize = _window.getSize();
        _test.assertEqual(windowSize.x, sizes[0][0]);
        _test.assertEqual(windowSize.y, sizes[0][1]);
    }

    { //A project with more than one viewport is asked instead, and answers by
      //layer. A layer no viewport is using has no size, which is the same
      //nothing-to-measure-against as a window which has not been laid out.
        ::SceneEditorFramework.HelperFunctions = {
            function gizmoLayerViewportSizes(){
                return [[1280, 720], null];
            }
        };

        local sizes = ::SceneEditorFramework.getGizmoLayerViewportSizes();
        _test.assertEqual(2, sizes.len());
        _test.assertEqual(1280, sizes[0][0]);
        _test.assertEqual(null, sizes[1]);
    }

    ::SceneEditorFramework.HelperFunctions = defaultHelpers;

    _test.endTest();
}

function assertClose(expected, found){
    local difference = expected - found;
    if(difference < 0) difference = -difference;
    _test.assertTrue(difference <= 0.001);
}
