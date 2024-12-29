package main

import "vendor:wgpu"

device_init :: proc() {
    instance := wgpu.CreateInstance(nil)
    defer wgpu.InstanceRelease(instance)

    if instance == nil do FATAL("wgpu is not supported")

    // SURFACE ADAPTER
    adapter_options := wgpu.RequestAdapterOptions{
        powerPreference = wgpu.PowerPreference.HighPerformance,
        compatibleSurface = device.surface,
    }

    device.surface = window_get_surface(instance)
    wgpu.InstanceRequestAdapter(instance, &adapter_options, on_adapter, nil)

    on_adapter :: proc "c" (status: wgpu.RequestAdapterStatus, adapter: wgpu.Adapter, message: cstring, userdata: rawptr) {
        context = ctx
        if status != .Success || adapter == nil {
            FATALF("request adapter failure: %v, %v", status, message, disable_location = true)
        }

        device.adapter = adapter
    }

    wgpu.AdapterRequestDevice(device.adapter, nil, on_device)

    on_device :: proc "c" (status: wgpu.RequestDeviceStatus, _device: wgpu.Device, message: cstring, userdata: rawptr) {
        context = ctx
        if status != .Success || _device == nil {
            FATALF("request device failure: %v, %v", status, message, disable_location = true)
        }

        device.device = _device
    }

    device.queue = wgpu.DeviceGetQueue(device.device)
    device_create_surface_textures(window_get_size())
}

device_destroy :: proc() {
}

device_create_buffer :: proc(usage_flags: wgpu.BufferUsageFlags, size: u64, mapped_at_creation: bool = false, label: cstring = "") -> wgpu.Buffer {
    return wgpu.DeviceCreateBuffer(device.device, &wgpu.BufferDescriptor{
        label = label,
        size  = next_pow2(size),
        usage = usage_flags,
        mappedAtCreation = b32(mapped_at_creation),
    })
}

next_pow2 :: proc(x: u64) -> u64 {
    if x <= 1 do return 1
    v := u64(1)
    for (v < x) do v <<= 1 // left shift until v is greater than x

    return v
}

device_create_surface_textures :: proc(size: vec2) {
    if render_textures.depth_texture != nil {
        wgpu.TextureViewRelease(render_textures.depth_texture_view)
        wgpu.TextureDestroy(render_textures.depth_texture)
        wgpu.TextureRelease(render_textures.depth_texture)

        render_textures.depth_texture_view = nil
        render_textures.depth_texture = nil
    }

    // DEBUGF("resizing window: w: %d, h: %d\n", size.x, size.y)

    render_textures.view_format = .RGBA8Unorm

    config := wgpu.SurfaceConfiguration{
        device          = device.device,
        format          = render_textures.view_format,
        usage           = { .RenderAttachment },
        alphaMode       = .Opaque,
        viewFormatCount = 1,
        viewFormats     = &render_textures.view_format,
        width           = u32(size.x),
        height          = u32(size.y),
        presentMode     = .Fifo,
         //presentMode     = .Mailbox,
         //presentMode     = .Immediate,
    }

    wgpu.SurfaceConfigure(device.surface, &config)

    depth_texture_format: wgpu.TextureFormat = .Depth24Plus

    depth_texture_descriptor := wgpu.TextureDescriptor{
        dimension       = ._2D,
        format          = depth_texture_format,
        mipLevelCount   = 1,
        sampleCount     = 1,
        size            = { config.width, config.height, 1 },
        usage           = { .RenderAttachment },
        viewFormatCount = 1,
        viewFormats     = &depth_texture_format,
    }
    render_textures.depth_texture = wgpu.DeviceCreateTexture(device.device, &depth_texture_descriptor)

    depth_texture_view_descriptor := wgpu.TextureViewDescriptor{
        aspect          = .DepthOnly,
        baseArrayLayer  = 0,
        arrayLayerCount = 1,
        baseMipLevel    = 0,
        mipLevelCount   = 1,
        dimension       = ._2D,
        format          = depth_texture_format,
    }

    render_textures.depth_texture_view = wgpu.TextureCreateView(render_textures.depth_texture, &depth_texture_view_descriptor)
}

device_get_default_pipeline :: proc(pipeline: ^Pipeline) {
    buf := read_file_to_cstring(pipeline.shader_filepath)
    defer delete(buf)

    pipeline.shader_code_descriptor.chain.sType = .ShaderModuleWGSLDescriptor
    pipeline.shader_code_descriptor.code = buf

    pipeline.shader_descriptor.hintCount = 0
    pipeline.shader_descriptor.nextInChain = &pipeline.shader_code_descriptor.chain
    pipeline.shader_module = wgpu.DeviceCreateShaderModule(device.device, &pipeline.shader_descriptor)

    pipeline.blend_state.color.srcFactor = .SrcAlpha
    pipeline.blend_state.color.dstFactor = .OneMinusSrcAlpha
    pipeline.blend_state.color.operation = .Add
    pipeline.blend_state.alpha.srcFactor = .Zero
    pipeline.blend_state.alpha.dstFactor = .One
    pipeline.blend_state.alpha.operation = .Add

    pipeline.color_target.format = render_textures.view_format
    pipeline.color_target.blend = &pipeline.blend_state
    pipeline.color_target.writeMask = {.Red, .Green, .Blue, .Alpha}

    // vertex shader
    pipeline.pipeline_descriptor.vertex.module = pipeline.shader_module
    pipeline.pipeline_descriptor.vertex.entryPoint = "vs_main"
    pipeline.pipeline_descriptor.vertex.constantCount = 0
    pipeline.pipeline_descriptor.vertex.constants = nil
    pipeline.pipeline_descriptor.vertex.bufferCount = 0
    pipeline.pipeline_descriptor.vertex.buffers = nil

    // fragment shader
    pipeline.fragment_state.module = pipeline.shader_module
    pipeline.fragment_state.entryPoint = "fs_main"
    pipeline.fragment_state.constantCount = 0
    pipeline.fragment_state.constants = nil
    pipeline.fragment_state.targetCount = 1
    pipeline.fragment_state.targets = &pipeline.color_target
    pipeline.pipeline_descriptor.fragment = &pipeline.fragment_state

    pipeline.pipeline_descriptor.primitive.topology = .TriangleList
    pipeline.pipeline_descriptor.primitive.stripIndexFormat = .Undefined // Undefined == vertices are considered sequentially
    pipeline.pipeline_descriptor.primitive.frontFace = .CW
    pipeline.pipeline_descriptor.primitive.cullMode = .Back
    // pipeline.pipeline_descriptor.primitive.cullMode = .None

    pipeline.depth_texture_format = .Depth24Plus
    pipeline.depth_stencil_state.format = .Depth24Plus
    pipeline.depth_stencil_state.depthWriteEnabled = true
    pipeline.depth_stencil_state.depthCompare = .Less
    pipeline.depth_stencil_state.stencilReadMask = 0
    pipeline.depth_stencil_state.stencilWriteMask = 0
    pipeline.depth_stencil_state.depthBias = 0
    pipeline.depth_stencil_state.depthBiasSlopeScale = 0
    pipeline.depth_stencil_state.depthBiasClamp = 0

    pipeline.depth_stencil_state.stencilFront.compare = .Always
    pipeline.depth_stencil_state.stencilFront.failOp = .Keep
    pipeline.depth_stencil_state.stencilFront.depthFailOp = .Keep
    pipeline.depth_stencil_state.stencilFront.passOp = .Keep

    pipeline.depth_stencil_state.stencilBack.compare = .Always
    pipeline.depth_stencil_state.stencilBack.failOp = .Keep
    pipeline.depth_stencil_state.stencilBack.depthFailOp = .Keep
    pipeline.depth_stencil_state.stencilBack.passOp = .Keep
    pipeline.pipeline_descriptor.depthStencil = &pipeline.depth_stencil_state

    pipeline.pipeline_descriptor.label = "default pipeline, rename this"
    pipeline.pipeline_descriptor.multisample.count = 1
    pipeline.pipeline_descriptor.multisample.mask = ~u32(0)
    pipeline.pipeline_descriptor.multisample.alphaToCoverageEnabled = false
}
