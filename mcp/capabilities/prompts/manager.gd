class_name MCPPromptManager
extends RefCounted

var _logger = MCPLogger.new("MCPPromptManager")
var _prompts = {}
var server = null

func register_prompt(prompt_data: MCPTypes.MCPPrompt) -> void:
    _prompts[prompt_data.name] = prompt_data
    _logger.info("Registered prompt: %s" % prompt_data.name)

func _handle_list_prompts(_request: Dictionary) -> Dictionary:
    _logger.debug("Handling list_prompts request")
    
    var prompts_array = []
    for name in _prompts:
        prompts_array.append(_prompts[name].to_dict())
    
    return {"prompts": prompts_array}

func _handle_get_prompt(request: Dictionary) -> Dictionary:
    var name = request.params.name
    _logger.debug("Handling get_prompt request for: %s" % name)
    
    if not _prompts.has(name):
        return {
            "prompt": null,
            "error": "Prompt not found: %s" % name
        }
    
    return {"prompt": _prompts[name].to_dict()}
