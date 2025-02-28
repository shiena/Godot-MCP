class_name MCPProtocol
extends RefCounted

var _logger = MCPLogger.new("MCPProtocol")

func validate_request(request: Dictionary) -> bool:
    if not request.has("jsonrpc") or request.jsonrpc != "2.0":
        return false
    if not request.has("id"):
        return false
    if not request.has("method"):
        return false
    return true

func validate_notification(notification: Dictionary) -> bool:
    if not notification.has("jsonrpc") or notification.jsonrpc != "2.0":
        return false
    if not notification.has("method"):
        return false
    return true

func create_response(id: String, result: Variant) -> Dictionary:
    return {
        "jsonrpc": "2.0",
        "id": id,
        "result": result
    }

func create_error_response(id: String, code: int, message: String, data = null) -> Dictionary:
    var response = {
        "jsonrpc": "2.0",
        "id": id,
        "error": {
            "code": code,
            "message": message
        }
    }
    
    if data != null:
        response.error.data = data
    
    return response

func create_notification(method: String, params: Dictionary = {}) -> Dictionary:
    return {
        "jsonrpc": "2.0",
        "method": method,
        "params": params
    }
