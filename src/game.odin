package main
import "core:fmt"
import "vendor:sdl3"

font: ^GameObject
cam: ^GameObject
player: ^GameObject
fps_txt: ^GameObject

mouse_speed :: 0.5

game_init :: proc(camera: ^GameObject) {
    cam = camera
    cam.position.xyz = 0

    window_enable_cursor(false)

    fps_btn := gui_create_quad("assets/btn/normal/Play@4x.png", proc(event: GuiEvent) {
        g := get_gui(event.id)

        if event.hovering {
            set_texture(event.id, "assets/btn/hover/MediumArrow-Right@4x.png")
            g.color.rb = 0.7
            g.color.g = 1.0
        } else {
            set_texture(event.id, "assets/btn/normal/Play@4x.png")
            g.color.rgb = 1
        }

        fps_lock = !event.toggle
    })

    fps_btn.scale.z = 0.3
    fps_btn.position.x = -WIN_SIZE.x + fps_btn.scale.x / 2.7
    fps_btn.position.y = WIN_SIZE.y - fps_btn.scale.y / 1.5

    fps_bg := gui_create_quad(color = vec4{ 0, 0, 0, 0.75 })
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

    player = gui_create_quad()
    player.scale = 12
    gui := get_gui(player.id)
    gui.gui_type = .GAME_OBJECT
}

game_destroy :: proc() {}

game_update :: proc(dt: f64) {
    delta := f32(dt)

    if is_key_holding(sdl3.Scancode.A) do player.position.x -= 1000.0 * delta
    if is_key_holding(sdl3.Scancode.D) do player.position.x += 1000.0 * delta
    if is_key_holding(sdl3.Scancode.SPACE) do player.position.y += 10000.0 * delta

    if is_key_pressed(sdl3.K_TAB) do window_toggle_cursor()
    if is_key_pressed(sdl3.K_ESCAPE) do app_quit()

    str := fmt.tprintf("FPS:%.2f (%.6f ms)", 1 / dt, dt * 1000)
    set_text(fps_txt.id, str)
}

game_input :: proc(event: sdl3.KeyboardEvent) {
    // DEBUG(event)
}

game_scroll :: proc(value: vec2) {
    // cam_speed += value.y * 0.1 * cam_speed
    // cam_speed = max(0.005, cam_speed)
}

game_resize :: proc(size: vec2) {
    // DEBUG(size)
}
