//Transform several objects at once as one undoable step.
//
//BasicCoordinatesChangeAction describes a single object, which is what a
//properties field asks for. A gizmo drag made with more than one object
//selected asks for the same change of every one of them, and that is one edit
//rather than one per object: half of it applied would leave the selection
//moved, sized or turned apart from itself. An edit which moves an object and
//then compensates for it elsewhere - centring a node on what hangs below it -
//has the same need of a single step.
//
//The values are local to each object's parent, so the same numbers can be
//applied again whatever else has happened between times.
::SceneEditorFramework.Actions[SceneEditorFramework_Action.MULTIPLE_COORDINATES_CHANGE] = class extends ::SceneEditorFramework.Action{

    mSceneTree_ = null;
    mBus_ = null;
    //Which of position, scale and orientation the values describe.
    mCoordType_ = null;
    //One entry per object, each {"id", "old", "new"}.
    mChanges_ = null;

    constructor(sceneTree, bus, coordType, changes){
        mSceneTree_ = sceneTree;
        mBus_ = bus;
        mCoordType_ = coordType;
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
    //has already been transformed.
    function perform_(key){
        foreach(change in mChanges_){
            local entry = mSceneTree_.getEntryForId(change.id);
            if(entry == null) continue;

            local data = {
                "id": change.id
            };
            local event = null;

            if(mCoordType_ == SceneEditorFramework_BasicCoordinateType.POSITION){
                entry.setPosition(change[key]);
                data.pos <- change[key];
                event = SceneEditorFramework_BusEvents.OBJECT_POSITION_CHANGE;
            }
            else if(mCoordType_ == SceneEditorFramework_BasicCoordinateType.SCALE){
                entry.setScale(change[key]);
                data.scale <- change[key];
                event = SceneEditorFramework_BusEvents.OBJECT_SCALE_CHANGE;
            }
            else if(mCoordType_ == SceneEditorFramework_BasicCoordinateType.ORIENTATION){
                entry.setOrientation(change[key]);
                data.orientation <- change[key];
                event = SceneEditorFramework_BusEvents.OBJECT_ORIENTATION_CHANGE;
            }else{
                assert(false);
            }

            mBus_.transmitEvent(event, data);
        }
    }
};
