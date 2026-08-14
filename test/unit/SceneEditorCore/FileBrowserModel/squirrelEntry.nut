function start(){
    local contents = {
        "virtual://root": [
            { name = "zeta.txt", isDirectory = false },
            { name = "Folder B", isDirectory = true },
            { name = "alpha.txt", isDirectory = false },
            { name = "Folder A", isDirectory = true }
        ],
        "virtual://root/Folder A": [
            { name = "nested.scene", isDirectory = false }
        ],
        "virtual://root/Folder B": []
    };
    local backend = {
        listDirectory = function(path){
            if(!contents.rawin(path)) throw "Not a directory";
            return contents.rawget(path);
        }
    };

    local model = ::SceneEditorFramework.FileBrowserModel("virtual://root/", backend);
    _test.assertEqual("virtual://root", model.getRootPath());
    _test.assertEqual("virtual://root", model.getCurrentPath());
    assertEntry(model.getEntries()[0], "Folder A", true);
    assertEntry(model.getEntries()[1], "Folder B", true);
    assertEntry(model.getEntries()[2], "alpha.txt", false);
    assertEntry(model.getEntries()[3], "zeta.txt", false);

    local folder = model.getEntries()[0];
    model.select(folder);
    _test.assertEqual(folder.path, model.getSelectedPath());
    _test.assertTrue(model.enter(folder));
    _test.assertEqual("virtual://root/Folder A", model.getCurrentPath());
    _test.assertEqual(null, model.getSelectedPath());
    assertEntry(model.getEntries()[0], "nested.scene", false);

    _test.assertFalse(model.setCurrentPath("virtual://outside"));
    _test.assertEqual("virtual://root/Folder A", model.getCurrentPath());
    _test.assertFalse(model.setCurrentPath("virtual://root/../outside"));
    _test.assertTrue(model.goUp());
    _test.assertEqual("virtual://root", model.getCurrentPath());
    _test.assertFalse(model.goUp());

    _test.assertTrue(model.setCurrentPath("virtual://root/Folder B"));
    _test.assertEqual(0, model.getEntries().len());
    _test.assertTrue(model.goToDepth(0));
    _test.assertEqual("virtual://root", model.getCurrentPath());

    //The default backend separates real directories from files using only the
    //filesystem functions exposed by avEngine.
    local filesystemModel = ::SceneEditorFramework.FileBrowserModel("res://");
    local setupFile = findEntry(filesystemModel, "avSetup.cfg");
    _test.assertNotEqual(null, setupFile);
    _test.assertFalse(setupFile.isDirectory);
    local fixtureDirectory = findEntry(filesystemModel, "fixtureDirectory");
    _test.assertNotEqual(null, fixtureDirectory);
    _test.assertTrue(fixtureDirectory.isDirectory);
    _test.assertTrue(filesystemModel.enter(fixtureDirectory));
    _test.assertNotEqual(null, findEntry(filesystemModel, "inside.txt"));

    _test.endTest();
}

function assertEntry(entry, name, directory){
    _test.assertEqual(name, entry.name);
    _test.assertEqual(directory, entry.isDirectory);
}

function findEntry(model, name){
    foreach(entry in model.getEntries()){
        if(entry.name == name) return entry;
    }
    return null;
}
