::SceneEditorFramework.GUISceneTree <- class extends ::SceneEditorFramework.GUIPanel{

    constructor(parent, baseObj){
        base.constructor(parent, baseObj);

        setup();
    }

    function setup(){
        local layout = _gui.createLayoutLine();

        local label = mParent_.createLabel();
        label.setText("Scene Tree");

        //TODO find a better way to get this.
        local activeTree = mBaseObj_.mActiveTree_;
        local indent = -1;
        local vertical = 0;
        foreach(c,entry in activeTree.mEntries_){
            local nodeType = entry.nodeType;
            if(nodeType == SceneTreeEntryType.CHILD){
                indent++;
                continue;
            }
            else if(nodeType == SceneTreeEntryType.TERM){
                indent--;
                continue;
            }
            local entry = mParent_.createLabel();
            entry.setPosition(indent * 30, vertical * 20);
            local testText = ::SceneEditorFramework.getNameForSceneEntryType(nodeType);
            entry.setText(testText);
            vertical++;
            //layout.addCell(entry);
        }

        layout.layout();
    }

};