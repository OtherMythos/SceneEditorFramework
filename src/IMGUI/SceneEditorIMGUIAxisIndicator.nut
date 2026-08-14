//A small camera-oriented XYZ indicator drawn entirely with ImGui widgets.
//
//The binding does not expose ImGui's draw list, so each axis is rasterised from
//small disabled ImGui buttons. They are borderless and closely spaced, producing
//a continuous line without claiming the viewport's mouse interaction.
::SceneEditorFramework.IMGUI.AxisIndicator <- class{

    AXIS_LENGTH = 24.0;
    INSET = 14.0;
    LABEL_GAP = 8.0;
    LINE_THICKNESS = 2.0;
    LINE_STEP = 1.0;

    function draw(camera, sceneX, sceneY, sceneWidth, sceneHeight){
        if(camera == null || sceneWidth <= 0 || sceneHeight <= 0) return;

        local scale = _imgui.getGlobalScale();
        local inset = INSET * scale;
        local length = AXIS_LENGTH * scale;
        local availableLength = (sceneWidth < sceneHeight ? sceneWidth : sceneHeight) * 0.30;
        if(length > availableLength) length = availableLength;
        if(length < 4.0) return;

        //The origin sits in the top-right with enough room for an axis to
        //point in any screen direction without leaving the render image.
        local originX = sceneX + sceneWidth - inset - length;
        local originY = sceneY + inset + length;

        //Camera orientation turns camera-local basis vectors into world space.
        //Dotting a world axis with camera right and up projects it onto screen.
        local orientation = camera.getOrientation();
        local cameraRight = orientation * Vec3(1, 0, 0);
        local cameraUp = orientation * Vec3(0, 1, 0);

        _imgui.pushStyleVar(_imgui.StyleVar_FramePadding, 0.0, 0.0);
        _imgui.pushStyleVar(_imgui.StyleVar_FrameBorderSize, 0.0);
        _imgui.pushStyleVar(_imgui.StyleVar_FrameRounding, 0.0);
        //Disabled pixels do not claim hover/clicks. Retaining full disabled alpha
        //keeps their axis colours bright while mouse input passes to the scene.
        _imgui.pushStyleVar(_imgui.StyleVar_DisabledAlpha, 1.0);
        _imgui.beginDisabled();

        drawWorldAxis_("x", originX, originY, length,
            cameraRight.x, cameraUp.x, 0.95, 0.20, 0.20);
        drawWorldAxis_("y", originX, originY, length,
            cameraRight.y, cameraUp.y, 0.20, 0.90, 0.30);
        drawWorldAxis_("z", originX, originY, length,
            cameraRight.z, cameraUp.z, 0.25, 0.55, 1.00);

        drawAxisLabel_("X", originX, originY, length,
            cameraRight.x, cameraUp.x, 0.95, 0.20, 0.20);
        drawAxisLabel_("Y", originX, originY, length,
            cameraRight.y, cameraUp.y, 0.20, 0.90, 0.30);
        drawAxisLabel_("Z", originX, originY, length,
            cameraRight.z, cameraUp.z, 0.25, 0.55, 1.00);

        _imgui.endDisabled();
        _imgui.popStyleVar(4);
    }

    function drawWorldAxis_(id, originX, originY, length, screenX, screenUp, r, g, b){
        //ImGui screen y increases downwards, hence the minus on camera-space up.
        drawLine_(id, originX, originY,
            originX + screenX * length, originY - screenUp * length, r, g, b);
    }

    function drawAxisLabel_(label, originX, originY, length, screenX, screenUp, r, g, b){
        local directionX = screenX;
        local directionY = -screenUp;
        local directionLength = sqrt(directionX * directionX + directionY * directionY);
        if(directionLength > 0.001){
            directionX /= directionLength;
            directionY /= directionLength;
        }

        local gap = LABEL_GAP * _imgui.getGlobalScale();
        local textSize = _imgui.calcTextSize(label);
        local endX = originX + screenX * length;
        local endY = originY - screenUp * length;
        _imgui.setCursorPos(endX + directionX * gap - textSize[0] * 0.5,
            endY + directionY * gap - textSize[1] * 0.5);
        _imgui.pushStyleColor(_imgui.Col_Text, r, g, b, 1.0);
        _imgui.text(label);
        _imgui.popStyleColor();
    }

    function drawLine_(id, startX, startY, endX, endY, r, g, b){
        local deltaX = endX - startX;
        local deltaY = endY - startY;
        local distance = sqrt(deltaX * deltaX + deltaY * deltaY);
        local scale = _imgui.getGlobalScale();
        local thickness = LINE_THICKNESS * scale;
        local spacing = LINE_STEP * scale;
        local steps = ceil(distance / spacing).tointeger();

        _imgui.pushStyleColor(_imgui.Col_Button, r, g, b, 1.0);
        _imgui.pushStyleColor(_imgui.Col_ButtonHovered, r, g, b, 1.0);
        _imgui.pushStyleColor(_imgui.Col_ButtonActive, r, g, b, 1.0);
        for(local step = 0; step <= steps; step++){
            local amount = steps == 0 ? 0.0 : step.tofloat() / steps.tofloat();
            _imgui.setCursorPos(startX + deltaX * amount - thickness * 0.5,
                startY + deltaY * amount - thickness * 0.5);
            _imgui.button("##axis" + id + step, thickness, thickness);
        }
        _imgui.popStyleColor(3);
    }
};
