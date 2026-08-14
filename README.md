# Scene Editor Framework

A framework to facilitate editing scenes in the avEngine.

Features include:
 * Fully editable scene tree for avEngine scene files
 * A ready-to-use docked ImGui editor with multiple scene viewports
 * Reusable scene-tree, object-property, context-menu and viewport components
 * Scene gizmos for editing

## Loading

Add the plugin directory to the project's `Plugins` array in `avSetup.cfg`:

```json
"Plugins": [ "res://sceneEditorFramework" ]
```

The engine reads `avPlugin.cfg` and loads `src/SceneEditorFramework.nut`, which defines all framework
objects in the `::SceneEditorFramework` namespace. Projects must not load that file themselves.
The plugin automatically registers its `res` directory, which contains the gizmo
meshes and viewport compositor definitions.

## First-party editor

`::SceneEditorFramework.IMGUI.Editor` owns the standard editor experience:
docking, scene viewports and cameras, transform toolbar, axis indicator, scene
tree, object properties, context menus, shortcuts, and layout persistence. A
tool can start with only a scene path:

Viewport navigation follows Blender-style controls: hold the right mouse button
and use WASDQE for FPS flight, drag the middle mouse button to orbit,
Shift-middle-drag to pan, and use the mouse wheel to zoom. Switching styles
continues from the camera's current position and direction. Shift+C smoothly
frames the currently selected object in the focused viewport. Each viewport's
View button controls its own gizmos, including selection outlines, independently;
that choice is restored with the viewport's layout state.

```squirrel
::MyEditor <- null;

function start(){
    ::MyEditor = ::SceneEditorFramework.IMGUI.Editor({
        "scenePath": "res://res/tool.avScene"
    });
    ::MyEditor.start();
}

function update(){ ::MyEditor.update(); }
function sceneSafeUpdate(){ ::MyEditor.sceneSafeUpdate(); }
function end(){ ::MyEditor.end(); }
```

Construct the editor in `start()`, after the engine has loaded script plugins.
The project's `avSetup.cfg` should disable `UseDefaultCompositor` and load the
ImGui plugin before this framework, as the example does.

The options table keeps common variations out of copied editor code:

| Option | Default | Purpose |
| --- | --- | --- |
| `scenePath` | required | Scene file to load and save. |
| `statePath` | `res://.editorState.json` | Layout sidecar; use `null` to disable persistence. |
| `createDefaultLight` | `true` | Add a directional light and ambient lighting. |
| `initialViewportCount` | `1` | Number of viewports in a new, unsaved layout. |
| `setupScene` | `null` | Callback receiving the editor during startup. |
| `onStarted` / `onShutdown` | `null` | Lifecycle callbacks around the running editor. |
| `helperFunctions` | `null` | Overrides for `SceneEditorFramework.HelperFunctions`. |
| `enableSceneTreeContextMenu` | `true` | Enable Add, Rename and Delete on right click. |
| `enableRaycastSelectionMenu` | `true` | Enable the Alt-click all-hits chooser. |
| `showViewportToolbar` | `true` | Show transform tools over each viewport. |
| `showAxisIndicator` | `true` | Show the camera-oriented XYZ indicator. |
| `showMainMenuBar` | `true` | Show the standard File, Edit and Window menus. |
| `cameraFocusDuration` | `0.3` | Seconds used to animate Shift+C framing. |
| `drawMainMenu` | `null` | Callback for adding project menus to the main bar. |
| `drawSceneTreeContextMenu` | `null` | Callback for adding project-specific object actions. |
| `fileBrowserRoot` | `res://` | Filesystem root shown by the built-in file browser. |
| `fileBrowserBackend` | `null` | Optional `listDirectory` / `isDirectory` callbacks for virtual filesystems. |
| `fileBrowserCallbacks` | `null` | Optional selection, activation, and preview-provider callbacks. |
| `resourcePrefix` | `sceneEditorFramework` | Prefix for generated camera and texture names. |
| `sceneWorkspacePrefix` | framework workspace prefix | Override viewport compositor workspace names. |
| `clearWindowWorkspace` | framework clear workspace | Override the main-window compositor workspace. |

The shell also accepts `sceneRenderWindowClass`, `sceneTreePanelClass`,
`objectPropertiesPanelClass`, `fileBrowserModelClass`, `fileBrowserPanelClass`,
`editorStateClass`, `sceneTreeContextMenuClass`,
and `raycastSelectionMenuClass` replacements, plus `sceneTreeWidth` and
`objectPropertiesWidth` layout ratios. Public accessors expose the base, scene
tree, file browser, and viewport list, while `addRenderWindow()` and `resetWindowLayout()`
cover common host-tool actions.

The file browser presents directories and resources as a responsive icon grid.
Its `previewProvider` callback receives an entry and may return a table containing
`texture` and optional `uv0` / `uv1` arrays. Returning `null` uses the built-in
folder, texture, mesh, script, or generic-file icon, allowing thumbnail loading
to be added asynchronously without changing the browser panel.

The individual classes under `SceneEditorFramework.IMGUI` remain public for
tools which need a custom shell. `Base.setupIMGUIWindow()` and `Base.drawIMGUI()`
provide the lower-level panel API.

## Example editor

`example/` is a small runnable editor that configures the first-party shell to
load and save `res/example.avScene`. Its `avImguiPlugin` distribution is bundled
at `example/plugins/avImguiPlugin/`.

Run the avEngine with `example/avSetup.cfg`.

On a clean shutdown the example writes `example/.editorState.json` beside that
setup file. It restores the dock layout and active tabs, floating-window
geometry, open viewports and their cameras, panel visibility, scene-tree
expansion and selection, and the active transform tool on the next run. The
file is local runtime state and is ignored by Git; removing it resets the
editor to its default layout.

## Tests

The unit and integration tests use the avEngine test runner:

```bash
python3 ~/Documents/avTools/testRunner/testRunner.py \
    -p ~/Documents/repo/SceneEditorFramework/test/avTests.cfg \
    -e ~/Documents/avEngine/build/Debug/av.app/Contents/MacOS/av
```
