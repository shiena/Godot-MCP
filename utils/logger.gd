class_name MCPLogger
extends RefCounted

enum LogLevel {
    DEBUG,
    INFO,
    WARN,
    ERROR
}

var _module_name: String
var _min_level: int = LogLevel.INFO

func _init(module_name: String = ""):
    _module_name = module_name

func set_level(level: int) -> void:
    _min_level = level

func debug(message: String) -> void:
    if _min_level <= LogLevel.DEBUG:
        _log(LogLevel.DEBUG, message)

func info(message: String) -> void:
    if _min_level <= LogLevel.INFO:
        _log(LogLevel.INFO, message)

func warn(message: String) -> void:
    if _min_level <= LogLevel.WARN:
        _log(LogLevel.WARN, message)

func error(message: String) -> void:
    if _min_level <= LogLevel.ERROR:
        _log(LogLevel.ERROR, message)

func _log(level: int, message: String) -> void:
    var level_str = _level_to_string(level)
    var module_prefix = _module_name if _module_name else "MCP"
    
    # Format the log message
    var formatted_message = "[%s][%s] %s" % [level_str, module_prefix, message]
    
    # Print to stdout (will go to Godot console)
    print(formatted_message)
    
    # For errors, also print to stderr
    if level == LogLevel.ERROR:
        printerr(formatted_message)

func _level_to_string(level: int) -> String:
    match level:
        LogLevel.DEBUG:
            return "DEBUG"
        LogLevel.INFO:
            return "INFO"
        LogLevel.WARN:
            return "WARN"
        LogLevel.ERROR:
            return "ERROR"
        _:
            return "UNKNOWN"
