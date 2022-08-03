[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=KYWUWS86GSFGL)

### 2D Interactive Plotting Program

Does anyone out there know of any good plotting programs?
All the ones i've ever tried are very slow or can't import data well or are not flexible enough.
Everything seems to fall short in one way or another.
I use gnuplot for most everything, except that even with that you don't get good interaction with your data.
Enter plot2d, the luajit-driven 2D plotting environment.

Controls:
- mouse click + drag to pan
- mouse wheel to zoom
- shift + mouse click to stretch individual axii

For a test drive try luajit run.lua

Depends on:
- luajit
- lua-ext
- lua-vec
- lua-glapp
- lua-ffi-bindings
- SDL
- Imgui
- Malkia's UFO
