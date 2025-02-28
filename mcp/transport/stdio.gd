class_name MCPStdioTransport
extends RefCounted

signal message_received(message: Dictionary)
signal transport_error(error: String)

var _logger = MCPLogger.new("MCPStdioTransport")

func _init():
    _logger.debug("Initializing STDIO transport")

func start() -> void:
    _logger.info("Starting STDIO transport")
    # Setup stdin reading
    if OS.get_name() != "HTML5":
        OS.set_low_processor_usage_mode(true)
    
    # Make sure we can read from stdin without blocking the main thread
    # We're using the updated method name
    if OS.get_stdin_type() != OS.STD_HANDLE_INVALID:
        # Start watching for input on a separate thread
        var thread = Thread.new()
        thread.start(_read_stdin_thread)
    else:
        _logger.error("Standard input is not available")

func send(message: Dictionary) -> void:
    var json_string = JSON.stringify(message)
    _logger.debug("Sending message: %s" % json_string)
    print(json_string)
    # Ensure output is flushed immediately
    # OS.flush_standard_output() doesn't exist, removing this call
    # The print() function should flush automatically in most cases

func _read_stdin_thread() -> void:
    _logger.debug("Starting stdin reading thread")
    while OS.get_stdin_type() != OS.STD_HANDLE_INVALID:
        # Read one line from stdin
        var line = OS.read_string_from_stdin(8192) # Using a reasonable buffer size
        if line:
            _logger.debug("Received line: %s" % line)
            # Process the line (parse JSON)
            var json = JSON.new()
            var error = json.parse(line)
            if error == OK:
                var message = json.get_data()
                # Emit signal on the main thread
                call_deferred("emit_signal", "message_received", message)
            else:
                var error_message = "JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()]
                _logger.error(error_message)
                call_deferred("emit_signal", "transport_error", error_message)
        else:
            # No data, sleep to avoid busy waiting
            OS.delay_msec(10)
