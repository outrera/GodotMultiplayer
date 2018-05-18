extends KinematicBody

var player_id = 0;
var control = false;

var velocity = Vector3();

func _physics_process(delta):
	if player_id > 0 and control:
		var direction = Vector3();
		if Input.is_action_pressed("move_forward"):
			direction.z -= 1;
		if Input.is_action_pressed("move_backward"):
			direction.z += 1;
		if Input.is_action_pressed("move_left"):
			direction.x -= 1;
		if Input.is_action_pressed("move_right"):
			direction.x += 1;

		velocity.x = direction.x;
		velocity.z = direction.z;
		velocity.y -= 9.8 * delta;

		velocity = move_and_slide(velocity, Vector3(0, 1, 0));

		if get_tree().network_peer.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_CONNECTED:
			rpc_unreliable("update_pos", transform.origin, player_id);

remote func update_pos(position, pid):
	var pnode = get_tree().get_root().find_node(Network.get_formatted_node_name(pid), true, false);

	pnode.set_translation(position);