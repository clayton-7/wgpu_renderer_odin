package main

import "vendor:wgpu"
import tt "vendor:stb/truetype"
import "core:math"
import "core:fmt"
import "core:unicode/utf8"


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
        if g.gui_type == .TEXT {
            is_font = 1

            // do not render empty text
            if len(get_text_component(id).text) == 0 do continue
        }

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

        e := g.last_event
        e.id = id

        if e.focused {
            e.key = key
            g.event_callback(e)
        }
    }
}

gui_create_bind_group :: proc(id: id_t) {
    gui := get_gui(id)
    texture := get_texture(id)

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

    gui_create_bind_group(id)

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

new_text :: proc(font_id: id_t, text: string, event_callback: proc(event: GuiEvent) = nil, color := vec4_one, loc:=#caller_location) -> ^GameObject {
    obj := new_empty()
    txt := new_text_component(obj.id)
    txt.text = text
    txt.atlas_id = font_id

    label := concat_cstring({ "text: (", to_string(obj.id), ") ubo" })

    gui := new_gui(obj.id)
    gui.gui_type = GuiType.TEXT
    gui.ubo = device_create_buffer({ .CopyDst, .Uniform }, size_of(GuiUbo), label=label)
    gui.color = color

    mats := update_matrix(obj.id)
    ui_ubo := GuiUbo{
        model = mats.model,
        is_font = 0,
        color = gui.color,
    }
    wgpu.QueueWriteBuffer(device.queue, gui.ubo, 0, &ui_ubo, size_of(GuiUbo))

    if event_callback != nil do gui.event_callback = event_callback

    texture := get_texture(txt.atlas_id)

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
        label = concat_cstring({ "gui quad: (", to_string(obj.id), ") bind group" }),
        entryCount = len(entries),
        entries = &entries[0],
        layout = gui_bind_group_layouts[1],
    }

    gui.bind_group = wgpu.DeviceCreateBindGroup(device.device, &bind_group_descriptor)

    set_text(obj.id, txt.text)

    return obj
}

set_text :: proc(id: id_t, text: string, loc:=#caller_location) {
    if len(text) == 0 do return

    txt := get_text_component(id)
    txt.text = text

    atlas := get_font_component(txt.atlas_id)
    obj := get_game_obj(id)
    obj.scale.xy = atlas.size.xy

    size := obj.scale.z

    // vertex stride, 6 f32, vec3 pos and vec3 coords
    vertices_data := make([]f32, len(text) * 2 * size_of(vec3), context.temp_allocator)
    indices_data := make([]u32, len(text) * 6, context.temp_allocator)

    x: f32 = 0
    y: f32 = 0

    vertex_index := 0
    idx_offset: u32 = 0
    next_rect_idx: u32 = 0

    begin_idx := rune(atlas.begin_idx)
    rect_indices_data := [?]u32{ 1, 2, 0, 1, 3, 2 }

    for ch, idx in text {
        ch_byte_size := len(fmt.tprintf("%c", ch))

        if ch_byte_size > 4 {
            WARNF("Character `%v`, codepoint: %v, bytes: %v, not supported\n", ch, u32(ch), ch_byte_size)
            continue
        }

        spc_advance := atlas.glyphs[' '].advance

        switch ch {
            case 0: continue // nul
            case '\n': { // new line
                x = 0
                y += spc_advance.y
                continue
            }
            case '\t': { // tab
                x += spc_advance.x * 4
                continue
            }
            case ' ': { // space
                x += spc_advance.x
                continue
            }
        }

        if ch < begin_idx {
            WARNF("Character `%v`, codepoint: %v, from atlas: %v, is invalid\n", ch, u32(ch), atlas.filepath)
            continue
        }

        if int(ch - begin_idx) > len(atlas.glyphs) {
            WARNF("Character `%v`, codepoint: %v, not found in atlas: %v, atlas is too small\n", ch, u32(ch), atlas.filepath)
            continue
        }

        size := atlas.glyphs[ch - begin_idx].size / atlas.size
        uv := atlas.glyphs[ch - begin_idx].uv

        x0 := x
        x1 := x + size.x

        // negative to flip the y value
        y0 := -(y + atlas.glyphs[ch - begin_idx].pos.y / atlas.size.y)
        y1 := y0 - size.y

        glyph_vertices := [4]vec3{
            vec3{ x0, y0, 0 }, // top left
            vec3{ x1, y0, 0 }, // top right
            vec3{ x0, y1, 0 }, // bottom left
            vec3{ x1, y1, 0 }, // bottom right
        }

        glyph_uv := [4]vec3{
            vec3{ uv.x, uv.y, 0 }, // top left
            vec3{ uv.z, uv.y, 0 }, // top right
            vec3{ uv.x, uv.w, 0 }, // bottom left
            vec3{ uv.z, uv.w, 0 }, // bottom right
        }

        for i in 0 ..< len(rect_indices_data) {
            indices_data[idx_offset + u32(i)] = rect_indices_data[i] + next_rect_idx
        }

        offset := 0
        for i in 0 ..< len(glyph_vertices) {
            for w in 0 ..< 3 {
                vertices_data[vertex_index + offset + w] = glyph_vertices[i][w]
                vertices_data[vertex_index + offset + w + 3] = glyph_uv[i][w]
            }

            // stride, 2 vec3
            offset += 6
        }

        x += atlas.glyphs[ch - begin_idx].advance.x

        if idx < len(text) - 1 {
            next_char, _ := utf8.decode_rune_in_string(text[idx + 1:])

            kern := tt.GetCodepointKernAdvance(atlas.font_info, ch, next_char)
            x += math.round(f32(kern) * atlas.scale) / atlas.size.x
        }

        vertex_index += 2 * size_of(vec3)
        idx_offset += len(rect_indices_data)
        next_rect_idx += 4 // 4 sides
    }

    gui := get_gui(id, loc=loc)

    gui.vertex_buffer_size = u64(size_of(f32) * len(vertices_data))
    gui.index_buffer_size = u64(size_of(u32) * len(indices_data))
    gui.index_count = u32(len(indices_data))

    if gui.vertex_buffer != nil {
        wgpu.BufferDestroy(gui.vertex_buffer)
        wgpu.BufferRelease(gui.vertex_buffer)

        wgpu.BufferDestroy(gui.index_buffer)
        wgpu.BufferRelease(gui.index_buffer)
    }

    label := concat_cstring({ "text: (", to_string(id), ") vertex buffer" })

    gui.vertex_buffer = device_create_buffer({ .CopyDst, .Vertex }, gui.vertex_buffer_size, label=label)
    wgpu.QueueWriteBuffer(device.queue, gui.vertex_buffer, 0, &vertices_data[0], uint(gui.vertex_buffer_size))

    label = concat_cstring({ "text: (", to_string(id), ") index buffer" })

    gui.index_buffer = device_create_buffer({ .CopyDst, .Index }, gui.index_buffer_size, label=label)
    wgpu.QueueWriteBuffer(device.queue, gui.index_buffer, 0, &indices_data[0], uint(gui.index_buffer_size))
}

new_font_atlas :: proc(filepath: string, padding: u32, font_size: f32, loc:=#caller_location) -> ^GameObject {
    obj := new_empty()
    atlas := new_font_component(obj.id, loc=loc)

    atlas.font_size = font_size
    atlas.filepath = filepath
    atlas.padding = padding

    // Load the font file
    font_data := read_file_to_u8(filepath, allocator=context.temp_allocator)
    if font_data == nil {
        ERROR("Failed to read font file.", loc=loc)
        return obj
    }

    begin_idx := ' '
    end_idx := '~' + 1

    // HACK: calculate this shit
    atlas.begin_idx = u32(begin_idx)
    atlas.end_idx = u32(end_idx)

    atlas.size.x = 1024
    atlas.size.y = 1024

    atlas.data = make([^]byte, int(atlas.size.x * atlas.size.y))
    // HACK: this should be a map because languages like japanese, chinese has an index too big to do in this way
    atlas.glyphs = make([]FontGlyph, int(end_idx - begin_idx))

    //----------------------------------------------------------------------------

    atlas.font_info = new(tt.fontinfo)
    if !tt.InitFont(atlas.font_info, &font_data[0], 0) {
        ERRORF("Failed to initialize the font: %v", filepath)
        return obj
    }

    scale := tt.ScaleForPixelHeight(atlas.font_info, atlas.font_size)
    atlas.scale = scale

    ascent, descent, line_gap: i32
    tt.GetFontVMetrics(atlas.font_info, &ascent, &descent, &line_gap)
    descent = i32(f32(descent) * scale)
    ascent = i32(f32(ascent) * scale)

    padding: i32 = 2
    col, row: i32 = padding, padding
    glyph_max_height: i32

    for c in begin_idx ..< end_idx {
        glyph := &atlas.glyphs[u32(c) - atlas.begin_idx]

        advance, lsb: i32
        tt.GetCodepointHMetrics(atlas.font_info, c, &advance, &lsb)

        advance = i32(math.round(f32(advance) * scale))
        lsb     = i32(math.round(f32(lsb) * scale))

        pos, size: vec2i32
        bitmap := tt.GetCodepointBitmapSubpixel(atlas.font_info, scale, scale, 0, 0, c, &size.x, &size.y, &pos.x, &pos.y)
        glyph.pos.x = f32(pos.x)
        glyph.pos.y= f32(pos.y)

        glyph_max_height = max(glyph_max_height, size.y)

        if size.x + col > i32(atlas.size.x) {
            col = padding
            row += glyph_max_height + padding

            if row > i32(atlas.size.y) {
                ERRORF("atlas size is too small for the font size, atlas: %v", filepath)
                return obj
            }
        }

        for y in 0 ..< size.y {
            for x in 0 ..< size.x {
                atlas.data[(row + y) * i32(atlas.size.x) + col + x] = bitmap[y * size.x + x]
            }
        }

        glyph.advance = vec2{ f32(advance - lsb) / atlas.size.x, f32(ascent + descent + line_gap + 4) / atlas.size.y }
        glyph.size = vec2{ f32(size.x), f32(size.y) }

        p := vec2{ f32(col) / atlas.size.x, f32(row) / atlas.size.x }
        s := vec2{ f32(size.x) / atlas.size.x, f32(size.y) / atlas.size.y }

        glyph.uv = vec4{
            p.x,
            p.y,
            p.x + s.x,
            p.y + s.y,
        }

        col += size.x + padding
    }

    // to visualize the atlas
    //image.write_jpg("test_atlas.jpg", i32(atlas.size.x), i32(atlas.size.y), 1, &atlas.data[0], 100)

    texture := new_texture(obj.id, loc=loc)
    texture.width = u32(atlas.size.x)
    texture.height = u32(atlas.size.y)
    texture.usage = { .TextureBinding, .CopyDst }

    create_texture(obj.id, .R8Unorm, atlas.data)

    return obj
}
