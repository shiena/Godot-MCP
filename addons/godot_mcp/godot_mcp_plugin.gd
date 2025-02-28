@tool
extends EditorPlugin

var mcp_server = null
var dock = null
var transport = null
var config = {
    "name": "godot-mcp",
    "version": "0.1.0"
}

func _enter_tree():
    # Initialize MCP server
    mcp_server = load("res://mcp/server/server.gd").new(config)
    
    # Register tools and capabilities
    _register_tools()
    
    # Create and start SSE transport
    transport = load("res://mcp/transport/sse.gd").new(8080)
    
    # First start the transport
    transport.start()
    
    # Connect signals from transport to server manually instead of passing transport to start()
    transport.message_received.connect(mcp_server._on_transport_message_received)
    transport.transport_error.connect(mcp_server._on_transport_error)
    
    # Set the transport on the server
    mcp_server.set_transport(transport)
    
    # Now start the server
    mcp_server.start()
    
    # Create UI
    _create_ui()
    
    print("Godot MCP Plugin started on http://localhost:%d" % transport._port)

func _exit_tree():
    # Clean up resources
    if dock:
        remove_control_from_docks(dock)
        dock.free()
    
    if mcp_server:
        # Don't call stop() on mcp_server if it doesn't exist
        # Just let it be garbage collected
        pass
    
    if transport:
        if transport.message_received.is_connected(mcp_server._on_transport_message_received):
            transport.message_received.disconnect(mcp_server._on_transport_message_received)
        
        if transport.transport_error.is_connected(mcp_server._on_transport_error):
            transport.transport_error.disconnect(mcp_server._on_transport_error)
        
        transport.stop()

func _register_tools():
    # Register your MCP tools here
    # Example:
    # mcp_server.register_tool("your_tool_name", YourToolClass)
    pass

func _create_ui():
    # Create a simple dock to show MCP status
    dock = preload("res://addons/godot_mcp/dock.tscn").instantiate()
    dock.set_mcp_server(mcp_server)
    # Fix: Pass the transport object directly to the dock
    dock.set_transport(transport)
    add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
