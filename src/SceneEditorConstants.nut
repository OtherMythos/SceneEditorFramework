
enum SceneEditorFramework_SceneTreeEntryType{
    NONE,

    CHILD,
    TERM,

    EMPTY,
    MESH,
    USER0,
    USER1,
    USER2,
    USER3,
};

enum SceneEditorFramework_BusEvents{
    NONE,
    SCENE_TREE_SELECTION_CHANGED,
    SCENE_TREE_OPTIONS_MENU_REQUEST,
    SCENE_TREE_CONTENTS_CHANGED,
    HANDLES_GIZMO_INTERACTION_BEGAN,
    HANDLES_GIZMO_INTERACTION_ENDED,

    SELECTED_POSITION_CHANGE,
    SELECTED_SCALE_CHANGE,
    SELECTED_ORIENTATION_CHANGE,
    SELECTED_DATA_CHANGE,

    OBJECT_POSITION_CHANGE,
    OBJECT_SCALE_CHANGE,
    OBJECT_ORIENTATION_CHANGE,
    OBJECT_NAME_CHANGE,
    OBJECT_VISIBILITY_CHANGE,

    REQUEST_SAVE,
};

enum SceneEditorFramework_Action{
    USER_0,
    USER_1,
    USER_2,
    USER_3,
    USER_4,
    USER_5,
    USER_6,
    USER_7,

    BASIC_COORDINATES_CHANGE,
    OBJECT_DELETION,
    RENAME_SCENE_NODE,
    CHANGE_SCENE_NODE_VISIBILITY,
    TREE_REARRANGE,
    OBJECT_INSERTION,

    MAX
};

enum SceneEditorFramework_ObjectInsertionType{
    NONE,
    INTO,
    ABOVE,
    BELOW
};

enum SceneEditorFramework_BasicCoordinateType{
    POSITION,
    SCALE,
    ORIENTATION,
    RAYCAST
}

//Raw SDL scancodes used by the scene-tree panel. Keeping these in the framework
//means modifier-aware selection does not depend on an editor defining its own
//KeyScancode table.
enum SceneEditorFramework_KeyScancode{
    LCTRL = 224,
    LSHIFT = 225,
    LGUI = 227,
    RCTRL = 228,
    RSHIFT = 229,
    RGUI = 231
}

//Where the framework's own geometry sits in the render queue.
//
//Ogre hands render queues 0-99 to v2 objects and 100-199 to v1 ones, so the
//gizmo takes the last of the v2 groups: a project's own content can use anything
//below it and still be drawn before the gizmo is.
enum SceneEditorFramework_RenderQueue{
    //Objects the scene tree builds, and the outline box drawn around the
    //selected one. Part of the scene, and drawn with it.
    SCENE = 30,
    //The transform gizmo, which is not part of the scene: it is drawn over it.
    //A project's compositor is expected to give this queue a pass of its own.
    //@see ::SceneEditorFramework.gizmoPassClearsDepth
    GIZMO = 99
}

//Masks the framework's own objects can be found by with a ray query. Written out
//rather than shifted because a squirrel enum only takes literals.
enum SceneEditorFramework_QueryFlag{
    //The arms of the transform gizmo. Only the copy of the gizmo in the viewport
    //the cursor is working in carries this.
    //@see SceneEditorFramework.SceneEditorGizmoLayers
    GIZMO_HANDLE = 0x400,     //1 << 10
    //Objects the scene tree builds.
    SCENE_OBJECT = 0x100000   //1 << 20
}

//How many viewports can show the transform gizmo at once.
//
//Each one draws its own copy of the gizmo, sized for the camera it is looking
//through, and tells them apart by a visibility flag - so this is a count of the
//flags the framework reserves for the purpose, being the lowest ones.
//
//A plain value rather than an enum, so that a project's entry file can name it
//whether it was compiled before the framework's scripts ran or after.
//@see ::SceneEditorFramework.getGizmoLayerCameras
::SceneEditorFramework.MAX_GIZMO_LAYERS <- 8;
