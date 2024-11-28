package main

import "vendor:wgpu"
import "core:strings"
import "core:math"

@(private="file") pipeline: Pipeline
@(private="file") gui_bind_group_layouts: [2]wgpu.BindGroupLayout
@(private="file") gui_global_buffer: wgpu.Buffer

// @(private="file")
// GuiGlobalUbo :: struct {
//     projection:   mat4,
//     view:         mat4,
//     inverse_view: mat4,
// }

gui_init :: proc() {
    pipeline.shader_filepath = "assets/shaders/gui.wgsl"
    device_get_default_pipeline(&pipeline)
    pipeline.pipeline_descriptor.label = "gui pipeline"

    vertex_attributes := [2]wgpu.VertexAttribute{}
    vertex_attributes[0].shaderLocation = 0
    vertex_attributes[0].format = .Float32x3
    vertex_attributes[0].offset = 0

    vertex_attributes[1].shaderLocation = 1
    vertex_attributes[1].format = .Float32x3
    vertex_attributes[1].offset = size_of(vec3)

    vertex_buffer_layout := wgpu.VertexBufferLayout{
        arrayStride = 2 * size_of(vec3),
        stepMode = .Vertex,
        attributeCount = len(vertex_attributes),
        attributes = &vertex_attributes[0],
    }

    pipeline.pipeline_descriptor.vertex.bufferCount = 1
    pipeline.pipeline_descriptor.vertex.buffers = &vertex_buffer_layout

    global_bind_group_layout_entry: [1]wgpu.BindGroupLayoutEntry
    global_bind_group_layout_entry[0].binding = 0
    global_bind_group_layout_entry[0].visibility = { .Vertex }
    global_bind_group_layout_entry[0].buffer.type = .Uniform
    global_bind_group_layout_entry[0].buffer.minBindingSize = size_of(GlobalUbo)

    gui_bind_group_layout_entry: [3]wgpu.BindGroupLayoutEntry
    gui_bind_group_layout_entry[0].binding = 0
    gui_bind_group_layout_entry[0].visibility = { .Vertex, .Fragment }
    gui_bind_group_layout_entry[0].buffer.type = .Uniform
    gui_bind_group_layout_entry[0].buffer.minBindingSize = size_of(GuiUbo)

    gui_bind_group_layout_entry[1].binding = 1
    gui_bind_group_layout_entry[1].visibility = { .Fragment }
    gui_bind_group_layout_entry[1].texture.sampleType = .Float
    gui_bind_group_layout_entry[1].texture.viewDimension = ._2D

    gui_bind_group_layout_entry[2].binding = 2
    gui_bind_group_layout_entry[2].visibility = { .Fragment }
    gui_bind_group_layout_entry[2].sampler.type = .Filtering

    bind_group_layout_descriptor: [2]wgpu.BindGroupLayoutDescriptor
    bind_group_layout_descriptor[0].label = "gui global bind group layout"
    bind_group_layout_descriptor[0].entryCount = len(global_bind_group_layout_entry)
    bind_group_layout_descriptor[0].entries = &global_bind_group_layout_entry[0]

    bind_group_layout_descriptor[1].label = "gui bind group layout"
    bind_group_layout_descriptor[1].entryCount = len(gui_bind_group_layout_entry)
    bind_group_layout_descriptor[1].entries = &gui_bind_group_layout_entry[0]

    gui_bind_group_layouts[0] = wgpu.DeviceCreateBindGroupLayout(device.device, &bind_group_layout_descriptor[0])
    gui_bind_group_layouts[1] = wgpu.DeviceCreateBindGroupLayout(device.device, &bind_group_layout_descriptor[1])

    gui_global_buffer = device_create_buffer({ .CopyDst, .Uniform }, size_of(GlobalUbo), label="gui global buffer")

    // BIND GROUP
    binding: [1]wgpu.BindGroupEntry
    binding[0].binding = 0
    binding[0].offset = 0
    binding[0].buffer = gui_global_buffer
    binding[0].size = size_of(GlobalUbo)

    bind_group_descriptor := wgpu.BindGroupDescriptor{
        label = "gui bind group descriptor",
        layout = gui_bind_group_layouts[0],
        entryCount = len(binding),
        entries = &binding[0],
    }

    pipeline.bind_group = wgpu.DeviceCreateBindGroup(device.device, &bind_group_descriptor)

    // PIPELINE
    pipeline.layout_descriptor = wgpu.PipelineLayoutDescriptor{
        label = "gui render pipeline layout",
        bindGroupLayoutCount = len(gui_bind_group_layouts),
        bindGroupLayouts = &gui_bind_group_layouts[0],
    }

    pipeline.pipeline_descriptor.layout = wgpu.DeviceCreatePipelineLayout(device.device, &pipeline.layout_descriptor)
    pipeline.pipeline_handle = wgpu.DeviceCreateRenderPipeline(device.device, &pipeline.pipeline_descriptor)
}

gui_destroy :: proc() {
    for layout in gui_bind_group_layouts {
        wgpu.BindGroupLayoutRelease(layout)
    }

    wgpu.RenderPipelineRelease(pipeline.pipeline_handle)
    wgpu.BufferDestroy(gui_global_buffer)
    wgpu.BufferRelease(gui_global_buffer)
}

gui_draw :: proc(render_pass: wgpu.RenderPassEncoder, queue: wgpu.Queue, global_ubo: GlobalUbo) {
    wgpu.RenderPassEncoderSetPipeline(render_pass, pipeline.pipeline_handle)
    wgpu.RenderPassEncoderSetBindGroup(render_pass, 0, pipeline.bind_group)

    aspect := window_get_viewport_aspect()
    ortho_proj := get_orthographic_projection(-aspect, aspect, -1, 1, -1, 1)

    // ubo := global_ubo
    ubo := GlobalUbo{}
    ubo.projection = ortho_proj
    ubo.view = mat4_identity

    // TODO: make an ubo struct for guis
    wgpu.QueueWriteBuffer(queue, gui_global_buffer, 0, &ubo, size_of(GlobalUbo))

    guis := get_guis()
    for g, i in guis {
        id := get_obj_id_from_comp_id(i, Components.GUI)

        if g.ubo == nil do return

        go := get_game_obj(id)
        if !go.enabled do continue

        model_matrix := update_matrix(id, is_2d = true).model

        is_font : u32 = 0
        if g.gui_type == .TEXT do is_font = 1

        ui_ubo := GuiUbo{
            model = model_matrix,
            is_font = is_font,
            color = g.color,
        }

        wgpu.RenderPassEncoderSetBindGroup(render_pass, 1, g.bind_group)
        wgpu.QueueWriteBuffer(queue, g.ubo, 0, &ui_ubo, size_of(GuiUbo))

        wgpu.RenderPassEncoderSetVertexBuffer(render_pass, 0, g.vertex_buffer, 0, g.vertex_buffer_size)
        wgpu.RenderPassEncoderSetIndexBuffer(render_pass, g.index_buffer, .Uint32, 0, g.index_buffer_size)
        wgpu.RenderPassEncoderDrawIndexed(render_pass, g.index_count, 1, 0, 0, 0)
    }
}

gui_cursor_event :: proc(pos: vec2) {
    guis := get_guis()

    for &g, i in guis {
        if g.event_callback == nil do continue

        id := get_obj_id_from_comp_id(i, Components.GUI)
        obj := get_game_obj(id)

        e := g.last_event
        e.id = id
        last_event_hover := e.hovering

        e.released = false
        e.hovering = false
        on_hover := is_mouse_on_gui(obj)

        if last_event_hover && !on_hover {
            e.hovering = false
            g.last_event = e
            g.event_callback(e)
            return
        }

        if !last_event_hover && on_hover {
            e.hovering = true
            g.last_event = e
            g.event_callback(e)
            return
        }
    }
}

gui_mouse :: proc(btn: MouseButton, state: State, mod: Mod) {
    guis := get_guis()

    for &g, i in guis {
        if g.event_callback == nil do continue

        id := get_obj_id_from_comp_id(i, Components.GUI)
        obj := get_game_obj(id)

        e := g.last_event
        e.id = id

        if is_mouse_on_gui(obj) {
            if btn == .LEFT && state == .PRESS {
                e.holding = true
                e.pressed = true
                e.focused = true
                e.released = false
                e.toggle = !e.toggle
            }

        } else {
            if btn == .LEFT && state == .PRESS do e.focused = false
        }

        if btn == .LEFT && state == .RELEASE {
            e.released = true
            e.pressed = false
            e.holding = false
        }

        g.last_event = e
        g.event_callback(e)
    }
}

gui_input :: proc(key: Key, scancode: i32, state: State, mod: Mod) {
    guis := get_guis()

    for &g, i in guis {
        if g.event_callback == nil do continue

        id := get_obj_id_from_comp_id(i, Components.GUI)
        obj := get_game_obj(id)

        e := g.last_event
        e.id = id

        if e.focused {
            e.key = key
            g.event_callback(e)
        }
    }
}

gui_create_bind_group :: proc(id: id_t, gui: ^Gui, texture: ^Texture) {
    entries: [3]wgpu.BindGroupEntry
    entries[0].binding = 0
    entries[0].buffer = gui.ubo
    entries[0].size = size_of(GuiUbo)

    // TEXTURE
    entries[1].textureView = texture.texture_view;
    entries[1].binding = 1

    // SAMPLER
    entries[2].sampler = texture.sampler
    entries[2].binding = 2

    bind_group_descriptor := wgpu.BindGroupDescriptor{
        label = concat_cstring({ "gui quad: (", to_string(id), ") bind group" }),
        entryCount = len(entries),
        entries = &entries[0],
        layout = gui_bind_group_layouts[1],
    }

    gui.bind_group = wgpu.DeviceCreateBindGroup(device.device, &bind_group_descriptor)
}

gui_create_quad :: proc(texture_filepath: string = "", event_callback: proc(event: GuiEvent) = nil, color := vec4_one) -> ^GameObject {
    obj := new_empty()
    id := obj.id

    label := concat_cstring({ "gui quad: (", to_string(id), ") ubo" })

    gui := new_gui(id)
    gui.gui_type = GuiType.IMAGE
    gui.ubo = device_create_buffer({ .CopyDst, .Uniform }, size_of(GuiUbo), label=label)
    gui.color = color

    mats := update_matrix(id)
    ui_ubo := GuiUbo{
        model = mats.model,
        is_font = 0,
        color = gui.color,
    }
    wgpu.QueueWriteBuffer(device.queue, gui.ubo, 0, &ui_ubo, size_of(GuiUbo))

    if event_callback != nil do gui.event_callback = event_callback

    vertex_data := [?]f32{
        // pos         uv
       -1,  1, 0,    0, 1, 0,
        1,  1, 0,    1, 1, 0,
       -1, -1, 0,    0, 0, 0,
        1, -1, 0,    1, 0, 0,
    }

    index_data  := [?]u32{ 1, 2, 0, 1, 3, 2 }

    gui.vertex_buffer_size = size_of(f32) * len(vertex_data)
    gui.index_buffer_size = size_of(u32) * len(index_data)
    gui.index_count = len(index_data)

    label = concat_cstring({ "gui quad: (", to_string(id), ") vertex buffer" })

    gui.vertex_buffer = device_create_buffer({ .CopyDst, .Vertex }, gui.vertex_buffer_size, label=label)
    wgpu.QueueWriteBuffer(device.queue, gui.vertex_buffer, 0, &vertex_data, uint(gui.vertex_buffer_size))

    label = concat_cstring({ "gui quad: (", to_string(id), ") index buffer" })

    gui.index_buffer = device_create_buffer({ .CopyDst, .Index }, gui.index_buffer_size, label=label)
    wgpu.QueueWriteBuffer(device.queue, gui.index_buffer, 0, &index_data, uint(gui.index_buffer_size))

    filepath := texture_filepath
    if len(filepath) == 0 do filepath = "assets/models/1x1.png"

    texture := load_texture_image(id, filepath)
    obj.scale.x = f32(texture.width)
    obj.scale.y = f32(texture.height)

    gui_create_bind_group(id, gui, texture)

    return obj
}

is_point_in_polygon :: proc(point: vec2, polygon: []vec2) -> bool {
    inside := false
    vert_count := len(polygon)

    for i := 0; i < vert_count; i += 1 {
        j := (i - 1 + vert_count) % vert_count

        a := (polygon[i].y > point.y) != (polygon[j].y > point.y)

        if polygon[j].y != polygon[i].y {
            b := point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x

            if a && b do inside = !inside

        } else {
            if point.y == polygon[i].y && (point.x >= min(polygon[i].x, polygon[j].x)) && (point.x <= max(polygon[i].x, polygon[j].x)) do return true
        }
    }

    return inside
}

is_mouse_on_gui :: proc(obj: ^GameObject) -> bool {
    if !is_cursor_enabled() do return false

    view := window_get_fixed_aspect_viewport()
    app_size := window_get_window_size()

    cursor := (((window_get_cursor_position_f32() / vec2{ view.w, view.h }) - 0.5) * 2) * app_size

    // setting cursor position to be the same independent screen size
    if view.x > 0 {
        cursor.x = ((((window_get_cursor_position_f32().x - view.x) / view.w -0.5) * 2) * app_size.x)
        cursor.y = -cursor.y
    } else {
        cursor.y = -((((window_get_cursor_position_f32().y - view.y) / view.h -0.5) * 2) * app_size.y)
    }

    corners: []vec2
    corners = make([]vec2, 4, allocator = context.temp_allocator)

    pos := vec2{ obj.position.x , obj.position.y }

    size := obj.scale * obj.scale.z
    rot := -obj.rotation.z

    // points
    corners[0] = vec2{ -size.x,  size.y } // tl
    corners[1] = vec2{  size.x,  size.y } // tr
    corners[2] = vec2{  size.x, -size.y } // br
    corners[3] = vec2{ -size.x, -size.y } // bl

    // rotate
    for i := 0; i < len(corners); i += 1 {
        x := corners[i].x
        y := corners[i].y
        angle := rot * math.RAD_PER_DEG

        corners[i].x = x * math.cos(angle) - y * math.sin(angle)
        corners[i].y = x * math.sin(angle) + y * math.cos(angle)
    }

    // position
    corners[0] += pos
    corners[1] += pos
    corners[2] += pos
    corners[3] += pos

    return is_point_in_polygon(cursor, corners)
}
