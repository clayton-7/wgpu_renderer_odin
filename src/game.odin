package main

import math "core:math/linalg"

crosshair: ^GameObject
rotate_cube: ^GameObject
cam: ^GameObject
rotate_gui: ^GameObject
test_gui: ^GameObject

mouse_speed :: 3.0
cam_speed: f32 = 20.0
acc: f32 = 0
last_pos: vec2

game_init :: proc(camera: ^GameObject) {
    cam = camera
    // window_enable_cursor(false)

    mat := Material{
        diffuse_filepath = "assets/models/c.png",
        normal_filepath = "assets/models/cn.png",
        normal_strength = 1.0,
        texture_tilling = 2,
    }

    crosshair = gui_create_quad(color = vec4{ 0, 1, 0, 1 })
    crosshair.scale.xy = 6

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

    rotate_gui = gui_create_quad("assets/models/c.png")
    rotate_gui.scale.xy = 256
    rotate_gui.position.x = 880
    rotate_gui.position.y = 460

    test_gui = gui_create_quad("assets/models/brick.jpg", proc(event: GuiEvent) {
        DEBUG(event)

        g := get_gui(test_gui.id)

        if event.hovering {
            g.color.a = 0.7
        } else {
            g.color.a = 1
        }
    })

    test_gui.scale.xy = 256
    test_gui.position.x = -1920 + test_gui.scale.x + 250
    test_gui.rotation.z = 45
    test_gui.scale.z = 0.5
}

game_destroy :: proc() {

}

rotate_camera :: proc(dt: f32) {
    pos := window_get_cursor_position_f32()

    rotate := (pos - last_pos) * mouse_speed * dt
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

game_update :: proc(dt: f64) {
    delta := f32(dt)
    rotate_cube.rotation.xy += 45 * delta
    rotate_gui.rotation.z += 45 * delta

    move_camera(delta)
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
