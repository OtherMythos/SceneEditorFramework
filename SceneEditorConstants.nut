
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
    MESH
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
    SELECTED_POSITION_CHANGE,

    REQUEST_SAVE
};