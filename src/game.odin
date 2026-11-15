package main
import "core:fmt"

test_gui: ^GameObject
font: ^GameObject
fps_txt: ^GameObject

mouse_speed :: 0.5

game_init :: proc(camera: ^GameObject) {
    window_enable_cursor(false)

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
            DEBUG("clicked")
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
}

game_destroy :: proc() {}

game_update :: proc(dt: f64) {
    delta := f32(dt)

    str := fmt.tprintf("FPS:%.2f (%.6f ms)", 1 / dt, dt * 1000)
    set_text(fps_txt.id, str)
}

game_input :: proc(key: Key, scancode: i32, state: State, mod: Mod) {
    if key == .ESCAPE do app_exit()

    if key == .TAB && state == .RELEASE {
        window_toggle_cursor()
    }
}

game_scroll :: proc(value: vec2f64) {
    // cam_speed += f32(value.y) * 0.1 * cam_speed
    // cam_speed = max(0.005, cam_speed)
}

game_resize :: proc(size: vec2) {
    // DEBUG(size)
}
