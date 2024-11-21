struct VertexInput {
    @location(0) position: vec3f,
};

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) tex_coord: vec3f,
};

struct MVP {
    model: mat4x4f,
    view: mat4x4f,
    proj: mat4x4f,
};

@group(0) @binding(0) var<uniform> mvp: MVP;
@group(0) @binding(1) var diffuse_texture: texture_cube<f32>;
@group(0) @binding(2) var diffuse_sampler: sampler;

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    out.position = mvp.proj * mvp.view * vec4f(in.position, 1.0);
    out.tex_coord = in.position.xyz;

    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    let img_color = textureSample(diffuse_texture, diffuse_sampler, in.tex_coord).rgb;

    let color = pow(img_color, vec3f(2.2)); // srgb to linear
    return vec4f(color, 1.0);
}
