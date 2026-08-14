//Replaces the renderable attached to a mesh entry and retains both resource
//names for undo/redo.
::SceneEditorFramework.Actions[SceneEditorFramework_Action.CHANGE_MESH_RESOURCE] = class extends ::SceneEditorFramework.Action{

    mSceneTree_ = null;
    mBus_ = null;
    mId_ = null;
    mOldMesh_ = null;
    mNewMesh_ = null;

    constructor(sceneTree, bus, id, oldMesh, newMesh){
        mSceneTree_ = sceneTree;
        mBus_ = bus;
        mId_ = id;
        mOldMesh_ = oldMesh;
        mNewMesh_ = newMesh;
    }

    function performAction(){ perform_(mNewMesh_); }
    function performAntiAction(){ perform_(mOldMesh_); }

    function perform_(meshName){
        local entry = mSceneTree_.getEntryForId(mId_);
        if(entry == null || entry.nodeType != SceneEditorFramework_SceneTreeEntryType.MESH) return;
        entry.data.meshName = meshName;
        mSceneTree_.regenerateSceneEntry(mId_);
        mBus_.transmitEvent(SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE, entry);
    }
};
