struct Light {
    color:      vec4f,
    direction:  vec3f,
    position:   vec3f,
    light_type: u32,
};

struct GlobalUbo {
    projection:    mat4x4f,
    view:          mat4x4f,
    inverse_view:  mat4x4f,
    ambient_light: vec4f,
    lights:        array<Light, 30>,
    light_count:   u32,
};

struct Material {
    diffuse:         vec3f,
    ambient:         vec3f,
    specular:        vec3f,
    texture_tilling: f32,
    normal_strength: f32,
};

struct ModelUbo {
    model_matrix:  mat4x4f,
    normal_matrix: mat4x4f,
    material:      Material,
};

struct VertexInput {
    @location(0) position:  vec3f,
    @location(1) normal:    vec3f,
    @location(2) tex_coord: vec3f,
    @location(3) tangent:   vec3f,
    @location(4) bitangent: vec3f,
};

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) color:     vec3f,
    @location(1) normal:    vec3f,
    @location(2) tex_coord: vec2f,
    @location(3) pos_world: vec3f,
    @location(4) tangent:   vec3f,
    @location(5) bitangent: vec3f,
};

@group(0) @binding(0) var<uniform> global_ubo: GlobalUbo;

@group(1) @binding(0) var<uniform> model_ubo: ModelUbo;
@group(1) @binding(1) var diffuse_texture:    texture_2d<f32>;
@group(1) @binding(2) var normal_texture:     texture_2d<f32>;
@group(1) @binding(3) var texture_sampler:    sampler;


@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var o: VertexOutput;

    let world_pos = model_ubo.model_matrix * vec4f(in.position, 1.0);

    o.pos_world = world_pos.xyz;
    o.position = global_ubo.projection * global_ubo.view * world_pos;

    o.tangent = (model_ubo.model_matrix * vec4f(in.tangent, 0.0)).xyz;
    o.bitangent = (model_ubo.model_matrix * vec4f(in.bitangent, 0.0)).xyz;
    o.normal = (model_ubo.normal_matrix * vec4f(in.normal, 0.0)).xyz;

    o.color = model_ubo.material.diffuse;
    o.tex_coord = in.tex_coord.rg * model_ubo.material.texture_tilling;

    return o;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    let camera_world_pos = global_ubo.inverse_view[3].xyz;
    let view_dir = normalize(camera_world_pos - in.pos_world);

    let encoded_normal = textureSample(normal_texture, texture_sampler, in.tex_coord).rgb;
    let normal_local = encoded_normal * 2.0 - 1.0;

    let TBN = mat3x3f(
        normalize(in.tangent),
        normalize(in.bitangent),
        normalize(in.normal),
    );

    let normal_world = TBN * normal_local;
    let normal = mix(normalize(in.normal), normal_world, model_ubo.material.normal_strength);

    var spot_light = vec3f(0.0);
    var point_light = vec3f(0.0);
    var direction_light = vec3f(0.0);

    var i: u32 = 0u;
//    for (;;) {
//        // DIRECTIONAL_LIGHT
//        if (global_ubo.lights[i].light_type == 0u) {
            direction_light = calculate_directional_light(global_ubo.lights[i], normal, view_dir, model_ubo.material);
//        }
//
//        i += 1u;
//        if (i >= global_ubo.light_count) { break; }
//    }

    let img_color = in.color * textureSample(diffuse_texture, texture_sampler, in.tex_coord).rgb;
    let result = (global_ubo.ambient_light.rgb + direction_light + spot_light + point_light) * img_color;

    // linear to sRGB
    var color = pow(result, vec3f(2.2));

    // ============================= tone mapping
    // reinhard tone mapping
    // color = color / (color + vec3(1.0));

    // reinhard extended tone mapping
    // color = reinhardExtendedLuminance(color, 1.0);

    // Krzysztof Narkowicz
    // color = aces_narkowicz(color);

    // Khronos PBR Neutral Tone Mapper
    // color = pbr_neutral(color);

    // agX Tone Mapper
    color = agx(color);

    // ==========================================

    return vec4f(color, 1.0);
}

// ========================= AGX ==============================================
const MIN_EV: f32 = -12.47393;
const MAX_EV: f32 = 4.026069;

const AGX_MAT: mat3x3<f32> = mat3x3<f32>(
    vec3<f32>(0.842479062253094, 0.0423282422610123, 0.0423756549057051),
    vec3<f32>(0.0784335999999992, 0.878468636469772, 0.0784336),
    vec3<f32>(0.0792237451477643, 0.0791661274605434, 0.879142973793104)
);

const INV_AGX_MAT: mat3x3<f32> = mat3x3<f32>(
    vec3<f32>(1.19687900512017, -0.0528514873049502, -0.0528514873049502),
    vec3<f32>(-0.0980201818432808, 1.15190312957764, -0.0980201818432808),
    vec3<f32>(-0.0990297440797225, -0.0990297440797225, 1.15107372944641)
);

const LUMA_WEIGHTS: vec3<f32> = vec3<f32>(0.2126, 0.7152, 0.0722);

fn agx(color: vec3<f32>) -> vec3<f32> {
    var col = color;

    col = log2(AGX_MAT * col);
    col = vec3<f32>(
        max(MIN_EV, min(MAX_EV, col.x)),
        max(MIN_EV, min(MAX_EV, col.y)),
        max(MIN_EV, min(MAX_EV, col.z))
    );

    col = (col - vec3<f32>(MIN_EV)) / (MAX_EV - MIN_EV);
    col *= (0.12410293 + col * (0.2078625 + col * (-5.9293431 + col * (30.376821 + col * (-38.901506 + col * 15.122061)))));

    let luma = dot(col, LUMA_WEIGHTS);
    let slope = vec3<f32>(1.0);
    let power = vec3<f32>(1.35);
    let sat = 1.4;

    var result = pow(col * slope, power);
    col = luma + sat * (result - luma);

    return INV_AGX_MAT * col;
}

// ============================================================================

fn pbr_neutral(color: vec3f) -> vec3f {
    let start_compression: f32 = 0.8 - 0.04;
    let desaturation: f32 = 0.15;

    var x: f32 = min(color.r, min(color.g, color.b));
    var offset: f32 = x - 6.25 * x * x;

    if (x >= 0.08) { offset = 0.04; }

    var res = color - offset;

    var peak: f32 = max(res.r, max(res.g, res.b));
    if (peak < start_compression) { return res; }

    let d: f32 = 1.0 - start_compression;
    var new_peak: f32 = 1.0 - d * d / (peak + d - start_compression);
    res *= new_peak / peak;

    var g: f32 = 1.0 - 1.0 / (desaturation * (peak - new_peak) + 1.0);
    return mix(res, new_peak * vec3f(1), g);
}

const LUMINANCE = vec3f(0.2126, 0.7152, 0.0722);

fn luminance(color: vec3f) -> f32 { return dot(color, LUMINANCE); }

fn reinhardExtendedLuminance(v: vec3f, maxWhiteL: f32) -> vec3f {
    let l_old = luminance(v);
    let numerator = l_old * (1.0f + (l_old / (maxWhiteL * maxWhiteL)));
    let l_new = numerator / (1.0f + l_old);

    return v * (l_new / luminance(v));
}

fn clamp(value: f32, _min: f32, _max: f32) -> f32 {
    return min(max(value, _min), _max);
}

fn clamp_vec3(value: vec3f, _min: f32, _max: f32) -> vec3f {
    return vec3f(clamp(value.x, _min, _max), clamp(value.y, _min, _max), clamp(value.z, _min, _max));
}

fn aces_narkowicz(value: vec3f) -> vec3f {
    let v = 0.6 * value;
    return clamp_vec3((v * (2.51 * v + 0.03)) / (v * (2.43 * v + 0.59) + 0.14), 0.0, 1.0);
}

fn calculate_directional_light(light: Light, normal: vec3f, view_dir: vec3f, material: Material) -> vec3f {
    let light_dir = normalize(-light.direction.xyz);
    let diff = max(dot(normal, light_dir), 0.0);

    let reflect_dir = reflect(-light_dir, normal);
    let spec = pow(max(dot(view_dir, reflect_dir), 0.0), 256.0);

    let ambient = light.color.rgb * material.ambient;
    let diffuse = light.color.rgb * diff * material.diffuse;
    let specular = light.color.rgb * spec * material.specular;

    // let ambient = light.color.rgb;
    // let diffuse = light.color.rgb * diff;
    // let specular = light.color.rgb * spec;

    return (ambient + diffuse + specular) * light.color.a;
}
