//A diagnostic view which paints every object in one viewport a flat, unlit colour
//of its own.
//
//A scene assembled from one kit of parts is largely one colour, and which of two
//touching walls the gizmo is about to move is then a matter of guesswork. With
//this on, each renderable is drawn in a colour of its own, so the parts separate
//visually even where the materials do not.
//
//One of these belongs to each viewport, holding the compositor identifier of the
//scene pass that viewport renders through, so the setting is per viewport rather
//than editor-wide: a scene can be read in flat colours in one pane while the pane
//beside it shows it lit. @see IMGUI.SceneRenderWindow
//
//The colouring itself is done by an Hlms piece the framework ships in
//res/hlms/pbs (objectColour_piece_vs.any / _ps.any), which is why a project has
//to add that directory to the pbs HLMS library in its avSetup.cfg. Without it
//everything here still works - the property is set, the toggle flips - and nothing
//in the viewport changes, since nothing is reading it. @see README.md
//
//The property is a shader-variant flag rather than a value in a buffer, which is
//what makes it possible to aim at one pass: only pass properties are per pass.
//The cost is that the passes affected build their shader permutation the first
//time the view is switched on, which is a one-off hitch on that frame and free
//from then on, as the built shaders stay cached.
::SceneEditorFramework.ObjectColourView <- class{

    //Read by both pieces. Anything the shader does not set behaves as absent, so
    //the view is switched off by clearing the property rather than by zeroing it.
    PROPERTY_NAME = "avSEObjectColour";

    //Null when the engine has no Hlms to register a pass property with, which
    //leaves the view inert rather than stopping the editor from opening.
    mPass_ = null;
    mEnabled_ = false;

    /**
     * @param passIdentifier The compositor identifier of the scene pass this view
     * applies to, as declared in res/SceneEditor.compositor.
     */
    constructor(passIdentifier){
        try{
            mPass_ = _hlms.pbs.getPass(passIdentifier);
        }catch(error){
            printf("Object colour view is unavailable: %s", error);
            mPass_ = null;
        }

        write_();
    }

    /** Whether the pass handle was obtained, and so whether the view can do anything. */
    function isAvailable(){
        return mPass_ != null;
    }

    function isEnabled(){
        return mEnabled_;
    }

    function setEnabled(enabled){
        if(mEnabled_ == enabled) return;
        mEnabled_ = enabled;
        write_();
    }

    function toggleEnabled(){
        setEnabled(!mEnabled_);
    }

    //Written when the flag changes rather than every frame: a pass property is
    //part of the shader cache key, so setting one is a statement about which
    //shader the pass wants and not a per-frame value.
    function write_(){
        if(mPass_ == null) return;

        if(mEnabled_) mPass_.setProperty(PROPERTY_NAME, 1);
        else mPass_.clearProperty(PROPERTY_NAME);
    }
};
