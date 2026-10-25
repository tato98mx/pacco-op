class_name SyncUtil
# Añade un MultiplayerSynchronizer (autoridad = host) a un nodo creado por código.

static func attach(n: Node, props: Array) -> void:
	var cfg := SceneReplicationConfig.new()
	for p in props:
		var path := NodePath(":" + p)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var s := MultiplayerSynchronizer.new()
	s.name = "Sync"
	s.replication_config = cfg
	n.add_child(s)
