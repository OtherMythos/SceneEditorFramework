/**
 * Filesystem-facing state for the ImGui file browser.
 *
 * Paths remain rooted below mRootPath_. Keeping navigation here rather than in
 * the panel makes the filesystem behaviour reusable by resource pickers and
 * keeps the ImGui class concerned only with presentation.
 */
::SceneEditorFramework.FileBrowserModel <- class{

    mRootPath_ = null;
    mSegments_ = null;
    mEntries_ = null;
    mSelectedPath_ = null;
    mError_ = null;
    mListDirectory_ = null;
    mIsDirectory_ = null;

    constructor(rootPath="res://", options=null){
        if(options == null) options = {};
        mRootPath_ = normaliseRoot_(rootPath);
        mSegments_ = [];
        mEntries_ = [];
        mListDirectory_ = options.rawin("listDirectory") ?
            options.rawget("listDirectory") : function(path){
                return _system.getFilesInDirectory(path);
            };
        mIsDirectory_ = options.rawin("isDirectory") ?
            options.rawget("isDirectory") : function(path){
                //std::filesystem considers "directory/." to exist, while
                //"file/." does not. This lets the current avEngine API expose
                //entry type without probing a file with a directory iterator.
                return _system.exists(path + "/.");
            };
        refresh();
    }

    function getRootPath(){ return mRootPath_; }
    function getCurrentPath(){ return pathForSegments_(mSegments_.len()); }
    function getSegments(){ return clone mSegments_; }
    function getEntries(){ return mEntries_; }
    function getSelectedPath(){ return mSelectedPath_; }
    function getError(){ return mError_; }

    function select(entry){
        mSelectedPath_ = entry == null ? null : entry.path;
    }

    function refresh(){
        mError_ = null;
        mEntries_.clear();
        local currentPath = getCurrentPath();

        try{
            local names = mListDirectory_(currentPath);
            foreach(value in names){
                local name = typeof value == "table" && value.rawin("name") ?
                    value.rawget("name") : value;
                if(typeof name != "string" || name.len() == 0 ||
                    name == "." || name == "..") continue;

                local path = join_(currentPath, name);
                local directory = typeof value == "table" && value.rawin("isDirectory") ?
                    value.rawget("isDirectory") : mIsDirectory_(path);
                mEntries_.append({
                    "name": name,
                    "path": path,
                    "isDirectory": directory,
                    "kind": kindForEntry_(name, directory)
                });
            }
            mEntries_.sort(function(a, b){
                if(a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
                return a.name.tolower() <=> b.name.tolower();
            });
        }catch(error){
            mError_ = error.tostring();
        }

        if(mSelectedPath_ != null && findEntryByPath_(mSelectedPath_) == null){
            mSelectedPath_ = null;
        }
        return mError_ == null;
    }

    function enter(entry){
        if(entry == null || !entry.isDirectory) return false;
        mSegments_.append(entry.name);
        mSelectedPath_ = null;
        if(refresh()) return true;
        //The directory may have disappeared since the listing was built.
        mSegments_.pop();
        refresh();
        return false;
    }

    function goUp(){
        if(mSegments_.len() == 0) return false;
        mSegments_.pop();
        mSelectedPath_ = null;
        refresh();
        return true;
    }

    function goToDepth(depth){
        if(depth < 0 || depth > mSegments_.len()) return false;
        while(mSegments_.len() > depth) mSegments_.pop();
        mSelectedPath_ = null;
        refresh();
        return true;
    }

    //Accept either the root itself or a descendant. Lexical '..' components
    //are resolved but cannot escape the configured root.
    function setCurrentPath(path){
        if(typeof path != "string") return false;
        local relative = null;
        if(path == mRootPath_){
            relative = "";
        }else{
            local prefix = mRootPath_ + (rootEndsWithSeparator_() ? "" : "/");
            if(path.len() < prefix.len() || path.slice(0, prefix.len()) != prefix) return false;
            relative = path.slice(prefix.len());
        }

        local newSegments = [];
        foreach(segment in splitPath_(relative)){
            if(segment == "" || segment == ".") continue;
            if(segment == ".."){
                if(newSegments.len() == 0) return false;
                newSegments.pop();
            }else{
                newSegments.append(segment);
            }
        }

        local oldSegments = mSegments_;
        mSegments_ = newSegments;
        mSelectedPath_ = null;
        if(refresh()) return true;
        mSegments_ = oldSegments;
        refresh();
        return false;
    }

    function pathForSegments_(count){
        local path = mRootPath_;
        for(local i = 0; i < count; i++) path = join_(path, mSegments_[i]);
        return path;
    }

    function join_(path, name){
        if(path.len() == 0 || path.slice(path.len() - 1) == "/") return path + name;
        return path + "/" + name;
    }

    function normaliseRoot_(path){
        if(typeof path != "string" || path.len() == 0) throw "File browser requires a root path.";
        //Preserve scheme roots such as res:// while trimming ordinary trailing
        //separators so descendant containment checks remain unambiguous.
        while(path.len() > 1 && path.slice(path.len() - 1) == "/" &&
            path.find("://") != path.len() - 3){
            path = path.slice(0, path.len() - 1);
        }
        return path;
    }

    function rootEndsWithSeparator_(){
        return mRootPath_.slice(mRootPath_.len() - 1) == "/";
    }

    function splitPath_(path){
        local result = [];
        local start = 0;
        while(start <= path.len()){
            local separator = path.find("/", start);
            if(separator == null){
                result.append(path.slice(start));
                break;
            }
            result.append(path.slice(start, separator));
            start = separator + 1;
        }
        return result;
    }

    function findEntryByPath_(path){
        foreach(entry in mEntries_){
            if(entry.path == path) return entry;
        }
        return null;
    }

    //The broad resource families represented by the browser icon atlas. This
    //is deliberately presentation-neutral metadata: a later thumbnail service
    //can still use the same entry and replace its generic icon.
    function kindForEntry_(name, directory){
        if(directory) return "directory";
        local extension = extensionForName_(name);
        if(arrayContains_(["png", "jpg", "jpeg", "bmp", "tga", "dds",
            "gif", "webp", "svg"], extension)) return "texture";
        if(arrayContains_(["mesh", "mesh2", "obj", "fbx", "gltf", "glb",
            "dae", "blend", "voxmesh"], extension)) return "mesh";
        if(arrayContains_(["nut", "json", "cfg", "xml", "material",
            "compositor", "program", "hlms", "glsl", "metal", "hlsl",
            "avscene"], extension)) return "script";
        return "file";
    }

    function extensionForName_(name){
        local start = 0;
        local lastSeparator = null;
        while(start < name.len()){
            local separator = name.find(".", start);
            if(separator == null) break;
            lastSeparator = separator;
            start = separator + 1;
        }
        if(lastSeparator == null || lastSeparator == name.len() - 1) return "";
        return name.slice(lastSeparator + 1).tolower();
    }

    function arrayContains_(values, target){
        foreach(value in values){
            if(value == target) return true;
        }
        return false;
    }
};
