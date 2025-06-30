package main

// import "vendor:wgpu"
//
// @(private="file") pipeline: Pipeline
// @(private="file") global_ubo_buffer: wgpu.Buffer
//
// shadow_init :: proc() {
//     pipeline.shader_filepath = "assets/shaders/shadow.wgsl"
//     device_get_default_pipeline(&pipeline)
//     pipeline.pipeline_descriptor.label = "shadow pipeline"
//
//     vertex_attributes := [5]wgpu.VertexAttribute{}
//     vertex_attributes[0].shaderLocation = 0
//     vertex_attributes[0].format = .Float32x3
//     vertex_attributes[0].offset = 0
//
//     vertex_attributes[1].shaderLocation = 1
//     vertex_attributes[1].format = .Float32x3
//     vertex_attributes[1].offset = u64(offset_of(Vertex, normal))
//
//     vertex_attributes[2].shaderLocation = 2
//     vertex_attributes[2].format = .Float32x3
//     vertex_attributes[2].offset = u64(offset_of(Vertex, tex_coord))
//
//     vertex_attributes[3].shaderLocation = 3
//     vertex_attributes[3].format = .Float32x3
//     vertex_attributes[3].offset = u64(offset_of(Vertex, tangent))
//
//     vertex_attributes[4].shaderLocation = 4
//     vertex_attributes[4].format = .Float32x3
//     vertex_attributes[4].offset = u64(offset_of(Vertex, bitangent))
//
//     vertex_buffer_layout := wgpu.VertexBufferLayout{
//         arrayStride = size_of(Vertex),
//         stepMode = .Vertex,
//         attributeCount = len(vertex_attributes),
//         attributes = &vertex_attributes[0],
//     }
//
//     pipeline.pipeline_descriptor.vertex.bufferCount = 1
//     pipeline.pipeline_descriptor.vertex.buffers = &vertex_buffer_layout
//
//     global_bind_group_layout_entry: [1]wgpu.BindGroupLayoutEntry
//     global_bind_group_layout_entry[0].binding = 0
//     global_bind_group_layout_entry[0].visibility = { .Vertex, .Fragment }
//     global_bind_group_layout_entry[0].buffer.type = .Uniform
//     global_bind_group_layout_entry[0].buffer.minBindingSize = size_of(GlobalUbo)
//
//     shadow_bind_group_layout_entry: [4]wgpu.BindGroupLayoutEntry
//     shadow_bind_group_layout_entry[0].binding = 0
//     shadow_bind_group_layout_entry[0].visibility = { .Vertex, .Fragment }
//     shadow_bind_group_layout_entry[0].buffer.type = .Uniform
//     shadow_bind_group_layout_entry[0].buffer.minBindingSize = size_of(ModelUbo)
//
//     shadow_bind_group_layout_entry[1].binding = 1
//     shadow_bind_group_layout_entry[1].visibility = { .Fragment }
//     shadow_bind_group_layout_entry[1].texture.sampleType = .Float
//     shadow_bind_group_layout_entry[1].texture.viewDimension = ._2D
//
//     shadow_bind_group_layout_entry[2].binding = 2
//     shadow_bind_group_layout_entry[2].visibility = { .Fragment }
//     shadow_bind_group_layout_entry[2].texture.sampleType = .Float
//     shadow_bind_group_layout_entry[2].texture.viewDimension = ._2D
//
//     shadow_bind_group_layout_entry[3].binding = 3
//     shadow_bind_group_layout_entry[3].visibility = { .Fragment }
//     shadow_bind_group_layout_entry[3].sampler.type = .Filtering
//
//     bind_group_layout_descriptor: [2]wgpu.BindGroupLayoutDescriptor
//     bind_group_layout_descriptor[0].label = "shadow global bind group layout"
//     bind_group_layout_descriptor[0].entryCount = len(global_bind_group_layout_entry)
//     bind_group_layout_descriptor[0].entries = &global_bind_group_layout_entry[0]
//
//     bind_group_layout_descriptor[1].label = "shadow bind group layout"
//     bind_group_layout_descriptor[1].entryCount = len(shadow_bind_group_layout_entry)
//     bind_group_layout_descriptor[1].entries = &shadow_bind_group_layout_entry[0]
//
//     shadow_bind_group_layouts[0] = wgpu.DeviceCreateBindGroupLayout(device.device, &bind_group_layout_descriptor[0])
//     shadow_bind_group_layouts[1] = wgpu.DeviceCreateBindGroupLayout(device.device, &bind_group_layout_descriptor[1])
//
//     global_ubo_buffer = device_create_buffer({ .CopyDst, .Uniform }, size_of(GlobalUbo), label = "shadow global ubo")
//
//     // BIND GROUP
//     binding: [1]wgpu.BindGroupEntry
//     binding[0].binding = 0
//     binding[0].offset = 0
//     binding[0].buffer = global_ubo_buffer
//     binding[0].size = size_of(GlobalUbo)
//
//     bind_group_descriptor := wgpu.BindGroupDescriptor{
//         label = "shadow bind group descriptor",
//         layout = shadow_bind_group_layouts[0],
//         entryCount = len(binding),
//         entries = &binding[0],
//     }
//
//     pipeline.bind_group = wgpu.DeviceCreateBindGroup(device.device, &bind_group_descriptor)
//
//     // PIPELINE
//     pipeline.layout_descriptor = wgpu.PipelineLayoutDescriptor{
//         label = "shadow pipeline layout",
//         bindGroupLayoutCount = len(shadow_bind_group_layouts),
//         bindGroupLayouts = &shadow_bind_group_layouts[0],
//     }
//
//     pipeline.pipeline_descriptor.layout = wgpu.DeviceCreatePipelineLayout(device.device, &pipeline.layout_descriptor)
//     pipeline.pipeline_handle = wgpu.DeviceCreateRenderPipeline(device.device, &pipeline.pipeline_descriptor)
// }
//
// shadow_destroy :: proc() {
//     for layout in shadow_bind_group_layouts {
//         wgpu.BindGroupLayoutRelease(layout)
//     }
//
//     wgpu.RenderPipelineRelease(pipeline.pipeline_handle)
//     wgpu.BufferDestroy(global_ubo_buffer)
//     wgpu.BufferRelease(global_ubo_buffer)
// }
//
// shadow_draw :: proc(render_pass: wgpu.RenderPassEncoder, queue: wgpu.Queue, global_ubo: GlobalUbo) {
//     wgpu.RenderPassEncoderSetPipeline(render_pass, pipeline.pipeline_handle)
//     wgpu.RenderPassEncoderSetBindGroup(render_pass, 0, pipeline.bind_group)
//
//     global_ubo := global_ubo
//     wgpu.QueueWriteBuffer(queue, global_ubo_buffer, 0, &global_ubo, size_of(GlobalUbo))
//
//     models := get_models()
//     for m, i in models {
//         id := get_obj_id_from_comp_id(i, Components.MODEL)
//
//         if m.ubo == nil do return
//         go := get_game_obj(id)
//
//         if !go.enabled do continue
//
//         original_transform := []f32{ go.position.x, go.position.y, go.position.z, go.rotation.x, go.rotation.y, go.rotation.z, go.scale.z }
//
//         if go.parent != INVALID_ID {
//             parent := get_game_obj(go.parent)
//             go.position += parent.position
//             go.rotation += parent.rotation
//             go.scale.z *= parent.scale.z
//         }
//
//         mat := update_matrix(id)
//
//         if go.parent != INVALID_ID {
//             go.position = vec3{ original_transform[0], original_transform[1], original_transform[2] }
//             go.rotation = vec3{ original_transform[3], original_transform[4], original_transform[5] }
//             go.scale.z = original_transform[6]
//         }
//
//         material := get_material(id)
//         ubo := ModelUbo{
//             model_matrix = mat.model,
//             normal_matrix = mat.normal,
//             material =  ModelMaterial{
//                 texture_tilling = material.texture_tilling,
//                 normal_strength = material.normal_strength,
//                 diffuse = vec3_one,
//                 ambient = vec3_one * 0.3,
//                 specular = vec3_one,
//             }
//         }
//
//         wgpu.RenderPassEncoderSetBindGroup(render_pass, 1, m.bind_group)
//         wgpu.QueueWriteBuffer(queue, m.ubo, 0, &ubo, size_of(ModelUbo))
//
//         wgpu.RenderPassEncoderSetVertexBuffer(render_pass, 0, m.vertex_buffer, 0, m.vertex_buffer_size)
//         wgpu.RenderPassEncoderSetIndexBuffer(render_pass, m.index_buffer, .Uint32, 0, m.index_buffer_size)
//         wgpu.RenderPassEncoderDrawIndexed(render_pass, u32(len(m.indices)), 1, 0, 0, 0)
//     }
// }
//
// shadow_update_lights :: proc(global_ubo: ^GlobalUbo, ambient_light: vec3) {
//     lights := get_lights()
//
//     global_ubo.ambient_light.rgb = ambient_light.rgb
//     global_ubo.ambient_light.a = 1
//     global_ubo.light_count = 0
//
//     for &l, i in lights {
//         id := get_obj_id_from_comp_id(i, Components.LIGHT)
//         if id == INVALID_ID do return
//
//         obj := get_game_obj(id)
//         if !obj.enabled do continue
//
//         l.direction = get_object_forward_dir(id)
//         global_ubo.lights[global_ubo.light_count] = lights[i]
//         global_ubo.light_count += 1
//     }
// }
//
// shadow_begin_render_pass :: proc(next_texture: wgpu.TextureView, encoder: wgpu.CommandEncoder, clear_color: vec4f64) -> wgpu.RenderPassEncoder {
//     render_pass_color_attachment := wgpu.RenderPassColorAttachment{
//         view = next_texture,
//         loadOp = .Clear,
//         storeOp = .Store,
//         clearValue = { clear_color.r, clear_color.g, clear_color.b, clear_color.a }
//     }
//
//     depth_stencil_attachment := wgpu.RenderPassDepthStencilAttachment{
//         view = render_textures.depth_texture_view,
//         depthClearValue = 1.0,
//         depthLoadOp = .Clear,
//         depthStoreOp = .Store,
//         depthReadOnly = false,
//         stencilClearValue = 0,
//         stencilLoadOp = .Clear,
//         stencilStoreOp = .Store,
//         stencilReadOnly = true,
//     }
//
//     render_pass_descriptor := wgpu.RenderPassDescriptor{
//         colorAttachmentCount = 1,
//         colorAttachments = &render_pass_color_attachment,
//         depthStencilAttachment = &depth_stencil_attachment,
//     }
//
//     // create a command encoder to be able to create command buffers
//     return wgpu.CommandEncoderBeginRenderPass(encoder, &render_pass_descriptor)
// }
