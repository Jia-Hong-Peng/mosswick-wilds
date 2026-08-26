class_name TestContext
extends RefCounted
## Collects assertion results for one test suite.

var suite_name: String
var assert_count := 0
var failures: PackedStringArray = []


func _init(name: String) -> void:
	suite_name = name


func check(condition: bool, message: String) -> void:
	assert_count += 1
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s (got %s, expected %s)" % [message, str(actual), str(expected)])
