
enum SceneEditorFramework_GUIObjectPropertiesWidgets{
    POSITION,
    SCALE,
    ORIENTATION
};

enum SceneEditorFramework_SceneTreeEntryType{
    NONE,

    CHILD,
    TERM,

    EMPTY,
    MESH,
    USER0,
    USER1,
    USER2,
};

enum SceneEditorFramework_GUIPanelId{
    SCENE_TREE,
    OBJECT_PROPERTIES,

    USER_CUSTOM_1 = 1000,
    USER_CUSTOM_2 = 1001,
    USER_CUSTOM_3 = 1002,

};

enum SceneEditorFramework_BusEvents{
    NONE,
    SCENE_TREE_SELECTION_CHANGED,
    HANDLES_GIZMO_INTERACTION_BEGAN,
    HANDLES_GIZMO_INTERACTION_ENDED,
    SELECTED_POSITION_CHANGE,
    SELECTED_SCALE_CHANGE,

    OBJECT_POSITION_CHANGE,
    OBJECT_SCALE_CHANGE,

    REQUEST_SAVE
};

enum SceneEditorFramework_Action{
    BASIC_COORDINATES_CHANGE,

    MAX
};

enum SceneEditorFramework_BasicCoordinateType{
    POSITION,
    SCALE,
    ORIENTATION
}