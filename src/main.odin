package main

main :: proc() {
    context.allocator = logger_init()
    println("init engine")
    app_init()

    println("destroy engine")
    logger_destroy()
}
