struct VertexInput {
    @location(0) position:  vec3f,
    @location(1) uv:        vec3f,
};

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) uv:             vec2f,
};

struct GlobalUbo {
    projection:   mat4x4f,
    view:         mat4x4f,
    inverse_view: mat4x4f,
};

struct ModelUbo {
    model_matrix: mat4x4f,
    color:        vec4f,
    is_font:      u32,
};

@group(0) @binding(0) var<uniform> global_ubo: GlobalUbo;

@group(1) @binding(0) var<uniform> model_ubo: ModelUbo;
@group(1) @binding(1) var ui_texture: texture_2d<f32>;
@group(1) @binding(2) var ui_sampler: sampler;

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    let world_pos = model_ubo.model_matrix * vec4f(in.position.xyz, 1.0);
    out.position = global_ubo.projection * global_ubo.view * world_pos;
    out.uv = in.uv.rg;

    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    let res = textureSample(ui_texture, ui_sampler, in.uv).rgba;

    if (model_ubo.is_font == 1) {
        if (res.r <= 0.0) { discard; }
        return pow(res.r * model_ubo.color, vec4f(2.2)); // srgb to linear
    }

    if (res.a <= 0.0) { discard; }
    return pow(res * model_ubo.color, vec4f(2.2)); // srgb to linear
}
