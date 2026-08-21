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
frames the currently selected object in the focused viewport. Delete or
Backspace removes the current selection, as an undoable action. H takes the
selection out of sight and brings it back, through
`SceneTree.toggleSelectionVisibility()`: a selection with anything still showing
in it is hidden, and only one which is already completely hidden comes back, so
a mixed selection is not left mixed the other way round. The whole press is one
undoable action however many objects it covered. Ctrl+C copies the
current selection, with everything below it, and Ctrl+V pastes it back beside
whatever is selected then - or at the end of the scene when nothing is - as one
undoable action which leaves the pasted objects selected. A copy describes what
was copied rather than pointing at it, so it can be pasted repeatedly, and after
the objects it was taken from have been deleted. Paste from an object's right
click menu instead, and what was copied becomes a child of that object. Ctrl+S
writes the scene back over the file it was loaded from, as the File menu's Save
does. Each viewport's
View button controls its own gizmos, including selection outlines, independently;
that choice is restored with the viewport's layout state.

The XYZ indicator in the corner of each viewport is also a way of aiming it, as
Blender's navigation gizmo is. Both ends of each axis are a handle, the positive
one lettered and the negative one dimmed, and clicking one turns the viewport
orthographic and looks back down that axis - so the ball nearest the camera is
the view the click gives. The same six views are named under *View &rarr;
Viewpoint*, alongside an Orthographic toggle which changes projection without
moving the camera and a Perspective entry which changes it back. A viewpoint
turns the camera around whatever it is already orbiting rather than sending it
back to the middle of the scene, and the orthographic window follows the distance
to that point, so switching projection shows the scene at the size it was and the
mouse wheel keeps zooming as it did. The projection is per viewport, and it is
restored with the layout state.

Transform gizmos are sized by their distance from the camera, so they stay the
same size on screen however far the view is from the object they belong to, and
by the size of the viewport showing them, so one docked down to a corner still
gets a gizmo big enough to grab rather than one shrunk in proportion with the
panel. A viewport of `SceneEditorFramework.GIZMO_REFERENCE_VIEWPORT_HEIGHT` gets
the gizmo at its usual size, a shorter one gets a proportionally larger one, and
a viewport narrower than it is tall brings it back in far enough to keep fitting.
`GIZMO_MIN_VIEWPORT_SCALE` and `GIZMO_MAX_VIEWPORT_SCALE` bound that, since
holding the pixel size exactly would leave a tiny viewport asking for a gizmo big
enough to swallow the scene. A project driving the framework itself supplies the
viewport sizes with a `gizmoLayerViewportSizes` helper function, indexed by gizmo
layer to match `gizmoLayerCameras`; without one the scene is taken to fill the
window.

A transform gizmo sits on the most recently clicked object, and dragging its
position handles moves everything which is selected. With more than one object
selected the handles move to the middle of the selection's bounds - the same
bounds the second, orange outline is drawn around - so the drag is about the
group rather than about whichever of them happened to be clicked last: the middle
goes where the drag asks and every object moves that same distance through the
world, so the group keeps the arrangement it was put in. An object which hangs
below another selected one is carried by it rather than being moved a second
time, and the whole drag is one undoable action however many objects it moved.
Every transform tool's handles go to that same middle, so switching between them
does not move the gizmo about; a selection has one centre whether it is being
moved, scaled or turned. Only a move widens to the group, though - scaling and
rotating still change the most recently clicked object alone, and about that
object's own origin rather than about the centre the handles are drawn at.

The position and scale gizmos both offer three axis handles and three plane
handles, one for each pair of axes and coloured for that pair. Dragging a plane
handle moves or resizes along both of its axes at once and leaves the third
alone, so a box can be made wider and deeper without becoming taller.

Holding shift while dragging any of the handles makes the drag move in steps: one
world unit of position, a quarter of scale, and fifteen degrees of rotation. A
position or a scale snaps to absolute multiples of its step, so objects dragged
this way line up with each other rather than each keeping whatever offset it
started with; a rotation snaps the angle it has turned through instead, so an
object already at an angle turns by whole steps from it. The modifier is read
while the drag is happening, so it can be taken up or let go part way through
one. Holding alt while dragging the scale handles scales all three axes together.

Clicking an object in a viewport selects it, and clicking the same spot again
steps to the next object along the cursor's ray, so something behind a larger
object can be reached by tapping. Alt+right clicking offers all of them at once
as a list to choose from instead. Both right click gestures are acted on when the
button comes up rather than when it goes down, since that button also flies the
camera: a release which flew it was doing that rather than asking for a menu.
A right press made with alt already held is never given to a camera at all, so
that gesture cannot begin a flight the release would then be mistaken for -
holding alt during a flight which is already under way is still the camera's own
speed modifier.

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
| `enableObjectColourView` | `true` | Offer the flat per-object colouring in each viewport's View menu. |
| `enableSceneTreeContextMenu` | `true` | Enable Add, Reparent, Centre on contents, Copy, Paste, Rename and Delete on right click. |
| `enableRaycastSelectionMenu` | `true` | Enable the alt+right click all-hits chooser. |
| `showViewportToolbar` | `true` | Show transform tools over each viewport. |
| `showAxisIndicator` | `true` | Show the camera-oriented XYZ indicator, whose handles aim the viewport. |
| `showMainMenuBar` | `true` | Show the standard File, Edit and Window menus. |
| `showUnsavedIndicator` | `true` | Show "Unsaved changes" in the main menu bar while the scene has been changed since it was last saved. |
| `markWindowTitleUnsaved` | `true` | Append an unsaved marker to the window title while the scene has been changed since it was last saved. |
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

Resource fields use `IMGUI.ResourceButton`. Clicking one opens a filtered modal
browser; resources can also be dragged from the main file browser and dropped
on a compatible button. The built-in mesh property uses this widget, and mesh
replacement is recorded as an undoable editor action.

An object's right click menu offers Centre on contents, which is
`SceneTree.centreEntryOnContents()`. A group built around objects which were
placed before it existed sits at the origin while everything below it holds a
position describing where it is in the scene, so moving the group is the only
way to move any of it. Centring moves the group to the middle of the bounds of
what hangs below it and takes that same offset back out of each of its direct
children, leaving every one of them where it was in the world but described
against the group rather than against the scene. Descendants deeper than those
children are already described against what they hang from and are left alone,
and a group of empties, which has no bounds to take, is centred on the middle of
where those empties are. The move and the compensation for it are one undoable
action.

Dragging an object in the scene tree moves it, and dropping the drag on a row
puts the selection above it, below it, or inside it depending on where in the row
the button came up. Holding alt as the drag is let go of leaves a copy at the
destination instead, through `SceneTree.duplicateCurrentSelection()`, and leaves
the copies selected. Nothing happens until the drop, so a drag can be taken back
with escape, and alt can be taken up or let go of part way through one - the row
under the cursor says which of the two the drop will do. Unlike a move, a copy
can be dropped inside the object it was taken from: what is duplicated is
described before anything is inserted, so the copy is of what that subtree was.
The whole drop is one undoable action however many objects it created.

Copy and paste go through `SceneEditorFramework.SceneTreeClipboard`, which the
base owns and `Base.getClipboard()` returns. It holds detached descriptions of
the copied entries rather than the entries themselves, so `SceneTree.pasteFromClipboard()`
instantiates its own objects each time it is called, with ids of the tree it is
pasting into - a clipboard filled from one scene tree can therefore be pasted into
another. An editor whose USER entries carry data a `clone` would leave shared
implements `copySceneTreeEntryData(entry)` in its helper functions to say what
copying one of its entries means.

The individual classes under `SceneEditorFramework.IMGUI` remain public for
tools which need a custom shell. `Base.setupIMGUIWindow()` and `Base.drawIMGUI()`
provide the lower-level panel API.

## Tags

A `tag` attribute on an object in an `avScene` file is what a scene is searched
by once it has been loaded, and it identifies one object: at most one object in
a scene carries any given tag. The engine refuses to parse a file where two
objects claim the same one, so the editor keeps that rule rather than leaving a
scene which cannot be loaded back.

Object Properties has a Tag field, which claims a tag for the selected object,
and a button beside it which gives the tag up. Both are undoable, through
`SceneTree.setEntryTag()` and `SceneTree.clearEntryTag()`. A tag another object
already holds is refused and the field goes back to what the object actually
carries, naming the object holding it: which of the two was meant to keep the
tag is not something a typed field can be read as asking for, so it is moved by
taking it off the first object and then giving it to the second. An emptied
field is no tag rather than a tag which is the empty string.

`SceneTree.getEntryIdForTag()` names the entry carrying a tag, or null, and
`SceneTree.isTagAvailable(tag, entryId)` says whether one can be claimed.
A change transmits `OBJECT_TAG_CHANGE` on the bus, as a rename transmits
`OBJECT_NAME_CHANGE`.

A pasted or duplicated object is a new object and does not take the tag of the
one it was copied from, since that would be a second claim on it. A file which
does claim one twice is still loaded: the first claim is kept, the later ones
are dropped with a message, and saving the scene back writes a file the engine
will parse.

## Object colours

A scene built from one kit of parts is largely one colour, which makes it hard to
see which of two touching objects the gizmo is about to move. A viewport's *View
&rarr; Object Colours* replaces the lit result with a flat, unlit colour of its
own for each object, so the parts separate visually even where their materials do
not. It belongs to the viewport rather than to the editor, so one pane can show
the scene in flat colours while the pane docked beside it shows it lit, and the
choice is restored with the rest of that viewport's state.

Only PBS objects are recoloured. The framework's own gizmos, selection outlines
and axis indicator use unlit datablocks and are left alone, which is what keeps
them readable against the recoloured scene.

The colour is hashed from the object's **world transform**, not from its draw id.
A draw id looks like the obvious choice and is not stable: Ogre folds the object's
quantised distance to the camera into the render queue sort key, so ids renumber
as the camera moves, and frustum culling shifts them again by changing what is
submitted at all. It is an index into a frame's buffers rather than an identity.
Two consequences of using the transform instead: objects sharing an identical
transform share a colour, and moving an object changes its colour, which reads as
the thing being dragged announcing itself.

It is drawn by an HLMS piece rather than by swapping datablocks, and HLMS library
directories can only be declared in a project's setup file — so a project using
this feature has to point `avSetup.cfg` at the framework's piece directory, with
the path relative to its `DataDirectory`:

```json
"HLMS": {
    "pbs": {
        "library": [ "../sceneEditorFramework/res/hlms/pbs" ]
    }
}
```

Without that entry the menu entry still works and nothing in the viewport changes,
since nothing is reading what it sets. The switch is a per-pass shader property
(`avSEObjectColour`) applied to the scene pass of the viewport's gizmo layer,
whose compositor identifier is `SceneEditorFramework.SCENE_PASS_IDENTIFIER_BASE`
plus that layer — a value in a buffer could not be aimed at one pass. Only pass
properties can, at the cost of building that pass's shader permutation the first
time the view is switched on: a one-off hitch on that frame, free from then on.
A project overriding `sceneWorkspacePrefix` with compositor definitions of its own
needs matching `identifier` values on its scene passes for the feature to reach
them.

## Example editor

`example/` is a small runnable editor that configures the first-party shell to
load and save `res/example.avScene`. Its `avImguiPlugin` distribution is bundled
at `example/plugins/avImguiPlugin/`.

Run the avEngine with `example/avSetup.cfg`. That file also shows the HLMS
library entry the object colour view needs.

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

Alongside `Unit` and `Integration`, `test/avTests.cfg` describes a `Stress` plan
in `test/stress`. Its cases run the editor rather than a part of the framework:
`test/stress/SceneTree/EditorSceneTreeActions` puts up the same ImGui editor the
example project does, with the example's scene in it, and rebuilds that scene out
of a long run of randomly chosen edits - insertion, deletion, renaming,
visibility, tagging, mesh changes, transforms, rearrangement, copy and paste,
grouping -
recording the tree after each one, then walks the action stack back and forward
over those recordings, in full and at random. The run is spread over frames, so
the interface is drawn against every state it passes through and the panels have
to keep up with a tree being pulled apart underneath them. Every state is checked
for internal consistency as well, so an engine scene node, an entry id or a node
lookup which an undo fails to release is caught where it is leaked. The edits come
from a seeded generator of the test's own, so a run is the same run every time and
a failure can be looked at again. Raise `STRESS_ACTION_COUNT` at the top of the
test to build a larger scene from a longer run, which is what to do when running
it under a memory profiler.

Because these cases run the editor, they need the imgui plugin the example
bundles at `example/plugins/avImguiPlugin`, which is not kept in this repository.
The test workflow downloads it from
[avEngineIMGUI](https://github.com/OtherMythos/avEngineIMGUI); locally it is
whatever the example is already being run with.
