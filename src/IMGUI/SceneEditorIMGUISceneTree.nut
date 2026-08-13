//A hierarchy built from ordinary ImGui controls rather than TreeNodeEx.  The
//flattened tree is still owned by SceneTree; this panel only keeps the visual
//expansion and rename state which does not belong in a saved scene.
::SceneEditorFramework.IMGUI.SceneTree <- class extends ::SceneEditorFramework.IMGUI.Panel{

    ICON_WIDTH = 14.0;
    ICON_HEIGHT = 12.0;
    ICON_CELL_WIDTH = 0.1;
    INDENT_WIDTH = 10.0;
    ICON_GAP = 6.0;
    SCROLLBAR_WIDTH = 14.0;
    DOUBLE_CLICK_TIME = 0.35;
    DRAG_THRESHOLD = 5.0;

    mSceneTree_ = null;
    mWindowTitle_ = "Scene Tree##SceneEditorFrameworkSceneTree";
    mItemClicked_ = false;

    //entry id -> expanded. Entries default to expanded, making the hierarchy
    //immediately useful after a scene loads.
    mExpandedEntries_ = null;
    mRenamingEntryId_ = null;
    mRenameText_ = "";
    mRenameFocusPending_ = false;
    mLastClickedEntryId_ = null;
    mLastClickTime_ = -100.0;

    //The plugin binding does not expose ImGui payloads, so a tree drag is
    //tracked from the selectable which captured the left mouse button.
    mPotentialDragEntryId_ = null;
    mDragStartMouse_ = null;
    mDragging_ = false;
    mDropTargetEntryId_ = null;
    mDropInsertionType_ = SceneEditorFramework_ObjectInsertionType.NONE;
    mDropTargetValid_ = false;

    //Shared hierarchy sprite sheets.
    mObjectIcons_ = null;
    mVisibilityIcons_ = null;

    constructor(baseObj, bus){
        base.constructor(baseObj, bus);
        mSceneTree_ = baseObj.getActiveSceneTree();
        mExpandedEntries_ = {};

        mObjectIcons_ = ::SceneEditorFramework.IMGUI.Textures.get(
            ::SceneEditorFramework.IMGUI.Textures.OBJECT_ICONS
        );
        mVisibilityIcons_ = ::SceneEditorFramework.IMGUI.Textures.get(
            ::SceneEditorFramework.IMGUI.Textures.VISIBLE_ICONS
        );
    }

    function draw(){
        if(!mVisible_) return;

        local shown = _imgui.begin(mWindowTitle_);
        if(shown){
            mItemClicked_ = false;
            resetDropTarget_();
            if(!mSceneTree_.sceneTreePopulated()){
                _imgui.textDisabled("Scene tree empty");
            }else{
                drawEntries_();
            }

            //Clicking unused space has the same clear-selection behaviour as
            //the old tree, while a child window remains responsible for scroll.
            if(_imgui.isWindowHovered(_imgui.HoveredFlags_ChildWindows) &&
                _input.getMousePressed(_MB_LEFT) && !mItemClicked_){
                mSceneTree_.notifySelectionChanged(null);
                cancelRename_();
            }

            updateDrag_();
        }
        _imgui.end();
    }

    function drawEntries_(){
        //The child padding is removed so the row highlight and root
        //arrow begin at the hierarchy's left edge.
        _imgui.pushStyleVar(_imgui.StyleVar_WindowPadding, 0.0, 0.0);
        if(!_imgui.beginChild("##sceneEditorHierarchyEntries", 0.0, 0.0,
            _imgui.ChildFlags_Borders, _imgui.WindowFlags_NoBackground)){
            _imgui.endChild();
            _imgui.popStyleVar();
            return;
        }

        drawEntryGroup_(0, 0);
        _imgui.endChild();
        _imgui.popStyleVar();
    }

    //Entries are stored as objects interleaved with CHILD and TERM markers.
    //Return the index immediately after this sibling group.
    function drawEntryGroup_(startIndex, depth){
        local entries = mSceneTree_.mEntries_;
        local index = startIndex;
        while(index < entries.len()){
            local entry = entries[index];
            if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.TERM){
                return index + 1;
            }
            if(entry.nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
                index++;
                continue;
            }

            local hasChildren = index + 1 < entries.len() &&
                entries[index + 1].nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD;
            drawEntry_(entry, depth, hasChildren);

            if(hasChildren){
                if(isExpanded_(entry.entryId)){
                    index = drawEntryGroup_(index + 2, depth + 1);
                }else{
                    index = skipEntries_(index + 1);
                }
            }else{
                index++;
            }
        }

        return index;
    }

    function drawEntry_(entry, depth, hasChildren){
        local startX = _imgui.getCursorPosX();
        local startY = _imgui.getCursorPosY();
        local screenPos = _imgui.getCursorScreenPos();
        local rowWidth = _imgui.getContentRegionAvail()[0];
        local frameHeight = _imgui.getFrameHeight();
        local dropTarget = updateDropTargetForRow_(entry, screenPos, rowWidth, frameHeight);
        //Retain the framework's HiDPI icon scaling. The surrounding hierarchy
        //coordinates follow the original icon design, which were fixed-size.
        local guiScale = _imgui.getGlobalScale();
        local iconWidth = ICON_WIDTH * guiScale;
        local iconHeight = ICON_HEIGHT * guiScale;
        local indent = depth * INDENT_WIDTH;
        local arrowX = startX + indent;
        local iconX = arrowX + frameHeight + ICON_GAP;
        local nameX = iconX + iconWidth + ICON_GAP;
        //Two scrollbar widths are left between the sprite's left edge
        //and the content edge. ScrollbarSize defaults to 14 and is style-scaled.
        local scrollbarSize = (SCROLLBAR_WIDTH * guiScale).tointeger();
        local visibilityX = startX + rowWidth - iconWidth - scrollbarSize * 2.0;
        local nameWidth = visibilityX - nameX;
        if(nameWidth < 8.0) nameWidth = 8.0;

        _imgui.pushId(entry.entryId);

        //The arrow is separate from the row selection, so opening a branch
        //doesn't accidentally select its parent.
        _imgui.setCursorPos(arrowX, startY);
        if(hasChildren){
            local direction = isExpanded_(entry.entryId) ? _imgui.Dir_Down : _imgui.Dir_Right;
            if(_imgui.arrowButton("##expand", direction)){
                mExpandedEntries_.rawset(entry.entryId, !isExpanded_(entry.entryId));
                mItemClicked_ = true;
                cancelRename_();
            }
        }else{
            _imgui.dummy(frameHeight, frameHeight);
        }

        //Object sprite sheet: empty, mesh, then the extension slots.
        _imgui.setCursorPos(iconX, startY + (frameHeight - iconHeight) * 0.5);
        drawObjectIcon_(entry.nodeType, iconWidth, iconHeight);

        //ImageButton is an actual ImGui button: it supplies the framed hover
        //and active states while the eye sprite supplies its image.
        _imgui.setCursorPos(visibilityX, startY);
        local visibilityUv0 = entry.visible ? 0.0 : ICON_CELL_WIDTH;
        if(_imgui.imageButton("##visibility", mVisibilityIcons_, iconWidth, iconHeight,
            visibilityUv0, 0.0, visibilityUv0 + ICON_CELL_WIDTH, 1.0)){
            mSceneTree_.setEntryVisibility(entry.entryId, !entry.visible);
            mItemClicked_ = true;
        }

        _imgui.setCursorPos(nameX, startY);
        if(mRenamingEntryId_ == entry.entryId){
            drawRenameInput_(entry, nameWidth);
        }else{
            local selected = mSceneTree_.isEntrySelected(entry.entryId);
            local label = ::SceneEditorFramework.getNameForSceneEntry(entry) + "##name";

            if(dropTarget){
                local colour = mDropTargetValid_ ? [0.85, 0.55, 0.10, 0.85] :
                    [0.80, 0.20, 0.20, 0.85];
                _imgui.pushStyleColor(_imgui.Col_Header, colour[0], colour[1], colour[2], colour[3]);
                _imgui.pushStyleColor(_imgui.Col_HeaderHovered, colour[0], colour[1], colour[2], colour[3]);
                _imgui.pushStyleColor(_imgui.Col_HeaderActive, colour[0], colour[1], colour[2], colour[3]);
            }
            _imgui.selectable(label, selected, 0, nameWidth, frameHeight);
            if(dropTarget) _imgui.popStyleColor(3);
            if(dropTarget){
                local targetName = ::SceneEditorFramework.getNameForSceneEntry(entry);
                if(mDropTargetValid_){
                    _imgui.setTooltip("Move " + insertionTypeName_(mDropInsertionType_) +
                        " " + targetName);
                }else{
                    _imgui.setTooltip("Cannot move selection here");
                }
            }

            if(_imgui.isItemClicked()){
                handleEntryClick_(entry);
            }
            if(_imgui.isItemClicked(_imgui.MouseButton_Right)){
                mItemClicked_ = true;
                mSceneTree_.notifySelectionChanged(entry.entryId);
                cancelRename_();
                mBus_.transmitEvent(SceneEditorFramework_BusEvents.SCENE_TREE_OPTIONS_MENU_REQUEST, entry.entryId);
            }
        }

        //Every row has exactly one frame-height advance, even though the
        //controls above were deliberately positioned over that row.
        _imgui.setCursorPos(startX, startY + frameHeight);
        _imgui.popId();
    }

    function handleEntryClick_(entry){
        mItemClicked_ = true;
        local now = _imgui.getTime();
        local doubleClick = mLastClickedEntryId_ == entry.entryId &&
            now - mLastClickTime_ <= DOUBLE_CLICK_TIME;

        local modifiers = getSelectionModifiers_();
        mSceneTree_.notifySelectionChanged(entry.entryId, modifiers.control, modifiers.shift);
        mPotentialDragEntryId_ = entry.entryId;
        mDragStartMouse_ = getMousePosition_();
        if(doubleClick){
            mRenamingEntryId_ = entry.entryId;
            mRenameText_ = ::SceneEditorFramework.getNameForSceneEntry(entry);
            mRenameFocusPending_ = true;
            mLastClickedEntryId_ = null;
        }else{
            cancelRename_();
            mLastClickedEntryId_ = entry.entryId;
            mLastClickTime_ = now;
        }
    }

    function drawRenameInput_(entry, width){
        if(mRenameFocusPending_){
            mRenameFocusPending_ = false;
            _imgui.setKeyboardFocusHere();
        }
        _imgui.setNextItemWidth(width);
        mRenameText_ = _imgui.inputText("##rename", mRenameText_, _imgui.InputTextFlags_EnterReturnsTrue);
        //The input sits inside the scroll child, so tell the parent window
        //that a press here was not a click on unused hierarchy space.
        if(_imgui.isItemClicked() || _imgui.isItemActive()) mItemClicked_ = true;

        //Enter releases InputText with this flag, and clicking elsewhere also
        //commits a changed edit. Empty names keep the framework's type-derived
        //fallback out of accidental reach.
        if(_imgui.isItemDeactivatedAfterEdit()){
            if(mRenameText_.len() > 0 && mRenameText_ != ::SceneEditorFramework.getNameForSceneEntry(entry)){
                mSceneTree_.renameEntry(entry.entryId, mRenameText_);
            }
            cancelRename_();
        }
    }

    function drawObjectIcon_(type, iconWidth, iconHeight){
        //TODO separate these into custom icons for user values.
        local cell = 0;
        if(type == SceneEditorFramework_SceneTreeEntryType.MESH){
            cell = 1;
        }else if(type == SceneEditorFramework_SceneTreeEntryType.USER0){
            cell = 2;
        }else if(type == SceneEditorFramework_SceneTreeEntryType.USER1){
            cell = 3;
        }else if(
            type == SceneEditorFramework_SceneTreeEntryType.USER2 ||
            type == SceneEditorFramework_SceneTreeEntryType.USER3
        ){
            cell = 4;
        }
        local uv0 = cell * ICON_CELL_WIDTH;
        _imgui.image(mObjectIcons_, iconWidth, iconHeight, uv0, 0.0, uv0 + ICON_CELL_WIDTH, 1.0);
    }

    function isExpanded_(entryId){
        return !mExpandedEntries_.rawin(entryId) || mExpandedEntries_.rawget(entryId);
    }

    function cancelRename_(){
        mRenamingEntryId_ = null;
        mRenameFocusPending_ = false;
    }

    function updateDrag_(){
        if(mPotentialDragEntryId_ == null) return;

        local mouseDown = _input.getMouseButton(_MB_LEFT);
        if(!mDragging_ && mouseDown){
            local mouse = getMousePosition_();
            local dx = mouse[0] - mDragStartMouse_[0];
            local dy = mouse[1] - mDragStartMouse_[1];
            if(dx * dx + dy * dy >= DRAG_THRESHOLD * DRAG_THRESHOLD){
                mDragging_ = true;
                cancelRename_();
            }
        }

        if(mouseDown) return;

        if(mDragging_ && mDropTargetValid_){
            local insertionType = mDropInsertionType_;
            local destinationId = mDropTargetEntryId_;
            if(mSceneTree_.rearrangeCurrentSelection(destinationId, insertionType) &&
                insertionType == SceneEditorFramework_ObjectInsertionType.INTO){
                mExpandedEntries_.rawset(destinationId, true);
            }
        }

        cancelDrag_();
    }

    function updateDropTargetForRow_(entry, screenPos, rowWidth, rowHeight){
        if(!mDragging_) return false;

        local mouse = getMousePosition_();
        local mouseX = mouse[0];
        local mouseY = mouse[1];
        if(mouseX < screenPos[0] || mouseX > screenPos[0] + rowWidth ||
            mouseY < screenPos[1] || mouseY > screenPos[1] + rowHeight){
            return false;
        }

        local relativeY = (mouseY - screenPos[1]) / rowHeight;
        local insertionType = SceneEditorFramework_ObjectInsertionType.INTO;
        if(relativeY < 0.4){
            insertionType = SceneEditorFramework_ObjectInsertionType.ABOVE;
        }else if(relativeY > 0.8){
            insertionType = SceneEditorFramework_ObjectInsertionType.BELOW;
        }

        mDropTargetEntryId_ = entry.entryId;
        mDropInsertionType_ = insertionType;
        mDropTargetValid_ = mSceneTree_.canRearrangeCurrentSelection(
            entry.entryId, insertionType);
        return true;
    }

    function resetDropTarget_(){
        mDropTargetEntryId_ = null;
        mDropInsertionType_ = SceneEditorFramework_ObjectInsertionType.NONE;
        mDropTargetValid_ = false;
    }

    function insertionTypeName_(insertionType){
        if(insertionType == SceneEditorFramework_ObjectInsertionType.ABOVE) return "above";
        if(insertionType == SceneEditorFramework_ObjectInsertionType.BELOW) return "below";
        return "into";
    }

    function cancelDrag_(){
        mPotentialDragEntryId_ = null;
        mDragStartMouse_ = null;
        mDragging_ = false;
        resetDropTarget_();
    }

    //The engine reports mouse coordinates in window units while ImGui uses the
    //render target's pixel coordinates. They differ on HiDPI displays.
    function getMousePosition_(){
        local windowSize = _window.getSize();
        local pixelSize = _window.getActualSize();
        if(windowSize.x <= 0 || windowSize.y <= 0) return [0.0, 0.0];
        return [
            _input.getMouseX() * (pixelSize.x / windowSize.x),
            _input.getMouseY() * (pixelSize.y / windowSize.y)
        ];
    }

    function getSelectionModifiers_(){
        return {
            "control": isAnyKeyHeld_([
                SceneEditorFramework_KeyScancode.LCTRL,
                SceneEditorFramework_KeyScancode.RCTRL,
                SceneEditorFramework_KeyScancode.LGUI,
                SceneEditorFramework_KeyScancode.RGUI
            ]),
            "shift": isAnyKeyHeld_([
                SceneEditorFramework_KeyScancode.LSHIFT,
                SceneEditorFramework_KeyScancode.RSHIFT
            ])
        };
    }

    function isAnyKeyHeld_(scancodes){
        foreach(scancode in scancodes){
            if(_input.getRawKeyScancodeInput(scancode)) return true;
        }
        return false;
    }

    //Skip a CHILD/TERM group without drawing it when its parent is collapsed.
    function skipEntries_(childIndex){
        local entries = mSceneTree_.mEntries_;
        local depth = 0;
        for(local index = childIndex; index < entries.len(); index++){
            if(entries[index].nodeType == SceneEditorFramework_SceneTreeEntryType.CHILD){
                depth++;
            }else if(entries[index].nodeType == SceneEditorFramework_SceneTreeEntryType.TERM){
                depth--;
                if(depth == 0) return index + 1;
            }
        }

        return entries.len();
    }
};
