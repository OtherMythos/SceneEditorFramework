::SceneEditorFramework <- {};

//Gizmo meshes live with the plugin, so projects do not need to register this location themselves.
_resources.addResourceLocation("script://../res", "FileSystem", "SceneEditor/general");
_resources.initialiseResourceGroup("SceneEditor/general");

_doFile("script://SceneEditorConstants.nut");

_doFile("script://SceneEditorBase.nut");
_doFile("script://SceneEditorActionStack.nut");
_doFile("script://SceneEditorSceneTreeEntry.nut");
_doFile("script://SceneEditorSceneTree.nut");
_doFile("script://SceneEditorSceneFileParser.nut");
_doFile("script://SceneEditorSceneFileWriter.nut");
_doFile("script://SceneEditorBus.nut");
_doFile("script://SceneEditorFileBrowserModel.nut");

_doFile("script://SceneEditorFPSCamera.nut");

_doFile("script://SceneEditorGizmo.nut");
_doFile("script://SceneEditorGizmoObjectHandles.nut");
_doFile("script://SceneEditorGizmoRotationHandles.nut");
_doFile("script://SceneEditorGizmoLayers.nut");
_doFile("script://SceneEditorGizmoOutlineBox.nut");
_doFile("script://SceneEditorGizmoOutlineLayers.nut");

::SceneEditorFramework.IMGUI <- {};
_doFile("script://IMGUI/SceneEditorIMGUITextures.nut");
_doFile("script://IMGUI/SceneEditorIMGUIPanel.nut");
_doFile("script://IMGUI/SceneEditorIMGUIResourceDragDrop.nut");
_doFile("script://IMGUI/SceneEditorIMGUIFileBrowser.nut");
_doFile("script://IMGUI/SceneEditorIMGUIResourceButton.nut");
_doFile("script://IMGUI/SceneEditorIMGUIResourcePickerPopup.nut");
_doFile("script://IMGUI/SceneEditorIMGUIWidgets.nut");
_doFile("script://IMGUI/SceneEditorIMGUISceneTree.nut");
_doFile("script://IMGUI/SceneEditorIMGUIObjectPropertyEntryMesh.nut");
_doFile("script://IMGUI/SceneEditorIMGUIObjectProperties.nut");
_doFile("script://IMGUI/SceneEditorIMGUIAxisIndicator.nut");
_doFile("script://IMGUI/SceneEditorIMGUIRaycastSelectionMenu.nut");
_doFile("script://IMGUI/SceneEditorIMGUISceneTreeContextMenu.nut");
_doFile("script://IMGUI/SceneEditorIMGUISceneRenderWindow.nut");
_doFile("script://IMGUI/SceneEditorIMGUIEditorState.nut");
_doFile("script://IMGUI/SceneEditorIMGUIEditor.nut");

_doFile("script://actions/BasicCoordinatesChangeAction.nut");
_doFile("script://actions/RenameSceneNodeAction.nut");
_doFile("script://actions/ChangeSceneNodeVisibilityAction.nut");
_doFile("script://actions/ObjectDeleteAction.nut");
_doFile("script://actions/TreeRearrangeAction.nut");
_doFile("script://actions/ObjectInsertionAction.nut");
_doFile("script://actions/ChangeMeshResourceAction.nut");
