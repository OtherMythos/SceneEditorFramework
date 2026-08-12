# Scene Editor Framework

A framework to facilitate editing scenes in the avEngine.

Features include:
 * Fully editable scene tree for avEngine scene files
 * Flexible GUI dialogs for interaction
 * Scene gizmos for editing

## Loading

Add the plugin directory to the project's `Plugins` array in `avSetup.cfg`:

```json
"Plugins": [ "res://sceneEditorFramework" ]
```

The engine reads `avPlugin.cfg` and loads `src/SceneEditorFramework.nut`, which defines all framework
objects in the `::SceneEditorFramework` namespace. Projects must not load that file themselves.
The plugin automatically registers its `res` directory, which contains the gizmo meshes.

## Example editor

`example/` is a small runnable editor that loads and saves `res/example.avScene`. It demonstrates loading a scene tree, displaying the framework's ImGui scene-tree and object-property panels, and using the position/scale gizmos. Its `avImguiPlugin` distribution is bundled at `example/plugins/avImguiPlugin/`.

```bash
git submodule update --init --recursive # only needed to explore the legacy GUI example
```

Then run the avEngine with `example/avSetup.cfg`.

The retained-mode implementation remains under `src/GUI/` for existing
EditorGUIFramework users. The ImGui implementation is parallel under `src/IMGUI/`;
use `Base.setupIMGUIWindow()` and call `Base.drawIMGUI()` once per rendered frame
after `_imgui.isFirstUpdateOfFrame()`.

## Tests

The unit and integration tests use the avEngine test runner:

```bash
python3 ~/Documents/avTools/testRunner/testRunner.py \
    -p ~/Documents/repo/SceneEditorFramework/test/avTests.cfg \
    -e ~/Documents/avEngine/build/Debug/av.app/Contents/MacOS/av
```
