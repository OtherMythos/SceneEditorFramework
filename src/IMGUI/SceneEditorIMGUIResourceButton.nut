/** A typed resource field which supports browsing and drag/drop assignment. */
::SceneEditorFramework.IMGUI.ResourceButton <- class{

    static ICON_SIZE = 22.0;
    static HEIGHT = 30.0;

    static function draw(id, value, kind, picker, onChanged){
        local texture = ::SceneEditorFramework.IMGUI.Textures.get(
            ::SceneEditorFramework.IMGUI.Textures.FILE_BROWSER_ICONS);
        local scale = _imgui.getGlobalScale();
        local height = HEIGHT * scale;
        local iconSize = ICON_SIZE * scale;
        local available = _imgui.getContentRegionAvail()[0];
        local buttonWidth = available - iconSize - 8.0 * scale;
        if(buttonWidth < 32.0 * scale) buttonWidth = 32.0 * scale;
        local start = _imgui.getCursorScreenPos();

        local drag = ::SceneEditorFramework.IMGUI.ResourceDragDrop;
        local mouse = drag.getMousePosition();
        local hovered = mouse[0] >= start[0] && mouse[0] <= start[0] + available &&
            mouse[1] >= start[1] && mouse[1] <= start[1] + height;
        local dragging = drag.isDragging();
        local compatible = dragging && drag.getDraggedEntry().kind == kind;

        if(hovered && dragging){
            if(compatible){
                _imgui.pushStyleColor(_imgui.Col_Button, 0.20, 0.48, 0.25, 1.0);
            }else{
                _imgui.pushStyleColor(_imgui.Col_Button, 0.55, 0.16, 0.16, 1.0);
            }
        }

        local icon = iconUV_(kind);
        _imgui.image(texture, iconSize, iconSize,
            icon.uv0[0], icon.uv0[1], icon.uv1[0], icon.uv1[1]);
        _imgui.sameLine();
        local label = (value == null || value.len() == 0 ? "<empty>" : value) + "##" + id;
        local pressed = _imgui.button(label, buttonWidth, height);

        if(hovered && dragging){
            _imgui.popStyleColor();
            if(compatible){
                drag.offerTarget(kind, onChanged);
                _imgui.setTooltip("Release to assign " + drag.getDraggedEntry().name);
            }else{
                _imgui.setTooltip("Expected a " + kind + " resource");
            }
        }

        if(pressed && picker != null) picker.request(kind, onChanged);
        return pressed;
    }

    static function iconUV_(kind){
        if(kind == "directory") return { uv0 = [0.0, 0.0], uv1 = [0.225, 0.358] };
        if(kind == "texture") return { uv0 = [0.235, 0.358], uv1 = [0.5, 0.83] };
        if(kind == "mesh") return { uv0 = [0.46, 0.358], uv1 = [0.71, 0.83] };
        if(kind == "script") return { uv0 = [0.685, 0.358], uv1 = [0.94, 0.83] };
        return { uv0 = [0.0, 0.358], uv1 = [0.225, 0.83] };
    }
};
