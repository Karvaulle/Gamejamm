extends Area2D

@export var item_name: String = "Skull Coin"

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("collect_skull"):
		body.collect_skull(1)
		queue_free()
