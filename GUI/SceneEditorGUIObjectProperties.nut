
::SceneEditorFramework.GUIObjectProperties <- class extends ::SceneEditorFramework.GUIPanel{

    mLayoutLine_ = null;
    mWidgets_ = null;

    constructor(parent, baseObj, bus){
        base.constructor(parent, baseObj, bus);
        mWidgets_ = {};

        bus.subscribeObject(this);
    }

    function setup(){
        local layoutLine = _gui.createLayoutLine();

        local label = mParent_.createLabel();
        label.setText("Object Properties");
        layoutLine.addCell(label);

        local position = mParent_.createLabel();
        position.setText("Position");
        layoutLine.addCell(position);
        mWidgets_.rawset(SceneEditorFramework_GUIObjectPropertiesWidgets.POSITION, position);

        local scale = mParent_.createLabel();
        scale.setText("scale");
        layoutLine.addCell(scale);
        mWidgets_.rawset(SceneEditorFramework_GUIObjectPropertiesWidgets.SCALE, scale);

        local orientation = mParent_.createLabel();
        orientation.setText("orientation");
        layoutLine.addCell(orientation);
        mWidgets_.rawset(SceneEditorFramework_GUIObjectPropertiesWidgets.ORIENTATION, orientation);

        mLayoutLine_ = layoutLine;

        setDataForEntry(null);
    }

    function notifyBusEvent(event, data){
        //local test = SceneEditorFramework_BusEvents.SCENE_TREE_SELECTION_CHANGED;
        if(event == 1){
            setDataForEntry(data);
        }

    }

    function setDataForEntry(entry){
        mWidgets_.rawget(SceneEditorFramework_GUIObjectPropertiesWidgets.POSITION)
            .setText("position: " + (entry == null ? "" : entry.position.tostring()));
        mWidgets_.rawget(SceneEditorFramework_GUIObjectPropertiesWidgets.SCALE)
            .setText("scale: " + (entry == null ? "" : entry.scale.tostring()));
        mWidgets_.rawget(SceneEditorFramework_GUIObjectPropertiesWidgets.ORIENTATION)
            .setText("orientation: " + (entry == null ? "" : entry.orientation.tostring()));

        mLayoutLine_.layout();
    }

};