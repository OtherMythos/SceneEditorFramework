::ExampleEditor <- {
    mBase_ = null
    mSceneParent_ = null
    mSceneTreePanel_ = null
    mObjectPropertiesPanel_ = null
    //sceneSafeUpdate runs before the next ImGui frame is built. Keep the
    //previous frame's capture result so that asking the framework whether the
    //scene is interactable never starts an ImGui frame too early.
    mSceneEditorInteractable_ = true

    PANEL_SCENE_TREE = 0
    PANEL_OBJECT_PROPERTIES = 1
    TRANSFORM_POSITION = 0
    TRANSFORM_SCALE = 1

    function setupLights_(){
        local light = _scene.createLight();
        local lightNode = _scene.getRootSceneNode().createChildSceneNode();
        lightNode.attachObject(light);

        light.setType(_LIGHT_DIRECTIONAL);
        light.setDirection(-1, -1, -1);
        light.setPowerScale(PI);
        _scene.setAmbientLight(ColourValue(0.7, 0.7, 0.7, 1), ColourValue(0.7, 0.7, 0.7, 1), Vec3(0, 1, 0));
    }

    function start(){
        if(!("_imgui" in getroottable())){
            throw "The example requires the AvImguiPlugin. See example/plugins/README.md.";
        }

        ::SceneEditorFramework.HelperFunctions = {
            function sceneEditorInteractable(){
                return ::ExampleEditor.mSceneEditorInteractable_;
            }

            function sceneTreeConstructObjectForUserEntry(userId, parentNode, entryData){}

            function getNameForUserEntry(userId){
                return "User" + userId;
            }

            function raycastForMovementGizmo(){
                return Vec3();
            }

            function basicMouseInteractionEnabled(){
                return true;
            }

            function drawIMGUIObjectPropertiesForUserEntry(userId, entry){
            }
        };

        setupLights_();
        _camera.setPosition(12, 8, 15);
        _camera.setDirection(Vec3(-12, -8, -15));

        mBase_ = ::SceneEditorFramework.Base();
        mSceneParent_ = _scene.getRootSceneNode().createChildSceneNode();
        mBase_.setActiveSceneTree(mBase_.loadSceneTree(mSceneParent_, "res://res/example.avScene"));

        mSceneTreePanel_ = mBase_.setupIMGUIWindow(PANEL_SCENE_TREE, ::SceneEditorFramework.IMGUI.SceneTree);
        mObjectPropertiesPanel_ = mBase_.setupIMGUIWindow(PANEL_OBJECT_PROPERTIES, ::SceneEditorFramework.IMGUI.ObjectProperties);
    }

    function update(){
        mBase_.update();
        if(!_imgui.isFirstUpdateOfFrame()) return;

        drawMenuBar_();
        mBase_.drawIMGUI();
        mSceneEditorInteractable_ = !_imgui.wantCaptureMouse();
    }

    function drawMenuBar_(){
        if(!_imgui.beginMainMenuBar()) return;

        if(_imgui.beginMenu("File")){
            if(_imgui.menuItem("Save")){
                mBase_.writeSceneFile("res://res/example.avScene");
            }
            _imgui.endMenu();
        }

        if(_imgui.beginMenu("Edit")){
            if(_imgui.menuItem("Undo")) mBase_.mActionStack_.undo();
            if(_imgui.menuItem("Redo")) mBase_.mActionStack_.redo();
            _imgui.separator();
            if(_imgui.menuItem("Position")){
                mBase_.getActiveSceneTree().setObjectTransformCoordinateType(::ExampleEditor.TRANSFORM_POSITION);
            }
            if(_imgui.menuItem("Scale")){
                mBase_.getActiveSceneTree().setObjectTransformCoordinateType(::ExampleEditor.TRANSFORM_SCALE);
            }
            _imgui.endMenu();
        }

        if(_imgui.beginMenu("Window")){
            if(_imgui.menuItem("Scene Tree", null, mSceneTreePanel_.isVisible())){
                mSceneTreePanel_.toggleVisible();
            }
            if(_imgui.menuItem("Object Properties", null, mObjectPropertiesPanel_.isVisible())){
                mObjectPropertiesPanel_.toggleVisible();
            }
            _imgui.endMenu();
        }

        _imgui.endMainMenuBar();
    }

    function sceneSafeUpdate(){
        mBase_.sceneSafeUpdate();
    }

    function end(){
        mBase_.shutdown();
    }
};

function start(){
    ::ExampleEditor.start();
}

function update(){
    ::ExampleEditor.update();
}

function sceneSafeUpdate(){
    ::ExampleEditor.sceneSafeUpdate();
}

function end(){
    ::ExampleEditor.end();
}
