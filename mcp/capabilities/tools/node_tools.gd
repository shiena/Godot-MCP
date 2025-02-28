class_name MCPNodeTools
extends RefCounted

var _logger = MCPLogger.new("MCPNodeTools")
var _tool_manager: MCPToolManager

func _init(tool_manager: MCPToolManager):
	_tool_manager = tool_manager
	_register_tools()

func _register_tools():
	# List nodes tool
	var list_nodes = MCPTypes.MCPTool.new(
		"listNodes",
		"Lists all nodes in the current scene",
		{
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Optional path filter"
				}
			}
		}
	)
	_tool_manager.register_tool(list_nodes)
	_tool_manager.register_tool_callback("listNodes", _list_nodes_callback)
	
	# Get node properties tool
	var get_node_properties = MCPTypes.MCPTool.new(
		"getNodeProperties",
		"Get properties of a specific node",
		{
			"type": "object",
			"required": ["path"],
			"properties": {
				"path": {
					"type": "string",
					"description": "Path to the node"
				}
			}
		}
	)
	_tool_manager.register_tool(get_node_properties)
	_tool_manager.register_tool_callback("getNodeProperties", _get_node_properties_callback)
	
	# Create node tool
	var create_node = MCPTypes.MCPTool.new(
		"createNode",
		"Create a new node in the scene",
		{
			"type": "object",
			"required": ["type", "parent_path"],
			"properties": {
				"type": {
					"type": "string",
					"description": "Node type to create (e.g. Sprite2D, Node2D)"
				},
				"parent_path": {
					"type": "string",
					"description": "Path to the parent node"
				},
				"name": {
					"type": "string",
					"description": "Optional name for the new node"
				},
				"properties": {
					"type": "object",
					"description": "Optional properties to set on the new node"
				}
			}
		}
	)
	_tool_manager.register_tool(create_node)
	_tool_manager.register_tool_callback("createNode", _create_node_callback)

func _list_nodes_callback(args: Dictionary, context: Dictionary) -> Dictionary:
	var path_filter = args.get("path", "")
	var editor_interface = EditorPlugin.new().get_editor_interface()
	var scene_root = editor_interface.get_edited_scene_root()
	
	if not scene_root:
		return {
			"content": [
				{
					"type": "text",
					"text": "No scene is currently open in the editor."
				}
			]
		}
	
	var nodes = []
	_collect_nodes(scene_root, "", nodes, path_filter)
	
	if nodes.size() == 0:
		return {
			"content": [
				{
					"type": "text",
					"text": "No nodes found matching the filter: %s" % path_filter
				}
			]
		}
	
	var result_text = "Nodes in the scene:\n\n"
	for node_info in nodes:
		result_text += "- %s (%s)\n" % [node_info.path, node_info.type]
	
	return {
		"content": [
			{
				"type": "text",
				"text": result_text
			}
		]
	}

func _collect_nodes(node: Node, path: String, result: Array, filter: String = "") -> void:
	var current_path = path + "/" + node.name if path else node.name
	
	if filter.is_empty() or filter in current_path:
		result.append({
			"path": current_path,
			"type": node.get_class()
		})
	
	for child in node.get_children():
		_collect_nodes(child, current_path, result, filter)

func _get_node_properties_callback(args: Dictionary, context: Dictionary) -> Dictionary:
	var node_path = args.path
	var editor_interface = EditorPlugin.new().get_editor_interface()
	var scene_root = editor_interface.get_edited_scene_root()
	
	if not scene_root:
		return {
			"content": [
				{
					"type": "text",
					"text": "No scene is currently open in the editor."
				}
			]
		}
	
	var node = scene_root.get_node_or_null(node_path)
	if not node:
		return {
			"content": [
				{
					"type": "text",
					"text": "Node not found: %s" % node_path
				}
			]
		}
	
	var properties = _get_node_property_list(node)
	var result_text = "Properties of node '%s' (%s):\n\n" % [node_path, node.get_class()]
	
	for prop in properties:
		var value = node.get(prop.name) if prop.name else "N/A"
		result_text += "- %s: %s\n" % [prop.name, str(value)]
	
	return {
		"content": [
			{
				"type": "text",
				"text": result_text
			}
		]
	}

func _get_node_property_list(node: Node) -> Array:
	var properties = []
	for property in node.get_property_list():
		# Filter out properties that are not relevant
		if property.usage & PROPERTY_USAGE_EDITOR and not (property.usage & PROPERTY_USAGE_INTERNAL):
			properties.append(property)
	return properties

func _create_node_callback(args: Dictionary, context: Dictionary) -> Dictionary:
	var node_type = args.type
	var parent_path = args.parent_path
	var node_name = args.get("name", "")
	var properties = args.get("properties", {})
	
	var editor_interface = EditorPlugin.new().get_editor_interface()
	var scene_root = editor_interface.get_edited_scene_root()
	
	if not scene_root:
		return {
			"content": [
				{
					"type": "text",
					"text": "No scene is currently open in the editor."
				}
			]
		}
	
	var parent_node = scene_root.get_node_or_null(parent_path)
	if not parent_node:
		return {
			"content": [
				{
					"type": "text",
					"text": "Parent node not found: %s" % parent_path
				}
			]
		}
	
	# Create the new node
	var new_node = ClassDB.instantiate(node_type)
	if new_node == null:
		return {
			"content": [
				{
					"type": "text",
					"text": "Failed to create node of type: %s. The type may not exist or cannot be instantiated." % node_type
				}
			]
		}
	
	# Set node name if provided
	if node_name:
		new_node.name = node_name
	
	# Add the node to the parent
	parent_node.add_child(new_node)
	new_node.owner = scene_root
	
	# Set properties if any
	for prop_name in properties:
		if new_node.has_property(prop_name):
			new_node.set(prop_name, properties[prop_name])
	
	return {
		"content": [
			{
				"type": "text",
				"text": "Created new %s node at %s/%s" % [node_type, parent_path, new_node.name]
			}
		]
	}
