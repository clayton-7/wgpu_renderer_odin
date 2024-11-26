package main

import "vendor:glfw"
import "vendor:wgpu"
import "vendor:wgpu/glfwglue"
import "core:c"

app_window_size: vec2

window_init :: proc(win_size: vec2, name: cstring) -> glfw.WindowHandle {
    app_window_size = win_size

    if !glfw.Init() do FATAL("Failed to initialize GLFW")

    glfw.WindowHint(glfw.DECORATED, false)
    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    glfw.WindowHintString(glfw.WAYLAND_APP_ID, name)
    glfw.WindowHintString(glfw.X11_CLASS_NAME, name)
    glfw.WindowHintString(glfw.X11_INSTANCE_NAME, name)

    window = glfw.CreateWindow(c.int(win_size.x), c.int(win_size.y), name, nil, nil)

    if window == nil do FATAL("Failed to create GLFW window")

    // glfw.SetFramebufferSizeCallback(window, size_callback)

    return window
}

window_destroy :: proc() {
    glfw.DestroyWindow(window)
    glfw.Terminate()
}

window_get_size :: proc() -> (size: vec2) {
    w, h := glfw.GetWindowSize(window)
    return vec2{f32(w), f32(h)}
}

window_set_size :: proc(size: vec2) {
    glfw.SetWindowSize(window, i32(size.x), i32(size.y))
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
    x, y := glfw.GetCursorPos(window)
    return vec2f64{ x, y }
}

window_get_cursor_position_f32 :: proc() -> vec2 {
    x, y := glfw.GetCursorPos(window)
    return vec2{ f32(x), f32(y) }
}

window_get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface { return glfwglue.GetSurface(instance, window) }

window_enable_cursor :: proc(enable: bool) {
    mode := glfw.CURSOR_NORMAL if enable else glfw.CURSOR_DISABLED
    glfw.SetInputMode(window, glfw.CURSOR, c.int(mode))
}

window_toggle_cursor :: proc() {
    mode := glfw.CURSOR_DISABLED
    if glfw.GetInputMode(window, glfw.CURSOR) == glfw.CURSOR_DISABLED do mode = glfw.CURSOR_NORMAL

    glfw.SetInputMode(window, glfw.CURSOR, c.int(mode))
}

is_key_pressed :: proc(key: Key) -> bool {
    return glfw.GetKey(window, i32(key)) == i32(State.PRESS)
}

is_key_released :: proc(key: Key) -> bool {
    return !(glfw.GetKey(window, i32(key)) == i32(State.PRESS)) && glfw.GetKey(window, i32(key)) == i32(State.RELEASE)
}

is_key_repeated :: proc(key: Key) -> bool {
    return glfw.GetKey(window, i32(key)) == i32(State.HOLD)
}

is_key_holding :: proc(key: Key) -> bool {
    return glfw.GetKey(window, i32(key)) == i32(State.PRESS) && !(glfw.GetKey(window, i32(key)) == i32(State.RELEASE))
}

set_cursor_position :: proc(pos: vec2) {
    glfw.SetCursorPos(window, f64(pos.x), f64(pos.y))
}

// enable_cursor :: proc(enable: bool) {
//     glfw.SetInputMode(window, glfw.CURSOR, if (enable) glfw.CURSOR_DISABLED else glfw.CURSOR_NORMAL)
// }

is_cursor_enabled :: proc() -> bool {
    return glfw.GetInputMode(window, glfw.CURSOR) != i32(glfw.CURSOR_DISABLED)
}
