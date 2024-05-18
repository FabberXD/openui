# OpenUI for Cubzh

OpenUI is a powerful and flexible Lua module designed to streamline the creation and management of user interfaces in Cubzh. It offers a comprehensive set of tools and components for building interactive UI elements such as buttons, sliders, checkboxes, and much more.

## Features

- **Ease of Use**: Simplifies the UI development process with straightforward functions and syntax.
- **Customizable Components**: Includes various pre-built components such as buttons, sliders, checkboxes, and text displays that can be easily customized and extended.
- **Event Handling**: Built-in support for touch and click event handling, making your UI interactive.
- **Flexible Layouts**: Supports dynamic positioning and scaling to fit different screen sizes and resolutions.
- **Custom Nodes support**: OpenUI allows you to import custom nodes for ease of use.

### Initialization

```lua
local openui_manager = require("openui_manager")
local config = {
    debug = false, -- Enable debugging (optional)
    -- Other configuration options as needed
}
openui = openui_manager.init(config)
```

### Creating UI Elements

Here's a quick example of how to create a button:

```lua
local button = openui:TextButton("Click Me!", {
    color = Color(63, 63, 63),
    textColor = Color(255, 255, 255),
    -- Other settings
})

button.OnRelease = function()
    print("Button clicked!")
end
```

## Components

The following components are available:

- **Frame**: Used to create rectangles on the screen.
- **Text**: For displaying text.
- **TextButton**: Interactive buttons with customizable text.
- **HorizontalSlider / VerticalSlider**: For creating slider controls.
- **Checkbox**: For creating toggleable checkboxes.

Each component can be customized with various parameters and supports event handling.

## Custom Nodes

You can import your own nodes using ui:ImportNode function:

```lua
openui:ImportNode("MyNode", myNode)
openui:MyNode() -- Automaticly adds 'MyNode' as method to spawn your nodes
```

## Documentation

For detailed documentation on each component and their supported configuration options, please refer to the in-code comments and default configs in code.

## Contributing

As an open-source project, contributions are welcome! Feel free to fork the repository, make your changes, and submit a pull request.

## License

OpenUI Manager is open-source software licensed under the MIT license.
