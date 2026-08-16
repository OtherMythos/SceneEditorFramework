/**
 * What a copy left behind, kept for the pastes which follow it.
 *
 * A scene tree is a flat list of read-only entry descriptions - position, scale,
 * orientation, name and whatever data the entry type carries - wrapped in CHILD
 * and TERM markers which describe the hierarchy. Copying is therefore taking a
 * detached copy of those descriptions, with no entry ids and no scene nodes:
 * nothing in here points at the tree it came from, so the tree can be rearranged,
 * or closed entirely, without the clipboard meaning something different when it
 * is finally pasted.
 *
 * The entries held here are never handed to a tree. Paste instantiates its own
 * copies of them, which is what lets the same clipboard be pasted any number of
 * times.
 *
 * @see SceneEditorFramework.SceneTree.pasteFromClipboard
 */
::SceneEditorFramework.SceneTreeClipboard <- class{

    //The copied layout, in the same flattened form the tree itself uses.
    mEntries_ = null;
    //How many of those entries sit at the top of the layout rather than below
    //one of the others. This is the number of objects the user copied; the rest
    //came along as descendants.
    mTopLevelCount_ = 0;

    constructor(){
        clear();
    }

    function clear(){
        mEntries_ = [];
        mTopLevelCount_ = 0;
    }

    function hasEntries(){
        return mEntries_.len() > 0;
    }

    /** How many objects the user copied, not counting their descendants. */
    function getCopiedCount(){
        return mTopLevelCount_;
    }

    /**
     * The copied layout. Treat it as read-only: it is the record of what was
     * copied, and every paste works from instantiated copies of it.
     */
    function getEntries(){
        return mEntries_;
    }

    /**
     * Replace the clipboard contents with a tree's current selection.
     *
     * The reduced selection is what is taken, so selecting a parent as well as
     * one of its children copies that child once, as part of its parent, rather
     * than twice.
     *
     * @returns true when something was copied. A selection of nothing leaves the
     * previous contents alone, so a stray shortcut cannot empty the clipboard.
     */
    function copyFromTree(tree){
        if(tree == null) return false;

        local selected = tree.getReducedSelection();
        if(selected.len() == 0) return false;

        local copied = [];
        foreach(entryId in selected){
            local startIndex = tree.findEntryIdIndexInTree_(entryId);
            if(startIndex == null) continue;

            local endIndex = tree.getEntrySectionEndInEntries_(tree.mEntries_, startIndex);
            for(local index = startIndex; index < endIndex; index++){
                copied.append(::SceneEditorFramework.copySceneTreeEntry(tree.mEntries_[index]));
            }
        }
        if(copied.len() == 0) return false;

        mEntries_ = copied;
        mTopLevelCount_ = countTopLevelEntries_(copied);
        return true;
    }

    function countTopLevelEntries_(entries){
        local count = 0;
        local depth = 0;
        foreach(entry in entries){
            if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
                depth++;
            }else if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.TERM){
                depth--;
            }else if(depth == 0){
                count++;
            }
        }
        return count;
    }

};

/**
A detached copy of one scene tree entry, without the id or scene node which tie
the original to a tree.

Used both to fill a clipboard and to instantiate its contents again when they are
pasted, so that neither the tree which was copied from nor the clipboard itself
shares anything with the objects a paste creates.

The hierarchy markers are shared singletons which carry nothing of their own, so
they are passed through as they are.
*/
::SceneEditorFramework.copySceneTreeEntry <- function(entry){
    if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
        return ::SceneEditorFramework.FileParser.CHILD_ENTRY;
    }
    if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.TERM){
        return ::SceneEditorFramework.FileParser.TERM_ENTRY;
    }

    local result = ::SceneEditorFramework.SceneTreeEntry();
    result.entryId = null;
    result.node = null;
    result.nodeType = entry.nodeType;
    result.name = entry.name;
    result.animIdx = entry.animIdx;
    result.visible = entry.visible;

    //The transform is read from the entry rather than from its node: an entry
    //which has never been given a node still describes where the object goes,
    //which is what makes a clipboard copy independent of one.
    result.position = entry.position == null ? Vec3() : entry.position.copy();
    result.scale = entry.scale == null ? Vec3(1, 1, 1) : entry.scale.copy();
    result.orientation = entry.orientation == null ? Quat() : entry.orientation.copy();

    result.data = ::SceneEditorFramework.copySceneTreeEntryData(entry);

    return result;
}

/**
Copy the data an entry carries, so that the copy can be edited without changing
the entry it was taken from.

The framework's own entry data is a flat class instance, which a clone covers.
An editor whose USER entries carry something a clone would leave shared - a
nested table, or an object which owns something in the engine - implements
copySceneTreeEntryData to say what copying one of its entries means.
*/
::SceneEditorFramework.copySceneTreeEntryData <- function(entry){
    if("copySceneTreeEntryData" in ::SceneEditorFramework.HelperFunctions){
        return ::SceneEditorFramework.HelperFunctions.copySceneTreeEntryData(entry);
    }

    if(entry.data == null) return null;
    return clone entry.data;
}
