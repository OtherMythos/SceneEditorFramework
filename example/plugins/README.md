# AvImguiPlugin

The example bundles the [avImguiPlugin](https://github.com/OtherMythos/avEngineIMGUI)
distribution here:

```
example/plugins/avImguiPlugin/avPlugin.cfg
```

`example/avSetup.cfg` loads it before the scene editor framework. The plugin
selects the correct binary from its `bin/` directory for the running platform and
build type.

The example's viewports use `beginClosable`, which is what puts the close button
in a window's title bar and on its tab. A build from before that existed still
runs the example - the viewports simply have no X, and are closed from the
Window menu instead.
