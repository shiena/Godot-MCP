@tool
extends Control

var mcp_server = null
var transport = null

@onready var status_label = $VBoxContainer/StatusLabel
@onready var clients_label = $VBoxContainer/ClientsLabel
@onready var info_label = $VBoxContainer/InfoLabel

func _ready():
    update_display()
    # Update UI every second
    var timer = Timer.new()
    timer.wait_time = 1.0
    timer.timeout.connect(update_display)
    timer.autostart = true
    add_child(timer)

func set_mcp_server(server):
    mcp_server = server

func set_transport(t):
    transport = t
    if transport and is_instance_valid(info_label):
        # Update the port information in case it changed during initialization
        if transport is MCPSSETransport:
            info_label.text = "URL: http://localhost:%d/sse" % transport._port

func update_display():
    if not is_instance_valid(status_label) or not is_instance_valid(clients_label):
        return
    
    if mcp_server:
        status_label.text = "MCP Server: Running"
        status_label.modulate = Color.GREEN
        
        if transport and transport is MCPSSETransport:
            var client_count = transport._clients.size()
            clients_label.text = "Connected clients: %d" % client_count
            # Update port information
            if is_instance_valid(info_label):
                info_label.text = "URL: http://localhost:%d/sse" % transport._port
        else:
            clients_label.text = "Transport not available"
    else:
        status_label.text = "MCP Server: Not running"
        status_label.modulate = Color.RED
        clients_label.text = ""
