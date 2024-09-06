
::SceneEditorFramework.GUIObjectProperties <- class extends ::SceneEditorFramework.GUIPanel{

    mLayoutLine_ = null;
    mWidgets_ = null;
    mContainerWindow_ = null;
    mNoSelectedObjectLabel_ = null;

    constructor(parent, baseObj, bus){
        base.constructor(parent, baseObj, bus);
        mWidgets_ = {};

        bus.subscribeObject(this);
    }

    function setup(){
        mNoSelectedObjectLabel_ = mParent_.createLabel();
        mNoSelectedObjectLabel_.setText("No object selected");

        mContainerWindow_ = mParent_.createWindow();
        mContainerWindow_.setSkinPack("internal/WindowNoBorder");
        local layoutLine = _gui.createLayoutLine();

        //TODO consider separating the widgets specifically off into their own repo so the SceneEditor can depend on that.
        local positionVec = ::EditorGUIFramework.Widget.Vector3Input(mContainerWindow_, "position");
        positionVec.addToLayout(layoutLine);
        positionVec.attachListener(::EditorGUIFramework.Listener(function(widget, action){
            local val = widget.getValue();
            print(val);
        }));
        mWidgets_.rawset(SceneEditorFramework_GUIObjectPropertiesWidgets.POSITION, positionVec);

        local scaleVec = ::EditorGUIFramework.Widget.Vector3Input(mContainerWindow_, "scale");
        scaleVec.addToLayout(layoutLine);
        scaleVec.attachListener(::EditorGUIFramework.Listener(function(widget, action){
            local val = widget.getValue();
            print(val);
        }));
        mWidgets_.rawset(SceneEditorFramework_GUIObjectPropertiesWidgets.SCALE, scaleVec);

        local orientation = mContainerWindow_.createLabel();
        orientation.setText("orientation");
        layoutLine.addCell(orientation);
        mWidgets_.rawset(SceneEditorFramework_GUIObjectPropertiesWidgets.ORIENTATION, orientation);

        mLayoutLine_ = layoutLine;

        mContainerWindow_.setPosition(0, 0);
        mContainerWindow_.setSize(mParent_.getSizeAfterClipping());
        mContainerWindow_.setVisualsEnabled(false);

        setDataForEntry(null);

    }

    function notifyBusEvent(event, data){
        if(event == SceneEditorFramework_BusEvents.SCENE_TREE_SELECTION_CHANGED){
            setDataForEntry(data);
        }
        else if(event == SceneEditorFramework_BusEvents.SELECTED_DATA_CHANGE){
            setDataForEntry(data);
        }

    }

    function setDataForEntry(entry){
        mContainerWindow_.setVisible(entry != null);
        mNoSelectedObjectLabel_.setVisible(entry == null);
        if(entry == null){
            return;
        }

        mWidgets_.rawget(SceneEditorFramework_GUIObjectPropertiesWidgets.POSITION)
            .setValue(entry == null ? Vec3() : entry.position);
        mWidgets_.rawget(SceneEditorFramework_GUIObjectPropertiesWidgets.SCALE)
            .setValue(entry == null ? Vec3() : entry.scale);
        mWidgets_.rawget(SceneEditorFramework_GUIObjectPropertiesWidgets.ORIENTATION)
            .setText("orientation: " + (entry == null ? "" : entry.orientation.tostring()));

        mLayoutLine_.layout();
    }

};