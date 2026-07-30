# <div align="center"> ~ [<ins>**UInteract**</ins>](https://github.com/archadiumm/UInteract/releases/latest) ~ </div> 

**UInteract** is a roblox library that can detect UI interactions, like collisions for example. It features a collision grouping system, and also supports rotated object collisions unlike some other libraries.

# Documentation

Firstly, you should download **UInteract** from the [latest release](https://github.com/archadiumm/UInteract/releases/latest). Next, create a new LocalScript to start things off.

To use **UInteract**, you need to convert your GuiObject to a UIObject using `UInteract.new` or `UInteract.find`.
```luau
const UInteract = require(path.to.UInteract)

const Frame = script.Parent.TestFrame
const Object = UInteract.new(Frame)
```

You can make and edit collision groups by using `setCollisionGroup`/`editCollisionGroup`. You can see so in the example below.
```luau
UInteract.setCollisionGroup("NewGroup", {"Default"})
UInteract.editCollisionGroup("NewGroup", {"NewGroup", "Default"})
```

Now, you can go back to your `UIObject` and use the functions below to do whatever you wish!
```luau
Object:setCollision("NewGroup") -- Sets the object's collisionGroup to "NewGroup"

print(Object:getTouching()) -- Gets a list of other UIObjects that are touching this Object.

Object:Touched(function(new: {UInteract.Object})
  print(new, "are touching the Object now!") -- Prints the list of newly touching objects that are now touching this.
end)

task.wait(5)

Object:Disconnect("Touched") -- Disconnects the Touched signal.
```
