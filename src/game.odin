package main

import math "core:math/linalg"
// import mu "vendor:microui"
import "core:fmt"
import box "vendor:box3d"

crosshair: ^GameObject
rotate_cube: ^GameObject
cam: ^GameObject
test_gui: ^GameObject
font: ^GameObject
fps_txt: ^GameObject
cube1: ^GameObject
cube1_body_id: box.BodyId
ground: ^GameObject

world_id: box.WorldId

mouse_speed :: 0.5
cam_speed: f32 = 12.0
acc: f32 = 0
cube_speed: f32 = 1
last_pos: vec2
cam_euler: vec3

game_init :: proc(camera: ^GameObject) {
    cam = camera
    cam_euler = get_rotation_euler(cam.id)
    window_enable_cursor(false)

    mat := Material{
        diffuse_filepath = "assets/models/c.png",
        normal_filepath = "assets/models/cn.png",
        normal_strength = 1.0,
        texture_tilling = 2,
    }

    // crosshair = gui_create_quad(color = vec4{ 0, 1, 0, 1 })
    // crosshair.scale.xy = 6
    // gui_set_render_index(crosshair.id, 999)

    mat.diffuse_filepath = "assets/models/brick.jpg"
    mat.normal_filepath = "assets/models/brick_normal.jpg"

    rotate_cube = new_object("assets/models/cube.gltf", mat)
    rotate_cube.position.x = 3
    rotate_cube.position.y = 0.5

    mat.texture_tilling = 2

    cube := new_object("assets/models/cube.gltf", mat)
    cube.position.y = 0.5

    cube1 = new_object("assets/models/cube.gltf")
    cube1.position.x = -2.5
    cube1.position.y = 5.5
    cube1.rotation = vec3_to_quat(vec3{ 45, 45, 45 })

    mat.diffuse_filepath = "assets/models/c.png"
    mat.normal_filepath = "assets/models/cn.png"
    mat.texture_tilling = 62

    ground = new_object("assets/models/cube.gltf", mat)
    ground.scale.xz = 100
    ground.scale.y= 0.100
    ground.position.y = -2

    light := new_light_obj(.Directional, { 1, 1, 1, 1 })
    set_rotation_euler(light.id, { 45, 0, 0 })

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

    test_gui.scale.z = 0.5
    test_gui.position.x = -WIN_SIZE.x + test_gui.scale.x / 2 + 6
    test_gui.position.y = WIN_SIZE.y - test_gui.scale.y / 1.15

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

    fps_btn.scale.z = 0.5
    fps_btn.position.x = -WIN_SIZE.x + fps_btn.scale.x * 1.5 + 6
    fps_btn.position.y = WIN_SIZE.y - fps_btn.scale.y / 1.15

    fps_bg := gui_create_quad(color = vec4{ 0, 0, 0, 0.75})
    fps_bg.scale.x = 360
    fps_bg.scale.y = 32
    fps_bg.position.x = -WIN_SIZE.x + fps_bg.scale.x + 6
    fps_bg.position.y = WIN_SIZE.y - 35
    gui_set_render_index(fps_bg.id, 1)

    font = new_font_atlas("assets/fonts/JetBrainsMono-Regular.ttf", 0, 70)
    fps_txt = new_text(font.id, "")
    fps_txt.position.x = -330
    fps_txt.position.y = -20
    gui_set_render_index(fps_txt.id, 2)

    set_parent(fps_bg.id, fps_txt.id)

    //000++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    world_def := box.DefaultWorldDef()
    world_def.gravity = { 0, -9.8, 0 }
    world_id = box.CreateWorld(world_def)

    ground_body_def := box.DefaultBodyDef()
    ground_body_def.position = ground.position.xyz
    ground_id := box.CreateBody(world_id, ground_body_def)

    ground_box := box.MakeBoxHull(ground.scale.x, ground.scale.y, ground.scale.z)
    ground_shape_def := box.DefaultShapeDef()
    _ = box.CreateHullShape(ground_id, ground_shape_def, &ground_box.base)

    cube_def := box.DefaultBodyDef()
    cube_def.type = .dynamicBody

    cube_def.position = cube1.position.xyz
    cube_def.rotation = cube1.rotation

    cube1_body_id = box.CreateBody(world_id, cube_def)

    dynamic_box := box.MakeBoxHull(cube1.scale.x, cube1.scale.y, cube1.scale.z)
    shape_def := box.DefaultShapeDef()
    shape_def.density = 1
    shape_def.baseMaterial.friction = 0.3

    _ = box.CreateHullShape(cube1_body_id, shape_def, &dynamic_box.base)
}

game_destroy :: proc() {

}

rotate_camera :: proc(dt: f32) {
    pos := window_get_cursor_position_f32()

    rotate := (pos - last_pos) * mouse_speed * 0.1
    last_pos = pos

    cam_euler.xy += rotate.yx
    cam_euler.x = math.clamp(cam_euler.x, -90, 90)
    set_rotation_euler(cam.id, cam_euler)
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
    rotate_delta := vec3_to_quat({ 45 * delta * cube_speed, 45 * delta * cube_speed, 0 })
    rotate_cube.rotation = rotate_delta * rotate_cube.rotation

    time_step:      f32 = 1. / 60.
    sub_step_count: i32 = 4

    box.World_Step(world_id, time_step, sub_step_count)

    cube1_trans := box.Body_GetTransform(cube1_body_id)
    cube1.position = cube1_trans.p.xyz
    set_rotation_quat(cube1.id, cube1_trans.q)

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
