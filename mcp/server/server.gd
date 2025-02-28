class_name MCPServer
extends RefCounted

signal initialized
signal closed

var _protocol = MCPProtocol.new()
var _message_handler = MCPMessageHandler.new()
var _transport: MCPStdioTransport
var _logger = MCPLogger.new("MCPServer")

# Will be instantiated once the capability managers are created
var _tool_manager
var _resource_manager
var _prompt_manager

var server_info: Dictionary = {
    "name": "godot-mcp-server",
    "version": "1.0.0"
}

var server_capabilities: Dictionary = {
    "tools": {},
    "resources": {},
    "prompts": {},
}

var client_info: Dictionary = {}
var client_capabilities: Dictionary = {}
var _is_initialized: bool = false

func _init(p_server_info: Dictionary = {}, p_server_capabilities: Dictionary = {}):
    if p_server_info:
        server_info = p_server_info
    if p_server_capabilities:
        server_capabilities = p_server_capabilities
    
    # Create capability managers
    _tool_manager = load("res://mcp/capabilities/tools/manager.gd").new()
    _resource_manager = load("res://mcp/capabilities/resources/manager.gd").new()
    _prompt_manager = load("res://mcp/capabilities/prompts/manager.gd").new()
    
    # Connect message handler to managers
    _message_handler.register_handler("tools/list", _tool_manager, "_handle_list_tools")
    _message_handler.register_handler("tools/call", _tool_manager, "_handle_call_tool")
    _message_handler.register_handler("resources/list", _resource_manager, "_handle_list_resources")
    _message_handler.register_handler("resources/read", _resource_manager, "_handle_read_resource")
    _message_handler.register_handler("prompts/list", _prompt_manager, "_handle_list_prompts")
    _message_handler.register_handler("prompts/get", _prompt_manager, "_handle_get_prompt")
    
    # Pass the server reference to the managers
    _tool_manager.server = self
    _resource_manager.server = self
    _prompt_manager.server = self

func start(transport: MCPStdioTransport) -> void:
    _transport = transport
    _transport.message_received.connect(_on_message_received)
    _transport.transport_error.connect(_on_transport_error)
    _transport.start()
    _logger.info("Server started with transport %s" % transport)

func _on_message_received(message: Dictionary) -> void:
    _logger.debug("Received message: %s" % JSON.stringify(message))
    
    # Check if the message is a request or notification
    if message.has("id"):
        # It's a request
        var response = _handle_request(message)
        if response:
            _transport.send(response)
    else:
        # It's a notification
        _handle_notification(message)

func _handle_request(request: Dictionary) -> Dictionary:
    # Validate request format
    if not _protocol.validate_request(request):
        return _protocol.create_error_response(
            request.get("id", ""), 
            MCPTypes.MCPErrorCode.INVALID_REQUEST, 
            "Invalid request format"
        )
    
    # Handle initialization request specially
    if request.method == "initialize":
        return _handle_initialize_request(request)
    
    # Check if server is initialized
    if not _is_initialized:
        return _protocol.create_error_response(
            request.id, 
            MCPTypes.MCPErrorCode.INVALID_REQUEST, 
            "Server not initialized"
        )
    
    # Route request to appropriate handler
    return _message_handler.handle_request(request)

func _handle_notification(notification: Dictionary) -> void:
    # Validate notification format
    if not _protocol.validate_notification(notification):
        _logger.error("Invalid notification format: %s" % JSON.stringify(notification))
        return
    
    # Handle initialized notification specially
    if notification.method == "initialized":
        _handle_initialized_notification()
        return
    
    # Check if server is initialized
    if not _is_initialized:
        _logger.error("Received notification before initialization: %s" % JSON.stringify(notification))
        return
    
    # Route notification to appropriate handler
    _message_handler.handle_notification(notification)

func _handle_initialize_request(request: Dictionary) -> Dictionary:
    _logger.info("Handling initialize request")
    
    # Store client information
    client_info = request.params.get("clientInfo", {})
    client_capabilities = request.params.get("capabilities", {})
    
    _logger.debug("Client info: %s" % JSON.stringify(client_info))
    _logger.debug("Client capabilities: %s" % JSON.stringify(client_capabilities))
    
    # Return server information
    var response = {
        "jsonrpc": "2.0",
        "id": request.id,
        "result": {
            "serverInfo": server_info,
            "capabilities": server_capabilities
        }
    }
    
    return response

func _handle_initialized_notification() -> void:
    _logger.info("Received initialized notification")
    _is_initialized = true
    emit_signal("initialized")

func _on_transport_error(error: String) -> void:
    _logger.error("Transport error: %s" % error)

func send_notification(method: String, params: Dictionary = {}) -> void:
    if not _is_initialized:
        _logger.warn("Attempted to send notification before initialization")
        return
    
    var notification = _protocol.create_notification(method, params)
    _transport.send(notification)

func close() -> void:
    _logger.info("Closing server")
    _is_initialized = false
    _transport = null
    emit_signal("closed")

# Tool registration
func register_tool(tool_data: MCPTypes.MCPTool) -> void:
    _tool_manager.register_tool(tool_data)

# Resource registration
func register_resource(resource_data: MCPTypes.MCPResource) -> void:
    _resource_manager.register_resource(resource_data)

# Prompt registration
func register_prompt(prompt_data: MCPTypes.MCPPrompt) -> void:
    _prompt_manager.register_prompt(prompt_data)
