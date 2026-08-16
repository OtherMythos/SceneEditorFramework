//Move several objects at once as one undoable step.
//
//BasicCoordinatesChangeAction describes a single object, which is what a gizmo
//drag or a properties field asks for. An edit which moves an object and then
//compensates for it elsewhere - centring a node on what hangs below it - has to
//leave one entry in the undo stack rather than one per object, since a half
//applied one would move the objects apart.
//
//Positions are local to each object's parent, so the same numbers can be
//applied again whatever else has happened between times.
::SceneEditorFramework.Actions[SceneEditorFramework_Action.MULTIPLE_POSITIONS_CHANGE] = class extends ::SceneEditorFramework.Action{

    mSceneTree_ = null;
    mBus_ = null;
    //One entry per object, each {"id", "old", "new"}.
    mChanges_ = null;

    constructor(sceneTree, bus, changes){
        mSceneTree_ = sceneTree;
        mBus_ = bus;
        mChanges_ = clone changes;
    }

    #Override
    function performAction(){
        perform_("new");
    }

    #Override
    function performAntiAction(){
        perform_("old");
    }

    //Parents come before their children in the changes, which is the order the
    //tree holds them in, so a child is put in its place against a parent which
    //has already been moved.
    function perform_(key){
        foreach(change in mChanges_){
            local entry = mSceneTree_.getEntryForId(change.id);
            if(entry == null) continue;

            entry.setPosition(change[key]);

            local data = {
                "id": change.id,
                "pos": change[key]
            }
            mBus_.transmitEvent(SceneEditorFramework_BusEvents.OBJECT_POSITION_CHANGE, data);
        }
    }
};
