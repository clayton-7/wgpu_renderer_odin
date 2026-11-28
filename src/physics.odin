package main

import "vendor:box3d"

TIME_STEP:	f32: 1.0 / 60.0
SUB_STEP_COUNT: i32: 4

world_id: box3d.WorldId

@(private="file") PhysicId :: struct {
	obj_id:  id_t,
	body_id: box3d.BodyId
}

@(private="file") body_ids: [dynamic]PhysicId

physics_init :: proc() {
	reserve(&body_ids, 1024)
	world_def := box3d.DefaultWorldDef()
	world_def.gravity = { 0, -9.8, 0 }
	world_id = box3d.CreateWorld(world_def)
}

physics_destroy :: proc() {
	box3d.DestroyWorld(world_id)
	delete(body_ids)
}

create_box_collider :: proc(obj_id: id_t, is_dynamic: bool = true, size: vec3 = vec3_one, loc := #caller_location) -> box3d.BodyId {
	obj := get_game_obj(obj_id, loc=loc)
	if obj == nil do return {}

	body_def := box3d.DefaultBodyDef()
	body_def.position = obj.position.xyz
	body_def.rotation = obj.rotation
	hull_size := obj.scale
	if size.x != 1 || size.y != 1 || size.z != 1 do hull_size = size

	box_hull := box3d.MakeBoxHull(hull_size.x, hull_size.y, hull_size.z)
	shape_def := box3d.DefaultShapeDef()

	// TODO: expose this values to the user
	if is_dynamic {
		shape_def.density = 1
		shape_def.baseMaterial.friction = 0.3
		body_def.type = .dynamicBody
	}

	box_id := box3d.CreateBody(world_id, body_def)
	_ = box3d.CreateHullShape(box_id, shape_def, &box_hull.base)

	append(&body_ids, { obj_id = obj_id, body_id = box_id })

	return box_id
}

physics_update :: proc() {
	box3d.World_Step(world_id, TIME_STEP, SUB_STEP_COUNT)

	for ids in body_ids {
		transform := box3d.Body_GetTransform(ids.body_id)
		obj := get_game_obj(ids.obj_id)
		if obj == nil do continue

		obj.position = transform.p.xyz
		set_rotation_quat(obj.id, transform.q)
	}

}
