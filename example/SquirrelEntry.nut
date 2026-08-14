//A complete editor assembled from the framework's first-party ImGui shell.
//Project-specific editors generally only need to choose their scene and add
//optional callbacks in this table.
::ExampleEditor <- null;

function start(){
    ::ExampleEditor = ::SceneEditorFramework.IMGUI.Editor({
        "scenePath": "res://res/example.avScene",
        "statePath": "res://.editorState.json"
    });
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
