::ExampleEditor <- {
    mBase_ = null
    mSceneParent_ = null

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

    function showPanel_(panelId, title, position){
        if(::guiFrameworkBase.windowForIdExists(panelId)) return;

        local window = ::guiFrameworkBase.createWindow(panelId, title);
        window.setPosition(position);
        window.setSize(280, 360);
        mBase_.setupGUIWindow(panelId, window.getWin());
    }

    function start(){
        _gui.setCanvasSize(_window.getSize(), _window.getActualSize());
        _doFile("res://editorGUIFramework/src/EditorGUIFramework.nut");

        ::SceneEditorFramework.HelperFunctions = {
            function sceneEditorInteractable(){
                return !::guiFrameworkBase.mouseInteracting();
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
        };

        ::guiFrameworkBase <- ::EditorGUIFramework.Base();
        ::guiFrameworkBase.setToolbar(::EditorGUIFramework.Toolbar([
            ["File", [
                ["Save", function(){ ::ExampleEditor.mBase_.writeSceneFile("res://res/example.avScene"); }]
            ]],
            ["Edit", [
                ["Undo", function(){ ::ExampleEditor.mBase_.mActionStack_.undo(); }],
                ["Redo", function(){ ::ExampleEditor.mBase_.mActionStack_.redo(); }],
                ["Position", function(){ ::ExampleEditor.mBase_.getActiveSceneTree().setObjectTransformCoordinateType(::ExampleEditor.TRANSFORM_POSITION); }],
                ["Scale", function(){ ::ExampleEditor.mBase_.getActiveSceneTree().setObjectTransformCoordinateType(::ExampleEditor.TRANSFORM_SCALE); }]
            ]],
            ["Window", [
                ["Scene Tree", function(){ ::ExampleEditor.showPanel_(::ExampleEditor.PANEL_SCENE_TREE, "Scene Tree", Vec2(20, 60)); }],
                ["Object Properties", function(){ ::ExampleEditor.showPanel_(::ExampleEditor.PANEL_OBJECT_PROPERTIES, "Object Properties", Vec2(320, 60)); }]
            ]]
        ]));

        local listener = class extends ::EditorGUIFramework.WindowManagerListener{
            function resized(id, size){
                ::ExampleEditor.mBase_.resizeGUIWindow(id, size);
            }

            function closed(id){
                ::ExampleEditor.mBase_.closeGUIWindow(id);
            }
        }();
        ::guiFrameworkBase.attachWindowManagerListener(listener);

        setupLights_();
        _camera.setPosition(12, 8, 15);
        _camera.setDirection(Vec3(-12, -8, -15));

        mBase_ = ::SceneEditorFramework.Base();
        mSceneParent_ = _scene.getRootSceneNode().createChildSceneNode();
        mBase_.setActiveSceneTree(mBase_.loadSceneTree(mSceneParent_, "res://res/example.avScene"));

        showPanel_(PANEL_SCENE_TREE, "Scene Tree", Vec2(20, 60));
        showPanel_(PANEL_OBJECT_PROPERTIES, "Object Properties", Vec2(320, 60));
    }

    function update(){
        mBase_.update();
        ::guiFrameworkBase.update();
        ::guiFrameworkBase.setMousePosition(_input.getMouseX(), _input.getMouseY());
        ::guiFrameworkBase.setMouseButton(0, _input.getMouseButton(_MB_LEFT));
        ::guiFrameworkBase.setMouseButton(1, _input.getMouseButton(_MB_RIGHT));
    }

    function sceneSafeUpdate(){
        mBase_.sceneSafeUpdate();
    }

    function end(){
        mBase_.shutdown();
        ::guiFrameworkBase.shutdown();
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
