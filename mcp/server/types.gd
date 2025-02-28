class_name MCPTypes
extends RefCounted

# Custom classes for MCP protocol messages

class MCPRequest:
    var id: String
    var method: String
    var params: Dictionary

    func _init(p_id: String, p_method: String, p_params: Dictionary = {}):
        id = p_id
        method = p_method
        params = p_params

    func to_dict() -> Dictionary:
        return {
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params
        }

class MCPResponse:
    var id: String
    var result: Variant
    
    func _init(p_id: String, p_result: Variant):
        id = p_id
        result = p_result
    
    func to_dict() -> Dictionary:
        return {
            "jsonrpc": "2.0",
            "id": id,
            "result": result
        }

class MCPErrorResponse:
    var id: String
    var code: int
    var message: String
    var data: Variant
    
    func _init(p_id: String, p_code: int, p_message: String, p_data: Variant = null):
        id = p_id
        code = p_code
        message = p_message
        data = p_data
    
    func to_dict() -> Dictionary:
        var result = {
            "jsonrpc": "2.0",
            "id": id,
            "error": {
                "code": code,
                "message": message
            }
        }
        if data != null:
            result.error.data = data
        return result

class MCPNotification:
    var method: String
    var params: Dictionary
    
    func _init(p_method: String, p_params: Dictionary = {}):
        method = p_method
        params = p_params
    
    func to_dict() -> Dictionary:
        return {
            "jsonrpc": "2.0",
            "method": method,
            "params": params
        }

# Tool-related classes
class MCPTool:
    var name: String
    var description: String
    var input_schema: Dictionary
    
    func _init(p_name: String, p_description: String, p_input_schema: Dictionary):
        name = p_name
        description = p_description
        input_schema = p_input_schema
    
    func to_dict() -> Dictionary:
        return {
            "name": name,
            "description": description,
            "inputSchema": input_schema
        }

# Resource-related classes
class MCPResource:
    var uri: String
    var name: String
    var description: String
    var mime_type: String
    
    func _init(p_uri: String, p_name: String, p_description: String = "", p_mime_type: String = ""):
        uri = p_uri
        name = p_name
        description = p_description
        mime_type = p_mime_type
    
    func to_dict() -> Dictionary:
        var result = {
            "uri": uri,
            "name": name
        }
        if description:
            result.description = description
        if mime_type:
            result.mimeType = mime_type
        return result

class MCPResourceContent:
    var uri: String
    var text: String
    var blob: String
    var mime_type: String
    
    func _init(p_uri: String, p_mime_type: String = ""):
        uri = p_uri
        mime_type = p_mime_type
    
    func to_dict() -> Dictionary:
        var result = {
            "uri": uri
        }
        if text:
            result.text = text
        if blob:
            result.blob = blob
        if mime_type:
            result.mimeType = mime_type
        return result

# Prompt-related classes
class MCPPromptArgument:
    var name: String
    var description: String
    var required: bool
    
    func _init(p_name: String, p_description: String, p_required: bool = false):
        name = p_name
        description = p_description
        required = p_required
    
    func to_dict() -> Dictionary:
        var result = {
            "name": name
        }
        if description:
            result.description = description
        if required:
            result.required = required
        return result

class MCPPrompt:
    var name: String
    var description: String
    var arguments: Array[MCPPromptArgument]
    
    func _init(p_name: String, p_description: String, p_arguments: Array[MCPPromptArgument] = []):
        name = p_name
        description = p_description
        arguments = p_arguments
    
    func to_dict() -> Dictionary:
        var result = {
            "name": name
        }
        if description:
            result.description = description
        if arguments.size() > 0:
            var args_array = []
            for arg in arguments:
                args_array.append(arg.to_dict())
            result.arguments = args_array
        return result

# Error codes
enum MCPErrorCode {
    PARSE_ERROR = -32700,
    INVALID_REQUEST = -32600,
    METHOD_NOT_FOUND = -32601,
    INVALID_PARAMS = -32602,
    INTERNAL_ERROR = -32603,
    
    # Custom error codes
    RESOURCE_NOT_FOUND = -32000,
    TOOL_EXECUTION_ERROR = -32001,
    PROMPT_ERROR = -32002
}
