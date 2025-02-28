class_name MCPFileResources
extends RefCounted

var _logger = MCPLogger.new("MCPFileResources")
var _resource_manager: MCPResourceManager

func _init(resource_manager: MCPResourceManager):
	_resource_manager = resource_manager
	_register_resources()
	_register_loaders()

func _register_resources():
	# Project directory resources
	var project_dir = MCPTypes.MCPResource.new(
		"file://{path}",
		"Project Files",
		"Files in the project directory",
		"application/directory"
	)
	_resource_manager.register_resource(project_dir)
	
	# Script resources
	var script_resource = MCPTypes.MCPResource.new(
		"script://{path}",
		"GDScript Files",
		"GDScript script files in the project",
		"text/x-gdscript"
	)
	_resource_manager.register_resource(script_resource)
	
	# Scene resources
	var scene_resource = MCPTypes.MCPResource.new(
		"scene://{path}",
		"Scene Files",
		"Godot scene files in the project",
		"text/x-godot-scene"
	)
	_resource_manager.register_resource(scene_resource)
	
	# Resource resources
	var res_resource = MCPTypes.MCPResource.new(
		"resource://{path}",
		"Resource Files",
		"Godot resource files in the project",
		"application/x-godot-resource"
	)
	_resource_manager.register_resource(res_resource)

func _register_loaders():
	# Register file loader
	_resource_manager.register_resource_loader("file://{path}", _file_loader)
	
	# Register script loader
	_resource_manager.register_resource_loader("script://{path}", _script_loader)
	
	# Register scene loader
	_resource_manager.register_resource_loader("scene://{path}", _scene_loader)
	
	# Register resource loader
	_resource_manager.register_resource_loader("resource://{path}", _resource_loader)

func _file_loader(uri: String) -> Dictionary:
	# Extract path from URI
	var path = uri.replace("file://", "")
	
	# Handle directory listing
	if DirAccess.dir_exists_absolute(path):
		return _list_directory(path)
	
	# Handle file reading
	if FileAccess.file_exists(path):
		return _read_file(path, uri)
	
	return {
		"contents": [
			{
				"uri": uri,
				"text": "File or directory not found: %s" % path
			}
		]
	}

func _script_loader(uri: String) -> Dictionary:
	# Extract path from URI
	var path = uri.replace("script://", "")
	
	# Add extension if not provided
	if not path.ends_with(".gd"):
		path += ".gd"
	
	# Handle file reading
	if FileAccess.file_exists(path):
		return _read_file(path, uri, "text/x-gdscript")
	
	return {
		"contents": [
			{
				"uri": uri,
				"text": "Script file not found: %s" % path
			}
		]
	}

func _scene_loader(uri: String) -> Dictionary:
	# Extract path from URI
	var path = uri.replace("scene://", "")
	
	# Add extension if not provided
	if not path.ends_with(".tscn"):
		path += ".tscn"
	
	# Handle file reading
	if FileAccess.file_exists(path):
		return _read_file(path, uri, "text/x-godot-scene")
	
	return {
		"contents": [
			{
				"uri": uri,
				"text": "Scene file not found: %s" % path
			}
		]
	}

func _resource_loader(uri: String) -> Dictionary:
	# Extract path from URI
	var path = uri.replace("resource://", "")
	
	# Handle file reading
	if FileAccess.file_exists(path):
		return _read_file(path, uri, "application/x-godot-resource")
	
	return {
		"contents": [
			{
				"uri": uri,
				"text": "Resource file not found: %s" % path
			}
		]
	}

func _list_directory(path: String) -> Dictionary:
	var dir = DirAccess.open(path)
	if not dir:
		return {
			"contents": [
				{
					"uri": "file://%s" % path,
					"text": "Failed to open directory: %s" % path
				}
			]
		}
	
	var result = "Directory listing for %s:\n\n" % path
	
	# List directories
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			result += "📁 %s/\n" % file_name
		else:
			result += "📄 %s\n" % file_name
		file_name = dir.get_next()
	
	return {
		"contents": [
			{
				"uri": "file://%s" % path,
				"text": result,
				"mimeType": "application/directory"
			}
		]
	}

func _read_file(path: String, uri: String, mime_type: String = "") -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {
			"contents": [
				{
					"uri": uri,
					"text": "Failed to open file: %s" % path
				}
			]
		}
	
	var content = file.get_as_text()
	
	# Determine MIME type if not provided
	if mime_type.is_empty():
		mime_type = _determine_mime_type(path)
	
	return {
		"contents": [
			{
				"uri": uri,
				"text": content,
				"mimeType": mime_type
			}
		]
	}

func _determine_mime_type(path: String) -> String:
	if path.ends_with(".gd"):
		return "text/x-gdscript"
	elif path.ends_with(".tscn"):
		return "text/x-godot-scene"
	elif path.ends_with(".tres") or path.ends_with(".res"):
		return "application/x-godot-resource"
	elif path.ends_with(".json"):
		return "application/json"
	elif path.ends_with(".txt"):
		return "text/plain"
	else:
		return "application/octet-stream"
