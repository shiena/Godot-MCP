@tool
extends EditorPlugin

# MCP Server configuration
var server = WebSocketMultiplayerPeer.new()
var port = 7000
var sessions = {}

# Editor state
var current_script = null
var script_editor = null

func _enter_tree():
	# Initialize plugin
	print("MCP Integration Plugin: Initializing")
	
	# Get the script editor interface
	script_editor = get_editor_interface().get_script_editor()
	
	# Connect to script changed signal
	script_editor.connect("editor_script_changed", _on_editor_script_changed)
	
	# Start the WebSocket server for the MCP client connections
	var result = server.create_server(port)
	if result != OK:
		push_error("Failed to start MCP server on port %d" % port)
		return
	print("MCP server started on port", port)
	
	server.peer_connected.connect(_client_connected)
	server.peer_disconnected.connect(_client_disconnected)
	# We'll handle data in the _process function using get_packet
	
	# Initial script update
	_on_editor_script_changed(script_editor.get_current_script())

func _process(delta):
	# Check for messages from connected clients
	if server.get_available_packet_count() > 0:
		var sender_id = server.get_packet_peer()
		var data = server.get_packet().get_string_from_utf8()
		var json = JSON.parse_string(data)
		
		if json == null:
			print("Invalid JSON received:", data)
			return
		
		# Process MCP JSON-RPC message
		if json.has("jsonrpc") and json["jsonrpc"] == "2.0":
			_handle_jsonrpc_message(sender_id, json)

func _exit_tree():
	# Clean up plugin
	print("MCP Integration Plugin: Cleaning up")
	
	# Disconnect signals
	if script_editor:
		script_editor.disconnect("editor_script_changed", _on_editor_script_changed)
	
	# Stop the WebSocket server
	server.close()

func _on_editor_script_changed(script):
	current_script = script
	
	if script:
		# Connect to text changed signals if it's a script with text content
		if script.is_connected("text_changed", _on_script_text_changed):
			script.disconnect("text_changed", _on_script_text_changed)
		
		script.connect("text_changed", _on_script_text_changed)
	
	# No need to send updates to an external server anymore
	# We'll provide the current script when requested via MCP

func _on_script_text_changed():
	# Script changed - we'll provide the latest version when requested via MCP
	pass

# === MCP Server Implementation ===

func _client_connected(id):
	print("MCP client connected: ", id)
	
	# Initialize a session for this client
	sessions[id] = {
		"id": id,
		"initialized": false,
		"capabilities": {}
	}

func _client_disconnected(id):
	print("MCP client disconnected: ", id)
	if sessions.has(id):
		sessions.erase(id)

# This function is no longer needed as we handle data in _process

func _handle_jsonrpc_message(id, message):
	if message.has("id") and message.has("method"):
		# This is a request
		var method = message["method"]
		var params = message.get("params", {})
		var request_id = message["id"]
		
		match method:
			"initialize":
				_handle_initialize(id, request_id, params)
			"resources/list":
				_handle_list_resources(id, request_id, params)
			"resources/read":
				_handle_read_resource(id, request_id, params)
			"tools/list":
				_handle_list_tools(id, request_id, params)
			"tools/call":
				_handle_call_tool(id, request_id, params)
			_:
				_send_error(id, request_id, -32601, "Method not found")
	
	elif message.has("method"):
		# This is a notification
		var method = message["method"]
		var params = message.get("params", {})
		
		match method:
			"initialized":
				sessions[id]["initialized"] = true
			_:
				print("Unhandled notification: ", method)

# MCP Protocol implementation

func _handle_initialize(id, request_id, params):
	# Process initialize request
	sessions[id]["capabilities"] = params.get("capabilities", {})
	
	_send_response(id, request_id, {
		"capabilities": {
			"resources": {},
			"tools": {}
		},
		"serverInfo": {
			"name": "Godot MCP",
			"version": "1.0.0"
		}
	})

func _handle_list_resources(id, request_id, params):
	var resources = []
	
	# Add current script resource
	var current_script = get_editor_interface().get_script_editor().get_current_script()
	if current_script:
		resources.append({
			"uri": "godot://script/current",
			"name": "Current Script",
			"description": "The currently active script in the editor",
			"mimeType": "text/plain"
		})
	
	# Add all scripts resource
	resources.append({
		"uri": "godot://scripts/all",
		"name": "All Project Scripts",
		"description": "List of all scripts in the project",
		"mimeType": "application/json"
	})
	
	_send_response(id, request_id, {
		"resources": resources
	})

func _handle_read_resource(id, request_id, params):
	var uri = params.get("uri", "")
	var contents = []
	
	match uri:
		"godot://script/current":
			var script = get_editor_interface().get_script_editor().get_current_script()
			if script:
				contents.append({
					"uri": uri,
					"text": script.source_code,
					"mimeType": "text/plain"
				})
		
		"godot://scripts/all":
			var scripts = _get_all_scripts()
			contents.append({
				"uri": uri,
				"text": JSON.stringify(scripts),
				"mimeType": "application/json"
			})
		
		_:
			return _send_error(id, request_id, -32602, "Unknown resource URI: " + uri)
	
	_send_response(id, request_id, {
		"contents": contents
	})

func _handle_list_tools(id, request_id, params):
	var tools = [
		{
			"name": "update-current-script",
			"description": "Update the currently open script content",
			"inputSchema": {
				"type": "object",
				"properties": {
					"content": {
						"type": "string",
						"description": "Content of the script"
					}
				},
				"required": ["content"]
			}
		},
		{
			"name": "read-script",
			"description": "Read the content of a specific script",
			"inputSchema": {
				"type": "object",
				"properties": {
					"scriptPath": {
						"type": "string",
						"description": "Path to the script file"
					}
				},
				"required": ["scriptPath"]
			}
		},
		{
			"name": "list-project-scripts",
			"description": "Lists all script files in a project directory",
			"inputSchema": {
				"type": "object",
				"properties": {
					"projectDir": {
						"type": "string",
						"description": "Path to the Godot project directory"
					}
				},
				"required": ["projectDir"]
			}
		}
	]
	
	_send_response(id, request_id, {
		"tools": tools
	})

func _handle_call_tool(id, request_id, params):
	var tool_name = params.get("name", "")
	var arguments = params.get("arguments", {})
	
	match tool_name:
		"update-current-script":
			var script = get_editor_interface().get_script_editor().get_current_script()
			if script:
				# Get the content parameter
				var content = arguments.get("content", "")
				
				# Update the script source
				script.source_code = content
				
				# Save the script
				var file = FileAccess.open(script.resource_path, FileAccess.WRITE)
				if file:
					file.store_string(content)
					file.close()
					_send_response(id, request_id, {
						"content": [
							{
								"type": "text",
								"text": "Script updated successfully"
							}
						]
					})
				else:
					_send_response(id, request_id, {
						"isError": true,
						"content": [
							{
								"type": "text",
								"text": "Failed to write script to file"
							}
						]
					})
			else:
				_send_response(id, request_id, {
					"isError": true,
					"content": [
						{
							"type": "text",
							"text": "No script is currently open in the editor"
						}
					]
				})
		
		"read-script":
			var path = arguments.get("scriptPath", "")
			if path:
				var file = FileAccess.open(path, FileAccess.READ)
				if file:
					var content = file.get_as_text()
					file.close()
					_send_response(id, request_id, {
						"content": [
							{
								"type": "text",
								"text": content
							}
						]
					})
				else:
					_send_response(id, request_id, {
						"isError": true,
						"content": [
							{
								"type": "text",
								"text": "Failed to read script at path: " + path
							}
						]
					})
			else:
				_send_response(id, request_id, {
					"isError": true,
					"content": [
						{
							"type": "text",
							"text": "Missing scriptPath parameter"
						}
					]
				})
		
		"list-project-scripts":
			var scripts = _get_all_scripts()
			_send_response(id, request_id, {
				"content": [
					{
						"type": "text",
						"text": JSON.stringify(scripts, "	")
					}
				]
			})
		
		_:
			_send_error(id, request_id, -32602, "Unknown tool: " + tool_name)

# Helper functions

func _send_response(id, request_id, result):
	var response = {
		"jsonrpc": "2.0",
		"id": request_id,
		"result": result
	}
	server.set_target_peer(id)
	server.put_packet(JSON.stringify(response).to_utf8_buffer())

func _send_error(id, request_id, code, message):
	var response = {
		"jsonrpc": "2.0",
		"id": request_id,
		"error": {
			"code": code,
			"message": message
		}
	}
	server.set_target_peer(id)
	server.put_packet(JSON.stringify(response).to_utf8_buffer())

func _get_all_scripts():
	var scripts = []
	# Recursively find all script files
	_scan_for_scripts("res://", scripts)
	return scripts

func _scan_for_scripts(path, scripts):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			var full_path = path + file_name
			
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					_scan_for_scripts(full_path + "/", scripts)
			elif file_name.ends_with(".gd") or file_name.ends_with(".cs"):
				scripts.append({
					"path": full_path,
					"name": file_name
				})
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
