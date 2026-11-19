package main

import "vendor:sdl3"
import "vendor:wgpu"
import "vendor:wgpu/sdl3glue"
import "core:c"

KEY_COUNT :: 512 // SDL_SCANCODE_COUNT

key_holding:  [KEY_COUNT]bool
key_pressed:  [KEY_COUNT]bool
key_released: [KEY_COUNT]bool
key_repeated: [KEY_COUNT]bool
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

key_index :: proc(scancode: sdl3.Scancode) -> int {
    i := int(scancode)
    if i < 0 || i >= KEY_COUNT do return -1
    return i
}

keyboard_new_frame :: proc() {
    for i in 0 ..< KEY_COUNT {
        key_pressed[i] = false
        key_released[i] = false
    }
}

keyboard_event :: proc(event: sdl3.KeyboardEvent) {
    i := key_index(event.scancode)
    if i < 0 do return

    if event.down {
        key_holding[i] = true

        if event.repeat do key_repeated[i] = true
        else do key_pressed[i] = true

        key_released[i] = false
    } else {
        key_holding[i] = false
        key_repeated[i] = false
        key_released[i] = true
        key_pressed[i] = false
    }
}

is_key_holding_scancode :: proc(scancode: sdl3.Scancode) -> bool {
    i := key_index(scancode)
    return i >= 0 && key_holding[i]
}

is_key_pressed_scancode :: proc(scancode: sdl3.Scancode) -> bool {
    i := key_index(scancode)
    return i >= 0 && key_pressed[i]
}

is_key_released_scancode :: proc(scancode: sdl3.Scancode) -> bool {
    i := key_index(scancode)
    return i >= 0 && key_released[i]
}

is_key_repeated_scancode :: proc(scancode: sdl3.Scancode) -> bool {
    i := key_index(scancode)
    return i >= 0 && key_repeated[i]
}

key_to_scancode :: proc(key: sdl3.Keycode) -> sdl3.Scancode {
    mod := sdl3.Keymod{}
    return sdl3.GetScancodeFromKey(key, &mod)
}

keycode_index :: proc(key: sdl3.Keycode) -> int {
    scancode := key_to_scancode(key)
    if scancode == sdl3.Scancode.UNKNOWN do return -1
    return key_index(scancode)
}

is_key_holding_keycode :: proc(key: sdl3.Keycode) -> bool {
    i := keycode_index(key)
    return i >= 0 && key_holding[i]
}

is_key_pressed_keycode :: proc(key: sdl3.Keycode) -> bool {
    i := keycode_index(key)
    return i >= 0 && key_pressed[i]
}

is_key_released_keycode :: proc(key: sdl3.Keycode) -> bool {
    i := keycode_index(key)
    return i >= 0 && key_released[i]
}

is_key_repeated_keycode :: proc(key: sdl3.Keycode) -> bool {
    i := keycode_index(key)
    return i >= 0 && key_repeated[i]
}

is_key_holding :: proc {
    is_key_holding_scancode,
    is_key_holding_keycode,
}

is_key_pressed :: proc {
    is_key_pressed_scancode,
    is_key_pressed_keycode,
}

is_key_released :: proc {
    is_key_released_scancode,
    is_key_released_keycode,
}

is_key_repeated :: proc {
    is_key_repeated_scancode,
    is_key_repeated_keycode,
}

set_cursor_position :: proc(pos: vec2) {
    sdl3.WarpMouseInWindow(window, pos.x, pos.y)
}

is_cursor_enabled :: proc() -> bool {
    return !sdl3.GetWindowRelativeMouseMode(window)
}
