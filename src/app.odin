package main

import "vendor:sdl3"
import "vendor:wgpu"
import "core:time"

WIN_TITLE :: "Force"
FOV :: 90

TARGET_FPS :: 60.0
TARGET_FPS_MINIMIZED :: 5.0
fps_lock: bool = true
quit: bool = false
 //WIN_SIZE :: vec2{ 1024, 1024 }
WIN_SIZE :: vec2{ 1920, 1080 }
// WIN_SIZE :: vec2{ 2560, 1440 }
// WIN_SIZE :: vec2{ 3840, 2160 }

// only used when the device does not report a texture limit; the WebGPU spec
// guarantees maxTextureDimension2D to be at least this, so it is a safe floor
MAX_WIN_SIZE :: 8192

app_init :: proc() {
	ctx = context
	types_init()
	go_init()
	window_init(WIN_SIZE, WIN_TITLE)
	device_init()

	gui_init()
	render_init()
	skybox_init()
	physics_init()

	app_update()
	game_destroy()
	app_destroy()
}

app_destroy :: proc() {
	physics_destroy()
	skybox_destroy()
	render_destroy()
	gui_destroy()
	device_destroy()
	window_destroy()
	go_destroy()
	types_destroy()
}

app_frame_limit :: proc(begin_time: time.Time, target: f64) {
	elapsed := time.duration_seconds(time.diff(begin_time, time.now()))
	free_time := 1.0 / target - elapsed

	if free_time > 0.0 do time.sleep(time.Duration(free_time * f64(time.Second)))
}

app_update :: proc() {
	event := sdl3.Event{}
	global_ubo := GlobalUbo{}
	last_frame := time.now()
	delta_time := f64(0.0)
	reconfigure_surface := false

	camera := new_empty()
	game_init(camera)

	for !quit {
		begin_time := time.now()
		keyboard_new_frame()

		for sdl3.PollEvent(&event) {
			#partial switch event.type {
			case sdl3.EventType.QUIT:
				quit = true
				return

			case sdl3.EventType.KEY_DOWN, sdl3.EventType.KEY_UP:
				keyboard_event(event.key)
				gui_input(event.key)
				game_input(event.key)

			case sdl3.EventType.MOUSE_MOTION:
				gui_cursor_event(event.motion)

			case sdl3.EventType.MOUSE_BUTTON_DOWN, sdl3.EventType.MOUSE_BUTTON_UP:
				gui_mouse(event.button)

			case sdl3.EventType.MOUSE_WHEEL:
				game_scroll(vec2{ event.wheel.x, event.wheel.y })

			case sdl3.EventType.WINDOW_RESIZED:
				app_resize(f32(event.window.data1), f32(event.window.data2))
			}
		}

		if reconfigure_surface {
			reconfigure_surface = false
			size := window_get_size()
			app_resize(size.x, size.y)
		}

		current_frame := time.now()
		delta_time = time.duration_seconds(time.diff(last_frame, current_frame))
		last_frame = current_frame

		render_update_lights(&global_ubo, { 0.4, 0.4, 0.4 })
		game_update(delta_time)
		physics_update()

		aspect: f32 = window_get_fixed_aspect()
		view_yxz := get_view_yxz(camera.position, get_rotation_euler(camera.id))

		global_ubo.projection = get_perspective_projection_matrix(FOV, aspect, 0.01, 3000)
		global_ubo.view = view_yxz.view
		global_ubo.inverse_view = view_yxz.inverse_view

		cmd_encoder_descriptor: wgpu.CommandEncoderDescriptor = { label = "Draw command encoder" }
		encoder: wgpu.CommandEncoder = wgpu.DeviceCreateCommandEncoder(device.device, &cmd_encoder_descriptor)

		// TEXTURE VIEW
		surface_texture := wgpu.SurfaceGetCurrentTexture(device.surface)
		defer wgpu.TextureRelease(surface_texture.texture)

		switch surface_texture.status {
			case .SuccessOptimal:

			// the texture is usable for this frame, but the surface settings no
			// longer fit the window, so they are configured again for the next
			case .SuccessSuboptimal:
				reconfigure_surface = true

			// the window is minimized or behind another window: nothing can be
			// presented, so only the events are polled at the minimized rate
			case .Occluded:
				app_frame_limit(begin_time, TARGET_FPS_MINIMIZED)
				continue

			case .Timeout:
				// nothing was handed over in time for this frame, try the next one
				INFOF("Cannot acquire the current render texture, status: %v\n", enum_to_string(surface_texture.status))
				continue

			case .Outdated:
				// the underlying surface has changed, the configuration is outdated and the acquired texture is unusable.
				INFOF("Cannot acquire the current render texture, status: %v\n", enum_to_string(surface_texture.status))
				reconfigure_surface = true
				continue

			case .Lost:
				// the surface is gone, nothing can be presented anymore
				INFOF("Cannot acquire the current render texture, status: %v\n", enum_to_string(surface_texture.status))
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

		skybox_draw(render_pass, device.queue, global_ubo)
		render_draw(render_pass, device.queue, global_ubo)
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
			app_frame_limit(begin_time, TARGET_FPS)
		}
	}
}

app_resize :: proc "c" (w: f32, h: f32) {
	context = ctx
	max_size := f32(device.max_texture_size)
	win_size := vec2{ w, h }

	if (win_size.x > max_size || win_size.y > max_size) {
		WARNF("Max supported resolution reached: %vx%v\n", win_size.x, win_size.y)
		win_size = vec2{ min(max_size, win_size.x), min(max_size, win_size.y) }
		window_set_size(win_size)
	}

	device_create_surface_textures(win_size)
	game_resize(win_size)
}

app_quit :: proc() {
	quit = true
}
