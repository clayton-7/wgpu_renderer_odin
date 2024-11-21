package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:mem"

import "base:runtime"

ENABLE_LOG :: true

LOG :: enum { TRACE, DEBUG, INFO, WARN, ERROR, FATAL }
LOG_FULL_PATH :: false

@(private="file") COLORS :: [?]string { "1;37", "1;34", "1;32", "0;33", "0;31", "1;31" }
@(private="file") LEVELS :: [?]string { "[TRACE]:", "[DEBUG]:", "[INFO]: ", "[WARN]: ", "[ERROR]:", "[FATAL]:" }
@(private="file") tmp_alloc: runtime.Allocator
@(private="file") track_alloc: mem.Tracking_Allocator

logger_init :: proc(temp_allocator := context.temp_allocator) -> runtime.Allocator {
    tmp_alloc = temp_allocator

    when ODIN_DEBUG {
        mem.tracking_allocator_init(&track_alloc, context.allocator)
        return mem.tracking_allocator(&track_alloc)
    }

    return context.allocator
}

logger_destroy :: proc() {
    when ODIN_DEBUG {
        if len(track_alloc.allocation_map) > 0 {
            ERRORF("%v allocations not freed:\n", len(track_alloc.allocation_map), disable_location = true)

            for _, entry in track_alloc.allocation_map {
                ERRORF("%v bytes at: %v\n", entry.size, entry.location, disable_location = true)
            }
        }

        if len(track_alloc.bad_free_array) > 0 {
            ERRORF("%v incorrect frees:\n", len(track_alloc.bad_free_array), disable_location = true)
            for entry in track_alloc.bad_free_array {
                fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
            }
        }

        mem.tracking_allocator_destroy(&track_alloc)
    }
}

read_file_to_cstring :: proc(file_path: string, allocator := context.allocator, loc := #caller_location) -> cstring {
    u8_buffer, ok := os.read_entire_file_from_filename(file_path, allocator, loc)

    if !ok {
        ERRORF("Failed to read the file:", file_path, loc=loc)
        return ""
    }

    c_buffer := make([]byte, len(u8_buffer) + 1, allocator, loc)
    copy(c_buffer, u8_buffer)
    c_buffer[len(u8_buffer)] = 0

    delete(u8_buffer)
    return cstring(&c_buffer[0])
}

concat_cstring :: proc(values: []string, allocator := context.temp_allocator) -> cstring {
    return strings.clone_to_cstring(strings.concatenate(values, allocator), allocator)
}

print :: proc(msg: any, level := LOG.DEBUG, new_line := true, loc := #caller_location, disable_location := false) {
    when ENABLE_LOG {
        context.temp_allocator = tmp_alloc

        file := loc.file_path
        colors := COLORS
        levels := LEVELS
        // FIX: os.get_current_directory() breaks if the print func is called by c code because it does not use context allocator
        // if !LOG_FULL_PATH {
        //     dir := os.get_current_directory()
        //     dir = fmt.tprintf("%v/", dir)
        //     file, _ = strings.remove(loc.file_path, dir, 1)
        // }

        format := ""
        if disable_location {
            format = fmt.tprintf("\033[%vm%v %v\033[0m", colors[level], levels[level], msg)
        } else {
            format = fmt.tprintf("[%v:%v] \033[%vm%v %v\033[5m", file, loc.line, colors[level], levels[level], msg)
        }

        if new_line {
            fmt.printf("%v\n", format)
        } else {
            fmt.print(format)
        }

        if level >= LOG.FATAL do os.exit(1)
    }
}

to_string :: proc(value: any) -> string { return  fmt.tprintf("%v", value) }

println :: proc(msg: any, level := LOG.DEBUG, loc := #caller_location, disable_location := false) {
    print(msg, level, true, loc, disable_location)
}

printf :: proc(level: LOG, format: string, args: ..any, loc := #caller_location, disable_location := false) {
    context.temp_allocator = tmp_alloc
    print(fmt.tprintf(format, ..args), level, false, loc, disable_location)
}

assert_msg :: proc(condition: bool, msg: string, loc := #caller_location, disable_location := false) {
    if !condition do println(msg, LOG.FATAL, loc, disable_location)
}

TRACE :: proc(msg: ..any, loc := #caller_location, disable_location := false) {
    println(msg, LOG.TRACE, loc, disable_location)
}

DEBUG :: proc(msg: ..any, loc := #caller_location, disable_location := false) {
    if len(msg) == 1 {
        println(msg[0], LOG.DEBUG, loc, disable_location)
        return
    }

    println(msg, LOG.DEBUG, loc, disable_location)
}

INFO :: proc(msg: ..any, loc := #caller_location, disable_location := false) {
    if len(msg) == 1 {
        println(msg[0], LOG.INFO, loc, disable_location)
        return
    }

    println(msg, LOG.INFO, loc, disable_location)
}

WARN :: proc(msg: ..any, loc := #caller_location, disable_location := false) {
    if len(msg) == 1 {
        println(msg[0], LOG.WARN, loc, disable_location)
        return
    }

    println(msg, LOG.WARN, loc, disable_location)
}

ERROR :: proc(msg: ..any, loc := #caller_location, disable_location := false) {
    if len(msg) == 1 {
        println(msg[0], LOG.ERROR, loc, disable_location)
        return
    }

    println(msg, LOG.ERROR, loc, disable_location)
}

FATAL :: proc(msg: ..any, loc := #caller_location, disable_location := false) {
    if len(msg) == 1 {
        println(msg[0], LOG.FATAL, loc, disable_location)
        os.exit(1)
    }

    println(msg, LOG.FATAL, loc, disable_location)
    os.exit(1)
}

TRACEF :: proc(format: string, args: ..any, loc := #caller_location, disable_location := false) {
    context.temp_allocator = tmp_alloc
    print(fmt.tprintf(format, ..args), LOG.TRACE, false, loc, disable_location)
}

DEBUGF :: proc(format: string, args: ..any, loc := #caller_location, disable_location := false) {
    context.temp_allocator = tmp_alloc
    print(fmt.tprintf(format, ..args), LOG.DEBUG, false, loc, disable_location)
}

INFOF :: proc(format: string, args: ..any, loc := #caller_location, disable_location := false) {
    context.temp_allocator = tmp_alloc
    print(fmt.tprintf(format, ..args), LOG.INFO, false, loc, disable_location)
}

WARNF :: proc(format: string, args: ..any, loc := #caller_location, disable_location := false) {
    context.temp_allocator = tmp_alloc
    print(fmt.tprintf(format, ..args), LOG.WARN, false, loc, disable_location)
}

ERRORF :: proc(format: string, args: ..any, loc := #caller_location, disable_location := false) {
    context.temp_allocator = tmp_alloc
    print(fmt.tprintf(format, ..args), LOG.ERROR, false, loc, disable_location)
}

FATALF :: proc(format: string, args: ..any, loc := #caller_location, disable_location := false) {
    context.temp_allocator = tmp_alloc
    print(fmt.tprintf(format, ..args), LOG.FATAL, false, loc, disable_location)
    os.exit(1)
}

enum_to_string :: proc(value: any, loc := #caller_location) -> string {
    v, ok := fmt.enum_value_to_string(value)
    if !ok {
        WARNF("invalid enum: %v", value, loc = loc)
        return ""
    }

    return  v
}
