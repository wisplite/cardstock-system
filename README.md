This repository contains the default system libraries, launcher, and applications for Cardstock OS. It currently includes the following components:

# Applications
Below is a list of the pre-installed applications currently included with Cardstock.
## Paper
Paper is Cardstock’s default launcher and serves as a reference implementation for other launchers.

In Cardstock, launchers are standard applications. They live in the `launcher/` folder, launch at boot, and act as the default home app.

# Libraries
The system libraries live in the `syslib/` folder. They are Lua files that provide helper utilities for Cardstock applications. Unlike app-scoped libraries, these are globally accessible.
## gfxplus.lua
`gfxplus` is a graphics helper library with simple functions for tasks like color math and more advanced rendering patterns.
## doublebuf.lua
`doublebuf` is a small helper library that makes the M5Canvas tools easier to use, enabling smooth animations via double-buffering.
## anim.lua
`anim` is a lightweight animation toolkit for smoothly interpolating values over time.

# Planned Updates
Over time, I plan to add more default system apps and continuously improve `syslib` as I build more applications with it.