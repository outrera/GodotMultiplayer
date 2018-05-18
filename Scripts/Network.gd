extends Node

const DEFAULT_PORT = 31516;
const MAX_PEERS = 10;
var players = {};
var player_name;

var host;

enum COMPRESS_MODE {None, Range_Coder, FastLZ, ZLib, ZSTD}

export (COMPRESS_MODE) var compression_mode = None setget set_compression_mode, get_compression_mode;

signal spawn_player(id);
signal remove_player(id);

func get_formatted_node_name(id):
	return "Player%d" % id;

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected");
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected");
	get_tree().connect("connected_to_server", self, "_connected_ok");
	get_tree().connect("connection_failed", self, "_connected_fail");
	get_tree().connect("server_disconnected", self, "_server_disconnected");
	host = NetworkedMultiplayerENet.new();

func get_connection_status():
	return host.get_connection_status();

# NOTE: If you want to use Hamachi, make sure to allow the game to communicate on public servers
func start_server(bind_ip="*", port=DEFAULT_PORT, max_peers=MAX_PEERS):
	if not player_name:
		player_name = "Server";

	print("starting server on ip " + bind_ip + " on port " + str(port));

	var host = NetworkedMultiplayerENet.new();
	host.set_bind_ip(bind_ip);
	host.compression_mode = compression_mode

	var err = host.create_server(port, max_peers)

	if err != OK:
		return err;

	get_tree().set_network_peer(host);
	get_tree().set_meta("network_peer", host);

	emit_signal("spawn_player", 1);
	return err;

func join_server(ip="127.0.0.1", port=DEFAULT_PORT):
	if not player_name:
		player_name = "Client";

	print("joining server at ip " + ip + " on port " + str(port));

	host.compression_mode = compression_mode

	var err = host.create_client(ip, port);

	if err == OK:
		get_tree().set_network_peer(host);
		get_tree().set_meta("network_peer", host);
	else:
		print(err);

	return err;

func _player_connected(id):
	print("player has connected with id " + str(id));

func _player_disconnected(id):
	unregister_player(id);
	rpc("unregister_player", id);
	print("player has disconnected with id " + str(id));

func _connected_ok():
	rpc_id(1, "user_ready", get_tree().get_network_unique_id(), player_name);

func _connected_fail():
	print("connection failed");
	host.close_connection();
#	get_tree().get_root().add_child(load("res://Scenes/Main.tscn"));
	pass;

remote func user_ready(id, player_name):
	if get_tree().is_network_server():
		rpc_id(id, "register_in_game");

remote func register_in_game():
	rpc("register_new_player", get_tree().get_network_unique_id(), player_name);
	register_new_player(get_tree().get_network_unique_id(), player_name);

func _server_disconnected():
	print("server has disconnected");
	for id in players.keys():
		if id != get_tree().get_network_unique_id():
			unregister_player(id);
	host.close_connection();
	#quit_game();

remote func register_new_player(id, name):
	if get_tree().is_network_server():
		rpc_id(id, "register_new_player", 1, player_name);

		for peer_id in players:
			rpc_id(id, "register_new_player", peer_id, players[peer_id]);

	players[id] = name;
	emit_signal("spawn_player", id);

remote func register_player(id, name):
	if get_tree().is_network_server():
		rpc_id(id, "register_new_player", 1, player_name);

		for peer_id in players:
			rpc_id(id, "register_new_player", peer_id, players[peer_id]);
			rpc_id(peer_id, "register_player", id, name);

	players[id] = name;

remote func unregister_player(id):
	emit_signal("remove_player", id);
	players.erase(id);

func quit_game():
	host.close_connection();
	players.clear();

func set_compression_mode(mode):
	compression_mode = mode;
	if get_tree() and get_tree().has_method("get_meta") and get_tree().get_meta("network_peer"):
		get_tree().get_meta("network_peer").compression_mode = mode;

func get_compression_mode():
	if get_tree() and get_tree().has_method("get_meta") and get_tree().get_meta("network_peer"):
		return get_tree().get_meta("network_peer").compression_mode;
	else:
		return compression_mode;
