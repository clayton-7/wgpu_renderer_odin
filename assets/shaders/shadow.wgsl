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
    color = pbr_neutral(color);

    // ==========================================

    color = 1.0 - exp(-1.0 * color);

    return vec4f(color, 1.0);
}

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

fn clamp(value: f32, min: f32, max: f32) -> f32 {
    return min(max(value, min), max);
}

fn clamp_vec3(value: vec3f, min: f32, max: f32) -> vec3f {
    return vec3f(clamp(value.x, min, max), clamp(value.y, min, max), clamp(value.z, min, max));
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


//--------------------------------------------------------------------------------------------------------------------------------------

// // struct Light {
// //     color:      vec4f,
// //     direction:  vec4f, //  TODO: remove this and use light_view
// //     position:   vec4f,
// // };
// //
// // struct GlobalUbo {
// //     projection:   mat4x4f,
// //     view:         mat4x4f,
// //     inverse_view: mat4x4f,
// //     // light_count: u32,
// //     lights: array<Light, 30>,
// // };
// //
// // struct Material {
// //     texture_tilling: f32,
// //     normal_strength: f32,
// // };
// //
// // struct ModelUbo {
// //     model_matrix:  mat4x4f,
// //     normal_matrix: mat4x4f,
// //     material:     Material,
// // };
// //
// // struct VertexInput {
// //     @location(0) position:  vec3f,
// //     @location(1) normal:    vec3f,
// //     @location(2) tex_coord: vec3f,
// //     @location(3) tangent:   vec3f,
// //     @location(4) bitangent: vec3f,
// // };
// //
// // struct VertexOutput {
// //     @builtin(position) position: vec4f,
// //
// //     @location(0) normal:    vec3f,
// //     @location(1) tex_coord: vec2f,
// //     @location(2) pos_world: vec3f,
// //     @location(3) tangent:   vec3f,
// //     @location(4) bitangent: vec3f,
// // };
// //
// // @group(0) @binding(0) var<uniform> global_ubo: GlobalUbo;
// //
// // @group(1) @binding(0) var<uniform> model_ubo: ModelUbo;
// // @group(1) @binding(1) var diffuse_texture: texture_2d<f32>;
// // @group(1) @binding(2) var texture_sampler: sampler;
// //
// //
// // fn pbr_neutral(color: vec3f) -> vec3f {
// //     let start_compression: f32 = 0.8 - 0.04;
// //     let desaturation: f32 = 0.15;
// //
// //     var x: f32 = min(color.r, min(color.g, color.b));
// //     var offset: f32 = x - 6.25 * x * x;
// //
// //     if (x >= 0.08) { offset = 0.04; }
// //
// //     var res = color - offset;
// //
// //     var peak: f32 = max(res.r, max(res.g, res.b));
// //     if (peak < start_compression) { return res; }
// //
// //     let d: f32 = 1.0 - start_compression;
// //     var new_peak: f32 = 1.0 - d * d / (peak + d - start_compression);
// //     res *= new_peak / peak;
// //
// //     var g: f32 = 1.0 - 1.0 / (desaturation * (peak - new_peak) + 1.0);
// //     return mix(res, new_peak * vec3f(1), g);
// // }
// //
// // const LUMINANCE = vec3f(0.2126, 0.7152, 0.0722);
// //
// // fn luminance(color: vec3f) -> f32 { return dot(color, LUMINANCE); }
// //
// // fn reinhardExtendedLuminance(v: vec3f, maxWhiteL: f32) -> vec3f {
// //     let l_old = luminance(v);
// //     let numerator = l_old * (1.0f + (l_old / (maxWhiteL * maxWhiteL)));
// //     let l_new = numerator / (1.0f + l_old);
// //
// //     return v * (l_new / luminance(v));
// // }
// //
// // fn clamp(value: f32, min: f32, max: f32) -> f32 {
// //     return min(max(value, min), max);
// // }
// //
// // fn clamp_vec3(value: vec3f, min: f32, max: f32) -> vec3f {
// //     return vec3f(clamp(value.x, min, max), clamp(value.y, min, max), clamp(value.z, min, max));
// // }
// //
// // fn aces_narkowicz(value: vec3f) -> vec3f {
// //     let v = 0.6 * value;
// //     return clamp_vec3((v * (2.51 * v + 0.03)) / (v * (2.43 * v + 0.59) + 0.14), 0.0, 1.0);
// // }
// //
// // fn calculate_directional_light(light: Light, normal: vec3f, view_dir: vec3f, material: Material) -> vec3f {
// //     let light_dir = normalize(-light.direction.xyz);
// //     let diff = max(dot(normal, light_dir), 0.0);
// //
// //     let reflect_dir = reflect(-light_dir, normal);
// //     let spec = pow(max(dot(view_dir, reflect_dir), 0.0), 256.0);
// //
// //     // let ambient = light.color.rgb * material.ambient;
// //     // let diffuse = light.color.rgb * diff * material.diffuse;
// //     // let specular = light.color.rgb * spec * material.specular;
// //
// //     let ambient = light.color.rgb * vec3f(0.01);
// //     let diffuse = light.color.rgb * diff * vec3f(1.0);
// //     let specular = light.color.rgb * spec * vec3f(1.0);
// //
// //     return (ambient + diffuse + specular) * light.color.a;
// //     // return (ambient + diffuse + specular) * 1.0;
// // }
// //
// // // ------------------------------------------------------------------------------------------------------------------------------------
// //
// // @vertex
// // fn vs_main(in: VertexInput) -> VertexOutput {
// //     var out: VertexOutput;
// //
// //     let world_pos = model_ubo.model_matrix * vec4f(in.position, 1.0);
// //     out.pos_world = world_pos.xyz;
// //
// //     out.position = global_ubo.projection * global_ubo.view * world_pos;
// //     out.tex_coord = in.tex_coord.xy * model_ubo.material.texture_tilling;
// //     out.tangent = (model_ubo.model_matrix * vec4f(in.tangent, 0.0)).xyz;
// //     out.bitangent = (model_ubo.model_matrix * vec4f(in.bitangent, 0.0)).xyz;
// //     out.normal = (model_ubo.normal_matrix * vec4f(in.normal, 0.0)).xyz;
// //
// //     return out;
// // }
// //
// // @fragment
// // fn fs_main(in: VertexOutput) -> @location(0) vec4f {
// //     // var result = textureSample(diffuse_texture, texture_sampler, in.tex_coord).rgb;
// //     //
// //     // // linear to sRGB
// //     // var color = result.rgb;
// //     // // var color = pow(result, vec3f(2.2));
// //
// //
// //
// //     let camera_world_pos = global_ubo.inverse_view[3].xyz;
// //     let view_dir = normalize(camera_world_pos - in.pos_world);
// //
// //     // let encoded_normal = textureSample(normal_texture, texture_sampler, in.tex_coord).rgb;
// //     // let normal_local = encoded_normal * 2.0 - 1.0;
// //     //
// //     // let TBN = mat3x3f(
// //     //     normalize(in.tangent),
// //     //     normalize(in.bitangent),
// //     //     normalize(in.normal),
// //     // );
// //     //
// //     // let normal_world = TBN * normal_local;
// //     // let normal = mix(in.normal, normal_world, model_ubo.material.normal_strength);
// //     let normal = in.normal;
// //
// //     var spot_light = vec3f(0.0);
// //     var point_light = vec3f(0.0);
// //     var direction_light = vec3f(0.0);
// //     var ambient_light = vec3f(0.3);
// //
// //     var i: u32 = 0u;
// //     // for (;;) {
// //         // DIRECTIONAL_LIGHT
// //         // if (global_ubo.lights[i].light_type == 0u) {
// //             direction_light += calculate_directional_light(global_ubo.lights[i], normal, view_dir, model_ubo.material);
// //         // }
// //
// //         // i += 1u;
// //         // if (i >= global_ubo.light_count) { break; }
// //     // }
// //
// //     let img_color = textureSample(diffuse_texture, texture_sampler, in.tex_coord).rgb;
// //     let result = (ambient_light + direction_light + spot_light + point_light) * img_color;
// //
// //     // linear to sRGB
// //     var color = pow(result, vec3f(2.2));
// //
// //     // ============================= tone mapping
// //     // reinhard tone mapping
// //     // color = color / (color + vec3(1.0));
// //
// //     // reinhard extended tone mapping
// //     // color = reinhardExtendedLuminance(color, 1.0);
// //
// //     // Krzysztof Narkowicz
// //     // color = aces_narkowicz(color);
// //
// //     // Khronos PBR Neutral Tone Mapper
// //     color = pbr_neutral(color);
// //
// //     // ==========================================
// //
// //     // color = 1.0 - exp(-1.0 * color);
// //
// //     return vec4f(color, 1.0);
// // }
// // --------------------------------------------------------------------------------------------------------------------------------------
