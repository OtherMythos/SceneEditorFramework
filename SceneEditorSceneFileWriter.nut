::SceneEditorFramework.FileWriter <- class{

    BASIC_POSITION = Vec3()
    BASIC_SCALE = Vec3(1, 1, 1)
    BASIC_ORIENTATION = Quat()

    constructor(){

    }

    function writeToFile(path, tree){
        printf("Writing file to path '%s'", path);

        local doc = XMLDocument();

        local root = doc.newElement("scene");

        local parents = [root];
        local indent = 0;
        local current = root;
        foreach(i in tree.mEntries_){
            local nodeType = i.nodeType;
            if(nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
                indent++;
                parents.append(current);
                continue;
            }
            else if(nodeType == SceneEditorFramework_SceneTreeEntryType.TERM){
                indent--;
                parents.pop();
                continue;
            }

            //current = parents.top().insertNewChildElement("mesh");
            current = _writeElementForEntry(i, parents.top());
        }

        doc.writeFile(path);
    }

    function _writeElementForEntry(entry, parent){
        local nameType = ::SceneEditorFramework.getNameForSceneEntryType(entry.nodeType);

        local inserted = parent.insertNewChildElement(nameType);

        if(entry.position <=> BASIC_POSITION){
            local position = inserted.insertNewChildElement("position");
            local target = entry.node.getPositionVec3();
            position.setAttribute("x", target.x.tostring());
            position.setAttribute("y", target.y.tostring());
            position.setAttribute("z", target.z.tostring());
        }
        if(entry.scale <=> BASIC_SCALE){
            local scale = inserted.insertNewChildElement("scale");
            scale.setAttribute("x", entry.scale.x.tostring());
            scale.setAttribute("y", entry.scale.y.tostring());
            scale.setAttribute("z", entry.scale.z.tostring());
        }
        if(entry.orientation <=> BASIC_ORIENTATION){
            local orientation = inserted.insertNewChildElement("orientation");
            orientation.setAttribute("x", entry.orientation.x.tostring());
            orientation.setAttribute("y", entry.orientation.y.tostring());
            orientation.setAttribute("z", entry.orientation.z.tostring());
            orientation.setAttribute("w", entry.orientation.w.tostring());
        }

        if(entry.animIdx != -1){
            inserted.setAttribute("animIdx", entry.animIdx);
        }

        if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.MESH){
            inserted.setAttribute("mesh", entry.data.meshName);
        }

        return inserted;
    }

};