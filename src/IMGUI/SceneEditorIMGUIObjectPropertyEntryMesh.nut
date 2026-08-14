::SceneEditorFramework.IMGUI.ObjectPropertyEntryMesh <- class{

    static function draw(entry, baseObj, bus, resourcePicker){
        _imgui.separatorText("Mesh");
        local entryId = entry.entryId;
        local oldMesh = entry.data.meshName;
        local assign = function(resource){
            if(resource == null || resource.kind != "mesh" || resource.name == oldMesh) return;
            local sceneTree = baseObj.getActiveSceneTree();
            local A = ::SceneEditorFramework.Actions[
                SceneEditorFramework_Action.CHANGE_MESH_RESOURCE];
            local action = A(sceneTree, bus, entryId, oldMesh, resource.name);
            baseObj.pushAction(action);
            action.performAction();
        };
        ::SceneEditorFramework.IMGUI.ResourceButton.draw(
            "meshResource" + entryId, entry.data.meshName, "mesh",
            resourcePicker, assign);
    }
};
