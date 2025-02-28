@tool
class_name MCPStdioServer
extends Node

var _server: MCPServer
var _transport: MCPStdioTransport
var _logger = MCPLogger.new("MCPStdioServer")

# Configuration
var server_info = {
    "name": "godot-mcp-server",
    "version": "1.0.0",
    "vendor": "Godot Engine",
    "implementation": "Godot MCP implementation"
}

var server_capabilities = {
    "tools": {
        # We advertise support for tools capability
        "supportedInterfaces": ["text"]
    },
    "resources": {
        # We advertise support for resources capability
        "supportedTypes": [
            "text/plain", 
            "text/x-gdscript",
            "application/json"
        ]
    },
    "prompts": {
        # We advertise support for prompts capability
    }
}

func _enter_tree():
    # Set debug log level
    _logger.set_level(MCPLogger.LogLevel.DEBUG)
    _logger.info("Starting MCP STDIO server")
    
    # Create and configure server
    _create_server()
    
    # Register default capabilities
    _register_default_capabilities()
    
    # Start server with stdio transport
    _start_server()

func _exit_tree():
    _logger.info("Stopping MCP STDIO server")
    if _server:
        _server.close()
        _server = null

func _create_server():
    # Create MCP Server with configured info and capabilities
    _server = MCPServer.new(server_info, server_capabilities)
    _server.initialized.connect(_on_server_initialized)
    _server.closed.connect(_on_server_closed)

func _start_server():
    # Create and start the STDIO transport
    _transport = MCPStdioTransport.new()
    _server.start(_transport)

func _register_default_capabilities():
    # Register node tools
    _register_node_tools()
    
    # Register resources
    _register_resources()
    
    # Register prompts
    _register_prompts()

func _register_node_tools():
    # Example node tools
    var tool = MCPTypes.Tool.new(
        "listNodes",
        "Lists all nodes in the current scene",
        {
            "type": "object",
            "properties": {}
        }
    )
    _server.register_tool(tool)
    
    # TODO: Add more node tools

func _register_resources():
    # Example resources
    var resource = MCPTypes.Resource.new(
        "project://project.godot",
        "Project Config",
        "Godot project configuration file",
        "application/godot-project"
    )
    _server.register_resource(resource)
    
    # Template for scenes
    var scene_resource = MCPTypes.Resource.new(
        "scene://{scene_path}",
        "Scene",
        "Godot scene file",
        "text/x-godot-scene"
    )
    _server.register_resource(scene_resource)
    
    # TODO: Add more resources

func _register_prompts():
    # Get access to the prompt manager
    var prompt_manager = _server._prompt_manager
    
    # Example: Create Node prompt
    var create_node_args = [
        MCPTypes.PromptArgument.new("node_type", "Type of node to create", true),
        MCPTypes.PromptArgument.new("node_name", "Name for the new node", false)
    ]
    
    var create_node_template = """
    Create a new {node_type} node in the current scene.
    
    Please provide:
    1. The basic configuration for this node
    2. Any scripts that should be attached to it
    3. Explanation of how to use this node in the game/application
    """
    
    prompt_manager.create_prompt_template(
        "createNode", 
        "Create a new node with the specified configuration", 
        create_node_template, 
        create_node_args
    )
    
    # TODO: Add more prompts

func _on_server_initialized():
    _logger.info("MCP server initialized successfully")

func _on_server_closed():
    _logger.info("MCP server closed")
