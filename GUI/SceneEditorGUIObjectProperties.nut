
::SceneEditorFramework.GUIObjectProperties <- class extends ::SceneEditorFramework.GUIPanel{

    mLayoutLine_ = null;
    mWidgets_ = null;
    mContainerWindow_ = null;
    mNoSelectedObjectLabel_ = null;

    PropertyEntry = class{
        mHorizLayout_ = null;
        mWidget_ = null;
        mResetButton_ = null;
        constructor(parent, window, widget, layout){
            mWidget_ = widget;

            local horizontalLine = _gui.createLayoutLine(_LAYOUT_HORIZONTAL);
            widget.addToLayout(horizontalLine);
            mHorizLayout_ = horizontalLine;

            widget.attachListener(::EditorGUIFramework.Listener(valueInputListener, parent));

            local button = window.createButton();
            button.setText("reset");
            button.setUserId(widget.getUserId());
            button.attachListenerForEvent(resetButtonListener, _GUI_ACTION_PRESSED, parent);
            horizontalLine.addCell(button);
            mResetButton_ = button;

            layout.addCell(horizontalLine);
        }

        function setValue(value){
            mWidget_.setValue(value);

            local coordType = mWidget_.getUserId();
            local same = false;
            if(coordType == SceneEditorFramework_BasicCoordinateType.POSITION){
                same = (mWidget_.getValue() <=> Vec3(0, 0, 0)) > 0;
            }
            else if(coordType == SceneEditorFramework_BasicCoordinateType.SCALE){
                same = (mWidget_.getValue() <=> Vec3(1, 1, 1)) > 0;
            }
            else if(coordType == SceneEditorFramework_BasicCoordinateType.ORIENTATION){
                same = (mWidget_.getValue() <=> Quat()) > 0;
            }

            mResetButton_.setVisible(same);
        }

        function resetButtonListener(widget, action){
            local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.BASIC_COORDINATES_CHANGE];
            local sceneTree = mBaseObj_.getActiveSceneTree();
            local coordType = widget.getUserId();

            local val = null;
            if(coordType == SceneEditorFramework_BasicCoordinateType.POSITION){
                val = Vec3(0, 0, 0);
            }
            else if(coordType == SceneEditorFramework_BasicCoordinateType.SCALE){
                val = Vec3(1, 1, 1);
            }
            else if(coordType == SceneEditorFramework_BasicCoordinateType.ORIENTATION){
                val = Quat();
            }

            local action = A(sceneTree, mBus_, sceneTree.mCurrentSelection, sceneTree.getValueForObjectCoordsChange_(coordType), val, coordType, false);
            mBaseObj_.pushAction(action);
            action.performAction();
        }

        function valueInputListener(widget, action){
            local val = widget.getValue();
            local A = ::SceneEditorFramework.Actions[SceneEditorFramework_Action.BASIC_COORDINATES_CHANGE];
            local sceneTree = mBaseObj_.getActiveSceneTree();
            local coordType = widget.getUserId();
            local action = A(sceneTree, mBus_, sceneTree.mCurrentSelection, sceneTree.getValueForObjectCoordsChange_(coordType), val, coordType, false);
            mBaseObj_.pushAction(action);
            action.performAction();
        }
    }

    constructor(parent, baseObj, bus){
        base.constructor(parent, baseObj, bus);
        mWidgets_ = {};

        bus.subscribeObject(this);
    }

    function shutdown(){
        mBus_.unsubscribeObject(this);
    }

    function setup(){
        mNoSelectedObjectLabel_ = mParent_.createLabel();
        mNoSelectedObjectLabel_.setText("No object selected");

        mContainerWindow_ = mParent_.createWindow();
        mContainerWindow_.setSkinPack("internal/WindowNoBorder");
        local layoutLine = _gui.createLayoutLine();

        local positionVec = ::EditorGUIFramework.Widget.Vector3Input(mContainerWindow_, "position");
        positionVec.setUserId(SceneEditorFramework_BasicCoordinateType.POSITION);
        local position = PropertyEntry(this, mContainerWindow_, positionVec, layoutLine);
        mWidgets_.rawset(SceneEditorFramework_GUIObjectPropertiesWidgets.POSITION, position);

        local scaleVec = ::EditorGUIFramework.Widget.Vector3Input(mContainerWindow_, "scale");
        scaleVec.setUserId(SceneEditorFramework_BasicCoordinateType.SCALE);
        local scale = PropertyEntry(this, mContainerWindow_, scaleVec, layoutLine);
        mWidgets_.rawset(SceneEditorFramework_GUIObjectPropertiesWidgets.SCALE, scale);

        local orientationVec = ::EditorGUIFramework.Widget.QuatInput(mContainerWindow_, "orientation");
        orientationVec.setUserId(SceneEditorFramework_BasicCoordinateType.ORIENTATION);
        local orientation = PropertyEntry(this, mContainerWindow_, orientationVec, layoutLine);
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
        print(mWidgets_.rawget(SceneEditorFramework_GUIObjectPropertiesWidgets.ORIENTATION));
        mWidgets_.rawget(SceneEditorFramework_GUIObjectPropertiesWidgets.ORIENTATION)
            .setValue(entry == null ? Quat() : entry.orientation);

        mLayoutLine_.layout();
    }

};