//The selection outline is eight small corner brackets rather than a complete
//wire box. Keeping the brackets independently positioned means a long, thin
//object does not stretch their three arms into an uneven-looking cuboid.
::SceneEditorFramework.SceneEditorGizmoOutlineBox <- class extends ::SceneEditorFramework.SceneEditorGizmo{

    CORNER_LENGTH_FRACTION = 0.5;
    //Move the brackets just beyond the selected mesh so their lines do not
    //fight the depth buffer on a cube face or other exact AABB match.
    AABB_EXPANSION = 0.05;

    //The brackets' default tint. The encompassing outline uses one of its own so
    //the two boxes drawn for a selection cannot be mistaken for each other.
    DEFAULT_DATABLOCK = "SceneEditorFramework/selectionOutline";

    mBus_ = null;
    //Null retains the old, scene-wide outline for direct users of this class.
    //A layer makes this a per-viewport overlay, rendered with that viewport's
    //other gizmos.
    mLayer_ = null;
    mDatablock_ = null;
    mCornerNodes_ = null;
    mArmNodes_ = null;
    mCentre_ = null;
    mHalfSize_ = null;

    constructor(parent, bus, layer=null, datablock=null){
        base.constructor(parent);

        mBus_ = bus;
        mLayer_ = layer;
        mDatablock_ = datablock == null ? DEFAULT_DATABLOCK : datablock;
        mCentre_ = Vec3();
        mHalfSize_ = Vec3();
        setup_(mParentNode_);
    }

    function setup_(parent){
        //The signs name the corner's direction away from the AABB centre.
        //Every bracket's three line meshes point back from that corner.
        local corners = [
            [-1, -1, -1], [1, -1, -1],
            [-1, 1, -1], [1, 1, -1],
            [-1, -1, 1], [1, -1, 1],
            [-1, 1, 1], [1, 1, 1]
        ];

        mCornerNodes_ = array(corners.len());
        mArmNodes_ = array(corners.len());
        foreach(index, signs in corners){
            local cornerNode = parent.createChildSceneNode();
            local arms = array(3);
            for(local axis = 0; axis < 3; axis++){
                local armNode = cornerNode.createChildSceneNode();
                local item = _scene.createItem("line");
                if(mLayer_ == null){
                    item.setRenderQueueGroup(SceneEditorFramework_RenderQueue.SCENE);
                }else{
                    item.setRenderQueueGroup(SceneEditorFramework_RenderQueue.GIZMO);
                    item.setVisibilityFlags(1 << mLayer_);
                }
                item.setQueryFlags(0);
                item.setDatablock(mDatablock_);
                armNode.attachObject(item);
                armNode.setOrientation(armOrientation_(axis, signs[axis]));
                arms[axis] = armNode;
            }

            mCornerNodes_[index] = cornerNode;
            mArmNodes_[index] = arms;
        }

        setVisible(false);
    }

    //The AABB is already world space. Its centre puts the bracket collection in
    //place; the individual corner nodes then receive only their local offsets.
    function setBounds(centre, halfSize){
        mCentre_ = centre.copy();
        mHalfSize_ = halfSize.copy();
        updateBounds_();
    }

    //Kept for callers using the old wire-box interface. setBounds is preferred
    //when both values are available because it updates every bracket at once.
    function setPosition(centre){
        mCentre_ = centre.copy();
        updateBounds_();
    }

    function setScale(halfSize){
        mHalfSize_ = halfSize.copy();
        updateBounds_();
    }

    function updateBounds_(){
        mParentNode_.setPosition(mCentre_);

        local displayHalfSize = mHalfSize_ * (1.0 + AABB_EXPANSION);

        //All three arms share a length. This is the important distinction from
        //scaling a single line-box by x/y/z independently.
        local armLength = min_(mHalfSize_.x, min_(mHalfSize_.y, mHalfSize_.z)) *
            CORNER_LENGTH_FRACTION;

        foreach(index, cornerNode in mCornerNodes_){
            local signs = cornerSigns_(index);
            cornerNode.setPosition(
                signs[0] * displayHalfSize.x,
                signs[1] * displayHalfSize.y,
                signs[2] * displayHalfSize.z);

            for(local axis = 0; axis < 3; axis++){
                local direction = inwardDirection_(axis, signs[axis]);
                local arm = mArmNodes_[index][axis];
                arm.setPosition(direction * (armLength * 0.5));
                //The built-in line runs from -1 to +1 on its local Y axis.
                arm.setScale(1, armLength * 0.5, 1);
            }
        }
    }

    function shutdown(){
        mParentNode_.destroyNodeAndChildren();
    }

    function cornerSigns_(index){
        return [
            index % 2 == 0 ? -1 : 1,
            (index / 2) % 2 == 0 ? -1 : 1,
            (index / 4) % 2 == 0 ? -1 : 1
        ];
    }

    function inwardDirection_(axis, cornerSign){
        local value = -cornerSign;
        if(axis == 0) return Vec3(value, 0, 0);
        if(axis == 1) return Vec3(0, value, 0);
        return Vec3(0, 0, value);
    }

    //Rotate the source line's Y axis toward the arm's inward world axis.
    function armOrientation_(axis, cornerSign){
        if(axis == 0){
            return Quat(cornerSign > 0 ? PI / 2 : -PI / 2, Vec3(0, 0, 1));
        }
        if(axis == 1){
            return cornerSign > 0 ? Quat(PI, Vec3(0, 0, 1)) : Quat();
        }
        return Quat(cornerSign > 0 ? -PI / 2 : PI / 2, Vec3(1, 0, 0));
    }

    function min_(first, second){
        return first < second ? first : second;
    }
};
