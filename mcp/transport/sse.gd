class_name MCPSSETransport
extends RefCounted

signal message_received(message: Dictionary)
signal transport_error(error: String)

var _server: TCPServer
var _logger = MCPLogger.new("MCPSSETransport")
var _clients = []
var _port: int
var _thread: Thread
var _running = false

func _init(port: int = 8080):
    _port = port
    _logger.debug("Initializing SSE transport on port %d" % _port)

func start() -> void:
    _logger.info("Starting SSE transport on port %d" % _port)
    
    _server = TCPServer.new()
    
    # Try a few port numbers if the default one is taken
    var max_attempts = 5
    var current_port = _port
    var error = ERR_ALREADY_IN_USE
    
    for attempt in range(max_attempts):
        error = _server.listen(current_port)
        if error == OK:
            _port = current_port  # Update port if we had to change it
            break
        elif error == ERR_ALREADY_IN_USE:
            # Port already in use, try the next one
            current_port += 1
            _logger.warning("Port %d already in use, trying port %d" % [current_port-1, current_port])
        else:
            # Some other error, break out
            break
    
    if error != OK:
        _logger.error("Failed to start TCP server: %d" % error)
        emit_signal("transport_error", "Failed to start TCP server")
        return
    
    _logger.info("TCP server successfully started on port %d" % _port)
    
    _running = true
    # Start polling in a thread
    _thread = Thread.new()
    _thread.start(Callable(self, "_poll_server"))
    
func stop() -> void:
    if _running:
        _running = false
        # Wait for thread to finish
        if _thread and _thread.is_started():
            _thread.wait_to_finish()
        
        # Close all connections
        for client in _clients:
            if client.is_connected_to_host():
                client.disconnect_from_host()
        
        _clients.clear()
        
        # Stop the server
        if _server:
            _server.stop()
    
func send(message: Dictionary) -> void:
    var json_string = JSON.stringify(message)
    _logger.debug("Sending message to %d clients: %s" % [_clients.size(), json_string])
    
    # Format as SSE message and send to all connected clients
    var disconnect_indices = []
    for i in range(_clients.size()):
        var client = _clients[i]
        if client.is_connected_to_host():
            var sse_message = "data: %s\n\n" % json_string
            client.put_data(sse_message.to_utf8_buffer())
        else:
            disconnect_indices.append(i)
    
    # Clean up disconnected clients (remove in reverse order to maintain indices)
    disconnect_indices.sort()
    disconnect_indices.reverse()
    for idx in disconnect_indices:
        _clients.remove_at(idx)

func _poll_server() -> void:
    _logger.debug("Starting TCP server polling thread")
    
    while _running:
        # Accept new connections
        if _server.is_connection_available():
            var client = _server.take_connection()
            call_deferred("_handle_new_connection", client)
        
        # Small delay to avoid busy waiting
        OS.delay_msec(10)

func _handle_new_connection(client: StreamPeerTCP) -> void:
    # Create packet peer to handle HTTP protocol
    var packet_peer = PacketPeerStream.new()
    packet_peer.set_stream_peer(client)
    
    # Read HTTP request - wait for data
    var start_time = Time.get_ticks_msec()
    var timeout = 1000  # 1 second timeout
    
    while client.get_available_bytes() <= 0:
        OS.delay_msec(10)
        if Time.get_ticks_msec() - start_time > timeout:
            _logger.error("Connection timeout waiting for HTTP request")
            client.disconnect_from_host()
            return

    # Read and parse HTTP request
    var request = client.get_string()
    var lines = request.split("\n")
    if lines.size() < 1:
        _logger.error("Invalid HTTP request")
        client.disconnect_from_host()
        return
        
    var request_line = lines[0].strip_edges()
    var parts = request_line.split(" ")
    if parts.size() < 2:
        _logger.error("Invalid HTTP request line: %s" % request_line)
        client.disconnect_from_host() 
        return
        
    var method = parts[0]
    var url = parts[1]
    
    _logger.debug("Client connected with %s request to %s" % [method, url])
    
    # Parse headers
    var headers = {}
    var i = 1
    while i < lines.size():
        var line = lines[i].strip_edges()
        i += 1
        if line.is_empty():
            break  # End of headers
            
        var header_parts = line.split(":", true, 1)
        if header_parts.size() == 2:
            headers[header_parts[0].to_lower()] = header_parts[1].strip_edges()
    
    # Read body if content length is specified
    var body = ""
    if headers.has("content-length"):
        var content_length = int(headers["content-length"])
        if content_length > 0:
            # Body starts after the empty line after headers, join remaining lines
            var body_lines = []
            while i < lines.size():
                body_lines.append(lines[i])
                i += 1
            body = "\n".join(body_lines)
    
    if url == "/sse":
        # Handle SSE endpoint
        var response = "HTTP/1.1 200 OK\r\n"
        response += "Content-Type: text/event-stream\r\n"
        response += "Cache-Control: no-cache\r\n"
        response += "Connection: keep-alive\r\n"
        response += "Access-Control-Allow-Origin: *\r\n"
        response += "\r\n"
        
        client.put_data(response.to_utf8_buffer())
        _clients.append(client)
        _logger.info("SSE client connected, total clients: %d" % _clients.size())
        
    elif url == "/messages":
        # Handle POST messages endpoint
        if method == "POST":
            _logger.debug("Received message: %s" % body)
            
            # Process JSON message
            var json = JSON.new()
            var error = json.parse(body)
            if error == OK:
                var message = json.get_data()
                # Emit signal on the main thread
                call_deferred("emit_signal", "message_received", message)
                
                # Send response
                var response = "HTTP/1.1 200 OK\r\n"
                response += "Content-Type: application/json\r\n"
                response += "Access-Control-Allow-Origin: *\r\n"
                response += "Content-Length: 2\r\n"
                response += "\r\n{}"
                client.put_data(response.to_utf8_buffer())
            else:
                var error_message = "JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()]
                _logger.error(error_message)
                
                # Send error response
                var response = "HTTP/1.1 400 Bad Request\r\n"
                response += "Content-Type: application/json\r\n"
                response += "Access-Control-Allow-Origin: *\r\n"
                response += "\r\n{\"error\": \"Invalid JSON\"}"
                client.put_data(response.to_utf8_buffer())
                
            # Close connection after handling the request
            client.disconnect_from_host()
                
        elif method == "OPTIONS":
            # Handle CORS preflight request
            var response = "HTTP/1.1 200 OK\r\n"
            response += "Access-Control-Allow-Origin: *\r\n"
            response += "Access-Control-Allow-Methods: POST, OPTIONS\r\n"
            response += "Access-Control-Allow-Headers: Content-Type\r\n"
            response += "\r\n"
            client.put_data(response.to_utf8_buffer())
            client.disconnect_from_host()
        else:
            # Method not allowed
            var response = "HTTP/1.1 405 Method Not Allowed\r\n"
            response += "Allow: POST, OPTIONS\r\n"
            response += "\r\n"
            client.put_data(response.to_utf8_buffer())
            client.disconnect_from_host()
    else:
        # Not found
        var response = "HTTP/1.1 404 Not Found\r\n\r\n"
        client.put_data(response.to_utf8_buffer())
        client.disconnect_from_host()
