/**
 * Shared textures used by the framework's ImGui panels. Textures are loaded
 * lazily so consumers can request them without depending on another panel
 * having been constructed first.
 */
::SceneEditorFramework.IMGUI.Textures <- class{

    static OBJECT_ICONS = "objectIcons.png";
    static VISIBLE_ICONS = "visibleIcon.png";

    static mTextures_ = {};

    static function get(textureName){
        if(mTextures_.rawin(textureName)) return mTextures_.rawget(textureName);

        local texture = _graphics.createOrRetrieveTexture(
            textureName,
            _GPU_PAGE_OUT_STRATEGY_DISCARD,
            _TEXTURE_FLAG_NONE,
            _TEXTURE_TYPE_2D,
            "SceneEditor/general"
        );
        texture.scheduleTransitionTo(_GPU_RESIDENCY_RESIDENT);
        texture.waitForData();
        mTextures_.rawset(textureName, texture);

        return texture;
    }
};
