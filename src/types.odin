package main

import "vendor:wgpu"
import "vendor:glfw"
import "base:runtime"

// GLOBALS ===================================================
window : glfw.WindowHandle = nil
device : Device
render_textures : RenderTextures
render_bind_group_layouts: [2]wgpu.BindGroupLayout
ctx: runtime.Context
// =--------==================================================

id_t :: distinct u128

vec2 :: distinct [2]f32
vec3 :: distinct [3]f32
vec4 :: distinct [4]f32

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

// mat2 :: distinct matrix [2, 2]f32
// mat3 :: distinct matrix [3, 3]f32
// mat4 :: distinct matrix [4, 4]f32

mat2 :: distinct [4]f32
mat3 :: distinct [9]f32
mat4 :: distinct [16]f32

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
    DirectionalLight = 0,
    PointLight       = 1,
    SpotLight        = 2,
}

Light :: struct {
    color:      vec4,
    direction:  vec3,
    position:   vec3,
    light_type: u32,
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
    shader_code_descriptor:        wgpu.ShaderModuleWGSLDescriptor,
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
}

GuiEvent :: struct {
    id:       id_t,
    pressed:  bool,
    released: bool,
    holding:  bool,
    hovering: bool,
    toggle:   bool,
    focused:  bool,
    key:      Key,
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

    data:   [^]byte,
    glyphs: []FontGlyph,
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
    id:        id_t,
    position:  vec3,
    rotation:  vec3,
    scale:     vec3,
    parent:    id_t,
    childs:    [dynamic]id_t,
    enabled:   bool,
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

get_game_objs :: proc() -> []GameObject { return game_objects }
get_textures :: proc() -> []Texture { return textures }
get_guis :: proc() -> []Gui { return guis }
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

//------------------------------------------------------------------------------------------

is_valid_component :: proc(id: id_t, comp: Components) -> bool {
    return comp_id_from_obj_id[comp][id] != INVALID_ID
}

/* Button/Key states */
State :: enum {
    RELEASE = 0,
    PRESS   = 1,
    HOLD    = 2,
}

/* Joystick hat states. */
HAT_CENTERED   :: 0
HAT_UP         :: 1
HAT_RIGHT      :: 2
HAT_DOWN       :: 4
HAT_LEFT       :: 8
HAT_RIGHT_UP   :: (HAT_RIGHT | HAT_UP)
HAT_RIGHT_DOWN :: (HAT_RIGHT | HAT_DOWN)
HAT_LEFT_UP    :: (HAT_LEFT  | HAT_UP)
HAT_LEFT_DOWN  :: (HAT_LEFT  | HAT_DOWN)

/** Printable keys **/
Key :: enum {
    UNKNOWN = -1,
    NONE = 0,
    SPACE         = 32,
    APOSTROPHE    = 39,  /* ' */
    COMMA         = 44,  /* , */
    MINUS         = 45,  /* - */
    PERIOD        = 46,  /* . */
    SLASH         = 47,  /* / */
    SEMICOLON     = 59,  /* ; */
    EQUAL         = 61,  /* :: */
    LEFT_BRACKET  = 91,  /* [ */
    BACKSLASH     = 92,  /* \ */
    RIGHT_BRACKET = 93,  /* ] */
    GRAVE_ACCENT  = 96,  /* ` */
    WORLD_1       = 161, /* non-US #1 */
    WORLD_2       = 162, /* non-US #2 */

    KEY_0 = 48,
    KEY_1 = 49,
    KEY_2 = 50,
    KEY_3 = 51,
    KEY_4 = 52,
    KEY_5 = 53,
    KEY_6 = 54,
    KEY_7 = 55,
    KEY_8 = 56,
    KEY_9 = 57,

    A = 65,
    B = 66,
    C = 67,
    D = 68,
    E = 69,
    F = 70,
    G = 71,
    H = 72,
    I = 73,
    J = 74,
    K = 75,
    L = 76,
    M = 77,
    N = 78,
    O = 79,
    P = 80,
    Q = 81,
    R = 82,
    S = 83,
    T = 84,
    U = 85,
    V = 86,
    W = 87,
    X = 88,
    Y = 89,
    Z = 90,

    ESCAPE       = 256,
    ENTER        = 257,
    TAB          = 258,
    BACKSPACE    = 259,
    INSERT       = 260,
    DELETE       = 261,
    RIGHT        = 262,
    LEFT         = 263,
    DOWN         = 264,
    UP           = 265,
    PAGE_UP      = 266,
    PAGE_DOWN    = 267,
    HOME         = 268,
    END          = 269,
    CAPS_LOCK    = 280,
    SCROLL_LOCK  = 281,
    NUM_LOCK     = 282,
    PRINT_SCREEN = 283,
    PAUSE        = 284,

    F1  = 290,
    F2  = 291,
    F3  = 292,
    F4  = 293,
    F5  = 294,
    F6  = 295,
    F7  = 296,
    F8  = 297,
    F9  = 298,
    F10 = 299,
    F11 = 300,
    F12 = 301,
    F13 = 302,
    F14 = 303,
    F15 = 304,
    F16 = 305,
    F17 = 306,
    F18 = 307,
    F19 = 308,
    F20 = 309,
    F21 = 310,
    F22 = 311,
    F23 = 312,
    F24 = 313,
    F25 = 314,

    KP_0 = 320,
    KP_1 = 321,
    KP_2 = 322,
    KP_3 = 323,
    KP_4 = 324,
    KP_5 = 325,
    KP_6 = 326,
    KP_7 = 327,
    KP_8 = 328,
    KP_9 = 329,

    KP_DECIMAL  = 330,
    KP_DIVIDE   = 331,
    KP_MULTIPLY = 332,
    KP_SUBTRACT = 333,
    KP_ADD      = 334,
    KP_ENTER    = 335,
    KP_EQUAL    = 336,

    LEFT_SHIFT    = 340,
    LEFT_CONTROL  = 341,
    LEFT_ALT      = 342,
    LEFT_SUPER    = 343,
    RIGHT_SHIFT   = 344,
    RIGHT_CONTROL = 345,
    RIGHT_ALT     = 346,
    RIGHT_SUPER   = 347,
    MENU          = 348,

    LAST = MENU
}

Mod :: enum {
    NONE      = 0x0000,
    SHIFT     = 0x0001,
    CONTROL   = 0x0002,
    ALT       = 0x0004,
    SUPER     = 0x0008,
    CAPS_LOCK = 0x0010,
    NUM_LOCK  = 0x0020,
}

MouseButton :: enum {
    LEFT   = 0,
    RIGHT  = 1,
    MIDDLE = 2,
    BTN_4  = 3,
    BTN_5  = 4,
    BTN_6  = 5,
    BTN_7  = 6,
    BTN_8  = 7,
}

MOUSE_BUTTON_1 :: 0
MOUSE_BUTTON_2 :: 1
MOUSE_BUTTON_3 :: 2
MOUSE_BUTTON_4 :: 3
MOUSE_BUTTON_5 :: 4
MOUSE_BUTTON_6 :: 5
MOUSE_BUTTON_7 :: 6
MOUSE_BUTTON_8 :: 7

MOUSE_BUTTON_LAST   :: MOUSE_BUTTON_8
MOUSE_BUTTON_LEFT   :: MOUSE_BUTTON_1
MOUSE_BUTTON_RIGHT  :: MOUSE_BUTTON_2
MOUSE_BUTTON_MIDDLE :: MOUSE_BUTTON_3

JOYSTICK_1  :: 0
JOYSTICK_2  :: 1
JOYSTICK_3  :: 2
JOYSTICK_4  :: 3
JOYSTICK_5  :: 4
JOYSTICK_6  :: 5
JOYSTICK_7  :: 6
JOYSTICK_8  :: 7
JOYSTICK_9  :: 8
JOYSTICK_10 :: 9
JOYSTICK_11 :: 10
JOYSTICK_12 :: 11
JOYSTICK_13 :: 12
JOYSTICK_14 :: 13
JOYSTICK_15 :: 14
JOYSTICK_16 :: 15
JOYSTICK_LAST :: JOYSTICK_16

GAMEPAD_BUTTON_A            :: 0
GAMEPAD_BUTTON_B            :: 1
GAMEPAD_BUTTON_X            :: 2
GAMEPAD_BUTTON_Y            :: 3
GAMEPAD_BUTTON_LEFT_BUMPER  :: 4
GAMEPAD_BUTTON_RIGHT_BUMPER :: 5
GAMEPAD_BUTTON_BACK         :: 6
GAMEPAD_BUTTON_START        :: 7
GAMEPAD_BUTTON_GUIDE        :: 8
GAMEPAD_BUTTON_LEFT_THUMB   :: 9
GAMEPAD_BUTTON_RIGHT_THUMB  :: 10
GAMEPAD_BUTTON_DPAD_UP      :: 11
GAMEPAD_BUTTON_DPAD_RIGHT   :: 12
GAMEPAD_BUTTON_DPAD_DOWN    :: 13
GAMEPAD_BUTTON_DPAD_LEFT    :: 14
GAMEPAD_BUTTON_LAST         :: GAMEPAD_BUTTON_DPAD_LEFT

GAMEPAD_BUTTON_CROSS    :: GAMEPAD_BUTTON_A
GAMEPAD_BUTTON_CIRCLE   :: GAMEPAD_BUTTON_B
GAMEPAD_BUTTON_SQUARE   :: GAMEPAD_BUTTON_X
GAMEPAD_BUTTON_TRIANGLE :: GAMEPAD_BUTTON_Y

GAMEPAD_AXIS_LEFT_X        :: 0
GAMEPAD_AXIS_LEFT_Y        :: 1
GAMEPAD_AXIS_RIGHT_X       :: 2
GAMEPAD_AXIS_RIGHT_Y       :: 3
GAMEPAD_AXIS_LEFT_TRIGGER  :: 4
GAMEPAD_AXIS_RIGHT_TRIGGER :: 5
GAMEPAD_AXIS_LAST          :: GAMEPAD_AXIS_RIGHT_TRIGGER
