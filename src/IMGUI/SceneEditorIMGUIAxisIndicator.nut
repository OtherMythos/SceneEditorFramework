//A camera-oriented XYZ indicator drawn entirely with ImGui widgets.
//
//The six ends of the three axes are handles rather than decoration: clicking one
//is how a viewport is asked to look down that axis, the way Blender's navigation
//gizmo works. So the indicator says whether the cursor is over one - a click on a
//handle is not also a click in the scene behind it.
//
//The binding does not expose ImGui's draw list, so every part of this is
//rasterised from small widgets: each axis line from a row of them, and each
//handle from one round one. Which means the indicator is drawn in whatever order
//it submits them, and a three dimensional thing drawn in the wrong order looks
//wrong - a line in front of the ball it passes, a ball in front of the line which
//is really nearer the camera.
//
//It is therefore drawn in two passes over one depth: how far along the way the
//camera faces each piece is.
//
//  * The handles are hit-tested first, nearest the camera first, with invisible
//    buttons which draw nothing. ImGui gives an overlapping click to the first
//    item which claims the hover id, so submitting them in that order is what
//    makes the ball in front the one which takes the click.
//  * Everything is then painted furthest away first, so that a nearer piece
//    covers a further one. Nothing painted claims the hover id - a progress bar
//    and a piece of text are both drawn without an ImGui id, unlike the buttons
//    an earlier version of this used - so painting cannot take a click away from
//    the pass which is meant to have it, whatever order the two disagree on.
//
//@see drawPieces_, which is the painter's algorithm that ordering amounts to.
::SceneEditorFramework.IMGUI.AxisIndicator <- class{

    AXIS_LENGTH = 24.0;
    INSET = 14.0;
    LINE_THICKNESS = 2.0;
    LINE_STEP = 1.0;

    //Wide enough for the letter inside the positive end of each axis.
    HANDLE_DIAMETER = 16.0;
    //What the negative end of an axis is multiplied by, which is what tells the
    //two ends apart while they are on top of each other.
    NEGATIVE_DIM = 0.4;
    //How far towards white a handle goes while the cursor is over it. Enough to
    //be unmistakable on the bright positive ends, which are already at their full
    //colour and so have nowhere brighter of their own to go.
    HOVER_LIGHTEN = 0.45;

    /**
     * Draw the indicator over a viewport's scene image.
     *
     * @returns A table. "clicked" is [axis, sign] for the handle which was
     * clicked this frame - axis 0, 1 or 2 for x, y or z, and sign 1 or -1 - or
     * null when none was. "hovered" is whether the cursor is over a handle, and
     * so whether the click belongs to the indicator rather than to the scene.
     */
    function draw(camera, sceneX, sceneY, sceneWidth, sceneHeight){
        local result = { clicked = null, hovered = false };
        if(camera == null || sceneWidth <= 0 || sceneHeight <= 0) return result;

        local scale = _imgui.getGlobalScale();
        local diameter = HANDLE_DIAMETER * scale;
        //The handles stick out past the ends of the axes, so the inset has to
        //keep room for one on whichever side an axis happens to point.
        local inset = INSET * scale + diameter * 0.5;
        local length = AXIS_LENGTH * scale;
        local availableLength = (sceneWidth < sceneHeight ? sceneWidth : sceneHeight) * 0.30;
        if(length > availableLength) length = availableLength;
        if(length < 4.0) return result;

        //The origin sits in the top-right with enough room for an axis to
        //point in any screen direction without leaving the render image.
        local originX = sceneX + sceneWidth - inset - length;
        local originY = sceneY + inset + length;

        //Camera orientation turns camera-local basis vectors into world space.
        //Dotting a world axis with camera right and up projects it onto screen,
        //and dotting it with the way the camera faces - its own negative z - is
        //the depth everything here is sorted by. Positive is away from the
        //camera, so a larger depth is a piece to paint sooner and hit-test later.
        local orientation = camera.getOrientation();
        local cameraRight = orientation * Vec3(1, 0, 0);
        local cameraUp = orientation * Vec3(0, 1, 0);
        local cameraForward = orientation * Vec3(0, 0, -1);

        //One entry per axis: its letter, the components which project it onto
        //the screen and into depth, and its colour.
        local axes = [
            ["X", cameraRight.x, cameraUp.x, cameraForward.x, 0.95, 0.20, 0.20],
            ["Y", cameraRight.y, cameraUp.y, cameraForward.y, 0.20, 0.90, 0.30],
            ["Z", cameraRight.z, cameraUp.z, cameraForward.z, 0.25, 0.55, 1.00]
        ];

        local handles = buildHandles_(axes, originX, originY, length);
        hitTestHandles_(handles, diameter, result);
        drawPieces_(buildPieces_(axes, handles, originX, originY, length, diameter));

        return result;
    }

    //Where both ends of each axis are on screen, and how far away they are.
    function buildHandles_(axes, originX, originY, length){
        local handles = [];
        foreach(index, axis in axes){
            for(local sign = 1; sign >= -1; sign -= 2){
                handles.append({
                    axis = index,
                    sign = sign,
                    //ImGui screen y increases downwards, hence the minus on
                    //camera-space up.
                    x = originX + axis[1] * sign * length,
                    y = originY - axis[2] * sign * length,
                    depth = axis[3] * sign,
                    hovered = false
                });
            }
        }
        return handles;
    }

    //Claim the clicks before anything is painted, nearest the camera first, so
    //that the ball in front is the one an overlapping click belongs to.
    function hitTestHandles_(handles, diameter, result){
        local ordered = clone handles;
        ordered.sort(function(a, b){
            return a.depth <=> b.depth;
        });

        foreach(handle in ordered){
            _imgui.setCursorPos(handle.x - diameter * 0.5, handle.y - diameter * 0.5);
            local pressed = _imgui.invisibleButton(
                "##axisHandle" + handle.axis + "_" + handle.sign, diameter, diameter);

            //The entries are the same tables the painting pass reads, so this is
            //the hover the handle is painted with rather than the one it had a
            //frame ago.
            handle.hovered = _imgui.isItemHovered();
            if(handle.hovered) result.hovered = true;
            if(pressed) result.clicked = [handle.axis, handle.sign];
        }
    }

    //Everything the indicator is made of, as flat round pieces with a depth: the
    //dots each axis line is rasterised from, and the handles at their ends.
    function buildPieces_(axes, handles, originX, originY, length, diameter){
        local pieces = [];
        local scale = _imgui.getGlobalScale();
        local thickness = LINE_THICKNESS * scale;
        local radius = diameter * 0.5;

        //A line is drawn only towards the positive end of each axis, which is the
        //half the letters are on and so the half which says which way round the
        //axis is. It stops at the edge of its handle, both because a line drawn
        //across a ball looks like a mistake and because the two would otherwise
        //be at the same depth with nothing to say which goes on top.
        foreach(index, axis in axes){
            local screenX = axis[1] * length;
            local screenY = -axis[2] * length;
            //How long the axis is once projected, which is nothing at all for one
            //pointed at the camera - and which is entirely under its own handle
            //for one pointed nearly at it.
            local distance = sqrt(screenX * screenX + screenY * screenY);
            local drawn = distance - radius;
            if(drawn < 1.0) continue;

            local steps = ceil(drawn / (LINE_STEP * scale)).tointeger();
            for(local step = 0; step <= steps; step++){
                //How far along the axis itself this dot is, which is what its
                //depth is a fraction of. The line covers only the part of the
                //axis left over once the handle has been taken off the end.
                local along = (steps == 0 ? 0.0 : step.tofloat() / steps.tofloat()) *
                    drawn / distance;
                pieces.append({
                    depth = axis[3] * along,
                    x = originX + screenX * along,
                    y = originY + screenY * along,
                    size = thickness,
                    //Square, so that the dots meet each other and the line comes
                    //out as solid as the handles it joins. Rounded, they would be
                    //circles the width of the line with gaps and half-lit edges
                    //between them.
                    rounding = 0.0,
                    r = axis[4], g = axis[5], b = axis[6],
                    label = null
                });
            }
        }

        foreach(handle in handles){
            local axis = axes[handle.axis];
            //The positive end is filled and lettered, the negative one dimmed and
            //blank, which is what tells the two ends of an axis apart when they
            //are on top of each other.
            local dim = handle.sign > 0 ? 1.0 : NEGATIVE_DIM;
            //Under the cursor either end lightens towards white, so that what is
            //about to be clicked says so. The same answer for both ends, rather
            //than a negative one merely coming up to its full colour: that told
            //an already bright positive end nothing, since it is at its full
            //colour whether the cursor is over it or not.
            local lighten = handle.hovered ? HOVER_LIGHTEN : 0.0;
            pieces.append({
                depth = handle.depth,
                x = handle.x,
                y = handle.y,
                size = diameter,
                //Half of it, which is as round as a square can be drawn.
                rounding = diameter * 0.5,
                r = lightened_(axis[4] * dim, lighten),
                g = lightened_(axis[5] * dim, lighten),
                b = lightened_(axis[6] * dim, lighten),
                label = handle.sign > 0 ? axis[0] : null
            });
        }

        return pieces;
    }

    //One channel of a colour taken that far towards white.
    function lightened_(channel, amount){
        return channel + (1.0 - channel) * amount;
    }

    //Paint the pieces furthest away first, so that a nearer one covers it.
    //
    //A progress bar filled to the top is a rounded rectangle of a colour of our
    //choosing, and is one of the few things the binding offers which ImGui draws
    //without an id - so none of this can claim the hover the handles above need.
    function drawPieces_(pieces){
        pieces.sort(function(a, b){
            return b.depth <=> a.depth;
        });

        _imgui.pushStyleVar(_imgui.StyleVar_FrameBorderSize, 0.0);
        //Nothing behind the fill, which is drawn over the scene.
        _imgui.pushStyleColor(_imgui.Col_FrameBg, 0.0, 0.0, 0.0, 0.0);
        //Dark, because a letter sits on the bright fill of its handle.
        _imgui.pushStyleColor(_imgui.Col_Text, 0.08, 0.08, 0.08, 1.0);

        foreach(piece in pieces){
            _imgui.pushStyleColor(_imgui.Col_PlotHistogram, piece.r, piece.g, piece.b, 1.0);
            _imgui.pushStyleVar(_imgui.StyleVar_FrameRounding, piece.rounding);
            _imgui.setCursorPos(piece.x - piece.size * 0.5, piece.y - piece.size * 0.5);
            //An empty overlay rather than none at all, which would be the
            //percentage ImGui writes over a bar by default.
            _imgui.progressBar(1.0, piece.size, piece.size, "");
            _imgui.popStyleVar();
            _imgui.popStyleColor();

            if(piece.label == null) continue;
            //Straight after the piece it belongs to, so a handle painted later
            //covers the letter of the one behind it along with the ball itself.
            local textSize = _imgui.calcTextSize(piece.label);
            _imgui.setCursorPos(piece.x - textSize[0] * 0.5, piece.y - textSize[1] * 0.5);
            _imgui.text(piece.label);
        }

        _imgui.popStyleColor(2);
        _imgui.popStyleVar();
    }
};
