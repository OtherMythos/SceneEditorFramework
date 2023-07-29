enum SceneEditorGUIObjectPropertiesWidgets{
    POSITION,
    SCALE,
    ORIENTATION
};

::SceneEditorFramework.GUIObjectProperties <- class extends ::SceneEditorFramework.GUIPanel{

    mLayoutLine_ = null;
    mWidgets_ = null;

    constructor(parent, baseObj, bus){
        base.constructor(parent, baseObj, bus);
        mWidgets_ = {};

        bus.subscribeObject(this);

        setup();
    }

    function setup(){
        local layoutLine = _gui.createLayoutLine();

        local label = mParent_.createLabel();
        label.setText("Object Properties");
        layoutLine.addCell(label);

        local position = mParent_.createLabel();
        position.setText("Position");
        layoutLine.addCell(position);
        mWidgets_.rawset(SceneEditorGUIObjectPropertiesWidgets.POSITION, position);

        local scale = mParent_.createLabel();
        scale.setText("scale");
        layoutLine.addCell(scale);
        mWidgets_.rawset(SceneEditorGUIObjectPropertiesWidgets.SCALE, scale);

        local orientation = mParent_.createLabel();
        orientation.setText("orientation");
        layoutLine.addCell(orientation);
        mWidgets_.rawset(SceneEditorGUIObjectPropertiesWidgets.ORIENTATION, orientation);

        mLayoutLine_ = layoutLine;

        setDataForEntry(null);
    }

    function notifyBusEvent(event, data){
        //local test = SceneEditorBusEvents.SCENE_TREE_SELECTION_CHANGED;
        if(event == 1){
            setDataForEntry(data);
        }

    }

    function setDataForEntry(entry){
        mWidgets_.rawget(SceneEditorGUIObjectPropertiesWidgets.POSITION)
            .setText("position: " + (entry == null ? "" : entry.position.tostring()));
        mWidgets_.rawget(SceneEditorGUIObjectPropertiesWidgets.SCALE)
            .setText("scale: " + (entry == null ? "" : entry.scale.tostring()));
        mWidgets_.rawget(SceneEditorGUIObjectPropertiesWidgets.ORIENTATION)
            .setText("orientation: " + (entry == null ? "" : entry.orientation.tostring()));

        mLayoutLine_.layout();
    }

};