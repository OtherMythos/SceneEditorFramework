//The camera which flies through the scene.
//
//Everything here is the half of it which does not involve the mouse: where the
//angles it is pointed by come from, what they are clamped to, and that a camera
//which has not been given the mouse does not move. What the mouse does with it
//cannot be tested without a window to move a cursor around in.
function assertClose(expected, found, message){
    local difference = expected - found;
    if(difference < 0) difference = -difference;

    if(difference > 0.001) print("Expected " + expected + " but found " + found + ": " + message);
    _test.assertTrue(difference <= 0.001);
}

function assertDirection(x, y, z, direction){
    assertClose(x, direction.x, "direction x");
    assertClose(y, direction.y, "direction y");
    assertClose(z, direction.z, "direction z");
}

function start(){
    local cameraNode = _scene.getRootSceneNode().createChildSceneNode();
    local camera = _scene.createCamera("sceneEditorTest/fpsCamera");
    cameraNode.attachObject(camera);

    { //A new camera starts from wherever the one it was handed is already
      //pointed, which for an untouched camera is down its own negative z.
        local fpsCamera = ::SceneEditorFramework.FPSCamera(camera);

        assertClose(270.0, fpsCamera.getYaw(), "an untouched camera faces negative z");
        assertClose(0.0, fpsCamera.getPitch(), "an untouched camera is level");
        assertDirection(0, 0, -1, fpsCamera.getDirection());
    }

    local fpsCamera = ::SceneEditorFramework.FPSCamera(camera);

    { //A direction is turned into the pair of angles the camera is flown by, and
      //does not have to be normalised to be understood.
        fpsCamera.setDirection(Vec3(2, 0, 0));
        assertClose(0.0, fpsCamera.getYaw(), "positive x is no yaw");
        assertClose(0.0, fpsCamera.getPitch(), "positive x is level");
        assertDirection(1, 0, 0, fpsCamera.getDirection());

        fpsCamera.setDirection(Vec3(0, 0, 1));
        assertClose(90.0, fpsCamera.getYaw(), "positive z is a quarter turn");
        assertDirection(0, 0, 1, fpsCamera.getDirection());

        fpsCamera.setDirection(Vec3(0, 1, 0));
        //Straight up is as far as the pitch goes, and the camera keeps the yaw
        //it had rather than taking one from a direction which has none.
        assertClose(89.0, fpsCamera.getPitch(), "straight up is clamped");
    }

    { //A direction of no length is not a direction, so the camera stays where it
      //was pointed rather than facing nowhere.
        fpsCamera.setDirection(Vec3(1, 0, 0));
        fpsCamera.setDirection(Vec3(0, 0, 0));

        assertClose(0.0, fpsCamera.getYaw(), "a direction of no length is ignored");
        assertDirection(1, 0, 0, fpsCamera.getDirection());
    }

    { //Any pair of numbers is somewhere to look: pitch is clamped short of
      //straight up and down, and yaw is wrapped into a single turn.
        fpsCamera.setYawPitch(45.0, 300.0);
        assertClose(89.0, fpsCamera.getPitch(), "pitch is clamped upwards");

        fpsCamera.setYawPitch(45.0, -300.0);
        assertClose(-89.0, fpsCamera.getPitch(), "pitch is clamped downwards");

        fpsCamera.setYawPitch(-90.0, 0.0);
        assertClose(270.0, fpsCamera.getYaw(), "a negative yaw wraps");

        fpsCamera.setYawPitch(450.0, 0.0);
        assertClose(90.0, fpsCamera.getYaw(), "a yaw past a full turn wraps");
    }

    { //The camera is placed by the node it is attached to.
        fpsCamera.setPosition(Vec3(1, 2, 3));

        local position = fpsCamera.getPosition();
        assertClose(1, position.x, "position x");
        assertClose(2, position.y, "position y");
        assertClose(3, position.z, "position z");

        local nodePosition = cameraNode.getPositionVec3();
        assertClose(1, nodePosition.x, "the node was moved");
    }

    { //A camera which has not been given the mouse does not take it, and a
      //camera which does not have it does not move.
        fpsCamera.setPosition(Vec3(0, 0, 0));

        _test.assertFalse(fpsCamera.update(false));
        _test.assertFalse(fpsCamera.isLooking());
        _test.assertFalse(fpsCamera.hasMoved());

        local position = fpsCamera.getPosition();
        assertClose(0, position.x, "a camera with no mouse stays put");
        assertClose(0, position.y, "a camera with no mouse stays put");
        assertClose(0, position.z, "a camera with no mouse stays put");
    }

    { //Giving up the mouse a camera never had is not an error.
        fpsCamera.cancel();
        _test.assertFalse(fpsCamera.isLooking());
    }

    { //How fast it flies and how far it turns are the project's to set.
        fpsCamera.setSpeed(2.5);
        assertClose(2.5, fpsCamera.getSpeed(), "speed");

        fpsCamera.setSensitivity(0.25);
        assertClose(0.25, fpsCamera.getSensitivity(), "sensitivity");

        fpsCamera.setPanSensitivity(0.01);
        assertClose(0.01, fpsCamera.getPanSensitivity(), "pan sensitivity");

        fpsCamera.setZoomSensitivity(0.2);
        assertClose(0.2, fpsCamera.getZoomSensitivity(), "zoom sensitivity");
    }

    { //Orbit changes position and direction around one fixed point. FPS and
      //orbit share the same transform, so there is no second camera to snap to.
        fpsCamera.setSensitivity(0.1);
        fpsCamera.setPanSensitivity(0.002);
        fpsCamera.setZoomSensitivity(0.15);
        fpsCamera.setPosition(Vec3(0, 0, 0));
        fpsCamera.setDirection(Vec3(0, 0, -1));
        fpsCamera.setOrbitDistance(10.0);

        fpsCamera.orbit(90.0, 0.0);
        assertDirection(1, 0, 0, fpsCamera.getDirection());
        local position = fpsCamera.getPosition();
        assertClose(-10, position.x, "orbit position x");
        assertClose(0, position.y, "orbit position y");
        assertClose(-10, position.z, "orbit position z");

        fpsCamera.zoom(1.0);
        assertClose(8.5, fpsCamera.getOrbitDistance(), "wheel zoom distance");
        position = fpsCamera.getPosition();
        assertClose(-8.5, position.x, "zoom moves towards the orbit point");
        assertClose(-10, position.z, "zoom retains the orbit point");

        fpsCamera.pan(10.0, 0.0);
        position = fpsCamera.getPosition();
        assertClose(-8.5, position.x, "pan retains camera depth");
        assertClose(-10.17, position.z, "pan follows horizontal mouse movement");

        //A new FPS position establishes a new point ahead, and the next orbit
        //starts there instead of returning to the old one.
        fpsCamera.setPosition(Vec3(2, 3, 4));
        fpsCamera.orbit(0.0, 10.0);
        position = fpsCamera.getPosition();
        _test.assertTrue(position.distance(Vec3(2, 3, 4)) > 0.001);
    }

    { //Camera poses animate with deterministic, eased progress. The target and
      //distance become the orbit state at every point along the transition.
        fpsCamera.setPosition(Vec3(0, 0, 0));
        fpsCamera.setDirection(Vec3(0, 0, -1));
        fpsCamera.setOrbitDistance(10.0);

        _test.assertTrue(fpsCamera.animateFrame(Vec3(10, 0, 0), 5.0, 1.0));
        _test.assertTrue(fpsCamera.isAnimating());
        _test.assertTrue(fpsCamera.updateAnimation(0.5));

        local position = fpsCamera.getPosition();
        assertClose(5, position.x, "animated position x at midpoint");
        assertClose(2.5, position.z, "animated position z at midpoint");
        assertClose(7.5, fpsCamera.getOrbitDistance(),
            "animated orbit distance at midpoint");
        assertDirection(0, 0, -1, fpsCamera.getDirection());

        _test.assertTrue(fpsCamera.updateAnimation(0.5));
        _test.assertFalse(fpsCamera.isAnimating());
        position = fpsCamera.getPosition();
        assertClose(10, position.x, "animated position x at end");
        assertClose(5, position.z, "animated position z at end");
        assertClose(5, fpsCamera.getOrbitDistance(), "animated orbit distance at end");

        //A zero-duration transition is also useful to callers which share the
        //pose API but allow animation to be disabled in configuration.
        _test.assertTrue(fpsCamera.animateTo(Vec3(0, 0, 0),
            Vec3(1, 0, 0), 0.0));
        assertDirection(1, 0, 0, fpsCamera.getDirection());
        _test.assertFalse(fpsCamera.isAnimating());
    }

    cameraNode.destroyNodeAndChildren();

    _test.endTest();
}
