::SceneEditorFramework.IMGUI.ObjectPropertyEntryMesh <- class{

    static function draw(entry){
        _imgui.separatorText("Mesh");
        _imgui.labelText("Resource", entry.data.meshName);
    }
};
