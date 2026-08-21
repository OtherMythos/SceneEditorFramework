::SceneEditorFramework.SceneEditorGizmo <- class{

    mParentNode_ = null;

    constructor(parent){
        mParentNode_ = parent.createChildSceneNode();
    }

    function setVisible(visible){
        mParentNode_.setVisible(visible);
    }
    function setPosition(pos){
        mParentNode_.setPosition(pos);
    }

    /**
     * Bring the handles into line with the modifier keys which are held.
     *
     * Every copy of the gizmo is told, rather than only the one the cursor is
     * working in: a modifier which changes what handles there are changes them
     * in every viewport showing the object, the same as any other thing the
     * gizmo shows about it. Most gizmos have nothing to say about a modifier
     * until they are dragged, so this does nothing by default.
     * @see SceneEditorFramework.SceneEditorGizmoObjectHandles
     */
    function updateHandleModifiers(){

    }

};