package main

import "vendor:wgpu"

@(private="file") pipeline: Pipeline
@(private="file") skybox_bind_group_layouts: [1]wgpu.BindGroupLayout

@(private="file") skybox_obj: ^GameObject
@(private="file") skybox_enabled := true
@(private="file") mvp_buffer: wgpu.Buffer

@(private="file") MVPUbo :: struct {
    model: mat4,
    view:  mat4,
    proj:  mat4,
}

skybox_init :: proc(enabled: bool = true) {
    skybox_enabled = enabled

    if !skybox_enabled do return

    filepaths := [6]string{
        // "assets/models/skybox/galax/right.jpg",
        // "assets/models/skybox/galax/left.jpg",
        // "assets/models/skybox/galax/top.jpg",
        // "assets/models/skybox/galax/bottom.jpg",
        // "assets/models/skybox/galax/front.jpg",
        // "assets/models/skybox/galax/back.jpg",
        "assets/models/skybox/right.jpg",
        "assets/models/skybox/left.jpg",
        "assets/models/skybox/top.jpg",
        "assets/models/skybox/bottom.jpg",
        "assets/models/skybox/front.jpg",
        "assets/models/skybox/back.jpg",
    }

    skybox_obj = new_object("assets/models/cube.gltf")
    skybox_obj.enabled = false // skybox will be rendered here and not in the main renderer

    create_cube_texture_image(skybox_obj.id, filepaths)

    pipeline.shader_filepath = "assets/shaders/skybox.wgsl"
    device_get_default_pipeline(&pipeline)
    pipeline.pipeline_descriptor.label = "skybox pipeline"

    // DISABLE DEPTH WRITING
    pipeline.depth_stencil_state.depthWriteEnabled = .False
    pipeline.pipeline_descriptor.primitive.cullMode = .Front

    vertex_attributes := [1]wgpu.VertexAttribute{}
    vertex_attributes[0].shaderLocation = 0
    vertex_attributes[0].format = .Float32x3
    vertex_attributes[0].offset = 0

    vertex_buffer_layout := wgpu.VertexBufferLayout{
        arrayStride = size_of(Vertex),
        stepMode = .Vertex,
        attributeCount = len(vertex_attributes),
        attributes = &vertex_attributes[0],
    }

    pipeline.pipeline_descriptor.vertex.bufferCount = 1
    pipeline.pipeline_descriptor.vertex.buffers = &vertex_buffer_layout

    skybox_bind_group_layout_entry: [3]wgpu.BindGroupLayoutEntry
    skybox_bind_group_layout_entry[0].binding = 0
    skybox_bind_group_layout_entry[0].visibility = { .Vertex, .Fragment }
    skybox_bind_group_layout_entry[0].buffer.type = .Uniform
    skybox_bind_group_layout_entry[0].buffer.minBindingSize = size_of(ModelUbo)

    skybox_bind_group_layout_entry[1].binding = 1
    skybox_bind_group_layout_entry[1].visibility = { .Fragment }
    skybox_bind_group_layout_entry[1].buffer.type = .Uniform
    skybox_bind_group_layout_entry[1].texture.sampleType = .Float
    skybox_bind_group_layout_entry[1].texture.multisampled = false
    skybox_bind_group_layout_entry[1].texture.viewDimension = .Cube

    skybox_bind_group_layout_entry[2].binding = 2
    skybox_bind_group_layout_entry[2].visibility = { .Fragment }
    skybox_bind_group_layout_entry[2].sampler.type = .Filtering

    bind_group_layout_descriptor: [1]wgpu.BindGroupLayoutDescriptor
    bind_group_layout_descriptor[0].label = "skybox bind group layout"
    bind_group_layout_descriptor[0].entryCount = len(skybox_bind_group_layout_entry)
    bind_group_layout_descriptor[0].entries = &skybox_bind_group_layout_entry[0]

    skybox_bind_group_layouts[0] = wgpu.DeviceCreateBindGroupLayout(device.device, &bind_group_layout_descriptor[0])
    mvp_buffer = device_create_buffer({ .CopyDst, .Uniform }, size_of(MVPUbo), label = "skybox mvp buffer")

    // BIND GROUP
    binding: [3]wgpu.BindGroupEntry

    binding[0].binding = 0
    binding[0].buffer = mvp_buffer
    binding[0].size = size_of(MVPUbo)

    // TEXTURE
    texture := get_texture(skybox_obj.id)
    binding[1].textureView = texture.texture_view
    binding[1].binding = 1

    // SAMPLER
    binding[2].sampler = texture.sampler
    binding[2].binding = 2

    bind_group_descriptor := wgpu.BindGroupDescriptor{
        label = "skybox bind group descriptor",
        layout = skybox_bind_group_layouts[0],
        entryCount = len(binding),
        entries = &binding[0],
    }

    pipeline.bind_group = wgpu.DeviceCreateBindGroup(device.device, &bind_group_descriptor)

    // PIPELINE
    pipeline.layout_descriptor = wgpu.PipelineLayoutDescriptor{
        label = "skybox pipeline layout",
        bindGroupLayoutCount = len(skybox_bind_group_layouts),
        bindGroupLayouts = &skybox_bind_group_layouts[0],
    }

    pipeline.pipeline_descriptor.layout = wgpu.DeviceCreatePipelineLayout(device.device, &pipeline.layout_descriptor)
    pipeline.pipeline_handle = wgpu.DeviceCreateRenderPipeline(device.device, &pipeline.pipeline_descriptor)
}

skybox_destroy :: proc() {
    if !skybox_enabled do return

    for layout in skybox_bind_group_layouts {
        wgpu.BindGroupLayoutRelease(layout)
    }

    wgpu.RenderPipelineRelease(pipeline.pipeline_handle)
    wgpu.BufferDestroy(mvp_buffer)
    wgpu.BufferRelease(mvp_buffer)
}

skybox_draw :: proc(render_pass: wgpu.RenderPassEncoder, queue: wgpu.Queue, global_ubo: GlobalUbo) {
    if !skybox_enabled do return

    wgpu.RenderPassEncoderSetPipeline(render_pass, pipeline.pipeline_handle)
    wgpu.RenderPassEncoderSetBindGroup(render_pass, 0, pipeline.bind_group)

    mvp: MVPUbo
    mvp.model = mat4_identity
    mvp.proj = global_ubo.projection
    mvp.view = global_ubo.view

    // BLOCK SKYBOX MOVEMENT
    // mvp.view[12] = 0
    // mvp.view[13] = 0
    // mvp.view[14] = 0
    // TEST:
    mvp.view[3, 0] = 0
    mvp.view[3, 1] = 0
    mvp.view[3, 2] = 0

    wgpu.QueueWriteBuffer(queue, mvp_buffer, 0, &mvp, size_of(MVPUbo))
    model := get_model(skybox_obj.id)

    wgpu.RenderPassEncoderSetVertexBuffer(render_pass, 0, model.vertex_buffer, 0, model.vertex_buffer_size)
    wgpu.RenderPassEncoderSetIndexBuffer(render_pass, model.index_buffer, .Uint32, 0, model.index_buffer_size)
    wgpu.RenderPassEncoderDrawIndexed(render_pass, u32(len(model.indices)), 1, 0, 0, 0)
}
