extends Object
class_name GameLogger

## Logging Utility
## Provides structured logging with levels and timestamps

enum Level {
	DEBUG,
	INFO,
	WARN,
	ERROR
}

static var current_level: Level = Level.INFO

static func debug(message: String, context: String = "") -> void:
	if current_level <= Level.DEBUG:
		_log("DEBUG", message, context)

static func info(message: String, context: String = "") -> void:
	if current_level <= Level.INFO:
		_log("INFO", message, context)

static func warn(message: String, context: String = "") -> void:
	if current_level <= Level.WARN:
		_log("WARN", message, context)
		push_warning(message)

static func error(message: String, context: String = "") -> void:
	if current_level <= Level.ERROR:
		_log("ERROR", message, context)
		push_error(message)

static func _log(level: String, message: String, context: String) -> void:
	var timestamp = Time.get_datetime_string_from_system()
	var ctx = ("[%s] " % context) if not context.is_empty() else ""
	print("[%s] %s%s%s" % [timestamp, level, ctx, message])

static func set_level(level: Level) -> void:
	current_level = level
