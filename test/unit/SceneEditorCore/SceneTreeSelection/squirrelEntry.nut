//Single, additive, range and reduced scene-tree selection, including what the
//selection means once an object it names is gone.
//
//Everything an editor does to an object - the properties panel, the gizmos, the
//options offered for a right clicked object - goes through the selection, so a
//selection which outlives its entry is a selection pointing at an entry which is
//no longer in the tree.
function start(){
    local editorBase = ::SceneEditorFramework.Base();
    local parentNode = _scene.getRootSceneNode().createChildSceneNode();
    local tree = editorBase.loadSceneTree(parentNode, "res://test.avScene");
    editorBase.setActiveSceneTree(tree);

    local firstId = findObjectId(tree, "First");
    local firstChildId = findObjectId(tree, "First child");
    local secondId = findObjectId(tree, "Second");
    local thirdId = findObjectId(tree, "Third");
    _test.assertNotEqual(null, firstId);
    _test.assertNotEqual(null, firstChildId);
    _test.assertNotEqual(null, secondId);
    _test.assertNotEqual(null, thirdId);

    { //Selecting names the entry.
        tree.notifySelectionChanged(firstId);
        _test.assertEqual(firstId, tree.mCurrentSelection);
        _test.assertEqual(1, tree.getSelectedCount());
        _test.assertTrue(tree.isEntrySelected(firstId));
        _test.assertEqual(firstId, tree.getFirstSelection());
    }

    { //Control adds to the selection. Clicking one of the selected entries
      //again without modifiers keeps the group ready for dragging.
        tree.notifySelectionChanged(secondId, true, false);
        _test.assertEqual(2, tree.getSelectedCount());
        _test.assertTrue(tree.isEntrySelected(firstId));
        _test.assertTrue(tree.isEntrySelected(secondId));

        tree.notifySelectionChanged(firstId);
        _test.assertEqual(2, tree.getSelectedCount());
        _test.assertEqual(firstId, tree.mCurrentSelection);
    }

    { //An ordinary click on an unselected entry starts a new selection.
        tree.notifySelectionChanged(thirdId);
        _test.assertEqual(1, tree.getSelectedCount());
        _test.assertTrue(tree.isEntrySelected(thirdId));
        _test.assertFalse(tree.isEntrySelected(firstId));
    }

    { //Shift selects every object in the flattened tree between the most
      //recent selection and the clicked entry, ignoring hierarchy markers.
        tree.notifySelectionChanged(firstId, false, true);
        _test.assertEqual(4, tree.getSelectedCount());
        _test.assertTrue(tree.isEntrySelected(firstId));
        _test.assertTrue(tree.isEntrySelected(firstChildId));
        _test.assertTrue(tree.isEntrySelected(secondId));
        _test.assertTrue(tree.isEntrySelected(thirdId));
    }

    { //A reduced selection omits a selected descendant when its parent is
      //also selected; reordering actions can operate on this list directly.
        local reduced = tree.getReducedSelection();
        _test.assertEqual(3, reduced.len());
        _test.assertTrue(arrayContains(reduced, firstId));
        _test.assertFalse(arrayContains(reduced, firstChildId));
    }

    { //Selecting nothing - clicking empty space in the scene tree, say - names
      //nothing rather than leaving the previous entry named.
        tree.notifySelectionChanged(null);
        _test.assertEqual(-1, tree.mCurrentSelection);
        _test.assertEqual(-1, tree.mCurrentSelectionIdx);
        _test.assertEqual(0, tree.getSelectedCount());
    }

    { //Tapping the same spot in the scene steps through the objects along the
      //ray, so one behind another can be reached by clicking again rather than
      //only through the Alt-click chooser. @see SceneTree.pickEntryFromQuery_
        local hits = [firstId, secondId, thirdId];
        local order = [firstId, secondId, thirdId, firstId];
        foreach(expected in order){
            local picked = tree.pickEntryFromQuery_(hits);
            _test.assertEqual(expected, picked);
            //What the click goes on to do with the entry it picked.
            tree.setCurrentSelection(picked);
        }

        //A different set of objects means the cursor is somewhere else, so the
        //nearest is taken rather than the next along the previous ray.
        local moved = [secondId, thirdId];
        _test.assertEqual(secondId, tree.pickEntryFromQuery_(moved));
        tree.setCurrentSelection(secondId);

        //So does selecting something else in between, in the tree say: a click
        //always selects what is actually in front of it.
        tree.setCurrentSelection(thirdId);
        _test.assertEqual(secondId, tree.pickEntryFromQuery_(moved));

        //Clicking where there is nothing selects nothing.
        _test.assertEqual(null, tree.pickEntryFromQuery_([]));
    }

    { //A rotation gizmo drag applies its world-axis delta to a nested object
      //and records the completed orientation change for undo.
        local parentEntry = tree.getEntryForId(firstId);
        local childEntry = tree.getEntryForId(firstChildId);
        parentEntry.setOrientation(Quat(PI / 2, Vec3(0, 0, 1)));
        tree.notifySelectionChanged(firstChildId);

        local worldDelta = Quat(PI / 2, Vec3(1, 0, 0));
        local oldDirection = childEntry.node.getDerivedOrientation() * Vec3(0, 1, 0);
        //The test script is compiled before plugin enums exist, so these are
        //the values of BEGAN, SELECTED_ORIENTATION_CHANGE, ENDED and ORIENTATION.
        editorBase.mBus_.transmitEvent(4, 2);
        editorBase.mBus_.transmitEvent(8, worldDelta);
        editorBase.mBus_.transmitEvent(5, 2);

        local newDirection = childEntry.node.getDerivedOrientation() * Vec3(0, 1, 0);
        assertVecClose(worldDelta * oldDirection, newDirection);

        editorBase.mActionStack_.undo();
        local restoredDirection = childEntry.node.getDerivedOrientation() * Vec3(0, 1, 0);
        assertVecClose(oldDirection, restoredDirection);
    }

    { //Deleting a multi-selection removes every selected entry and clears the
      //selection, so nothing is left naming a deleted entry.
        tree.notifySelectionChanged(secondId);
        tree.notifySelectionChanged(thirdId, true, false);
        tree.deleteCurrentSelection();

        _test.assertEqual(null, tree.findEntryIdIndexInTree_(secondId));
        _test.assertEqual(null, tree.findEntryIdIndexInTree_(thirdId));
        _test.assertNotEqual(null, tree.findEntryIdIndexInTree_(firstId));
        _test.assertEqual(-1, tree.mCurrentSelection);
        _test.assertEqual(-1, tree.mCurrentSelectionIdx);
        _test.assertEqual(0, tree.getSelectedCount());
    }

    { //A shift click in the scene adds the object to the selection, and the
      //whole selection is outlined by one box around everything in it rather
      //than the outline staying on the object which was selected first.
      //@see SceneTree.toggleEntrySelection
        local leftCube = tree.insertPrimitiveMeshChild(firstId, "cube", "Left cube");
        local rightCube = tree.insertPrimitiveMeshChild(firstId, "cube", "Right cube");
        tree.getEntryForId(leftCube).setPosition(Vec3(-4, 0, 0));
        tree.getEntryForId(rightCube).setPosition(Vec3(4, 0, 0));

        //One object with nothing below it is entirely described by its own
        //outline, so there is no second box to draw.
        tree.notifySelectionChanged(leftCube);
        _test.assertFalse(tree.mChildrenOutlineBox_.mVisible_);

        tree.toggleEntrySelection(rightCube);
        _test.assertEqual(2, tree.getSelectedCount());
        _test.assertTrue(tree.isEntrySelected(leftCube));
        _test.assertEqual(rightCube, tree.mCurrentSelection);
        _test.assertTrue(tree.mChildrenOutlineBox_.mVisible_);
        //Big enough to hold both cubes, which sit 8 apart. Their parent is
        //rotated by an earlier case, so which axis they are apart on is not
        //assumed here.
        local outlineCentre = tree.mChildrenOutlineBox_.mCentre_;
        local outlineHalfSize = tree.mChildrenOutlineBox_.mHalfSize_;
        assertBoxContains(outlineCentre, outlineHalfSize, tree.getEntryAABB(leftCube));
        assertBoxContains(outlineCentre, outlineHalfSize, tree.getEntryAABB(rightCube));
        _test.assertTrue(largestExtent(outlineHalfSize) >= 4.0);

        //Shift clicking a selected object takes it back out, handing the
        //gizmo and the outline to what is still selected.
        tree.toggleEntrySelection(rightCube);
        _test.assertEqual(1, tree.getSelectedCount());
        _test.assertEqual(leftCube, tree.mCurrentSelection);
        _test.assertFalse(tree.mChildrenOutlineBox_.mVisible_);
    }

    { //A position outside the scene viewport is over nothing, rather than an
      //error. @see SceneTree.findEntryIdAtScenePosition
        _test.assertEqual(null, tree.findEntryIdAtScenePosition(null));
        _test.assertEqual(0, tree.findEntryIdsAtScenePosition(null).len());
    }

    _test.endTest();
}

//The first entry which is an object rather than one of the markers which give
//the flattened tree its shape.
//
//Found by name rather than by node type, because the framework's enums are
//squirrel constants: they exist once the plugin's scripts have run, which is
//after this file was compiled, so naming one here would not resolve.
function findObjectId(tree, name){
    foreach(entry in tree.mEntries_){
        if(entry.name == name) return entry.entryId;
    }

    return null;
}

function arrayContains(values, target){
    foreach(value in values){
        if(value == target) return true;
    }
    return false;
}

//Every corner of the bounds lies inside the box the outline was given.
function assertBoxContains(centre, halfSize, bounds){
    local boundsCentre = bounds.getCentre();
    local boundsHalfSize = bounds.getHalfSize();
    _test.assertTrue(fabs(boundsCentre.x - centre.x) + boundsHalfSize.x <= halfSize.x + 0.001);
    _test.assertTrue(fabs(boundsCentre.y - centre.y) + boundsHalfSize.y <= halfSize.y + 0.001);
    _test.assertTrue(fabs(boundsCentre.z - centre.z) + boundsHalfSize.z <= halfSize.z + 0.001);
}

function largestExtent(halfSize){
    local largest = halfSize.x;
    if(halfSize.y > largest) largest = halfSize.y;
    if(halfSize.z > largest) largest = halfSize.z;
    return largest;
}

function assertVecClose(expected, found){
    _test.assertTrue(expected.distance(found) <= 0.001);
}
