package main

import "vendor:sdl3"
import "vendor:wgpu"
import "core:time"

WIN_TITLE :: "Force"
FOV :: 90

TARGET_FPS :: 60.0
fps_lock: bool = true
quit: bool = false
 //WIN_SIZE :: vec2{ 1024, 1024 }
WIN_SIZE :: vec2{ 1920, 1080 }
// WIN_SIZE :: vec2{ 2560, 1440 }
// WIN_SIZE :: vec2{ 3840, 2160 }

app_init :: proc() {
    ctx = context
    types_init()
    go_init()
    window_init(WIN_SIZE, WIN_TITLE)
    device_init()

    gui_init()
    // render_init()
    // skybox_init()

    app_update()
    game_destroy()
    app_destroy()
}

app_destroy :: proc() {
    // skybox_destroy()
    // render_destroy()
    gui_destroy()
    device_destroy()
    window_destroy()
    go_destroy()
    types_destroy()
}

app_update :: proc() {
    event := sdl3.Event{}
    global_ubo := GlobalUbo{}
    last_frame := time.now()
    delta_time := f64(0.0)

    camera := new_empty(vec3_back * 9)
    game_init(camera)

    for !quit {
        begin_time := time.now()

        for sdl3.PollEvent(&event) {
            #partial switch event.type {
                case sdl3.EventType.QUIT:
                    quit = true
                    return

                case sdl3.EventType.KEY_DOWN, sdl3.EventType.KEY_UP:
                    gui_input(event.key)
                    game_input(event.key)

                case sdl3.EventType.MOUSE_MOTION:
                    gui_cursor_event(event.motion)

                case sdl3.EventType.MOUSE_BUTTON_DOWN, sdl3.EventType.MOUSE_BUTTON_UP:
                    gui_mouse(event.button)

                case sdl3.EventType.MOUSE_WHEEL:
                    game_scroll(vec2{ event.wheel.x, event.wheel.y })

                case sdl3.EventType.WINDOW_RESIZED:
                    new_size := vec2{ f32(event.window.data1), f32(event.window.data2) }
                    device_create_surface_textures(new_size)
                    game_resize(new_size)
            }
        }

        current_frame := time.now()
        delta_time = time.duration_seconds(time.diff(last_frame, current_frame))
        last_frame = current_frame

        // render_update_lights(&global_ubo, { 0.4, 0.4, 0.4 })
        game_update(delta_time)

        aspect: f32 = window_get_fixed_aspect()
        view_yxz := get_view_yxz(camera.position, get_rotation_euler(camera.id))

        // global_ubo.projection = get_perspective_projection_matrix(FOV, aspect, 0.01, 3000)
        global_ubo.projection = get_orthographic_projection(-aspect, aspect, -1, 1, -1, 1)
        global_ubo.view = view_yxz.view
        global_ubo.inverse_view = view_yxz.inverse_view

        cmd_encoder_descriptor: wgpu.CommandEncoderDescriptor = { label = "Draw command encoder" }
        encoder: wgpu.CommandEncoder = wgpu.DeviceCreateCommandEncoder(device.device, &cmd_encoder_descriptor)

        // TEXTURE VIEW
        surface_texture := wgpu.SurfaceGetCurrentTexture(device.surface)
        defer wgpu.TextureRelease(surface_texture.texture)

        switch surface_texture.status {
        // TODO: reconfigure surface case `SuccessSuboptimal`
        case .SuccessOptimal, .SuccessSuboptimal:
        // case .SuccessSuboptimal:
        //     wgpu.SurfaceConfigure(device.surface, {})

        case .Occluded: continue // the window is minimized or behind another window

        // TODO: use wgpu.SurfaceConfigure for Outdated
        // Outdated: The underlying surface has changed, and therefore the surface configuration is outdated.
        case .Timeout, .Outdated, .Lost:
            INFOF("Cannot acquire the current render texture, status: %v\n", enum_to_string(surface_texture.status))

            if surface_texture.texture != nil {
                wgpu.TextureRelease(surface_texture.texture)
            }
            device_create_surface_textures(WIN_SIZE)
            game_resize(WIN_SIZE)
            return

        case .Error:
            FATALF("Fatal error on the current render texture, status: %v\n", enum_to_string(surface_texture.status))
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

        // skybox_draw(render_pass, device.queue, global_ubo)
        // render_draw(render_pass, device.queue, global_ubo)
        gui_draw(render_pass, device.queue, global_ubo)

        wgpu.RenderPassEncoderEnd(render_pass)
        wgpu.RenderPassEncoderRelease(render_pass)
        wgpu.TextureViewRelease(current_texture_view)
        // ===================================

        command_buffer_descriptor := wgpu.CommandBufferDescriptor{ label = "Draw command buffer" }
        command := wgpu.CommandEncoderFinish(encoder, &command_buffer_descriptor)

        wgpu.RawQueueSubmit(device.queue, 1, &command)

        wgpu.CommandBufferRelease(command)
        wgpu.CommandEncoderRelease(encoder)

        wgpu.SurfacePresent(device.surface)

        async_set_textures()
        free_all(context.temp_allocator)

        if fps_lock {
            elapsed := time.duration_seconds(time.diff(begin_time, time.now()))
            frame_budget := 1.0 / f64(TARGET_FPS)

            if free_time := frame_budget - elapsed; free_time > 0.0 {
                time.sleep(time.Duration(free_time * f64(time.Second)))
            }
        }
    }
}

app_resize:: proc "c"(w: f32, h: f32) {
    context = ctx

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

app_quit :: proc() {
    quit = true
}
