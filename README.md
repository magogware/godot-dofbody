# godot-dofbody
Need a flexible solution for VR (and non-VR, too!) doors, drawers, levers, dials, valves, or any other interactable object with restricted movement? The DoFBody is here!

The DoFBody is a RigidBody with customisable and restrictable degrees of freedom, particularly for use in VR. The DoFBody node allows you to restrict the movement of grabbable objects in your VR (or non-VR) game without introducing any extra code. Simply call the `_grabbed` function on the DoFBody, pass in the Spatial node containing your in-game hand (such as an ARVRController node), and the DoFBody will automatically follow your hand without violating the constraints you configure. The DoFBody will also emit signals when it fully opens, closes, or moves out of being fully open or closed. It can even emit a tick signal at specified intervals as it moves through its range of motion.

You can limit movement to any of the 6 degrees of freedom in 3D: X, Y, and Z translation, and X, Y, and Z rotation. You can even link rotation about an axis to the rotation of a controller. Finally, a VR safe-cracking game is at hand! 

All movement is calculated using local object axes, so all of the transformations work without having to align things to the global transformation axes or doing any matrix math.

# Documentation
A scene with a variety of pre-configured DoFBodies is available under the `example` directory. Use the WASD keys to move around, the left mouse button to grab an object, and the Q and E keys to twist your in-game hand clockwise and counter-clockwise.

A video demo of the DoFBody, with tutorials on how to implement several common objects, is available [here](link to demo). **Please watch the demo and tutorial!** Configuring a DoFBody requires visualising things in 3D, which is especially difficult to convey in words. The documentation here is a good reference, but a video is worth a thousand manuals!

# Usage

## Basic setup
DoFBodies can be added to the scene tree like any other node; hit Ctrl-A (or Cmd-A on macOS) or click the `+` icon at the top of the scene tree, then select DoFBody from the popup window. After that, give the body a collision shape and (optionally) a MeshInstance so you can see it in-game.

After this, select the DoFBody and view it in the Property Inspector. Under the `dofs` property, click the up arrow to add a slot for a degree of freedom, or DoF resource. You can add as many as you'd like and freely combine translation and rotation, but you should ensure that you do not add more than one DoF for the same axis and degree of freedom. For example, a DoFBody with a translation DoF on the X axis and a rotation DoF on the X axis will function fine, but a DoFBody with two rotation DoFs on the X axis will behave unpredictably.

## Configuring degrees of freedom; the DoF resource
A DoFBody's DoF resources describe how it can move and how it is constrained. Each DoF resources corresponds to one degree of freedom, and is either a translation along, or a rotation about, a particular axis.

The `mode` property selects whether this is a translation or rotation DoF.

If the DoF is set to translation, then you can select precisely one axis to translate along.

If the DoF is set to rotation, you must select two axes. The first is the rotation axis, which is the axis that the DoFBody will revolve around. The second is the edge axis, which is the axis that you would like to point toward the player's hand. For example, a door will typically rotate on its Y axis and its edge axis will typically be the X axis. As the door rotates, its edge will point towards your hand. A lever, on the other hand, will usually rotate on its Z or X axis (depending on whether your lever works front-to-back or left-to-right), and its edge axis will be its Y axis (i.e. the stem of the lever that points upward). If rotation isn't working as expected, double-check the orientation of your mesh in Godot or your 3D modeler. All transformations take place in the objects local space, so these settings will work even if you rotate or translate the DoFBody in Godot. For example, if you set the Y axis to be the axis of rotation, then rotate your lever sideways, the DoFBody will still work as expected.

If the DoF is set to rotation, there will also be the option to link rotation to the in-game hand. This is useful for objects like dials that should rotate as the player twists their hand. If controller linkage is enabled for a DoF, you must select the axis on the controller that rotation should be linked to. This is generally the axis on the controller that will be perpendicular to the rotation axis on the DoFBody, which is usually the Z axis. The video gives an in-detail visualisation of this.

Open range describes how far the DoFBody can move from its starting position (i.e. its position as seen in the editor) in a positive direction along the axis (for translation DoFs) or a counter-clockwise direction (for rotation DoFs). For example, the open range describes how far a translation DoF set to the X axis can move to the right. For translation DoFs, this property is measured in the engine's distance unit (meters). For rotation DoFs, this property is measured in degrees.

Close range is the same as open range, but describes how far the DoFBody can move from its starting position in a negative direction or clockwise rotation.

Max opening speed describes how fast the DoFBody can move toward its open position. Set this to 0 to allow the DoFBody to open as fast as the controller can move. For translation DoFs, this is measured in engine units (meters) per second. For rotation DoFs, this is measured in degrees per second.

Max closing speed is the same as max opening speed, but describes how fast the DoFBody can move toward its open position.

Retraction direction describes how the DoFBody will move when it is not being grabbed. This can be set to either retract towards the open position, the closed position, or not to retract at all. The DoFBody will not retract while held, only when it is released.

Open latching mode describes how the DoFBody will latch (i.e. stick) to its opening position once it fully opens. If set to latch forever, the DoFBody will not move at all once it is fully open. It will not move if grabbed or if its retraction is set to retract closed. The DoFBody's movement in this particular DoF will, in effect, be permanently disabled once open. Note that this does not inhibit movement in any other DoFs on the DoFBody. If set to latch within distance, the DoFBody will not move until it is grabbed and moved past the distance set in the latch distance property. This will prevent retraction from affecting the DoFBody, and is useful for preventing the player from accidentally shifting the DoFBody from a fully open position with a stray grab. For translation DoFs, the latch distance is measured in engine units (meters). For rotation DoFs, the latch distance is measured in degrees.

Close latching mode is the same as open latching mode, but describes how the DoFBody will latch to its closed position once it fully closes.

**Please note that there is a bug in the DoFBody latching implementation:** if a DoFBody is set to latch in a direction and its latch distance is shorter than that direction's range of motion, the DoFBody will permanently latch in that direction from the get-go and will not be movable at all. For example, if a DoFBody is set to latch open within a distance, the open range is 10, and the latch distance is 5, then the DoFBody will be permanently latched once it fully opens. This is particularly problematic with ranges of 0 (i.e.: when the DoFBody only moves in one direction from its starting position in the editor) as the DoFBody will not move from its starting position. 

## Signals
The DoFBody has four signals: open, moving, closed, and tick.

The open and closed signals are emitted when the DoFBody reaches the fully open or fully closed position of *any* DoF. To help you work out which DoF has been opened or closed, the DoFBody will pass the index of the relevant DoF in its `dofs` array property.

The moving signal is emitted when the DoFBody moves from a fully open or fully closed position to somewhere in between. This also emits the index of the relevant DoF. **Please note that there is a bug in the moving signal for translation DoFs**: currently, a DoFBody will infinitely emit the moving signal when a DoFBody is fully open.

The tick signal is emitted when the DoFBody moves through 1/n of its total range (closed and open), where n is defined by the ticks property of a DoF. For example, for a translation DoF with a close range of 2, an open range of 3, and ticks set to 10, the tick signal will be emitted as the DoFBody passes 0.5 engine unit (meters) increments along its DoF. This also emits the index of the relevant DoF. This is useful for triggering sound effects like a ratchet or creak, or setting a progress meter on another node.

## Handles
You can also add a RigidBody or KinematicBody child node to the DoFBody to act as a handle. If you set up this handle to collide with the player's hand, and the main DoFBody to ignore collisions with the players hand, you can ensure that the player can only grab the DoFBody from one specific position. This setup is used in the example scene. 
