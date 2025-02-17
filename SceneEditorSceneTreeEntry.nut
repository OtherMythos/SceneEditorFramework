::SceneEditorFramework.SceneTreeMeshData <- class{
    meshName = null;
};
::SceneEditorFramework.SceneTreeUserEntryData <- class{
    value = null;
};

::SceneEditorFramework.SceneTreeEntry <- class{

    entryId = null;
    position = null;
    scale = null;
    orientation = null;
    nodeType = SceneEditorFramework_SceneTreeEntryType.NONE;
    animIdx = -1;

    node = null;
    data = null;

    constructor(){

    }

    function destroy(){
        if(node != null){
            node.destroyNodeAndChildren();
            node = null;
        }
    }

    function reset(){
        position = Vec3();
        scale = Vec3(1, 1, 1);
        orientation = Quat();
    }

    function setPosition(pos, absolute=false){
        if(absolute){
            node.setDerivedPosition(pos);
        }else{
            node.setPosition(pos);
        }
        position = node.getPositionVec3();
        //position = pos.copy();
    }

    function getPositionDerived(){
        return node.getDerivedPositionVec3();
    }

    function setScale(newScale){
        scale = newScale.copy();
        node.setScale(newScale);
    }

    function setOrientation(newOrientation){
        orientation = newOrientation.copy();
        node.setOrientation(newOrientation);
    }

}