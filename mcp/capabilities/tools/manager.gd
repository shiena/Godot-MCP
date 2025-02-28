class_name MCPToolManager
extends RefCounted

var _logger = MCPLogger.new("MCPToolManager")
var _tools = {}
var server = null

func register_tool(tool_data: MCPTypes.MCPTool) -> void:
    _tools[tool_data.name] = {
        "data": tool_data,
        "callback": null
    }
    _logger.info("Registered tool: %s" % tool_data.name)

func register_tool_callback(tool_name: String, callback: Callable) -> void:
    if not _tools.has(tool_name):
        _logger.error("Cannot register callback for unknown tool: %s" % tool_name)
        return
    
    _tools[tool_name].callback = callback
    _logger.debug("Registered callback for tool: %s" % tool_name)

func _handle_list_tools(request: Dictionary) -> Dictionary:
    _logger.debug("Handling list_tools request")
    
    var tools_array = []
    for tool_name in _tools:
        tools_array.append(_tools[tool_name].data.to_dict())
    
    return {"tools": tools_array}

func _handle_call_tool(request: Dictionary) -> Dictionary:
    var tool_name = request.params.name
    var arguments = request.params.get("arguments", {})
    var progress_token = request.params.get("_meta", {}).get("progressToken")
    
    _logger.debug("Handling call_tool request for tool: %s" % tool_name)
    
    if not _tools.has(tool_name):
        return {
            "isError": true,
            "content": [
                {
                    "type": "text",
                    "text": "Tool not found: %s" % tool_name
                }
            ]
        }
    
    var tool_info = _tools[tool_name]
    
    if not tool_info.callback:
        return {
            "isError": true,
            "content": [
                {
                    "type": "text",
                    "text": "No callback registered for tool: %s" % tool_name
                }
            ]
        }
    
    # Execute the tool callback
    var result
    var context = {
        "progress_token": progress_token, 
        "server": server
    }
    
    # Use a safer error handling approach
    result = tool_info.callback.call(arguments, context)
    if result == null or (result is int and result < 0):  # Basic error check
        var error_msg = "Error executing tool %s" % tool_name
        _logger.error(error_msg)
        return {
            "isError": true,
            "content": [
                {
                    "type": "text",
                    "text": error_msg
                }
            ]
        }
    
    # If the result is a string, convert it to a proper content structure
    if typeof(result) == TYPE_STRING:
        result = {
            "content": [
                {
                    "type": "text",
                    "text": result
                }
            ]
        }
    
    return result

func report_progress(progress_token: String, progress: int, total: int) -> void:
    if not server:
        _logger.error("Cannot report progress: server reference is null")
        return
    
    if not progress_token:
        _logger.warn("Cannot report progress: no progress token provided")
        return
    
    server.send_notification("notifications/progress", {
        "progressToken": progress_token,
        "progress": progress,
        "total": total
    })
