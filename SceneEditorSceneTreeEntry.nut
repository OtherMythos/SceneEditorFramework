::SceneEditorFramework.SceneTreeMeshData <- class{
    meshName = null;
};

::SceneEditorFramework.SceneTreeEntry <- class{

    entryId = 0;
    position = null;
    scale = null;
    orientation = null;
    nodeType = SceneTreeEntryType.NONE;

    node = null;
    data = null;

    constructor(){

    }

    function reset(){
        position = Vec3();
        scale = Vec3(1, 1, 1);
        orientation = Quat();
    }

}