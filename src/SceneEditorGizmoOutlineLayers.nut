//The selection brackets are an editor overlay just like the transform gizmo:
//every viewport needs its own copy so it can be visible in one view and absent
//from another. Each copy shares the selected object's bounds, but is masked to
//the viewport layer which owns it.
::SceneEditorFramework.SceneEditorGizmoOutlineLayers <- class{

    mParentNode_ = null;
    mBus_ = null;
    mLayers_ = null;
    mVisible_ = false;
    mCentre_ = null;
    mHalfSize_ = null;

    constructor(parentNode, bus){
        mParentNode_ = parentNode;
        mBus_ = bus;
        mLayers_ = array(::SceneEditorFramework.MAX_GIZMO_LAYERS, null);
    }

    //Keep the copies in step with the gizmo layers. A viewport which has turned
    //off gizmos supplies no camera, so it owns no selection-outline copy either.
    function update(){
        syncLayers_(::SceneEditorFramework.getGizmoLayerCameras());
    }

    function setVisible(visible){
        mVisible_ = visible;
        foreach(i in mLayers_){
            if(i != null) i.setVisible(visible);
        }
    }

    function setBounds(centre, halfSize){
        mCentre_ = centre.copy();
        mHalfSize_ = halfSize.copy();
        foreach(i in mLayers_){
            if(i != null) i.setBounds(mCentre_, mHalfSize_);
        }
    }

    function syncLayers_(cameras){
        for(local layer = 0; layer < mLayers_.len(); layer++){
            local camera = layer < cameras.len() ? cameras[layer] : null;
            if(camera != null && mLayers_[layer] == null){
                local outline = ::SceneEditorFramework.SceneEditorGizmoOutlineBox(
                    mParentNode_, mBus_, layer);
                outline.setVisible(mVisible_);
                if(mCentre_ != null) outline.setBounds(mCentre_, mHalfSize_);
                mLayers_[layer] = outline;
            }else if(camera == null && mLayers_[layer] != null){
                mLayers_[layer].shutdown();
                mLayers_[layer] = null;
            }
        }
    }
};
