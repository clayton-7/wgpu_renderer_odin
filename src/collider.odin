package main

import math "core:math/linalg"

CUBE_MASS: f32 = 2
GRAVITY: f32: -9.8

Plane :: struct {
    normal: vec3, // Normal vector of the plane
    d:       f32, // Distance from origin
}

OBB :: struct {
    position:         vec3,
    rotation:         quat,
    axes_dir:         [3]vec3, // orientation axes (u, v, w)
    half_size:        vec3,    // half size of the object
    velocity:         vec3,
    angular_velocity: vec3,
    bounce_factor:    f32,
    damper_factor:    f32,
}

// Calculate the moment of inertia tensor for a cube
calculate_inertia_tensor :: proc(obb: OBB) -> mat3 {
    mass := CUBE_MASS
    side_length := obb.half_size.x
    factor := mass * side_length * side_length

    // return mat3{
    //     factor, 0.0, 0.0,
    //     0.0, factor, 0.0,
    //     0.0, 0.0, factor
    // }

    local_inertia := mat3{
        factor, 0.0, 0.0,
        0.0, factor, 0.0,
        0.0, 0.0, factor
    }

    // Transform the local inertia tensor to world space
    rotation_matrix := quat_to_mat3(obb.rotation)
    world_inertia := rotation_matrix * (local_inertia * math.transpose(rotation_matrix))
    return world_inertia
}

// Transform the inertia tensor to world coordinates
transform_inertia_tensor :: proc(inertia_tensor: mat3, rotation: mat3) -> mat3 {
    return rotation * (inertia_tensor * math.transpose(rotation))
}

// Calculate the inverse of the inertia tensor
inverse_inertia_tensor :: proc(inertia_tensor: mat3) -> mat3 {
    return math.inverse(inertia_tensor)
}

update_angular_velocity :: proc(obb: ^OBB, torque: vec3) {
    inertia_tensor := calculate_inertia_tensor(obb^)
    inv_inertia_tensor := inverse_inertia_tensor(inertia_tensor)

    delta_angular_velocity := inv_inertia_tensor * torque
    obb.angular_velocity += delta_angular_velocity
}

obb_hit_plane :: proc(obb: ^OBB, plane: Plane) -> (bool, vec3) {
    position_distance := math.dot(plane.normal, obb.position) + plane.d

    radius := math.abs(math.dot(obb.axes_dir[0], plane.normal)) * obb.half_size.x +
              math.abs(math.dot(obb.axes_dir[1], plane.normal)) * obb.half_size.y +
              math.abs(math.dot(obb.axes_dir[2], plane.normal)) * obb.half_size.z

    if math.abs(position_distance) <= radius {
        dir: f32 = 1.0
        if position_distance <= 0 do dir = -1

        collision_dir := plane.normal * dir * (radius - math.abs(position_distance))

        obb.velocity += collision_dir * obb.bounce_factor
        obb.velocity *= obb.damper_factor





    //
    // // Apply bounce factor to the normal component
    // normal_component := math.dot(obb.velocity, plane.normal) * plane.normal
    // obb.velocity -= (1.0 + obb.bounce_factor) * normal_component
    //
    // // Apply friction to the tangential component
    // obb.velocity = apply_friction(obb.velocity, plane.normal, 0.5)
    //
    // // Clamp small velocities to zero
    // obb.velocity = clamp_velocity(obb.velocity, 0.01)






        if obb.velocity.y < 0 do obb.velocity.y = 0

        // Find the point of contact
        CENTER :: vec3_zero
        contact_point := CENTER
        min_distance := max(f32)

        for i := -1; i <= 1; i += 2 {
            for j := -1; j <= 1; j += 2 {
                for k := -1; k <= 1; k += 2 {
                    vertex := CENTER +
                        obb.axes_dir[0] * (f32(i) * obb.half_size.x) +
                        obb.axes_dir[1] * (f32(j) * obb.half_size.y) +
                        obb.axes_dir[2] * (f32(k) * obb.half_size.z)

                    distance := math.dot(vertex, plane.normal) + plane.d

                    if math.abs(distance) < math.abs(min_distance) {
                        min_distance = distance
                        contact_point = vertex
                    }
                }
            }
        }

        // Calculate torque
        r := contact_point - obb.position
        force := collision_dir * obb.bounce_factor
        torque := math.cross(r, force)

        update_angular_velocity(obb, torque)

        // Apply angular damping
        obb.angular_velocity *= obb.damper_factor

        return true, collision_dir
    }

    return false, vec3_zero
}

acce: f32
obb: OBB
plane :: Plane{
    normal = vec3_up, // orientation of the plane (e.g., horizontal plane)
    d = 0.0           // Distance from origin
}

update_rotation_quaternion :: proc(obb: ^OBB, dt: f32) {
    // Convert angular velocity to a pure quaternion
    angular_velocity_quat := quat{0, obb.angular_velocity.x, obb.angular_velocity.y, obb.angular_velocity.z}

    // Compute the quaternion derivative
    rotation_derivative := 0.5 * (angular_velocity_quat * obb.rotation)

    // Integrate the rotation using Euler integration
    obb.rotation += rotation_derivative * dt

    magnitude := math.length(obb.rotation)
    // if magnitude == 0 || math.is_nan(magnitude) {
        obb.rotation = math.normalize(obb.rotation)
    // }
}

update_axes_dir :: proc(obb: ^OBB) {
    rotation_matrix := quat_to_mat3(obb.rotation)

    obb.axes_dir[0] = rotation_matrix * vec3_right
    obb.axes_dir[1] = rotation_matrix * vec3_up
    obb.axes_dir[2] = rotation_matrix * vec3_forward
}

orthonormalize_axes_dir :: proc(obb: ^OBB) {
    // Gram-Schmidt orthonormalization
    u := math.normalize(obb.axes_dir[0])
    v := math.normalize(obb.axes_dir[1] - math.dot(obb.axes_dir[1], u) * u)
    w := math.cross(u, v)

    obb.axes_dir[0] = u
    obb.axes_dir[1] = v
    obb.axes_dir[2] = w
}

// test_collider :: proc(cube, plane: ^GameObject, dt: f32) {
//     plane_col := Plane{
//         normal = vec3_up,
//         d = 1
//     }
//
//     obb.bounce_factor = 100.0
//     obb.damper_factor = 0.7
//     obb.velocity.y -= 1 * CUBE_MASS
//     obb.velocity.y = max(obb.velocity.y, GRAVITY * CUBE_MASS)
//
//     obb.position = cube.position
//     obb.axes_dir = { get_object_right_dir(cube.id), get_object_up_dir(cube.id), get_object_forward_dir(cube.id) }
//     obb.half_size = vec3_one
//
//     hit, dir := obb_hit_plane(&obb, plane_col)
//     cube.position += obb.velocity * dt
//
//
//     cube.using_quat = true
//     DEBUG(cube.quat)
//
//     obb.rotation = cube.quat
//     update_rotation_quaternion(&obb, dt)
//     update_axes_dir(&obb)
//     cube.quat = obb.rotation
//
//
//
//     // cube.rotation += obb.angular_velocity * dt
//
//
//
//
//     obb.velocity += obb.angular_velocity * obb.damper_factor * dt
// }
clamp_velocity :: proc(velocity: vec3, threshold: f32) -> vec3 {
    if math.length(velocity) < threshold {
        return vec3_zero
    }
    return velocity
}
 apply_friction :: proc(velocity: vec3, normal: vec3, friction_coefficient: f32) -> vec3 {
    // Calculate the normal component of the velocity
    normal_component := math.dot(velocity, normal) * normal

    // Calculate the tangential component of the velocity
    tangential_component := velocity - normal_component

    // Apply friction to the tangential component
    tangential_magnitude := math.length(tangential_component)
    if tangential_magnitude > 0 {
        friction_force := min(friction_coefficient, tangential_magnitude)
        tangential_component *= (tangential_magnitude - friction_force) / tangential_magnitude
    }

    // Combine the normal and reduced tangential components
    return normal_component + tangential_component
}

frame_count := 0

test_collider :: proc(cube, plane: ^GameObject, dt: f32) {
    plane_col := Plane{
        normal = vec3_up,
        d = 1,
    }

    // TODO: FIX THE PHYSICS, NOT WORKING RIGHT NOW
    obb.bounce_factor = 20.0
    obb.damper_factor = 0.98
    obb.velocity.y -= 1 * CUBE_MASS
    obb.velocity.y = max(obb.velocity.y, GRAVITY * CUBE_MASS)

    obb.position = cube.position
    obb.rotation = cube.quat
    obb.half_size = vec3_one

    hit, dir := obb_hit_plane(&obb, plane_col)
    cube.position += obb.velocity * dt

    // Update rotation
    update_rotation_quaternion(&obb, dt)
    update_axes_dir(&obb)

    // Periodically re-orthonormalize the axes
    if frame_count % 60 == 0 { // Every 60 frames
        orthonormalize_axes_dir(&obb)
    }

    // Apply damping
    obb.velocity *= obb.damper_factor
    obb.angular_velocity *= obb.damper_factor

    // Clamp small velocities to zero
    obb.velocity = clamp_velocity(obb.velocity, 0.01)
    obb.angular_velocity = clamp_velocity(obb.angular_velocity, 0.01)

    // Apply friction if there was a collision
    if hit {
        obb.velocity = apply_friction(obb.velocity, plane_col.normal, 0.5)
    }

    cube.using_quat = true
    cube.quat = obb.rotation
    frame_count += 1
}
