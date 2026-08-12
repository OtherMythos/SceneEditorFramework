::SceneEditorFramework.IMGUI.Widgets <- {};

/**
 * ImGui's multi-component widgets take numeric arrays rather than engine
 * Vec3 or Quat instances. Convert at this boundary so the rest of the panels
 * continue to work with engine values.
 */
::SceneEditorFramework.IMGUI.Widgets.drawVector3 <- function(label, value, speed=0.1){
    local values = [value.x, value.y, value.z];
    local result = {
        value = Vec3(value.x, value.y, value.z),
        edited = _imgui.dragFloat3(label, values, speed),
        activated = _imgui.isItemActivated(),
        deactivatedAfterEdit = _imgui.isItemDeactivatedAfterEdit()
    };
    result.value = Vec3(values[0], values[1], values[2]);

    return result;
};

::SceneEditorFramework.IMGUI.Widgets.drawQuat <- function(label, value, speed=0.01){
    local values = [value.x, value.y, value.z, value.w];
    local result = {
        value = Quat(value.x, value.y, value.z, value.w),
        edited = _imgui.dragFloat4(label, values, speed),
        activated = _imgui.isItemActivated(),
        deactivatedAfterEdit = _imgui.isItemDeactivatedAfterEdit()
    };
    result.value = Quat(values[0], values[1], values[2], values[3]);

    return result;
};
