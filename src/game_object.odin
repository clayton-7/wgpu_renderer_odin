package main

import "core:os"
import "core:encoding/json"
import "core:strings"
import "core:mem"
import "core:math"
import "core:thread"
import "core:sync"

import lmath "core:math/linalg"
import "vendor:wgpu"
import "vendor:stb/image"

GLTF_TYPE :: enum(u32) {
    I8 = 5120,
    U8 = 5121,
    I16 = 5122,
    U16 = 5123,
    U32 = 5125,
    F32 = 5126,
    UVEC2 = 5127,
    UVEC3 = 5128,
    UVEC4 = 5129,
    IVEC2 = 5130,
    IVEC3 = 5131,
    IVEC4 = 5132,
    MAT2 = 5133,
    MAT3 = 5134,
    MAT4 = 5135,
    MAT2x3 = 5136,
    MAT2x4 = 5137,
    MAT3x2 = 5138,
    MAT3x4 = 5139,
}

@(private="file") async_textures: [dynamic]ATexture

go_init :: proc() {
    async_textures.allocator = context.temp_allocator
}

go_destroy :: proc() {
    destroy_model()
    destroy_textures()
    //destroy_texts()
    destroy_fonts()
//     destroy_gui()
//     destroy_light()
}

load_model :: proc() {
}
// pub fn destroy_gui() void {
//     const guis = t.get_guis()
//
//     for (0..guis.len) |i| {
//         const g = guis[i]
//         if (g.vertex_buffer == null) continue
//
//         c.wgpuBufferDestroy(g.vertex_buffer)
//         c.wgpuBufferDestroy(g.index_buffer)
//         c.wgpuBufferDestroy(g.ubo)
//         c.wgpuBufferRelease(g.vertex_buffer)
//         c.wgpuBufferRelease(g.index_buffer)
//         c.wgpuBufferRelease(g.ubo)
//     }
// }
//
// pub fn destroy_light() void {
//     // const lights = t.get_lights()
//     // _ = lights
// }
//
destroy_model :: proc() {
    models := get_models()

    for model in models {
        if (model.vertex_buffer == nil) do continue
        wgpu.BufferDestroy(model.vertex_buffer)
        wgpu.BufferDestroy(model.index_buffer)
        wgpu.BufferDestroy(model.ubo)
        wgpu.BufferRelease(model.vertex_buffer)
        wgpu.BufferRelease(model.index_buffer)
        wgpu.BufferRelease(model.ubo)

        delete(model.vertices)
        delete(model.indices)
    }
}

destroy_textures :: proc() {
    textures := get_textures()

    for t in textures {
        if t.texture == nil do continue

        wgpu.TextureViewRelease(t.texture_view)
        wgpu.TextureDestroy(t.texture)
        wgpu.TextureRelease(t.texture)
        wgpu.SamplerRelease(t.sampler)
    }
}

destroy_fonts :: proc() {
    fonts := get_fonts()

    for f in fonts {
        if f.data == nil do continue

        free(f.data)
        free(f.font_info)
        delete(f.glyphs)
    }
}

destroy_texture :: proc(id: id_t, loc:=#caller_location) {
    t := get_texture(id, loc=loc)

    wgpu.TextureViewRelease(t.texture_view)
    wgpu.TextureDestroy(t.texture)
    wgpu.TextureRelease(t.texture)
    wgpu.SamplerRelease(t.sampler)
}

//
// pub fn destroy_obj(id: t.id_t) void {
//     destroy_model(id)
//     destroy_textures(id)
// }
//
// pub fn destroy_texts() void {
//     const texts = t.get_texts()
//
//     for (0..texts.len) |i| {
//         const txt = texts[i]
//         c_alloc.free(txt.text)
//     }
// }
new_empty :: proc(position := vec3_zero, rotation := vec3_zero, scale := vec3_one, loc := #caller_location) -> ^GameObject{
    id := new_id()
    go := new_game_obj(id, loc=loc)

    go.id = id
    go.enabled = true
    go.position = position
    go.rotation = rotation
    go.scale = scale
    go.parent = INVALID_ID

    return go
}

new_object :: proc(model_filepath: string, material: Material = Material{}, loc := #caller_location) -> ^GameObject {
    obj := new_empty()
    id := obj.id
    mat := new_material(id)

    mat.diffuse_filepath = material.diffuse_filepath
    mat.texture_tilling = material.texture_tilling
    mat.normal_filepath = material.normal_filepath
    mat.normal_strength = clamp(0, 1, material.normal_strength)

    if len(mat.diffuse_filepath) == 0 do mat.diffuse_filepath = "assets/models/1x1.png"
    if len(mat.normal_filepath) == 0 do mat.normal_filepath = "assets/models/1x1.png"
    if mat.texture_tilling == 0 do mat.texture_tilling = 1

    label := concat_cstring({ "game object id: (", to_string(id), ") ubo" })

    model := new_model(id)
    model.filepath = model_filepath
    model.ubo = device_create_buffer({ .CopyDst, .Uniform }, size_of(ModelUbo), label=label)

    mats := update_matrix(id)
    model.model_ubo = ModelUbo{
        model_matrix = mats.model,
        normal_matrix = mats.normal,
        material = ModelMaterial{ texture_tilling = mat.texture_tilling, normal_strength = mat.normal_strength }
    }

    wgpu.QueueWriteBuffer(device.queue, model.ubo, 0, &model.ubo, size_of(ModelUbo))
    load_gltf(id)

    label = concat_cstring({ "game object id: (", to_string(id), ") vertex buffer" })

    model.vertex_buffer = device_create_buffer({ .CopyDst, .Vertex }, model.vertex_buffer_size, label=label)
    wgpu.QueueWriteBuffer(device.queue, model.vertex_buffer, 0, &model.vertices[0], uint(model.vertex_buffer_size))

    label = concat_cstring({ "game object id: (", to_string(id), ") index buffer" })

    model.index_buffer = device_create_buffer({ .CopyDst, .Index }, model.index_buffer_size, label=label)
    wgpu.QueueWriteBuffer(device.queue, model.index_buffer, 0, &model.indices[0], uint(model.index_buffer_size))

    diffuse_tex := load_texture_image(id, mat.diffuse_filepath)
    normal_tex := load_texture_image(id, mat.normal_filepath)

    go_create_bind_group(id, obj, model, diffuse_tex, normal_tex)

    return obj
}

go_create_bind_group :: proc(id: id_t, gui: ^GameObject, model: ^Model, diffuse_tex: ^Texture, normal_tex: ^Texture) {
    entries: [4]wgpu.BindGroupEntry
    entries[0].binding = 0
    entries[0].buffer = model.ubo
    entries[0].size = size_of(ModelUbo)
    entries[1].binding = 1;
    entries[1].textureView = diffuse_tex.texture_view
    entries[2].binding = 2;
    entries[2].textureView = normal_tex.texture_view
    entries[3].binding = 3;
    entries[3].sampler = diffuse_tex.sampler

    bind_group_descriptor := wgpu.BindGroupDescriptor{
        label = concat_cstring({ "game object id: (", to_string(id), ") bind group" }),
        entryCount = len(entries),
        entries = &entries[0],
        layout = render_bind_group_layouts[1],
    }

    model.bind_group = wgpu.DeviceCreateBindGroup(device.device, &bind_group_descriptor)
}

new_light_obj :: proc(light_type: LightType, color: vec4, loc := #caller_location) -> ^GameObject {
    obj := new_empty(loc=loc)
    light := new_light(obj.id, loc=loc)

    light.light_type = u32(light_type)
    light.color = color
    light.direction = get_object_forward_dir(obj.id)

    return obj
}

get_perspective_projection_matrix :: proc (fov_y, aspect, near, far: f32) -> mat4 {
    tan_half_fov_y: f32 = math.tan((fov_y * math.RAD_PER_DEG) / 2)

    projection_matrix := mat4_zero
    projection_matrix[0] = 1.0 / tan_half_fov_y
    projection_matrix[5] = 1.0 / ((1.0 / aspect) * tan_half_fov_y)
    projection_matrix[10] = far / (far - near)
    projection_matrix[11] = 1.0
    projection_matrix[14] = -(far * near) / (far - near)

    // projection_matrix[0, 0] = 1.0 / tan_half_fov_y
    // projection_matrix[1, 1] = 1.0 / ((1.0 / aspect) * tan_half_fov_y)
    // projection_matrix[2, 2] = far / (far - near)
    // projection_matrix[2, 3] = 1.0
    // projection_matrix[3, 2] = -(far * near) / (far - near)

    return projection_matrix
}

get_orthographic_projection :: proc (left, right, top, bottom, near, far: f32) -> mat4 {
    projection_matrix := mat4_identity

    projection_matrix[0] = 2.0 / (right - left)
    projection_matrix[5] = 2.0 / (bottom - top)
    projection_matrix[10] = (far - near)
    projection_matrix[11] = -near / (far - near)
    projection_matrix[12] = -(right + left) / (right - left)
    projection_matrix[13] = -(bottom + top) / (bottom - top)

    // projection_matrix[0, 0] = 2.0 / (right - left)
    // projection_matrix[1, 1] = 2.0 / (bottom - top)
    // projection_matrix[2, 2] = (far - near)
    // projection_matrix[2, 3] = -near / (far - near)
    // projection_matrix[3, 0] = -(right + left) / (right - left)
    // projection_matrix[3, 1] = -(bottom + top) / (bottom - top)

    return projection_matrix
}

get_view_yxz :: proc(position, rotation: vec3) -> struct { view: mat4, inverse_view: mat4 } {
    c3: f32 = math.cos(rotation.z * math.RAD_PER_DEG)
    s3: f32 = math.sin(rotation.z * math.RAD_PER_DEG)
    c2: f32 = math.cos(rotation.x * math.RAD_PER_DEG)
    s2: f32 = math.sin(rotation.x * math.RAD_PER_DEG)
    c1: f32 = math.cos(rotation.y * math.RAD_PER_DEG)
    s1: f32 = math.sin(rotation.y * math.RAD_PER_DEG)

    u: vec3 = { (c1 * c3 + s1 * s2 * s3), (c2 * s3), (c1 * s2 * s3 - c3 * s1) }
    v: vec3 = { (c3 * s1 * s2 - c1 * s3), (c2 * c3), (c1 * c3 * s2 + s1 * s3) }
    w: vec3 = { (c2 * s1), (-s2), (c1 * c2) }

    view_matrix := mat4_identity
    inverse_view_matrix := mat4_identity

    view_matrix[0] = u.x
    view_matrix[4] = u.y
    view_matrix[8] = u.z
    view_matrix[1] = v.x
    view_matrix[5] = v.y
    view_matrix[9] = v.z
    view_matrix[2] = w.x
    view_matrix[6] = w.y
    view_matrix[10] = w.z
    view_matrix[12] = -lmath.dot(u, position)
    view_matrix[13] = -lmath.dot(v, position)
    view_matrix[14] = -lmath.dot(w, position)

    inverse_view_matrix[0] = u.x
    inverse_view_matrix[1] = u.y
    inverse_view_matrix[2] = u.z
    inverse_view_matrix[4] = v.x
    inverse_view_matrix[5] = v.y
    inverse_view_matrix[6] = v.z
    inverse_view_matrix[8] = w.x
    inverse_view_matrix[9] = w.y
    inverse_view_matrix[10] = w.z
    inverse_view_matrix[12] = position.x
    inverse_view_matrix[13] = position.y
    inverse_view_matrix[14] = position.z

    // view_matrix[0, 0] = u.x
    // view_matrix[1, 0] = u.y
    // view_matrix[2, 0] = u.z
    // view_matrix[0, 1] = v.x
    // view_matrix[1, 1] = v.y
    // view_matrix[2, 1] = v.z
    // view_matrix[0, 2] = w.x
    // view_matrix[1, 2] = w.y
    // view_matrix[2, 2] = w.z
    // view_matrix[3, 0] = -lmath.dot(u, position)
    // view_matrix[3, 1] = -lmath.dot(v, position)
    // view_matrix[3, 2] = -lmath.dot(w, position)
    //
    // inverse_view_matrix[0, 0] = u.x
    // inverse_view_matrix[0, 1] = u.y
    // inverse_view_matrix[0, 2] = u.z
    // inverse_view_matrix[1, 0] = v.x
    // inverse_view_matrix[1, 1] = v.y
    // inverse_view_matrix[1, 2] = v.z
    // inverse_view_matrix[2, 0] = w.x
    // inverse_view_matrix[2, 1] = w.y
    // inverse_view_matrix[2, 2] = w.z
    // inverse_view_matrix[3, 0] = position.x
    // inverse_view_matrix[3, 1] = position.y
    // inverse_view_matrix[3, 2] = position.z

    return { view_matrix, inverse_view_matrix }
}

update_matrix :: proc (id: id_t, loc := #caller_location, is_2d := false) -> struct { model: mat4, normal: mat4 } {
    obj := get_game_obj(id, loc)
    if obj == nil { return { mat4_identity, mat4_identity } }

    pos   := obj.position
    rot   := obj.rotation * math.RAD_PER_DEG
    scale := obj.scale

    if is_2d {
        app_size := window_get_window_size()
        aspect := window_get_viewport_aspect()

        pos = pos / vec3{app_size.x, app_size.y, 1}
        pos.x *= aspect

        scale_tmp := scale.z
        scale /= app_size.x / aspect
        scale *= scale_tmp

        rot.z = -rot.z
    }

    c3: f32 = math.cos(rot.z)
    s3: f32 = math.sin(rot.z)
    c2: f32 = math.cos(rot.x)
    s2: f32 = math.sin(rot.x)
    c1: f32 = math.cos(rot.y)
    s1: f32 = math.sin(rot.y)

    model_matrix: mat4 = {
        scale.x * (c1 * c3 + s1 * s2 * s3), scale.x * (c2 * s3), scale.x * (c1 * s2 * s3 - c3 * s1), 0.0,
        scale.y * (c3 * s1 * s2 - c1 * s3), scale.y * (c2 * c3), scale.y * (c1 * c3 * s2 + s1 * s3), 0.0,
        scale.z * (c2 * s1), scale.z * (-s2), scale.z * (c1 * c2), 0.0,
        pos.x, pos.y, pos.z, 1.0
    }

    // normal matrix
    scale = 1.0 / scale

    normal_matrix: mat4 = {
        scale.x * (c1 * c3 + s1 * s2 * s3), scale.x * (c2 * s3), scale.x * (c1 * s2 * s3 - c3 * s1), 0.0,
        scale.y * (c3 * s1 * s2 - c1 * s3), scale.y * (c2 * c3), scale.y * (c1 * c3 * s2 + s1 * s3), 0.0,
        scale.z * (c2 * s1),scale.z * (-s2), scale.z * (c1 * c2), 0.0,
        pos.x, pos.y, pos.z, 1.0
    }

    return { model_matrix, normal_matrix }
}

get_object_forward_dir :: proc(obj_id: id_t) -> vec3 {
    mats := update_matrix(obj_id)
    return vec3{ mats.model[8], mats.model[9], mats.model[10] }
    // return vec3{ mats.model[2, 0], mats.model[2, 1], mats.model[2, 2] }
}

get_object_right_dir :: proc(obj_id: id_t) -> vec3 {
    mats := update_matrix(obj_id)
    return vec3{ mats.model[0], mats.model[1], mats.model[2] }
    // return vec3{ mats.model[0, 0], mats.model[0, 1], mats.model[0, 2] }
}

get_object_up_dir :: proc(obj_id: id_t) -> vec3 {
    mats := update_matrix(obj_id)
    return vec3{ mats.model[4], mats.model[5], mats.model[6] }
    // return vec3{ mats.model[1, 0], mats.model[1, 1], mats.model[1, 2] }
}

set_scale :: proc(obj_id: id_t, scale: vec3) {
    get_game_obj(obj_id).scale *= scale
}

set_parent :: proc(parent_id, child_id: id_t) {
    get_game_obj(child_id).parent = parent_id
}

load_gltf :: proc(id: id_t, loc := #caller_location) {
    model := get_model(id)
    filepath := model.filepath

    json_data_file, success := os.read_entire_file_from_filename(filepath)
    defer delete(json_data_file)

    if !success {
        ERRORF("Cannot load model: %s\n", filepath, loc = loc)
        return
    }

    data, err := json.parse(json_data_file)
    defer json.destroy_value(data)

    if err != .None {
        ERRORF("Cannot load model: %s, error: %v\n", filepath, err, loc = loc)
        return
    }

    json_data := data.(json.Object)
    // DEBUG(json_data)

    gltf_buffer_views := json_data["bufferViews"].(json.Array)

    buffers_length := make([]i64, len(gltf_buffer_views))
    buffers_offset := make([]i64, len(gltf_buffer_views))
    defer delete(buffers_length)
    defer delete(buffers_offset)

    for i := 0; i < len(gltf_buffer_views); i += 1 {
        buffers_length[i] = i64(gltf_buffer_views[i].(json.Object)["byteLength"].(json.Float))
        buffers_offset[i] = 0

        offset := gltf_buffer_views[i].(json.Object)["byteOffset"]

        if offset != nil {
            buffers_offset[i] = i64(offset.(json.Float))
        }
    }

    binary_filepath := strings.trim_suffix(filepath, ".gltf")
    binary_filepath = strings.trim_suffix(binary_filepath, ".glb")

    error: mem.Allocator_Error
    binary_filepath, error = strings.concatenate({binary_filepath, ".bin"})
    defer delete(binary_filepath)

    if error != .None {
        ERRORF("Cannot load model binary: %s\n", binary_filepath, loc = loc)
        return
    }

    binary_data: []u8
    binary_data, success = os.read_entire_file_from_filename(binary_filepath)
    defer delete(binary_data)

    if !success {
        ERRORF("Cannot load model binary: %s\n", binary_filepath, loc = loc)
        return
    }

    meshes := json_data["meshes"].(json.Array)
    primitive := meshes[0].(json.Object)["primitives"].(json.Array)[0].(json.Object)
    attributes := primitive["attributes"].(json.Object)

    accessors := json_data["accessors"].(json.Array)

    if pos_idx, ok := attributes["POSITION"].(json.Float); ok {
        idx := u64(pos_idx)
        pos := transmute([]f32) binary_data[buffers_offset[idx] : buffers_offset[idx] + buffers_length[idx]]

        count := int(accessors[idx].(json.Object)["count"].(json.Float))
        model.vertices = make([]Vertex, count)

        offset: u64 = 0

        for i := 0; i < count; i += 1 {
            model.vertices[i].position = { pos[offset], pos[offset + 1], pos[offset + 2] }
            // DEBUGF("pos[%v]: %v\n", i, model.vertices[i].position)
            offset += 3
        }

        model.vertex_buffer_size = u64(count * size_of(Vertex))
    }

    has_normal := false
    if normal_idx, ok := attributes["NORMAL"].(json.Float); ok {
        has_normal = true

        idx := u64(normal_idx)
        norm := transmute([]f32) binary_data[buffers_offset[idx] : buffers_offset[idx] + buffers_length[idx]]

        count := int(accessors[idx].(json.Object)["count"].(json.Float))
        offset: u64 = 0

        for i := 0; i < count; i += 1 {
            model.vertices[i].normal = { norm[offset], norm[offset + 1], norm[offset + 2] }
            // DEBUGF("normal[%v]: %v\n", i, model.vertices[i].normal)
            offset += 3
        }
    }

    if tex_coord_idx, ok := attributes["TEXCOORD_0"].(json.Float); ok {
        idx := u64(tex_coord_idx)
        tex := transmute([]f32) binary_data[buffers_offset[idx] : buffers_offset[idx] + buffers_length[idx]]

        count := int(accessors[idx].(json.Object)["count"].(json.Float))
        offset: u64 = 0

        for i := 0; i < count; i += 1 {
            model.vertices[i].tex_coord = { tex[offset], tex[offset + 1], 0 }
            // DEBUGF("tex_coord[%v]: %v\n", i, model.vertices[i].tex_coord)
            offset += 2
        }
    }

    if tangent_idx, ok := attributes["TANGENT"].(json.Float); ok {
        idx := u64(tangent_idx)

        if !has_normal {
            WARN("tangent must have normal attribute.", loc = loc)
        }

        tan := transmute([]f32) binary_data[buffers_offset[idx] : buffers_offset[idx] + buffers_length[idx]]

        count := int(accessors[idx].(json.Object)["count"].(json.Float))
        offset: u64 = 0

        for i := 0; i < count; i += 1 {
            model.vertices[i].tangent = { tan[offset], tan[offset + 1], tan[offset + 2] }

            bitangent := lmath.vector_cross3(model.vertices[i].normal, model.vertices[i].tangent)
            model.vertices[i].bitangent = { bitangent[0], bitangent[1], bitangent[2] }
            model.vertices[i].bitangent = model.vertices[i].bitangent * tan[offset + 3]

            // DEBUGF("tangent[%v]: %v\n", i, model.vertices[i].tangent)
            // DEBUGF("bitangent[%v]: %v\n", i, model.vertices[i].bitangent)
            offset += 4
        }
    }

    if indices_idx, ok := primitive["indices"].(json.Float); ok {
        idx := u64(indices_idx)

        type_id := GLTF_TYPE(u32(accessors[idx].(json.Object)["componentType"].(json.Float)))
        type_size: u64 = size_of(u16)

        if (type_id == GLTF_TYPE.U32) {
            type_size = size_of(u32)
        }

        count := int(accessors[idx].(json.Object)["count"].(json.Float))
        model.indices = make([]u32, count)

        if (type_id == GLTF_TYPE.U16) {
            values := transmute([]u16) binary_data[buffers_offset[idx] : buffers_offset[idx] + buffers_length[idx]]

            for i := 0; i < count; i += 1 {
                model.indices[i] = u32(values[i])
                // DEBUGF("index[%v]: %v\n", i, model.indices[i])
            }

        } else if type_id == GLTF_TYPE.U32 {
            model.indices = transmute([]u32) binary_data[buffers_offset[idx] : buffers_offset[idx] + buffers_length[idx]]
            // for i := 0; i < count; i += 1 do DEBUGF("index[%v]: %v\n", i, model.indices[i])
        }

        model.index_buffer_size = u64(count * size_of(u32))
    }
}

create_texture :: proc(id: id_t, texture_format: wgpu.TextureFormat, data: [^]u8, loc := #caller_location) {
    texture := get_texture(id, loc=loc)

    texture_descriptor := wgpu.TextureDescriptor{
        usage = texture.usage,
        dimension = ._2D,
        size = { texture.width, texture.height, 1 },
        format = texture_format,
        mipLevelCount = 1,
        sampleCount = 1,
        viewFormatCount = 0,
    }
    texture.texture = wgpu.DeviceCreateTexture(device.device, &texture_descriptor)

    destination := wgpu.ImageCopyTexture{
        texture = texture.texture,
        mipLevel = 0,
        origin = { 0, 0, 0 },
        aspect = texture.aspect,
    }

    // TODO: Improve this
    channel_count: u32 = 1
    if texture_format != .R8Unorm do channel_count = 4

    image_size := uint(texture.width * texture.height * channel_count)

    source := wgpu.TextureDataLayout{
        offset = 0,
        bytesPerRow = texture_descriptor.size.width * channel_count,
        rowsPerImage = texture_descriptor.size.height,
    }
    wgpu.QueueWriteTexture(device.queue, &destination, data, image_size, &source, &texture_descriptor.size)

    texture_view_descriptor := wgpu.TextureViewDescriptor{
        format = texture_descriptor.format,
        dimension = ._2D,
        baseMipLevel = 0,
        mipLevelCount = 1,
        baseArrayLayer = 0,
        arrayLayerCount = 1,
        aspect = texture.aspect,
    }

    texture.texture_view = wgpu.TextureCreateView(texture.texture, &texture_view_descriptor)

    // Create a sampler
    sampler_descriptor := wgpu.SamplerDescriptor{
        addressModeU = .Repeat,
        addressModeV = .Repeat,
        addressModeW = .Repeat,
        magFilter = .Linear,
        minFilter = .Linear,
        mipmapFilter = .Linear,
        lodMinClamp = 0,
        lodMaxClamp = 0,
        compare = .Undefined,
        maxAnisotropy = 1,
    }

    texture.sampler = wgpu.DeviceCreateSampler(device.device, &sampler_descriptor)
}

load_texture_image :: proc(id: id_t, filepath: string, loc := #caller_location) -> ^Texture {
    texture := new_texture(id, loc=loc)
    texture.filepath = filepath

    if len(filepath) <= 0 {
        ERRORF("texture id(%v), empty filepath\n", id, loc = loc)
        return nil
    }

    width, height, channel: i32

    temp_filepath, err := strings.clone_to_cstring(texture.filepath, context.temp_allocator)

    if err != .None {
        ERRORF("Failed to convert filepath string: %s, error: %v\n", texture.filepath, err, loc = loc)
        return texture
    }

    data := image.load(temp_filepath, &width, &height, &channel, 4)

    if data == nil {
        ERRORF("Failed to load texture image: %s\n", texture.filepath, loc = loc)
        return texture
    }

    texture.width = u32(width)
    texture.height = u32(height)
    texture.usage = { .TextureBinding, .CopyDst }

    create_texture(id, .RGBA8Unorm, data)
    image.image_free(data)

    return texture
}

create_cube_texture_image :: proc(id: id_t, filepaths: [6]string, loc := #caller_location) {
    texture := new_texture(id, loc=loc)
    IMG_COUNT :: 6

    WorkerData:: struct {
        waitgroupdata: ^sync.Wait_Group,
        img_data:      [^]u8,
        filepath:      string,
        width:         i32,
        height:        i32,
        channel:       i32,
        error:         bool
    }

    worker :: proc(t: ^thread.Thread) {
        data := cast(^WorkerData) t.data

        data.img_data = image.load(strings.clone_to_cstring(data.filepath, context.temp_allocator), &data.width, &data.height, &data.channel, 4)

        if data.img_data == nil {
            ERRORF("Failed to load cube texture image on thread: %v\n", t.user_index)
            data.error = true
        }

        sync.wait_group_done(data.waitgroupdata)
    }

    wg: sync.Wait_Group
    sync.wait_group_add(&wg, IMG_COUNT)

    work_data: [IMG_COUNT]WorkerData
    threads: [IMG_COUNT]^thread.Thread

    for i in 0 ..< IMG_COUNT {
        threads[i] = thread.create(worker, .High)

        if threads[i] == nil {
            ERRORF("Cannot create a thread to load the image: %v, error on thread %v\n", threads[i].user_index)
            return
        }

        work_data[i].waitgroupdata = &wg
        work_data[i].filepath = filepaths[i]

        threads[i].user_index = i
        threads[i].data = &work_data[i]
        threads[i].flags = { .Self_Cleanup }

        thread.start(threads[i])
    }

    sync.wait_group_wait(&wg)
    for wd in work_data {
        if wd.error do return
    }


    width, height, _ := work_data[0].width, work_data[0].height, work_data[0].channel

    texture.width = u32(width)
    texture.height = u32(height)

    image_size := int(width * height * 4)
    buffer_size := image_size * IMG_COUNT

    data := make([^]u8, buffer_size, context.temp_allocator)

    for i in 0 ..< IMG_COUNT {
        mem.copy(&data[image_size * i], work_data[i].img_data, image_size)
        image.image_free(work_data[i].img_data)
    }

    texture_descriptor: wgpu.TextureDescriptor
    texture_descriptor.usage = { .CopyDst , .TextureBinding }
    texture_descriptor.dimension = ._2D
    texture_descriptor.size = { texture.width, texture.height, IMG_COUNT }
    texture_descriptor.format = .RGBA8Unorm
    texture_descriptor.mipLevelCount = 1
    texture_descriptor.sampleCount = 1
    texture_descriptor.viewFormatCount = 0
    texture_descriptor.viewFormats = nil
    texture.texture = wgpu.DeviceCreateTexture(device.device, &texture_descriptor)

    destination: wgpu.ImageCopyTexture
    destination.texture = texture.texture
    destination.mipLevel = 0
    destination.origin = { 0, 0, 0 }
    destination.aspect = .All

    source: wgpu.TextureDataLayout
    source.offset = 0
    source.bytesPerRow = texture_descriptor.size.width * 4
    source.rowsPerImage = texture_descriptor.size.height
    wgpu.QueueWriteTexture(device.queue, &destination, data, uint(buffer_size), &source, &texture_descriptor.size)

    texture_view_descriptor: wgpu.TextureViewDescriptor
    texture_view_descriptor.format = texture_descriptor.format
    texture_view_descriptor.dimension = .Cube
    texture_view_descriptor.baseMipLevel = 0
    texture_view_descriptor.mipLevelCount = 1
    texture_view_descriptor.baseArrayLayer = 0
    texture_view_descriptor.arrayLayerCount = 6
    texture_view_descriptor.aspect = .All
    texture.texture_view = wgpu.TextureCreateView(texture.texture, &texture_view_descriptor)

    sampler_descriptor: wgpu.SamplerDescriptor
    sampler_descriptor.addressModeU = .Repeat
    sampler_descriptor.addressModeV = .Repeat
    sampler_descriptor.addressModeW = .Repeat
    sampler_descriptor.magFilter = .Linear
    sampler_descriptor.minFilter = .Linear
    sampler_descriptor.mipmapFilter = .Linear
    sampler_descriptor.lodMinClamp = 0
    sampler_descriptor.lodMaxClamp = 0
    sampler_descriptor.compare = .Undefined
    sampler_descriptor.maxAnisotropy = 1
    texture.sampler = wgpu.DeviceCreateSampler(device.device, &sampler_descriptor)
}

_set_texture :: proc(t : ATexture) {
    filepath := t.filepath
    loc := t.loc
    id := t.id

    if len(filepath) <= 0 {
        ERRORF("texture id(%v), empty filepath\n", id, loc = loc)
        return
    }

    texture: ^Texture

    if is_valid_component(id, Components.TEXTURE) {
        texture = get_texture(id, loc=loc)

        if is_valid_component(id, Components.GUI) {
            gui := get_gui(id, loc=loc)

            wgpu.BindGroupRelease(gui.bind_group)
            gui.bind_group = nil

        } else {
            model := get_model(id, loc=loc)

            wgpu.BindGroupRelease(model.bind_group)
            model.bind_group = nil
        }

        destroy_texture(id, loc=loc)

    } else {
        texture = new_texture(id, loc=loc)
    }

    texture.filepath = filepath
    temp_filepath, err := strings.clone_to_cstring(texture.filepath, context.temp_allocator)

    if err != .None {
        ERRORF("Failed to convert filepath string: %s, error: %v\n", texture.filepath, err, loc = loc)
        return
    }

    width, height, channel: i32
    data := image.load(temp_filepath, &width, &height, &channel, 4)

    if data == nil {
        ERRORF("Failed to load texture image: %s\n", texture.filepath, loc = loc)
        return
    }

    texture.width = u32(width)
    texture.height = u32(height)
    texture.usage = { .TextureBinding, .CopyDst }

    create_texture(id, .RGBA8Unorm, data)
    image.image_free(data)

    if is_valid_component(id, Components.GUI) {
        gui_create_bind_group(id)

    } else {

        model := get_model(id, loc=loc)
        go := get_game_obj(id, loc=loc)

        // HACK: fix this
        go_create_bind_group(id, go, model, texture, texture)
    }
}

async_set_textures :: proc() {
    if wgpu.DevicePoll(device.device, true) do return

    for t in async_textures {
        _set_texture(t)
        pop(&async_textures)
    }
}


// TODO: set more than one texture, eg: diff, normal, spec...
set_texture :: proc(id: id_t, filepath: string, loc:=#caller_location) {
    append(&async_textures, ATexture{ id = id, filepath = filepath, loc = loc })
}
