package main

import math "core:math/linalg"
import "core:fmt"

crosshair: ^GameObject
rotate_cube: ^GameObject
cam: ^GameObject
test_gui: ^GameObject
font: ^GameObject
fps_txt: ^GameObject

mouse_speed :: 0.5
cam_speed: f32 = 20.0
acc: f32 = 0
cube_speed: f32 = 1
last_pos: vec2

game_init :: proc(camera: ^GameObject) {
    cam = camera
     window_enable_cursor(false)

    mat := Material{
        diffuse_filepath = "assets/models/c.png",
        normal_filepath = "assets/models/cn.png",
        normal_strength = 1.0,
        texture_tilling = 2,
    }

    crosshair = gui_create_quad(color = vec4{ 0, 1, 0, 1 })
    crosshair.scale.xy = 6
    gui_set_render_index(crosshair.id, 999)

    mat.diffuse_filepath = "assets/models/brick.jpg"
    mat.normal_filepath = "assets/models/brick_normal.jpg"

    rotate_cube = new_object("assets/models/cube.gltf", mat)
    rotate_cube.position.x = 3
    rotate_cube.position.y = 0.5

    mat.texture_tilling = 2

    cube := new_object("assets/models/cube.gltf", mat)
    cube.position.y = 0.5

    cube1 := new_object("assets/models/cube.gltf")
    cube1.position.x = -2.5
    cube1.position.y = 0.5

    mat.diffuse_filepath = "assets/models/c.png"
    mat.normal_filepath = "assets/models/cn.png"
    mat.texture_tilling = 62

    ground := new_object("assets/models/plane.gltf", mat)
    ground.position.y = -1
    ground.rotation.x = 0
    ground.scale.xyz = 100

    light := new_light_obj(.DirectionalLight, { 1, 1, 1, 1.3 })
    light.rotation.x = 40

    test_gui = gui_create_quad("assets/btn/normal/Play@4x.png", proc(event: GuiEvent) {
        g := get_gui(event.id)

        if event.hovering {
            set_texture(event.id, "assets/btn/hover/Play@4x.png")
            g.color.rg = 0.7
            g.color.b = 1.0
        } else {
            set_texture(event.id, "assets/btn/normal/Play@4x.png")
            g.color.rgb = 1
        }
        if event.pressed {
            cube_speed += 3
        }
    })

    test_gui.position.x = -1920 + test_gui.scale.x
    test_gui.position.y = 1080 - test_gui.scale.y
    test_gui.scale.z = 0.5

    fps_btn := gui_create_quad("assets/btn/normal/Play@4x.png", proc(event: GuiEvent) {
        g := get_gui(event.id)

        if event.hovering {
            set_texture(event.id, "assets/btn/hover/MediumArrow-Right@4x.png")
            g.color.rb = 0.7
            g.color.g = 1.0
        } else {
            set_texture(event.id, "assets/btn/normal/MediumArrow-Right@4x.png")
            g.color.rgb = 1
        }

        fps_lock = !event.toggle
    })

    fps_btn.position.x = -1920 + fps_btn.scale.x * 2 + 12
    fps_btn.position.y = 1080 - fps_btn.scale.y
    fps_btn.scale.z = 0.5

    fps_bg := gui_create_quad(color = vec4{ 0, 0, 0, 0.75})
    fps_bg.scale.x = 360
    fps_bg.scale.y = 32
    fps_bg.position.x = -WIN_SIZE.x / 2 - 590
    fps_bg.position.y = WIN_SIZE.y - 35
    gui_set_render_index(fps_bg.id, 1)

    font = new_font_atlas("assets/fonts/JetBrainsMono-Regular.ttf", 0, 70)
    fps_txt = new_text(font.id, "")
    fps_txt.position.x = -330
    fps_txt.position.y = -20
    gui_set_render_index(fps_txt.id, 2)

    set_parent(fps_bg.id, fps_txt.id)
}

game_destroy :: proc() {

}

rotate_camera :: proc(dt: f32) {
    pos := window_get_cursor_position_f32()

    rotate := (pos - last_pos) * mouse_speed * 0.1
    last_pos = pos

    cam.rotation.xy += rotate.yx
    cam.rotation.x = math.clamp(cam.rotation.x, -90, 90)
}

last_dir: vec3
cam_dir : vec3

move_camera :: proc(dt: f32) {
    if !is_cursor_enabled() do rotate_camera(dt)

    cam_dir = vec3{}
    forward_dir := get_object_forward_dir(cam.id)
    right_dir := get_object_right_dir(cam.id)

    if is_key_pressed(.W) do cam_dir += forward_dir
    if is_key_pressed(.S) do cam_dir -= forward_dir
    if is_key_pressed(.A) do cam_dir -= right_dir
    if is_key_pressed(.D) do cam_dir += right_dir

    if is_key_pressed(.E) || is_key_pressed(.SPACE) do        cam_dir += vec3_up
    if is_key_pressed(.Q) || is_key_pressed(.LEFT_CONTROL) do cam_dir -= vec3_up

    if math.dot(cam_dir, cam_dir) > math.F32_EPSILON {
        last_dir = cam_dir
        acc += 5 * dt
    } else {
        acc -= 6 * dt
        acc = max(acc, 0.0)
        cam_dir = last_dir
    }

    if math.dot(cam_dir, cam_dir) > math.F32_EPSILON {
        cam_dir = math.normalize(cam_dir)

        if is_key_pressed(.LEFT_SHIFT) {
            cam_dir *= 3.0 * cam_speed * dt
        } else {
            cam_dir *= cam_speed * dt
        }

        acc = min(acc, 1.0)
        cam.position += cam_dir * acc
    }
}

time: f64
game_update :: proc(dt: f64) {
    delta := f32(dt)
    rotate_cube.rotation.xy += 45 * delta * cube_speed

    move_camera(delta)

    time += dt

    if time > 0.1 {
        str := fmt.tprintf("FPS:%.2f (%.6f ms)", 1 / dt, dt * 1000)
        set_text(fps_txt.id, str)
        time = 0
    }
}

game_input :: proc(key: Key, scancode: i32, state: State, mod: Mod) {
    if key == .CAPS_LOCK || key == .ESCAPE do app_exit()

    if key == .TAB && state == .RELEASE {
        if is_cursor_enabled() {
            cursor_pos := window_get_cursor_position()
            last_pos = vec2{f32(cursor_pos.x), f32(cursor_pos.y)}
        }

        window_toggle_cursor()
    }
}

game_scroll :: proc(value: vec2f64) {
    cam_speed += f32(value.y) * 0.1 * cam_speed
    cam_speed = max(0.005, cam_speed)
}

game_resize :: proc(size: vec2) {
    // DEBUG(size)
}
