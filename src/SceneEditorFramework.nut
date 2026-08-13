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

_doFile("script://SceneEditorFPSCamera.nut");

_doFile("script://SceneEditorGizmo.nut");
_doFile("script://SceneEditorGizmoObjectHandles.nut");
_doFile("script://SceneEditorGizmoLayers.nut");
_doFile("script://SceneEditorGizmoOutlineBox.nut");

_doFile("script://GUI/SceneEditorGUIPanel.nut");
_doFile("script://GUI/SceneEditorGUISceneTree.nut");
_doFile("script://GUI/SceneEditorGUIObjectProperties.nut");

//The immediate-mode implementation deliberately lives alongside the legacy
//engine GUI panels above. Projects can opt into it without changing an
//existing EditorGUIFramework integration.
::SceneEditorFramework.IMGUI <- {};
_doFile("script://IMGUI/SceneEditorIMGUITextures.nut");
_doFile("script://IMGUI/SceneEditorIMGUIPanel.nut");
_doFile("script://IMGUI/SceneEditorIMGUIWidgets.nut");
_doFile("script://IMGUI/SceneEditorIMGUISceneTree.nut");
_doFile("script://IMGUI/SceneEditorIMGUIObjectPropertyEntryMesh.nut");
_doFile("script://IMGUI/SceneEditorIMGUIObjectProperties.nut");

_doFile("script://actions/BasicCoordinatesChangeAction.nut");
_doFile("script://actions/RenameSceneNodeAction.nut");
_doFile("script://actions/ChangeSceneNodeVisibilityAction.nut");
_doFile("script://actions/ObjectDeleteAction.nut");
_doFile("script://actions/TreeRearrangeAction.nut");
