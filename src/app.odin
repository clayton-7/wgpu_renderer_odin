package main

import "vendor:glfw"
import "vendor:wgpu"
import "core:time"

WIN_TITLE :: "Force"

TARGET_FPS :: 60.0
fps_lock: bool = true
 //WIN_SIZE :: vec2{ 1024, 1024 }
WIN_SIZE :: vec2{ 1920, 1080 }
// WIN_SIZE :: vec2{ 2560, 1440 }
 //WIN_SIZE :: vec2{ 3840, 2160 }

app_init :: proc() {
    ctx = context
    types_init()
    go_init()
    window_init(WIN_SIZE, WIN_TITLE)
    device_init()

    gui_init()
    render_init()
    skybox_init()

    app_update()
}

app_destroy :: proc() {
    skybox_destroy()
    render_destroy()
    gui_destroy()
    device_destroy()
    window_destroy()
    go_destroy()
    types_destroy()
}

app_update :: proc() {
    delta_time: f64 = 0.0
    last_frame: f64 = 0.0

    global_ubo := GlobalUbo{}

    glfw.SetKeyCallback(window, app_input)
    glfw.SetScrollCallback(window, app_scroll)
    glfw.SetWindowSizeCallback(window, app_resize)
    glfw.SetMouseButtonCallback(window, app_mouse_btn)
    glfw.SetCursorPosCallback(window, app_cursor)

    camera := new_empty(vec3_back * 9)
    game_init(camera)

    for !glfw.WindowShouldClose(window) {
        begin_time := glfw.GetTime()
        glfw.PollEvents()

        current_frame := glfw.GetTime()
        delta_time = current_frame - last_frame
        last_frame = current_frame

        render_update_lights(&global_ubo, { 0.4, 0.4, 0.4 })
        game_update(delta_time)

        aspect: f32 = window_get_fixed_aspect()
        view_yxz := get_view_yxz(camera.position, camera.rotation)

        global_ubo.projection = get_perspective_projection_matrix(110, aspect, 0.01, 3000)
        global_ubo.view = view_yxz.view
        global_ubo.inverse_view = view_yxz.inverse_view

        // DEBUGF("FPS: %.2f\n", 1.0 / delta_time)

        cmd_encoder_descriptor: wgpu.CommandEncoderDescriptor = { nextInChain = nil, label = "Draw command encoder" }
        encoder: wgpu.CommandEncoder = wgpu.DeviceCreateCommandEncoder(device.device, &cmd_encoder_descriptor)

        // TEXTURE VIEW
        surface_texture := wgpu.SurfaceGetCurrentTexture(device.surface)
        defer wgpu.TextureRelease(surface_texture.texture)

        if surface_texture.status != .Success {
            INFOF("Cannot acquire the current render texture, status: %v\n", enum_to_string(surface_texture.status))
            continue
        }

        tex_view_desc := wgpu.TextureViewDescriptor{
            aspect = .All,
            arrayLayerCount = 1,
            mipLevelCount = 1,
            dimension = ._2D,
            format = render_textures.view_format,
        }

        current_texture_view := wgpu.TextureCreateView(surface_texture.texture, &tex_view_desc)
        render_pass: wgpu.RenderPassEncoder = render_begin_render_pass(current_texture_view, encoder, vec4f64_zero)

        view := window_get_fixed_aspect_viewport()
        wgpu.RenderPassEncoderSetScissorRect(render_pass, u32(view.x), u32(view.y), u32(view.w), u32(view.h))
        wgpu.RenderPassEncoderSetViewport(render_pass, view.x, view.y, view.w, view.h, 0.0, 1.0)

        skybox_draw(render_pass, device.queue, global_ubo)
        render_draw(render_pass, device.queue, global_ubo)
        gui_draw(render_pass, device.queue, global_ubo)

        wgpu.RenderPassEncoderEnd(render_pass)
        wgpu.RenderPassEncoderRelease(render_pass)
        wgpu.TextureViewRelease(current_texture_view)
        // ===================================

        command_buffer_descriptor := wgpu.CommandBufferDescriptor{ nextInChain = nil, label = "Draw command buffer" }
        command := wgpu.CommandEncoderFinish(encoder, &command_buffer_descriptor)

        wgpu.RawQueueSubmit(device.queue, 1, &command)

        wgpu.CommandBufferRelease(command)
        wgpu.CommandEncoderRelease(encoder)

        wgpu.SurfacePresent(device.surface)

        async_set_textures()
        free_all(context.temp_allocator)

        if fps_lock {
            target_fps_f64 := f64(TARGET_FPS)
            free_time : f64 = 1.0 / target_fps_f64 - (glfw.GetTime() - begin_time)

            if free_time > 0.0 {
                sleep_time := time.Duration(free_time * f64(time.Second))
                time.sleep(sleep_time)
            }
        }
    }

    game_destroy()
    app_destroy()
}

app_resize:: proc "c"(window: glfw.WindowHandle, width: i32, height: i32) {
    context = ctx
    w := f32(width)
    h := f32(height)

    // HACK: HANDLE THIS PROPERLY
    // TODO: FIND THE MAX RESOLUTION SUPPORTED FOR THE CURRENT DEVICE
    if (w >= 8192 || h >= 8192) {
        WARNF("Max supported resolution reached: %vx%v\n", w, h)
        window_set_size(vec2{ min(8192, w), min(8192, h) })
        return
    }

    win_size := vec2{ w, h }

    device_create_surface_textures(win_size)
    game_resize(win_size)
}

app_cursor :: proc "c" (_: glfw.WindowHandle, xpos,  ypos: f64) {
    context = ctx
    gui_cursor_event(vec2{ f32(xpos), f32(ypos) })
}

app_mouse_btn :: proc "c" (_: glfw.WindowHandle, button, action, mods: i32) {
    context = ctx
    gui_mouse(MouseButton(button), State(action), Mod(mods))
}

app_input :: proc "c"(_: glfw.WindowHandle, key, scancode, action, mods: i32) {
    context = ctx
    gui_input(Key(key), scancode, State(action), Mod(mods))
    game_input(Key(key), scancode, State(action), Mod(mods))
}

app_scroll :: proc "c"(_: glfw.WindowHandle, xoffset, yoffset: f64) {
    context = ctx
    game_scroll(vec2f64{ xoffset, yoffset} )
}

app_exit :: proc() {
    glfw.SetWindowShouldClose(window, true)
}
