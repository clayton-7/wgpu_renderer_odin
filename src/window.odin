package main

import "vendor:sdl3"
import "vendor:wgpu"
import "vendor:wgpu/sdl3glue"
import "core:c"

app_window_size: vec2

window_init :: proc(win_size: vec2, name: cstring) -> ^sdl3.Window {
    app_window_size = win_size

    if !sdl3.Init(sdl3.INIT_VIDEO) do FATAL("Failed to initialize SDL3")

    flags := sdl3.WindowFlags{ .BORDERLESS, .RESIZABLE }
    window = sdl3.CreateWindow(name, c.int(win_size.x), c.int(win_size.y), flags)

    if window == nil do FATAL("Failed to create SDL3 window")

    return window
}

window_destroy :: proc() {
    sdl3.DestroyWindow(window)
    sdl3.Quit()
}

window_get_size :: proc() -> (size: vec2) {
    w, h := c.int(0), c.int(0)
    sdl3.GetWindowSize(window, &w, &h)
    return vec2{f32(w), f32(h)}
}

window_set_size :: proc(size: vec2) {
    sdl3.SetWindowSize(window, c.int(size.x), c.int(size.y))
}

window_get_aspect :: proc() -> f32 {
    win_size := window_get_size()
    return win_size.x / win_size.y
}

window_get_viewport_aspect :: proc() -> f32 {
    v := window_get_fixed_aspect_viewport()
    return  v.w / v.h;
}

window_get_window_size :: proc() -> vec2 {
    return app_window_size
}

window_get_fixed_aspect :: proc() -> f32 {
    return app_window_size.x / app_window_size.y
}

window_get_fixed_aspect_viewport :: proc() -> struct { x: f32, y: f32, w: f32, h: f32 } {
    aspect := window_get_fixed_aspect()
    window_size := window_get_size()
    w := min(window_size.x, window_size.y * aspect)
    h := min(window_size.y, window_size.x / aspect)
    x := (window_size.x - w) / 2.0
    y := (window_size.y - h) / 2.0

    return { x = x, y = y, w = w, h = h }
}

window_get_cursor_position :: proc() -> vec2f64 {
    x, y := f32(0), f32(0)
    // NOTE: GetMouseState returns window-relative coordinates, like glfw.GetCursorPos did.
    // GetGlobalMouseState returns desktop coordinates and breaks GUI hit testing.
    _ = sdl3.GetMouseState(&x, &y)
    return vec2f64{ f64(x), f64(y) }
}

window_get_cursor_position_f32 :: proc() -> vec2 {
    x, y := f32(0), f32(0)
    _ = sdl3.GetMouseState(&x, &y)
    return vec2{ x, y }
}

window_get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface { return sdl3glue.GetSurface(instance, window) }

window_enable_cursor :: proc(enable: bool) {
    err := sdl3.SetWindowRelativeMouseMode(window, enable)
    _ = err
}

window_toggle_cursor :: proc() {
    enabled := sdl3.GetWindowRelativeMouseMode(window)
    err := sdl3.SetWindowRelativeMouseMode(window, !enabled)
    _ = err
}

is_key_pressed :: proc(key: sdl3.Keycode) -> bool {
    state := sdl3.GetKeyboardState(nil)
    return state[int(key)]
}

is_key_released :: proc(key: sdl3.Keycode) -> bool {
    state := sdl3.GetKeyboardState(nil)
    return !state[int(key)]
}

is_key_repeated :: proc(key: sdl3.Keycode) -> bool {
    // SDL3 doesn't have a direct "repeated" state,
    // we track this in the event loop
    return false
}

is_key_holding :: proc(key: sdl3.Keycode) -> bool {
    state := sdl3.GetKeyboardState(nil)
    return state[int(key)]
}

set_cursor_position :: proc(pos: vec2) {
    sdl3.WarpMouseInWindow(window, pos.x, pos.y)
}

is_cursor_enabled :: proc() -> bool {
    return !sdl3.GetWindowRelativeMouseMode(window)
}
