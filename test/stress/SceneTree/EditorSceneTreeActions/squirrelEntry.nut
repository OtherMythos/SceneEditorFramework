//A stress test for the scene tree and the action stack behind it, run through
//the editor rather than against a scene tree of its own.
//
//This puts up the same first-party ImGui editor the example project does, with
//the example's own scene in it, and then rebuilds that scene out of a long run
//of randomly chosen edits - insertion, deletion, renaming, visibility, mesh
//changes, transforms, rearrangement, copy and paste, grouping - recording what
//the tree looks like after each one. The stack is then walked all the way back
//to the loaded scene and all the way forward again, several times over and then
//at random, checking the tree against those recordings at every step. An action
//which does not restore exactly what it replaced shows up as a mismatch at the
//step which pushed it.
//
//The run is spread over frames rather than done in one call, so the interface is
//drawn against every state it passes through: the scene tree, the object
//properties panel and the viewports all redraw against a tree which is being
//pulled apart underneath them, and the gizmos are rebuilt for each new selection
//as they would be for a user. A panel which holds on to an entry, a node or an
//id which an edit has taken away fails here rather than in front of one.
//
//Each state is checked for internal consistency as well as against its
//recording, which is what makes this worth running under a memory profiler: an
//engine scene node, an entry id or a node lookup which is not released by an
//undo is left behind in the tree it belongs to and is caught here rather than
//only showing as growing memory use.
//
//The edits are chosen by a generator of this file's own, seeded with a constant,
//so a run of any length is the same run every time and a failure can be looked
//at again. Raise STRESS_ACTION_COUNT for a longer profiling run.
//
//Values which mirror the plugin's enums are written out: those constants are
//loaded after this test script is compiled.

//How many actions to build the scene out of, and roughly how many objects those
//actions aim to keep in it.
::STRESS_ACTION_COUNT <- 250;
::STRESS_OBJECT_TARGET <- 100;
//How many times the whole stack is walked back and forward, and how many random
//single steps over it follow that.
::STRESS_UNDO_REDO_CYCLES <- 2;
::STRESS_RANDOM_WALK_STEPS <- 200;
//How much of the run each frame carries out. The interface is drawn between one
//frame's worth of edits and the next, so this is how many edits the panels are
//asked to keep up with at a time.
::STRESS_STEPS_PER_FRAME <- 4;

::STRESS_SEED <- 20260816;

//SceneEditorFramework_ObjectInsertionType
::INTO <- 1;
::ABOVE <- 2;
::BELOW <- 3;
//SceneEditorFramework_SceneTreeEntryType
::TYPE_CHILD <- 1;
::TYPE_TERM <- 2;
::TYPE_MESH <- 4;
//SceneEditorFramework_BasicCoordinateType
::COORD_POSITION <- 0;
::COORD_SCALE <- 1;
::COORD_ORIENTATION <- 2;
//SceneEditorFramework_BusEvents
::EVENT_GIZMO_BEGAN <- 4;
::EVENT_GIZMO_ENDED <- 5;
//SceneEditorFramework_Action
::ACTION_CHANGE_MESH_RESOURCE <- 14;

//The engine's built in primitives, which are what an inserted mesh is given.
::PRIMITIVE_MESHES <- ["cube", "sphere", "capsule", "plane"];

::OP_INSERT_EMPTY <- 0;
::OP_INSERT_MESH <- 1;
::OP_RENAME <- 2;
::OP_VISIBILITY <- 3;
::OP_CHANGE_MESH <- 4;
::OP_TRANSFORM <- 5;
::OP_MULTI_TRANSFORM <- 6;
::OP_REARRANGE <- 7;
::OP_REARRANGE_MULTI <- 8;
::OP_COPY_PASTE <- 9;
::OP_REPARENT_EMPTY <- 10;
::OP_CENTRE_ON_CONTENTS <- 11;
::OP_DELETE <- 12;
::OP_TAG <- 13;
::OP_MAX <- 14;

::OPERATION_NAMES <- [
    "insert empty", "insert mesh", "rename", "visibility", "change mesh",
    "transform", "multiple transform", "rearrange", "rearrange multiple",
    "copy and paste", "group under empty", "centre on contents", "delete",
    "tag"
];

::RANDOM_STATE <- ::STRESS_SEED;
//A name for each created object which says which step created it, so a mismatch
//names the edit it came from.
::NAME_COUNTER <- 0;
//What the operation currently being performed is, and what it did, for the same
//reason. The type is also what the run is checked for coverage against.
::CURRENT_OPERATION_TYPE <- -1;
::CURRENT_OPERATION <- "";

//What the run is doing now. It is spread over frames, so where it has got to
//lives here rather than in one function's local state.
::PHASE_BUILD <- 0;
::PHASE_UNDO <- 1;
::PHASE_REDO <- 2;
::PHASE_RANDOM_WALK <- 3;
::PHASE_TAIL <- 4;
::PHASE_FINISHED <- 5;

::StressEditor <- null;
::STRESS_PHASE <- 0;
//states[n] is the tree after n actions, and descriptions[n] the edit which
//pushed the nth one.
::STRESS_STATES <- null;
::STRESS_DESCRIPTIONS <- null;
//Where in the stack the tree currently is, which is what the state it is checked
//against is indexed by.
::STRESS_INDEX <- 0;
::STRESS_CYCLE <- 0;
::STRESS_WALK_STEP <- 0;
::STRESS_ATTEMPTS <- 0;
::STRESS_OPERATION_COUNTS <- null;
::STRESS_LARGEST_OBJECT_COUNT <- 0;
//How many frames of the interface were built while the run went on. Counted
//from inside the editor's own gui, so a run which stopped drawing - or never
//started - is a failure rather than something which quietly passes.
::STRESS_FRAMES_DRAWN <- 0;

function start(){
    //The editor the example project puts up, with the example's own scene in it.
    //Everything below works through it, so the run is of the editor rather than
    //of a scene tree assembled for the test.
    ::StressEditor = ::SceneEditorFramework.IMGUI.Editor({
        "scenePath": "res://../../../../example/res/example.avScene",
        //No layout file: one left behind by a previous run would change what
        //this draws, and a test has no business writing one.
        "statePath": null,
        //Called while the editor builds its main menu bar, which is to say once
        //per frame of gui it draws.
        "drawMainMenu": function(editor){
            ::STRESS_FRAMES_DRAWN = ::STRESS_FRAMES_DRAWN + 1;
        }
    });
    ::StressEditor.start();

    //Reload must remove renderable entries belonging to the discarded tree,
    //clear their actions, and point the panel at the replacement model.
    local loadedState = captureState(stressTree());
    local discardedTree = stressTree();
    discardedTree.insertPrimitiveMeshChild(null, "cube", "Discarded by reload");
    _test.assertEqual(1, ::StressEditor.mBase_.mActionStack_.mUndoStack_.len());
    _test.assertTrue(::StressEditor.reloadScene_());
    _test.assertTrue(stressTree() != discardedTree);
    _test.assertEqual(null, discardedTree.mParentNode_);
    _test.assertTrue(::StressEditor.mSceneTreePanel_.mSceneTree_ == stressTree());
    _test.assertEqual(0, ::StressEditor.mBase_.mActionStack_.mUndoStack_.len());
    _test.assertEqual(0, ::StressEditor.mBase_.mActionStack_.mRedoStack_.len());
    assertState(stressTree(), loadedState, "reload from disk");

    ::STRESS_STATES = [captureState(stressTree())];
    ::STRESS_DESCRIPTIONS = [];
    ::STRESS_OPERATION_COUNTS = array(::OP_MAX, 0);
    assertTreeConsistent(stressTree());
}

function update(){
    //The interface is drawn first, so what it draws is the tree as the previous
    //frame's edits left it and every one of them is drawn against.
    ::StressEditor.update();

    for(local step = 0; step < ::STRESS_STEPS_PER_FRAME; step++){
        if(::STRESS_PHASE == ::PHASE_FINISHED) return;
        stressStep();
    }
}

function sceneSafeUpdate(){
    ::StressEditor.sceneSafeUpdate();
}

function end(){
    ::StressEditor.end();
}

function stressTree(){
    return ::StressEditor.getSceneTree();
}

function stressStack(){
    return ::StressEditor.getBase().mActionStack_;
}

//One unit of the run: one edit while the scene is being built, and one step over
//the stack while it is being walked.
function stressStep(){
    switch(::STRESS_PHASE){
        case ::PHASE_BUILD: stressBuildStep(); break;
        case ::PHASE_UNDO: stressUndoStep(); break;
        case ::PHASE_REDO: stressRedoStep(); break;
        case ::PHASE_RANDOM_WALK: stressRandomWalkStep(); break;
        case ::PHASE_TAIL: stressTail(); break;
    }
}

function stressBuildStep(){
    local tree = stressTree();
    local stack = stressStack();

    ::STRESS_ATTEMPTS++;
    //Every operation has something it can do to a tree of the size this one is
    //kept at, so a run which cannot fill its stack is a failure rather than
    //something to keep trying at.
    _test.assertTrue(::STRESS_ATTEMPTS < ::STRESS_ACTION_COUNT * 10);

    local editorBase = ::StressEditor.getBase();
    local undoCount = stack.mUndoStack_.len();
    ::CURRENT_OPERATION = "";
    performRandomOperation(tree, editorBase, editorBase.getClipboard());
    local pushed = stack.mUndoStack_.len() - undoCount;

    //One edit is one undo step, whatever it had to change to make it. An
    //operation is free to decide it has nothing to do - a rearrangement onto its
    //own subtree, a mesh change to the mesh already there - and one which
    //changes nothing must not leave an action behind.
    _test.assertTrue(pushed == 0 || pushed == 1);
    if(pushed == 0) return;

    assertTreeConsistent(tree);
    ::STRESS_OPERATION_COUNTS[::CURRENT_OPERATION_TYPE]++;
    local objectCount = objectIds(tree).len();
    if(objectCount > ::STRESS_LARGEST_OBJECT_COUNT) ::STRESS_LARGEST_OBJECT_COUNT = objectCount;
    ::STRESS_DESCRIPTIONS.append(::CURRENT_OPERATION);
    ::STRESS_STATES.append(captureState(tree));

    if(::STRESS_DESCRIPTIONS.len() < ::STRESS_ACTION_COUNT) return;

    _test.assertEqual(::STRESS_ACTION_COUNT, stack.mUndoStack_.len());
    _test.assertEqual(0, stack.mRedoStack_.len());

    //A run which never deleted anything, or never moved anything, would pass
    //everything below it while stressing far less than it appears to.
    foreach(operation, count in ::STRESS_OPERATION_COUNTS){
        if(count > 0) continue;
        print("Scene tree stress test made no use of " + ::OPERATION_NAMES[operation]);
        _test.assertTrue(false);
    }

    //Walking the stack from end to end, more than once, so that a state which is
    //only wrong the second time it is arrived at is caught as well.
    ::STRESS_INDEX = ::STRESS_STATES.len() - 1;
    ::STRESS_PHASE = ::PHASE_UNDO;
}

function stressUndoStep(){
    local stack = stressStack();
    if(::STRESS_INDEX > 0){
        stack.undo();
        ::STRESS_INDEX--;
        assertState(stressTree(), ::STRESS_STATES[::STRESS_INDEX],
            "undo of " + describe(::STRESS_DESCRIPTIONS, ::STRESS_INDEX + 1));
        return;
    }

    _test.assertEqual(0, stack.mUndoStack_.len());
    _test.assertEqual(::STRESS_STATES.len() - 1, stack.mRedoStack_.len());
    //Everything the run created has been given back, leaving the scene as the
    //file described it.
    assertIdsAccountedFor(stressTree());

    ::STRESS_PHASE = ::PHASE_REDO;
}

function stressRedoStep(){
    local stack = stressStack();
    if(::STRESS_INDEX < ::STRESS_STATES.len() - 1){
        stack.redo();
        ::STRESS_INDEX++;
        assertState(stressTree(), ::STRESS_STATES[::STRESS_INDEX],
            "redo of " + describe(::STRESS_DESCRIPTIONS, ::STRESS_INDEX));
        return;
    }

    _test.assertEqual(::STRESS_STATES.len() - 1, stack.mUndoStack_.len());
    _test.assertEqual(0, stack.mRedoStack_.len());

    ::STRESS_CYCLE++;
    //A user does not only walk the stack from one end to the other, so once it
    //has been walked in full, step over it at random as well.
    ::STRESS_PHASE = ::STRESS_CYCLE < ::STRESS_UNDO_REDO_CYCLES ?
        ::PHASE_UNDO : ::PHASE_RANDOM_WALK;
}

function stressRandomWalkStep(){
    if(::STRESS_WALK_STEP >= ::STRESS_RANDOM_WALK_STEPS){
        ::STRESS_PHASE = ::PHASE_TAIL;
        return;
    }
    ::STRESS_WALK_STEP++;

    local stack = stressStack();
    local back = nextRandom(2) == 0;
    if(back && ::STRESS_INDEX > 0){
        stack.undo();
        ::STRESS_INDEX--;
        assertState(stressTree(), ::STRESS_STATES[::STRESS_INDEX],
            "random undo to step " + ::STRESS_INDEX);
    }else if(!back && ::STRESS_INDEX < ::STRESS_STATES.len() - 1){
        stack.redo();
        ::STRESS_INDEX++;
        assertState(stressTree(), ::STRESS_STATES[::STRESS_INDEX],
            "random redo to step " + ::STRESS_INDEX);
    }
}

function stressTail(){
    local tree = stressTree();
    local stack = stressStack();

    //A new edit made partway through the stack drops what was undone, and the
    //objects that history described stay gone.
    while(::STRESS_INDEX > ::STRESS_STATES.len() / 2){
        stack.undo();
        ::STRESS_INDEX--;
    }
    local truncated = stack.mUndoStack_.len();
    ::CURRENT_OPERATION = "";
    local created = tree.insertEmptyChild(null, "After truncation");
    _test.assertNotEqual(null, created);
    _test.assertEqual(0, stack.mRedoStack_.len());
    _test.assertEqual(truncated + 1, stack.mUndoStack_.len());
    assertTreeConsistent(tree);

    stack.undo();
    assertState(tree, ::STRESS_STATES[::STRESS_INDEX],
        "undo of the edit which truncated the stack");

    //Back to the loaded scene, with everything the run built released.
    while(stack.mUndoStack_.len() > 0) stack.undo();
    assertState(tree, ::STRESS_STATES[0], "undo back to the loaded scene");
    assertIdsAccountedFor(tree);

    //All of that happened underneath an editor which was drawing the scene and
    //its panels the whole time, rather than in front of nothing.
    _test.assertTrue(::STRESS_FRAMES_DRAWN > 0);
    _test.assertEqual(1, ::StressEditor.getRenderWindows().len());

    print("Scene tree stress test: " + ::STRESS_ACTION_COUNT + " actions from " +
        ::STRESS_ATTEMPTS + " operations, seed " + ::STRESS_SEED + ", " +
        ::STRESS_LARGEST_OBJECT_COUNT + " objects at its largest, " +
        objectIds(tree).len() + " once undone back to the loaded scene, over " +
        ::STRESS_FRAMES_DRAWN + " drawn frames.");
    foreach(operation, count in ::STRESS_OPERATION_COUNTS){
        print("  " + ::OPERATION_NAMES[operation] + ": " + count);
    }

    ::STRESS_PHASE = ::PHASE_FINISHED;
    _test.endTest();
}

/**
 * The edits.
 *
 * Each one picks its own targets out of the tree as it is, and is free to do
 * nothing when there is nothing sensible for it to do. What it did is recorded
 * in CURRENT_OPERATION so a failing state can be traced back to it.
 */
function performRandomOperation(tree, editorBase, clipboard){
    local ids = objectIds(tree);
    local operation = chooseOperation(ids.len());
    ::CURRENT_OPERATION_TYPE = operation;

    switch(operation){
        case ::OP_INSERT_EMPTY:{
            //A null target is an insertion at the end of the scene's top level,
            //which is a path of its own through the insertion code.
            local target = nextRandom(6) == 0 ? null : randomId(ids);
            local name = "Empty" + nextName();
            ::CURRENT_OPERATION = "insert empty " + name + " into " + target;
            tree.insertEmptyChild(target, name);
            break;
        }
        case ::OP_INSERT_MESH:{
            local target = randomId(ids);
            local insertion = randomInsertion();
            local meshName = ::PRIMITIVE_MESHES[nextRandom(::PRIMITIVE_MESHES.len())];
            local name = "Mesh" + nextName();
            local data = ::SceneEditorFramework.SceneTreeMeshData();
            data.meshName = meshName;
            ::CURRENT_OPERATION = "insert mesh " + name + " (" + meshName + ") " +
                insertion + " " + target;
            tree.insertEntry(target, insertion, ::TYPE_MESH, data, name);
            break;
        }
        case ::OP_RENAME:{
            local target = randomId(ids);
            local name = "Renamed" + nextName();
            ::CURRENT_OPERATION = "rename " + target + " to " + name;
            tree.renameEntry(target, name);
            break;
        }
        case ::OP_VISIBILITY:{
            local target = randomId(ids);
            local visible = !tree.getEntryForId(target).visible;
            ::CURRENT_OPERATION = "set " + target + " visibility to " + visible;
            tree.setEntryVisibility(target, visible);
            break;
        }
        case ::OP_CHANGE_MESH:{
            local meshIds = meshEntryIds(tree);
            if(meshIds.len() == 0) break;

            local target = randomId(meshIds);
            local entry = tree.getEntryForId(target);
            local meshName = ::PRIMITIVE_MESHES[nextRandom(::PRIMITIVE_MESHES.len())];
            //The panel which drives this leaves the mesh alone when it is asked
            //for the one already there, so neither does this.
            if(meshName == entry.data.meshName) break;

            ::CURRENT_OPERATION = "change mesh of " + target + " to " + meshName;
            local A = ::SceneEditorFramework.Actions[::ACTION_CHANGE_MESH_RESOURCE];
            local action = A(tree, editorBase.mBus_, target, entry.data.meshName, meshName);
            editorBase.pushAction(action);
            action.performAction();
            break;
        }
        case ::OP_TRANSFORM:{
            local target = randomId(ids);
            local coordType = nextRandom(3);
            tree.setSingleSelection(target);

            //The same sequence a gizmo drag makes: the tree records what the
            //object was before the drag, the drag itself moves the object, and
            //the end of it is what puts an action on the stack.
            ::CURRENT_OPERATION = "transform " + target + " of type " + coordType;
            tree.notifyBusEvent(::EVENT_GIZMO_BEGAN, coordType);
            if(coordType == ::COORD_POSITION){
                tree.setSelectedNodePosition(randomPosition());
            }else if(coordType == ::COORD_SCALE){
                tree.setSelectedNodeScale(randomScale());
            }else{
                tree.setSelectedNodeOrientationFromWorldDelta_(randomOrientationDelta());
            }
            tree.notifyBusEvent(::EVENT_GIZMO_ENDED, coordType);
            break;
        }
        case ::OP_MULTI_TRANSFORM:{
            local selected = selectSeveral(tree, ids, 2 + nextRandom(3));
            if(selected.len() == 0) break;

            //A drag of more than one object is one action for the whole of the
            //selection rather than one per object, whichever transform tool
            //made it.
            local coordType = nextRandom(3);
            ::CURRENT_OPERATION = "transform selection " + idsString(selected) +
                " of type " + coordType;
            tree.notifyBusEvent(::EVENT_GIZMO_BEGAN, coordType);
            if(coordType == ::COORD_POSITION){
                tree.setSelectedNodePosition(randomPosition());
            }else if(coordType == ::COORD_SCALE){
                tree.setSelectedNodeScale(randomScale());
            }else{
                tree.setSelectedNodeOrientationFromWorldDelta_(randomOrientationDelta());
            }
            tree.notifyBusEvent(::EVENT_GIZMO_ENDED, coordType);
            break;
        }
        case ::OP_REARRANGE:{
            if(ids.len() < 2) break;

            local target = randomId(ids);
            local destination = randomId(ids);
            if(destination == target) break;

            local insertion = randomInsertion();
            ::CURRENT_OPERATION = "move " + target + " " + insertion + " " + destination;
            tree.setSingleSelection(target);
            tree.rearrangeCurrentSelection(destination, insertion);
            break;
        }
        case ::OP_REARRANGE_MULTI:{
            if(ids.len() < 3) break;

            local selected = selectSeveral(tree, ids, 2 + nextRandom(2));
            if(selected.len() == 0) break;

            local destination = randomId(ids);
            if(arrayContains(selected, destination)) break;

            local insertion = randomInsertion();
            ::CURRENT_OPERATION = "move selection " + idsString(selected) + " " +
                insertion + " " + destination;
            tree.rearrangeCurrentSelection(destination, insertion);
            break;
        }
        case ::OP_COPY_PASTE:{
            //A paste brings in a copy of everything below what was copied, so
            //leave it alone once the tree has reached the size it is kept at.
            if(ids.len() >= ::STRESS_OBJECT_TARGET) break;

            local selected = selectSeveral(tree, ids, 1 + nextRandom(3));
            if(selected.len() == 0) break;
            if(!tree.copySelectionToClipboard(clipboard)) break;

            //A paste with no target of its own goes beside the selection, one
            //aimed at an entry goes where that entry says, and the scene tree's
            //own background paste goes at the end of the top level.
            local choice = nextRandom(3);
            if(choice == 0){
                ::CURRENT_OPERATION = "paste " + idsString(selected) + " beside the selection";
                tree.pasteFromClipboard(clipboard);
            }else if(choice == 1){
                local destination = randomId(ids);
                local insertion = randomInsertion();
                ::CURRENT_OPERATION = "paste " + idsString(selected) + " " +
                    insertion + " " + destination;
                tree.pasteFromClipboard(clipboard, destination, insertion);
            }else{
                ::CURRENT_OPERATION = "paste " + idsString(selected) + " at the top level";
                tree.pasteFromClipboardAtTopLevel(clipboard);
            }
            break;
        }
        case ::OP_REPARENT_EMPTY:{
            local selected = selectSeveral(tree, ids, 1 + nextRandom(3));
            if(selected.len() == 0) break;

            local name = "Group" + nextName();
            ::CURRENT_OPERATION = "group " + idsString(selected) + " under " + name;
            tree.reparentSelectionWithEmpty(name);
            break;
        }
        case ::OP_CENTRE_ON_CONTENTS:{
            local parents = parentEntryIds(tree);
            if(parents.len() == 0) break;

            local target = randomId(parents);
            ::CURRENT_OPERATION = "centre " + target + " on its contents";
            tree.centreEntryOnContents(target);
            break;
        }
        case ::OP_DELETE:{
            local selected = selectSeveral(tree, ids, 1 + nextRandom(3));
            if(selected.len() == 0) break;

            ::CURRENT_OPERATION = "delete " + idsString(selected);
            tree.deleteCurrentSelection();
            break;
        }
        case ::OP_TAG:{
            local target = randomId(ids);
            local roll = nextRandom(3);
            local tag = null;
            if(roll == 0){
                //Give up whatever tag it holds.
            }else if(roll == 1){
                //One of a small set, so the run keeps asking for tags which are
                //already taken. Those must be refused rather than moved off the
                //object holding them, and must leave nothing on the stack.
                tag = "Tag" + nextRandom(4);
            }else{
                tag = "Tag" + nextName();
            }
            ::CURRENT_OPERATION = "set the tag of " + target + " to " +
                (tag == null ? "-" : tag);
            tree.setEntryTag(target, tag);
            break;
        }
    }
}

//Insertion while the tree is below the size it is kept at and deletion once it
//is above it, so a run of any length works on a tree of about that size rather
//than emptying it or growing without bound.
function chooseOperation(objectCount){
    local roll = nextRandom(100);
    if(objectCount < 8) return roll % 2 == 0 ? ::OP_INSERT_EMPTY : ::OP_INSERT_MESH;
    if(objectCount > ::STRESS_OBJECT_TARGET && roll < 35) return ::OP_DELETE;
    if(objectCount < ::STRESS_OBJECT_TARGET && roll < 35){
        return roll % 2 == 0 ? ::OP_INSERT_EMPTY : ::OP_INSERT_MESH;
    }

    return nextRandom(::OP_MAX);
}

/**
 * What the tree holds, as a string.
 *
 * Both what the tree says about each object and what its engine node says are
 * described, so an action which puts an entry back without putting its node back
 * is a mismatch rather than something which goes unnoticed. Everything an action
 * is responsible for restoring belongs here; the selection does not, since it
 * belongs to the user rather than to a position in the stack.
 */
function captureState(tree){
    local result = "";
    foreach(entry in tree.mEntries_){
        if(entry.nodeType == ::TYPE_CHILD){
            result += "[";
            continue;
        }
        if(entry.nodeType == ::TYPE_TERM){
            result += "]";
            continue;
        }

        result += "{" + entry.entryId + " " + entry.nodeType +
            " " + (entry.name == null ? "-" : entry.name) +
            " " + (entry.tag == null ? "-" : entry.tag) +
            " " + (entry.nodeType == ::TYPE_MESH ? entry.data.meshName : "-") +
            " " + (entry.visible ? "visible" : "hidden") +
            " " + vec3String(entry.node.getPositionVec3()) +
            " " + vec3String(entry.node.getScale()) +
            " " + quatString(entry.node.getOrientation()) +
            " " + entry.node.getNumAttachedObjects() + "}";
    }

    return result;
}

function assertState(tree, expected, description){
    local actual = captureState(tree);
    if(actual != expected){
        //The comparison prints both trees, which says nothing about which step
        //produced them.
        print("Scene tree stress test mismatch after " + description);
    }
    _test.assertEqual(expected, actual);

    assertTreeConsistent(tree);
}

/**
 * Everything which must be true of the tree whatever has been done to it.
 *
 * This is where a leak shows up: an engine node, an id or a node lookup left
 * behind by an edit or by undoing one is not part of the state the edit
 * describes, so it is caught here rather than by the comparison above.
 */
function assertTreeConsistent(tree){
    local entries = tree.mEntries_;
    //Every scene has the root marker pair.
    _test.assertTrue(entries.len() >= 2);
    _test.assertEqual(::TYPE_CHILD, entries[0].nodeType);
    _test.assertEqual(::TYPE_TERM, entries[entries.len() - 1].nodeType);

    //The hierarchy the flattened tree describes, walked the same way the tree
    //builds its scene nodes from it.
    local currentNodes = [tree.mSceneRootNode_];
    local lastNode = null;
    local objectCount = 0;
    local seenIds = {};
    //How many direct children each node is expected to have, keyed by node id.
    local childCounts = {};
    childCounts.rawset(tree.mSceneRootNode_.getId(), 0);

    for(local index = 0; index < entries.len(); index++){
        local entry = entries[index];
        if(entry.nodeType == ::TYPE_CHILD){
            //A group with nothing in it is removed as its last object leaves,
            //so only the root pair can be empty.
            _test.assertTrue(index == 0 ||
                entries[index + 1].nodeType != ::TYPE_TERM);
            if(index != 0) currentNodes.append(lastNode);
            continue;
        }
        if(entry.nodeType == ::TYPE_TERM){
            _test.assertTrue(currentNodes.len() > 0);
            currentNodes.pop();
            continue;
        }

        objectCount++;
        _test.assertFalse(seenIds.rawin(entry.entryId));
        seenIds.rawset(entry.entryId, true);

        //Each object has an engine node, under the node its place in the
        //flattened tree says it belongs to.
        _test.assertNotEqual(null, entry.node);
        local parent = currentNodes.top();
        _test.assertEqual(parent.getId(), entry.node.getParent().getId());
        childCounts.rawset(parent.getId(), childCounts.rawget(parent.getId()) + 1);
        childCounts.rawset(entry.node.getId(), 0);

        //The lookup from engine node back to entry is what a scene click goes
        //through, and it is rebuilt with the nodes rather than added to.
        _test.assertTrue(tree.mNodesForEntry_.rawin(entry.node.getId()));
        _test.assertEqual(entry.entryId, tree.mNodesForEntry_.rawget(entry.node.getId()));

        lastNode = entry.node;
    }

    //Every marker was closed.
    _test.assertEqual(0, currentNodes.len());
    _test.assertEqual(objectCount, tree.mNodesForEntry_.len());

    //No node holds a child the tree does not know about, so nothing an edit
    //built or rebuilt has been left behind under one of the nodes which remain.
    foreach(nodeId, expectedChildren in childCounts){
        _test.assertEqual(expectedChildren, nodeForId(tree, nodeId).getNumChildren());
    }

    assertIdsUnclaimed(tree, seenIds);
    assertTagsUnique(tree);
}

//A tag identifies one object in a scene, so no edit - and no undo of one - may
//leave two objects claiming the same one.
function assertTagsUnique(tree){
    local seenTags = {};
    foreach(entry in tree.mEntries_){
        if(entry.tag == null) continue;
        _test.assertFalse(seenTags.rawin(entry.tag));
        seenTags.rawset(entry.tag, true);
    }
}

//An id is either an object's or waiting in the pool to be handed out again.
//One which is in neither has been leaked, and one which is in both is about to
//be given to a second object.
function assertIdsUnclaimed(tree, liveIds){
    local pooled = {};
    foreach(id in tree.mIdPool_.mIdPool_){
        _test.assertFalse(pooled.rawin(id));
        _test.assertFalse(liveIds.rawin(id));
        pooled.rawset(id, true);
    }

    _test.assertEqual(tree.mIdPool_.mCount_, liveIds.len() + pooled.len());
}

//With the whole run undone, the only ids in use are the ones the file was
//loaded with: everything the run created has been given back.
function assertIdsAccountedFor(tree){
    local ids = objectIds(tree);
    local liveIds = {};
    foreach(id in ids) liveIds.rawset(id, true);

    assertIdsUnclaimed(tree, liveIds);
}

function nodeForId(tree, nodeId){
    if(tree.mSceneRootNode_.getId() == nodeId) return tree.mSceneRootNode_;

    local entryId = tree.mNodesForEntry_.rawget(nodeId);
    return tree.getEntryForId(entryId).node;
}

//The objects in the tree, in tree order. The markers which describe the
//hierarchy are not objects and have no ids.
function objectIds(tree){
    local result = [];
    foreach(entry in tree.mEntries_){
        if(entry.nodeType == ::TYPE_CHILD || entry.nodeType == ::TYPE_TERM) continue;
        result.append(entry.entryId);
    }
    return result;
}

function meshEntryIds(tree){
    local result = [];
    foreach(entry in tree.mEntries_){
        if(entry.nodeType == ::TYPE_MESH) result.append(entry.entryId);
    }
    return result;
}

function parentEntryIds(tree){
    local result = [];
    local entries = tree.mEntries_;
    for(local index = 0; index < entries.len() - 1; index++){
        local entry = entries[index];
        if(entry.nodeType == ::TYPE_CHILD || entry.nodeType == ::TYPE_TERM) continue;
        if(entries[index + 1].nodeType == ::TYPE_CHILD) result.append(entry.entryId);
    }
    return result;
}

//Build a selection of up to count objects and return what was selected, which
//is not what was asked for when the same object came up twice.
function selectSeveral(tree, ids, count){
    if(ids.len() == 0) return [];

    tree.clearAllSelection();
    local selected = [];
    for(local i = 0; i < count; i++){
        local id = randomId(ids);
        if(arrayContains(selected, id)) continue;
        selected.append(id);
        tree.notifySelectionChanged(id, true, false);
    }

    return selected;
}

function randomId(ids){
    return ids[nextRandom(ids.len())];
}

function randomInsertion(){
    local insertions = [::INTO, ::ABOVE, ::BELOW];
    return insertions[nextRandom(insertions.len())];
}

function randomPosition(){
    return Vec3(randomCoordinate(), randomCoordinate(), randomCoordinate());
}

function randomScale(){
    //Away from zero, so an object's scale stays something a bounding box can be
    //taken from.
    return Vec3(randomScaleValue(), randomScaleValue(), randomScaleValue());
}

function randomOrientationDelta(){
    return Quat(nextRandom(360).tofloat() * 0.0174532, Vec3(0, 1, 0));
}

function randomCoordinate(){
    return (nextRandom(2001) - 1000).tofloat() / 100.0;
}

function randomScaleValue(){
    return (nextRandom(400) + 25).tofloat() / 100.0;
}

/**
 * A generator of this file's own, so a run is the same run every time.
 *
 * The engine's own random numbers are shared with everything else which asks for
 * one, which would leave a failing run impossible to look at a second time. The
 * high bits are what is used, since the low ones of a generator like this repeat
 * far sooner than the whole of it does.
 */
function nextRandom(limit){
    ::RANDOM_STATE = (::RANDOM_STATE * 1103515245 + 12345) % 2147483648;
    return (::RANDOM_STATE / 65536) % limit;
}

function nextName(){
    ::NAME_COUNTER = ::NAME_COUNTER + 1;
    return ::NAME_COUNTER;
}

function describe(descriptions, index){
    return "step " + index + " (" + descriptions[index - 1] + ")";
}

function idsString(ids){
    local result = "";
    foreach(id in ids) result += (result == "" ? "" : ",") + id;
    return result;
}

function vec3String(vec){
    return vec.x + "/" + vec.y + "/" + vec.z;
}

function quatString(quat){
    return quat.x + "/" + quat.y + "/" + quat.z + "/" + quat.w;
}

function arrayContains(target, value){
    foreach(i in target){
        if(i == value) return true;
    }
    return false;
}
