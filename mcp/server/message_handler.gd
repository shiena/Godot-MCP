class_name MCPMessageHandler
extends RefCounted

var _logger = MCPLogger.new("MCPMessageHandler")
var _protocol = MCPProtocol.new()
var _handlers = {}

func register_handler(method: String, target: Object, function: String) -> void:
	_handlers[method] = {"target": target, "function": function}
	_logger.debug("Registered handler for method: %s" % method)

func handle_request(request: Dictionary) -> Dictionary:
	var method = request.method
	_logger.debug("Handling request for method: %s" % method)
	
	if not _handlers.has(method):
		return _protocol.create_error_response(
			request.id, 
			MCPTypes.MCPErrorCode.METHOD_NOT_FOUND, 
			"Method not found: %s" % method
		)
	
	var handler = _handlers[method]
	
	# Call the handler function
	var result
	if handler.target.has_method(handler.function):
		result = handler.target.call(handler.function, request)
	else:
		var error = "Method %s not found on target object" % handler.function
		_logger.error(error)
		return _protocol.create_error_response(
			request.id, 
			MCPTypes.MCPErrorCode.INTERNAL_ERROR, 
			error
		)
	
	# Create response
	return _protocol.create_response(request.id, result)

func handle_notification(notif_data: Dictionary) -> void:
	var method = notif_data.method
	_logger.debug("Handling notification for method: %s" % method)
	
	if not _handlers.has(method):
		_logger.warn("No handler found for notification method: %s" % method)
		return
	
	var handler = _handlers[method]
	
	# Call the handler function
	if handler.target.has_method(handler.function):
		handler.target.call(handler.function, notif_data)
	else:
		_logger.error("Method %s not found on target object for notification %s" % [handler.function, method])
