package main

import "vendor:wgpu"
import "vendor:sdl3"
import tt "vendor:stb/truetype"
import "base:runtime"
import "core:sort"
import "core:math"

// GLOBALS ===================================================
window : ^sdl3.Window = nil
device : Device
render_textures : RenderTextures
render_bind_group_layouts: [2]wgpu.BindGroupLayout
ctx: runtime.Context
// =--------==================================================

id_t :: distinct u128

vec2 :: distinct [2]f32
vec3 :: distinct [3]f32
vec4 :: distinct [4]f32
quat :: quaternion128

vec2i32 :: distinct [2]i32
vec3i32 :: distinct [3]i32
vec4i32 :: distinct [4]i32

vec2f64 :: distinct [2]f64
vec3f64 :: distinct [3]f64
vec4f64 :: distinct [4]f64

@(private="file") _vec_2 :: proc(x: f32 = 0, y: f32 = 0) -> vec2 { return vec2{ x, y } }

@(private="file") _vec_3a :: proc(x: f32 = 0, y: f32 = 0, z: f32 = 0) -> vec3 { return vec3{ x, y, z } }
@(private="file") _vec_3b :: proc(v: vec2) -> vec3 { return vec3{ v.x, v.y, 0 } }

@(private="file") _vec_4a :: proc(x: f32 = 0, y: f32 = 0, z: f32 = 0, w: f32 = 0) -> vec4 { return vec4{ x, y, z, w } }
@(private="file") _vec_4b :: proc(v: vec2, v1: vec2) -> vec4 { return vec4{ v.x, v.y, v1.x, v1.y } }
@(private="file") _vec_4c :: proc(v: vec2) -> vec4 { return vec4{ v.x, v.y, 0, 0 } }
@(private="file") _vec_4d :: proc(v: vec3) -> vec4 { return vec4{ v.x, v.y, v.z, 0 } }

vec_3 :: proc{ _vec_3a, _vec_3b }
vec_4 :: proc{ _vec_4a, _vec_4b, _vec_4c, _vec_4d }

mat2 :: distinct #row_major matrix [2, 2]f32
mat3 :: distinct #row_major matrix [3, 3]f32
mat4 :: distinct #row_major matrix [4, 4]f32

mat2f64 :: distinct [4]f64
mat3f64 :: distinct [9]f64
mat4f64 :: distinct [16]f64

vec2_one :: vec2{ 1, 1 }
vec3_one :: vec3{ 1, 1, 1 }
vec4_one :: vec4{ 1, 1, 1, 1 }

vec2_zero :: vec2{ 0, 0 }
vec3_zero :: vec3{ 0, 0, 0 }
vec4_zero :: vec4{ 0, 0, 0, 0 }

vec2_up :: vec2{ 0, 1 }
vec3_up :: vec3{ 0, 1, 0 }
vec4_up :: vec4{ 0, 1, 0, 0 }

vec2_right :: vec2{ 1, 0 }
vec3_right :: vec3{ 1, 0, 0 }
vec4_right :: vec4{ 1, 0, 0, 0 }

vec2_left :: vec2{ -1, 0 }
vec3_left :: vec3{ -1, 0, 0 }
vec4_left :: vec4{ -1, 0, 0, 0 }

vec3_forward :: vec3{ 0, 0, 1 }
vec4_forward :: vec4{ 0, 0, 1, 0 }

vec3_back :: vec3{ 0, 0, -1 }
vec4_back :: vec4{ 0, 0, -1, 0 }

vec2_down :: vec2{ 0, -1 }
vec3_down :: vec3{ 0, -1, 0 }
vec4_down :: vec4{ 0, -1, 0, 0 }

quat_identity :: quaternion(w = 1, x = 0, y = 0, z = 0)

mat2_identity :: mat2{ 1, 0, 0, 1 }
mat3_identity :: mat3{ 1, 0, 0, 0, 1, 0, 0, 0, 1 }
mat4_identity :: mat4{ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }

mat2_zero :: mat2{}
mat3_zero :: mat3{}
mat4_zero :: mat4{}

vec2f64_one :: vec2f64{ 1, 1 }
vec3f64_one :: vec3f64{ 1, 1, 1 }
vec4f64_one :: vec4f64{ 1, 1, 1, 1 }

vec2f64_zero :: vec2f64{ 0, 0 }
vec3f64_zero :: vec3f64{ 0, 0, 0 }
vec4f64_zero :: vec4f64{ 0, 0, 0, 0 }

vec2f64_up :: vec2f64{ 0, 1 }
vec3f64_up :: vec3f64{ 0, 1, 0 }
vec4f64_up :: vec4f64{ 0, 1, 0, 0 }

vec2f64_right :: vec2f64{ 1, 0 }
vec3f64_right :: vec3f64{ 1, 0, 0 }
vec4f64_right :: vec4f64{ 1, 0, 0, 0 }

vec2f64_left :: vec2f64{ -1, 0 }
vec3f64_left :: vec3f64{ -1, 0, 0 }
vec4f64_left :: vec4f64{ -1, 0, 0, 0 }

vec3f64_forward :: vec3f64{ 0, 0, 1 }
vec4f64_forward :: vec4f64{ 0, 0, 1, 0 }

vec3f64_back :: vec3f64{ 0, 0, -1 }
vec4f64_back :: vec4f64{ 0, 0, -1, 0 }

vec2f64_down :: vec2f64{ 0, -1 }
vec3f64_down :: vec3f64{ 0, -1, 0 }
vec4f64_down :: vec4f64{ 0, -1, 0, 0 }

mat2f64_identity :: mat2f64{ 1, 0, 0, 1 }
mat3f64_identity :: mat3f64{ 1, 0, 0, 0, 1, 0, 0, 0, 1 }
mat4f64_identity :: mat4f64{ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }

mat2f64_zero :: mat2f64{}
mat3f64_zero :: mat3f64{}
mat4f64_zero :: mat4f64{}

quat_to_mat4 :: proc(q: quat) -> mat4 {
    w, x, y, z := q.w, q.x, q.y, q.z

    m00 := 1 - 2 * y * y - 2 * z * z
    m01 := 2 * x * y + 2 * z * w
    m02 := 2 * x * z - 2 * y * w

    m10 := 2 * x * y - 2 * z * w
    m11 := 1 - 2 * x * x - 2 * z * z
    m12 := 2 * y * z + 2 * x * w

    m20 := 2 * x * z + 2 * y * w
    m21 := 2 * y * z - 2 * x * w
    m22 := 1 - 2 * x * x - 2 * y * y

    return mat4{
        m00, m01, m02, 0,
        m10, m11, m12, 0,
        m20, m21, m22, 0,
        0,   0,   0,   1,
    }
}

quat_to_mat3 :: proc(q: quat) -> mat3 {
    w, x, y, z := q.w, q.x, q.y, q.z

    m00 := 1 - 2 * y * y - 2 * z * z
    m01 := 2 * x * y + 2 * z * w

    m10 := 2 * x * y - 2 * z * w
    m11 := 1 - 2 * x * x - 2 * z * z

    return mat3{
        m00, m01,  0,
        m10, m11,  0,
        0,   0,    1
    }
}

vec3_to_quat :: proc(v: vec3) -> quat {
    rx := v.x * math.RAD_PER_DEG * 0.5
    ry := v.y * math.RAD_PER_DEG * 0.5
    rz := v.z * math.RAD_PER_DEG * 0.5

    qx := quaternion(w = math.cos(rx), x = math.sin(rx), y = 0, z = 0)
    qy := quaternion(w = math.cos(ry), x = 0, y = math.sin(ry), z = 0)
    qz := quaternion(w = math.cos(rz), x = 0, y = 0, z = math.sin(rz))

    // YXZ order: R = Ry(yaw) * Rx(pitch) * Rz(roll)
    return qy * qx * qz
}

quat_to_vec3 :: proc(q_in: quat) -> vec3 {
    q := q_in

    // Normalize in case the input drifted from unit length.
    n := math.sqrt(q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z)
    if n == 0 do return vec3_zero

    q.w /= n
    q.x /= n
    q.y /= n
    q.z /= n

    // quat_to_mat4 returns the transpose of the rotation matrix, so
    // m[row, col] == R[col, row].
    m := quat_to_mat4(q)
    e := vec3_zero

    // Pitch (rotation around X)
    sinp := -m[2, 1]
    sinp = max(-1.0, min(1.0, sinp))

    if sinp >= 0.9999 || sinp <= -0.9999 {
        // Gimbal lock: pitch is ±90°, so fix yaw = 0 and fold it into roll.
        e.x = math.copy_sign(math.PI / 2.0, sinp)
        e.y = 0.0
        e.z = math.atan2(-m[1, 0], m[0, 0])
    } else {
        e.x = math.asin(sinp)
        e.y = math.atan2(m[2, 0], m[2, 2]) // Yaw (rotation around Y)
        e.z = math.atan2(m[0, 1], m[1, 1]) // Roll (rotation around Z)
    }

    return e * math.DEG_PER_RAD
}

vec3_to_mat3 :: proc(v: vec3) -> mat3 {
    c1 := math.cos(-v.x)
    c2 := math.cos(-v.y)
    c3 := math.cos(-v.z)
    s1 := math.sin(-v.x)
    s2 := math.sin(-v.y)
    s3 := math.sin(-v.z)

    m: mat3
    m[0, 0] = c2 * c3
    m[1, 0] =-c1 * s3 + s1 * s2 * c3
    m[2, 0] = s1 * s3 + c1 * s2 * c3
    m[0, 1] = c2 * s3
    m[1, 1] = c1 * c3 + s1 * s2 * s3
    m[2, 1] =-s1 * c3 + c1 * s2 * s3
    m[0, 2] =-s2
    m[1, 2] = s1 * c2
    m[2, 2] = c1 * c2
    return m
}

mat3_to_vec3 :: proc(m: mat3) -> vec3 {
    T1 := math.atan2(m[1, 2], m[2, 2])
    C2 := math.sqrt(m[0, 0]*m[0, 0] + m[0, 1]*m[0, 1])
    T2 := math.atan2(-m[0, 2], C2)
    S1 := math.sin(T1)
    C1 := math.cos(T1)
    T3 := math.atan2(S1*m[2, 0] - C1*m[1, 0], C1*m[1, 1] - S1*m[2, 1])
    return vec3{ -T1, -T2, -T3 }
}

ModelMaterial :: struct #packed {
    diffuse:         vec3,
    pad1:            f32,

    ambient:         vec3,
    pad2:            f32,

    specular:        vec3,
    texture_tilling: f32,
    normal_strength: f32,

    pad4:            [12]u8,
}

ModelUbo :: struct {
    model_matrix:  mat4,
    normal_matrix: mat4,
    material:      ModelMaterial,
}

LightType :: enum(u32) {
    Directional = 0,
    Point       = 1,
    Spot        = 2,
}

Light :: struct {
    color:      vec4,
    direction:  vec3,
    position:   vec3,
    light_type: LightType ,
    pad:        [12]u8
}

GlobalUbo :: struct {
    projection:    mat4,
    view:          mat4,
    inverse_view:  mat4,
    ambient_light: vec4,
    lights:        [30]Light,
    light_count:   u32,
}

GuiUbo :: struct {
    model:      mat4,
    view:       mat4,
    color:      vec4,
    is_font:    u32,
    pad:        vec3
}

ATexture :: struct {
    id: id_t,
    filepath: string,
    loc: runtime.Source_Code_Location,
}

Pipeline :: struct {
    vertex_attributes:             [2]wgpu.VertexAttribute,
    vertex_buffer_layout:          wgpu.VertexBufferLayout,
    pipeline_descriptor:           wgpu.RenderPipelineDescriptor,
    shader_code_descriptor:        wgpu.ShaderSourceWGSL,
    shader_descriptor:             wgpu.ShaderModuleDescriptor,
    shader_module:                 wgpu.ShaderModule,
    fragment_state:                wgpu.FragmentState,
    blend_state:                   wgpu.BlendState,
    color_target:                  wgpu.ColorTargetState,
    depth_texture_format:          wgpu.TextureFormat,
    depth_stencil_state:           wgpu.DepthStencilState,
    depth_texture_descriptor:      wgpu.TextureDescriptor,
    depth_texture_view_descriptor: wgpu.TextureViewDescriptor,
    binding_layout:                wgpu.BindGroupLayoutEntry,
    shader_filepath:               string,
    buffers:                       [2]wgpu.Buffer,
    layout_descriptor:             wgpu.PipelineLayoutDescriptor,
    pipeline_handle:               wgpu.RenderPipeline,
    bind_group_layout_descriptor:  wgpu.BindGroupLayoutDescriptor,
    bind_group:                    wgpu.BindGroup,
    bind_group_layout:             wgpu.BindGroupLayout,
}

Vertex :: struct {
    position:  vec3,
    normal:    vec3,
    tex_coord: vec3,
    tangent:   vec3,
    bitangent: vec3,
}

Device :: struct {
    surface  : wgpu.Surface,
    adapter  : wgpu.Adapter,
    device   : wgpu.Device,
    queue    : wgpu.Queue,
}

RenderTextures :: struct {
    view_format        : wgpu.TextureFormat,
    depth_texture      : wgpu.Texture,
    depth_texture_view : wgpu.TextureView,
}

Material :: struct {
    diffuse_filepath:  string,
    normal_filepath:   string,
    specular_filepath: string,

    normal_strength: f32,
    texture_tilling: f32,
}

Texture :: struct {
    width:    u32,
    height:   u32,
    channels: u32,
    tilling:  f32,
    filepath: string,

    texture:      wgpu.Texture,
    sampler:      wgpu.Sampler,
    texture_view: wgpu.TextureView,
    aspect:       wgpu.TextureAspect,
    usage:        wgpu.TextureUsageFlags,
    format:       wgpu.TextureFormat,
}

GuiType :: enum {
    EMPTY,
    IMAGE,
    BUTTON,
    TEXT,
    ATLAS,
    GAME_OBJECT,
}

GuiEvent :: struct {
    id:       id_t,
    pressed:  bool,
    released: bool,
    holding:  bool,
    hovering: bool,
    toggle:   bool,
    focused:  bool,
    key:      sdl3.Keycode,
}

Gui :: struct {
    gui_type:  GuiType,

    ubo:           wgpu.Buffer,
    vertex_buffer: wgpu.Buffer,
    index_buffer:  wgpu.Buffer,
    bind_group:    wgpu.BindGroup,

    index_buffer_size:  u64,
    vertex_buffer_size: u64,
    index_count:        u32,

    color:          vec4,
    last_event:     GuiEvent,
    event_callback: proc(event: GuiEvent),
}

Text :: struct {
    text:     string,
    atlas_id: id_t,
    color:    vec4,
}

FontAtlas :: struct {
    filepath:  string,
    font_size: f32,
    padding:   u32,
    size:      vec2,

    begin_idx: u32,
    end_idx:   u32,

    scale:     f32,
    data:      [^]byte, // rasterized font atlas
    font_data: [^]byte, // raw ttf data; stb_truetype keeps a pointer into it
    glyphs:    []FontGlyph,
    font_info: ^tt.fontinfo
}

FontGlyph :: struct {
    size:         vec2,
    pos:     vec2,
    advance:      vec2,
    uv:           vec4,
}

Model :: struct {
    vertices: []Vertex,
    indices:  []u32,

    filepath:  string,
    model_ubo: ModelUbo,
    ubo:       wgpu.Buffer,

    vertex_buffer_size: u64,
    index_buffer_size:  u64,
    vertex_buffer:      wgpu.Buffer,
    index_buffer:       wgpu.Buffer,
    bind_group:         wgpu.BindGroup,
}

GameObject :: struct {
    id:         id_t,
    position:   vec3,
    rotation:   quat, // quaternion; use set_rotation_euler/get_rotation_euler for Euler angles
    scale:      vec3,
    parent:     id_t,
    childs:     [dynamic]id_t,
    enabled:    bool,
}

INVALID_ID :: ~id_t(1)

// TODO: PUT THIS VARIABLES IN A STRUCT
@(private="file") game_objects: []GameObject
@(private="file") textures: []Texture
@(private="file") guis: []Gui
@(private="file") models: []Model
@(private="file") materials: []Material
@(private="file") lights: []Light
@(private="file") texts: []Text
@(private="file") fonts: []FontAtlas

@(private="file") comp_id_from_obj_id: [len(Components)][]id_t
@(private="file") obj_id_from_comp_id: [len(Components)][]id_t

@(private="file") sorted_gui_indices: []vec2

get_game_objs :: proc() -> []GameObject { return game_objects }
get_textures :: proc() -> []Texture { return textures }
get_guis :: proc() -> []Gui { return guis }
get_sorted_gui_indices :: proc() -> []vec2 { return sorted_gui_indices }
get_models :: proc() -> []Model { return models }
get_lights :: proc() -> []Light { return lights }
get_texts :: proc() -> []Text { return texts }
get_fonts :: proc() -> []FontAtlas { return fonts }

GAME_OBJ_MAX :: 256
TEXTURE_MAX :: 256
GUI_MAX :: 256
MODEL_MAX :: 256
MATERIALS_MAX :: 256
LIGHT_MAX :: 32
TEXT_MAX :: 256
FONT_ATLAS_MAX :: 256

Components :: enum {
    GAME_OBJ,
    GUI,
    MODEL,
    TEXTURE,
    MATERIAL,
    LIGHT,
    TEXT,
    FONT_ATLAS,
}

types_init :: proc () {
    game_objects = make([]GameObject, GAME_OBJ_MAX)
    textures = make([]Texture, TEXTURE_MAX)
    guis = make([]Gui, GUI_MAX)
    models = make([]Model, MODEL_MAX)
    materials = make([]Material, MATERIALS_MAX)
    lights = make([]Light, LIGHT_MAX)
    texts = make([]Text, LIGHT_MAX)
    fonts = make([]FontAtlas, FONT_ATLAS_MAX)

    sorted_gui_indices = make([]vec2, GUI_MAX)

    for &g in sorted_gui_indices {
        g.x = -1
    }

    for i in 0 ..< len(comp_id_from_obj_id) {
        comp_id_from_obj_id[i] = make([]id_t, GAME_OBJ_MAX)
        obj_id_from_comp_id[i] = make([]id_t, GAME_OBJ_MAX)

        for &m in comp_id_from_obj_id[i] {
            m = INVALID_ID

        }

        for &m in obj_id_from_comp_id[i] {
            m = INVALID_ID
        }
    }
}

types_destroy :: proc() {
    for i in 0 ..< len(comp_id_from_obj_id) {
        delete(comp_id_from_obj_id[i])
        delete(obj_id_from_comp_id[i])
    }

    delete(game_objects)
    delete(textures)
    delete(guis)
    delete(models)
    delete(materials)
    delete(lights)
    delete(texts)
    delete(fonts)
    delete(sorted_gui_indices)
}

get_obj_id_from_comp_id :: proc(component_id: int , component_type: Components) -> id_t {
    return obj_id_from_comp_id[component_type][component_id]
}

get_comp_id_from_obj_id :: proc(game_object_id: int, component_type: Components) -> id_t {
    return comp_id_from_obj_id[component_type][game_object_id]
}

search_empty_spot :: proc (array: []id_t, loc := #caller_location) -> id_t {
    for i in 0 ..< len(array) {
        if (array[i] == INVALID_ID) do return id_t(i)
    }

    return INVALID_ID
}

new_id :: proc() -> id_t { return search_empty_spot(comp_id_from_obj_id[Components.GAME_OBJ]) }

set_id :: proc(obj_id: id_t, array_id: u64, loc := #caller_location) -> id_t {
    comp_id := search_empty_spot(obj_id_from_comp_id[array_id])

    if comp_id == INVALID_ID {
        ERRORF("max %v capacity reached\n", enum_to_string(Components(array_id)), loc = loc)
        return comp_id
    }

    comp_id_from_obj_id[array_id][obj_id] = comp_id
    obj_id_from_comp_id[array_id][comp_id] = obj_id
    return comp_id
}

new_game_obj :: proc(id: id_t, loc := #caller_location) -> ^GameObject {
    comp_id := set_id(id, u64(Components.GAME_OBJ), loc = loc)
    return &game_objects[comp_id]
}

get_game_obj :: proc(id: id_t, loc := #caller_location) -> ^GameObject {
    if comp_id_from_obj_id[Components.GAME_OBJ][id] == INVALID_ID {
        ERRORF("invalid id: %v\n", id, loc = loc)
        return nil
    }

    idx := comp_id_from_obj_id[Components.GAME_OBJ][id]
    return &game_objects[idx]
}

new_gui :: proc(id: id_t, loc := #caller_location) -> ^Gui {
    comp_id := set_id(id, u64(Components.GUI), loc = loc)

    gui_set_render_index(id, 0)
    return &guis[comp_id]
}

get_gui :: proc(id: id_t, loc := #caller_location) -> ^Gui {
    if comp_id_from_obj_id[Components.GUI][id] == INVALID_ID {
        ERRORF("invalid id: %v\n", id, loc = loc)
        return nil
    }

    idx := comp_id_from_obj_id[Components.GUI][id]
    return &guis[idx]
}

new_model :: proc(id: id_t, loc := #caller_location) -> ^Model {
    comp_id := set_id(id, u64(Components.MODEL), loc = loc)
    return &models[comp_id]
}

get_model :: proc(id: id_t, loc := #caller_location) -> ^Model {
    if comp_id_from_obj_id[Components.MODEL][id] == INVALID_ID {
        ERRORF("invalid id: %v\n", id, loc = loc)
        return nil
    }

    idx := comp_id_from_obj_id[Components.MODEL][id]
    return &models[idx]
}

new_material :: proc(id: id_t, loc := #caller_location) -> ^Material {
    comp_id := set_id(id, u64(Components.MATERIAL), loc = loc)
    return &materials[comp_id]
}

get_material :: proc(id: id_t, loc := #caller_location) -> ^Material {
    if comp_id_from_obj_id[Components.MATERIAL][id] == INVALID_ID {
        ERRORF("invalid id: %v\n", id, loc = loc)
        return nil
    }

    idx := comp_id_from_obj_id[Components.MATERIAL][id]
    return &materials[idx]
}

new_texture :: proc(id: id_t, loc := #caller_location) -> ^Texture {
    comp_id := set_id(id, u64(Components.TEXTURE), loc = loc)
    return &textures[comp_id]
}

get_texture :: proc(id: id_t, loc := #caller_location) -> ^Texture {
    if comp_id_from_obj_id[Components.TEXTURE][id] == INVALID_ID {
        ERRORF("invalid id: %v\n", id, loc = loc)
        return nil
    }

    idx := comp_id_from_obj_id[Components.TEXTURE][id]
    return &textures[idx]
}

new_light :: proc(id: id_t, loc := #caller_location) -> ^Light {
    comp_id := set_id(id, u64(Components.LIGHT), loc = loc)
    return &lights[comp_id]
}

get_light :: proc(id: id_t, loc := #caller_location) -> ^Light {
    if comp_id_from_obj_id[Components.LIGHT][id] == INVALID_ID {
        ERRORF("invalid id: %v\n", id, loc = loc)
        return nil
    }

    idx := comp_id_from_obj_id[Components.LIGHT][id]
    return &lights[idx]
}

new_text_component :: proc(id: id_t, loc := #caller_location) -> ^Text {
    comp_id := set_id(id, u64(Components.TEXT), loc = loc)
    return &texts[comp_id]
}

get_text_component :: proc(id: id_t, loc := #caller_location) -> ^Text {
    if comp_id_from_obj_id[Components.TEXT][id] == INVALID_ID {
        ERRORF("invalid id: %v\n", id, loc = loc)
        return nil
    }

    idx := comp_id_from_obj_id[Components.TEXT][id]
    return &texts[idx]
}

new_font_component :: proc(id: id_t, loc := #caller_location) -> ^FontAtlas {
    comp_id := set_id(id, u64(Components.FONT_ATLAS), loc = loc)
    return &fonts[comp_id]
}

get_font_component :: proc(id: id_t, loc := #caller_location) -> ^FontAtlas {
    if comp_id_from_obj_id[Components.FONT_ATLAS][id] == INVALID_ID {
        ERRORF("invalid id: %v\n", id, loc = loc)
        return nil
    }

    idx := comp_id_from_obj_id[Components.FONT_ATLAS][id]
    return &fonts[idx]
}

set_render_index :: proc(id: id_t, loc := #caller_location) {
    if comp_id_from_obj_id[Components.GUI][id] == INVALID_ID {
        ERRORF("invalid id: %v\n", id, loc = loc)
        return
    }

    sorted_gui_indices[id].x = f32(comp_id_from_obj_id[Components.GUI][id])
    sorted_gui_indices[id].y = get_game_obj(id).position.z + 1
    sort.quick_sort_proc(sorted_gui_indices[:], proc(a, b: vec2) -> int {
        return int(a.y - b.y)
    })
}

//------------------------------------------------------------------------------------------

is_valid_component :: proc(id: id_t, comp: Components) -> bool {
    return comp_id_from_obj_id[comp][id] != INVALID_ID
}
