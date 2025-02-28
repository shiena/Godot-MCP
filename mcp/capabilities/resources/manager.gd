class_name MCPResourceManager
extends RefCounted

var _logger = MCPLogger.new("MCPResourceManager")
var _resources = {}
var _resource_loaders = {}
var server = null

func register_resource(resource_data: MCPTypes.MCPResource) -> void:
    _resources[resource_data.uri] = resource_data
    _logger.info("Registered resource: %s" % resource_data.uri)

func register_resource_loader(uri: String, loader: Callable) -> void:
    _resource_loaders[uri] = loader
    _logger.debug("Registered loader for resource: %s" % uri)

func _handle_list_resources(_request: Dictionary) -> Dictionary:
    _logger.debug("Handling list_resources request")
    
    var resources_array = []
    for uri in _resources:
        resources_array.append(_resources[uri].to_dict())
    
    return {"resources": resources_array}

func _handle_read_resource(request: Dictionary) -> Dictionary:
    var uri = request.params.uri
    _logger.debug("Handling read_resource request for URI: %s" % uri)
    
    if not _resources.has(uri) and not _has_uri_template_match(uri):
        return {
            "contents": [
                {
                    "uri": uri,
                    "text": "Resource not found: %s" % uri
                }
            ]
        }
    
    if not _resource_loaders.has(uri) and not _has_loader_for_uri(uri):
        return {
            "contents": [
                {
                    "uri": uri,
                    "text": "No loader found for resource: %s" % uri
                }
            ]
        }
    
    # Get the loader and execute it
    var loader = _get_loader_for_uri(uri)
    if not loader:
        return {
            "contents": [
                {
                    "uri": uri,
                    "text": "Failed to find loader for resource: %s" % uri
                }
            ]
        }
    
    # Execute the loader and handle errors properly
    var result = loader.call(uri)
    if result == null or (result is int and result < 0):
        var error_msg = "Error loading resource %s: Failed to load resource" % uri
        _logger.error(error_msg)
        return {
            "contents": [
                {
                    "uri": uri,
                    "text": error_msg
                }
            ]
        }
    
    # If the result is a string, convert it to a proper content structure
    if typeof(result) == TYPE_STRING:
        result = {
            "contents": [
                {
                    "uri": uri,
                    "text": result
                }
            ]
        }
    
    return result

func _has_uri_template_match(uri: String) -> bool:
    # Check if any registered resource URI could be a template match
    for resource_uri in _resources:
        if _is_uri_template(resource_uri) and _matches_uri_template(uri, resource_uri):
            return true
    return false

func _is_uri_template(uri: String) -> bool:
    return "{" in uri and "}" in uri

func _matches_uri_template(uri: String, template: String) -> bool:
    # Very basic template matching - replace each {param} with a .* regex
    var regex_pattern = template.replace("{", "(.*)").replace("}", "(.*)")
    var regex = RegEx.new()
    regex.compile(regex_pattern)
    return regex.search(uri) != null

func _has_loader_for_uri(uri: String) -> bool:
    # Check for direct match
    if _resource_loaders.has(uri):
        return true
    
    # Check for template match
    for loader_uri in _resource_loaders:
        if _is_uri_template(loader_uri) and _matches_uri_template(uri, loader_uri):
            return true
    
    return false

func _get_loader_for_uri(uri: String) -> Callable:
    # Direct match
    if _resource_loaders.has(uri):
        return _resource_loaders[uri]
    
    # Template match
    for loader_uri in _resource_loaders:
        if _is_uri_template(loader_uri) and _matches_uri_template(uri, loader_uri):
            return _resource_loaders[loader_uri]
    
    return Callable()
