::SceneEditorFramework.FileParser <- class{

    static INVALID_TAG = "Invalid tag in file"

    constructor(){

    }

    function parseForSceneTree(path, tree){
        printf("Beginning parse for file at path '%s'", path);

        local doc = XMLDocument();
        doc.loadFile(path);

        local root = doc.getRootElement();
        if(root.getName() != "scene") throw INVALID_TAG;

        local entries = [CHILD_ENTRY];
        local currentChild = root.getFirstChildElement();
        while(currentChild != null){
            parseNodeForSceneTree_(currentChild, entries);

            currentChild = currentChild.nextSiblingElement();
        }
        entries.append(TERM_ENTRY);

        tree.setEntries(entries);
    }

    function parseNodeForSceneTree_(node, entries){
        local nodeEntry = ::SceneEditorFramework.SceneTreeEntry();
        nodeEntry.reset();

        local name = node.getName();
        nodeEntry.nodeType = getNodeTypeForName(name);
        entries.append(nodeEntry);

        nodeEntry.data = parseDataForNode_(name, node);

        if(!node.hasChildren()){
            return;
        }

        local currentChild = node.getFirstChildElement();
        local startedWrap = false;
        while(currentChild != null){

            local name = currentChild.getName();
            if(name == "position"){
                nodeEntry.position.x = currentChild.getAttribute("x").tofloat();
                nodeEntry.position.y = currentChild.getAttribute("y").tofloat();
                nodeEntry.position.z = currentChild.getAttribute("z").tofloat();
            }
            else if(name == "orientation"){
                nodeEntry.orientation.x = currentChild.getAttribute("x").tofloat();
                nodeEntry.orientation.y = currentChild.getAttribute("y").tofloat();
                nodeEntry.orientation.z = currentChild.getAttribute("z").tofloat();
                nodeEntry.orientation.w = currentChild.getAttribute("w").tofloat();
            }
            else if(name == "scale"){
                nodeEntry.scale.x = currentChild.getAttribute("x").tofloat();
                nodeEntry.scale.y = currentChild.getAttribute("y").tofloat();
                nodeEntry.scale.z = currentChild.getAttribute("z").tofloat();
            }
            else{
                if(getNodeTypeForName(name) != SceneTreeEntryType.NONE){
                    if(!startedWrap){
                        entries.append(CHILD_ENTRY);
                    }
                    parseNodeForSceneTree_(currentChild, entries);
                    startedWrap = true;
                }
            }

            currentChild = currentChild.nextSiblingElement();
        }
        if(startedWrap){
            entries.append(TERM_ENTRY);
        }
    }

    function parseDataForNode_(name, node){
        if(name == "mesh"){
            local mesh = node.getAttribute("mesh");

            local meshData = ::SceneEditorFramework.SceneTreeMeshData();
            meshData.meshName = mesh;
            return meshData;
        }

        return null;
    }

    function getNodeTypeForName(name){
        if(name == "empty") return SceneTreeEntryType.EMPTY;
        else if(name == "mesh") return SceneTreeEntryType.MESH;

        return SceneTreeEntryType.NONE;
    }

};
::SceneEditorFramework.FileParser.CHILD_ENTRY <- ::SceneEditorFramework.SceneTreeEntry();
::SceneEditorFramework.FileParser.CHILD_ENTRY.nodeType = SceneTreeEntryType.CHILD;
::SceneEditorFramework.FileParser.TERM_ENTRY <- ::SceneEditorFramework.SceneTreeEntry();
::SceneEditorFramework.FileParser.TERM_ENTRY.nodeType = SceneTreeEntryType.TERM;