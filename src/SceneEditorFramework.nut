::SceneEditorFramework <- {};

//Gizmo meshes live with the plugin, so projects do not need to register this location themselves.
_resources.addResourceLocation("script://../res", "FileSystem", "SceneEditor/general");

_doFile("script://SceneEditorConstants.nut");

_doFile("script://SceneEditorBase.nut");
_doFile("script://SceneEditorActionStack.nut");
_doFile("script://SceneEditorSceneTreeEntry.nut");
_doFile("script://SceneEditorSceneTree.nut");
_doFile("script://SceneEditorSceneFileParser.nut");
_doFile("script://SceneEditorSceneFileWriter.nut");
_doFile("script://SceneEditorBus.nut");

_doFile("script://SceneEditorGizmo.nut");
_doFile("script://SceneEditorGizmoObjectHandles.nut");
_doFile("script://SceneEditorGizmoOutlineBox.nut");

_doFile("script://GUI/SceneEditorGUIPanel.nut");
_doFile("script://GUI/SceneEditorGUISceneTree.nut");
_doFile("script://GUI/SceneEditorGUIObjectProperties.nut");

_doFile("script://actions/BasicCoordinatesChangeAction.nut");
_doFile("script://actions/RenameSceneNodeAction.nut");
_doFile("script://actions/ObjectDeleteAction.nut");
