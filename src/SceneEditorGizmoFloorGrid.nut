//A camera-adaptive XZ floor grid for one viewport.
//
//It uses the viewport's gizmo visibility layer, but has its own render queue so
//the compositor can draw it against the scene depth before clearing depth for
//the transform handles. Geometry is made of narrow quads instead of hardware
//lines: that gives every tenth line a reliably larger on-screen weight on all
//render backends.
::SceneEditorFramework.SceneEditorGizmoFloorGrid <- class extends ::SceneEditorFramework.SceneEditorGizmo{

    HALF_LINE_COUNT = 60;
    LINES_PER_AXIS = 121;
    QUAD_COUNT = 242;
    VERTEX_COUNT = 968;
    INDEX_COUNT = 1452;
    BYTES_PER_VERTEX = 28; //float3 position + float4 colour

    mCamera_ = null;
    mLayer_ = null;
    mMeshName_ = null;
    mVertexBuffer_ = null;
    mLastSpacing_ = null;
    mLastCentreX_ = null;
    mLastCentreZ_ = null;
    mLastWorldPerPixel_ = null;
    mLastWidth_ = 0;
    mLastHeight_ = 0;

    constructor(parent, camera, layer, meshName){
        base.constructor(parent);
        mCamera_ = camera;
        mLayer_ = layer;
        mMeshName_ = meshName;
        createGeometry_();
    }

    function shutdown(){
        //The item must release the mesh before its resource is removed.
        mParentNode_.destroyNodeAndChildren();
        _graphics.removeManualMesh(mMeshName_);
        mVertexBuffer_ = null;
        mCamera_ = null;
    }

    function createGeometry_(){
        local mesh = _graphics.createManualMesh(mMeshName_);
        local subMesh = mesh.createSubMesh();

        local elements = _graphics.createVertexElemVec();
        elements.pushVertexElement(_VET_FLOAT3, _VES_POSITION);
        elements.pushVertexElement(_VET_FLOAT4, _VES_DIFFUSE);

        mVertexBuffer_ = _graphics.createVertexBuffer(elements, VERTEX_COUNT,
            BYTES_PER_VERTEX, blob(VERTEX_COUNT * BYTES_PER_VERTEX), false);

        local indices = blob(INDEX_COUNT * 2);
        for(local quad = 0; quad < QUAD_COUNT; quad++){
            local first = quad * 4;
            indices.writen(first, 'w');
            indices.writen(first + 1, 'w');
            indices.writen(first + 2, 'w');
            indices.writen(first + 2, 'w');
            indices.writen(first + 3, 'w');
            indices.writen(first, 'w');
        }
        local indexBuffer = _graphics.createIndexBuffer(_IT_16BIT, indices,
            INDEX_COUNT);
        local vao = _graphics.createVertexArrayObject(mVertexBuffer_, indexBuffer,
            _OT_TRIANGLE_LIST);
        subMesh.pushMeshVAO(vao, _VP_NORMAL);

        //The grid follows the camera over an effectively unbounded plane. A
        //large conservative bound prevents the moving portion being culled by
        //the bounds from a previous update.
        local bounds = AABB(Vec3(), Vec3(1000000, 1, 1000000));
        mesh.setBounds(bounds);
        mesh.setBoundingSphereRadius(1414214.0);

        local item = _scene.createItem(mesh);
        item.setRenderQueueGroup(SceneEditorFramework_RenderQueue.FLOOR_GRID);
        item.setVisibilityFlags(1 << mLayer_);
        item.setQueryFlags(0);
        item.setDatablock(::SceneEditorFramework.ensureFloorGridDatablock());
        mParentNode_.attachObject(item);
    }

    function update(viewportWidth, viewportHeight){
        if(mCamera_ == null || viewportWidth <= 0 || viewportHeight <= 0) return;

        local footprint = cameraFootprint_();
        local spacing = spacingForSpan_(footprint[2]);
        local centreX = snapped_(footprint[0], spacing);
        local centreZ = snapped_(footprint[1], spacing);
        local smallestViewportSide = viewportWidth < viewportHeight ?
            viewportWidth : viewportHeight;
        local worldPerPixel = footprint[2] / smallestViewportSide.tofloat();

        //Moving within the same snapped cell changes no grid geometry. A resize
        //or camera rotation can change the required world-space line width even
        //when the cell and spacing remain the same.
        if(spacing == mLastSpacing_ && centreX == mLastCentreX_ &&
            centreZ == mLastCentreZ_ && viewportWidth == mLastWidth_ &&
            viewportHeight == mLastHeight_ &&
            worldPerPixel == mLastWorldPerPixel_) return;

        mLastSpacing_ = spacing;
        mLastCentreX_ = centreX;
        mLastCentreZ_ = centreZ;
        mLastWorldPerPixel_ = worldPerPixel;
        mLastWidth_ = viewportWidth;
        mLastHeight_ = viewportHeight;

        local minorWidth = worldPerPixel * 0.8;
        local minimumWidth = spacing * 0.012;
        if(minorWidth < minimumWidth) minorWidth = minimumWidth;
        local majorWidth = minorWidth * 3.0;
        local extent = spacing * HALF_LINE_COUNT;
        local majorSpacing = spacing * 10.0;

        local vertices = blob(VERTEX_COUNT * BYTES_PER_VERTEX);
        for(local i = -HALF_LINE_COUNT; i <= HALF_LINE_COUNT; i++){
            local x = centreX + i * spacing;
            local majorX = isMultiple_(x, majorSpacing);
            writeQuad_(vertices, x - (majorX ? majorWidth : minorWidth) * 0.5,
                centreZ - extent, x + (majorX ? majorWidth : minorWidth) * 0.5,
                centreZ + extent, majorX);
        }
        for(local i = -HALF_LINE_COUNT; i <= HALF_LINE_COUNT; i++){
            local z = centreZ + i * spacing;
            local majorZ = isMultiple_(z, majorSpacing);
            writeQuad_(vertices, centreX - extent,
                z - (majorZ ? majorWidth : minorWidth) * 0.5,
                centreX + extent, z + (majorZ ? majorWidth : minorWidth) * 0.5,
                majorZ);
        }
        mVertexBuffer_.upload(vertices);
    }

    //Centre and approximate visible span of the camera's intersection with Y=0.
    //
    //A raw ray/plane intersection is singular at the horizon: an imperceptible
    //turn can move it from a few hundred units away to infinity, or to no hit at
    //all. Clamp every sample to a camera-height-dependent horizon distance.
    //The resulting point moves continuously as a ray crosses the horizon,
    //which prevents a stationary-looking view from flickering between grid
    //decades.
    function cameraFootprint_(){
        local cameraPos = ::SceneEditorFramework.getCameraPosition(mCamera_);
        local centreX = cameraPos == null ? 0.0 : cameraPos.x;
        local centreZ = cameraPos == null ? 0.0 : cameraPos.z;
        local minX = centreX;
        local maxX = centreX;
        local minZ = centreZ;
        local maxZ = centreZ;
        local plane = Plane(Vec3(0, 1, 0), 0);
        local cameraHeight = cameraPos == null ? 5.0 : cameraPos.y;
        if(cameraHeight < 0) cameraHeight = -cameraHeight;
        if(cameraHeight < 5.0) cameraHeight = 5.0;
        local horizonDistance = cameraHeight * 40.0;

        for(local y = 0; y < 3; y++){
            for(local x = 0; x < 3; x++){
                //The lower part of the viewport is the stable part of a floor
                //view. Top-edge rays are commonly above the horizon and add no
                //visible floor, while including their projected far points
                //would make an ordinary perspective view unnecessarily coarse.
                local viewportY = 0.6 + y * 0.2;
                local ray = mCamera_.getCameraToViewportRay(x * 0.5, viewportY);
                local distance = ray.intersects(plane);
                if(distance == false || distance > horizonDistance){
                    distance = horizonDistance;
                }
                local point = ray.getPoint(distance);
                if(x == 0 && y == 0){
                    minX = maxX = point.x;
                    minZ = maxZ = point.z;
                }else{
                    if(point.x < minX) minX = point.x;
                    if(point.x > maxX) maxX = point.x;
                    if(point.z < minZ) minZ = point.z;
                    if(point.z > maxZ) maxZ = point.z;
                }
            }
        }

        local centreRay = mCamera_.getCameraToViewportRay(0.5, 0.5);
        local centreDistance = centreRay.intersects(plane);
        if(centreDistance == false || centreDistance > horizonDistance){
            //When the centre itself is at/above the horizon, centre the grid on
            //the stable lower-half footprint instead of jumping far away.
            centreX = (minX + maxX) * 0.5;
            centreZ = (minZ + maxZ) * 0.5;
        }else{
            local centre = centreRay.getPoint(centreDistance);
            centreX = centre.x;
            centreZ = centre.z;
        }

        local spanX = maxX - minX;
        local spanZ = maxZ - minZ;
        local span = spanX > spanZ ? spanX : spanZ;
        local cameraHeightSpan = cameraHeight * 2.0;
        if(cameraHeightSpan < 20.0) cameraHeightSpan = 20.0;
        if(span < cameraHeightSpan) span = cameraHeightSpan;
        return [centreX, centreZ, span];
    }

    //One-unit cells nearby; powers of ten replace them once they would become
    //too dense. Consequently every tenth visible line is always the next world
    //decade: 10 units, then 100, then 1000, and so on.
    function spacingForSpan_(span){
        //Use different thresholds for moving up and down a decade. Without
        //this dead band, a span hovering around exactly 100 cells can alternate
        //between (for example) one- and ten-unit spacing on successive frames.
        if(mLastSpacing_ != null){
            local spacing = mLastSpacing_;
            while(span / spacing > 110.0) spacing *= 10.0;
            while(spacing > 1.0 && span / (spacing / 10.0) < 75.0){
                spacing /= 10.0;
            }
            return spacing;
        }

        local spacing = 1.0;
        while(span / spacing > 100.0) spacing *= 10.0;
        return spacing;
    }

    function snapped_(value, spacing){
        return floor(value / spacing + 0.5) * spacing;
    }

    function isMultiple_(value, spacing){
        local quotient = value / spacing;
        local nearest = floor(quotient + 0.5);
        local difference = quotient - nearest;
        if(difference < 0) difference = -difference;
        return difference < 0.0001;
    }

    function writeQuad_(out, minX, minZ, maxX, maxZ, major){
        writeVertex_(out, minX, minZ, major);
        writeVertex_(out, maxX, minZ, major);
        writeVertex_(out, maxX, maxZ, major);
        writeVertex_(out, minX, maxZ, major);
    }

    function writeVertex_(out, x, z, major){
        out.writen(x, 'f'); out.writen(0.0, 'f'); out.writen(z, 'f');
        local colour = major ? 0.62 : 0.42;
        local alpha = major ? 0.58 : 0.30;
        out.writen(colour, 'f'); out.writen(colour, 'f');
        out.writen(colour, 'f'); out.writen(alpha, 'f');
    }
};
