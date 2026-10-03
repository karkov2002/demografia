class_name ConfirmPopup
extends ModalPopup
## Question à deux réponses : annuler (bouton de gauche, ou Échap) ou confirmer (bouton de droite). Le
## message sous le titre est facultatif (vide : pas de message).

signal confirmed
signal cancelled


func setup(title: String, message: String, cancel_text: String, confirm_text: String) -> void:
	var content := _build_frame()
	content.add_child(_label(title, 24, INK))
	if message != "":
		content.add_child(_label(message, 15, MUTED_INK))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	var cancel := _main_button(cancel_text)
	cancel.pressed.connect(_cancel)
	buttons.add_child(cancel)
	var confirm := _main_button(confirm_text)
	confirm.pressed.connect(confirmed.emit)
	buttons.add_child(confirm)
	content.add_child(buttons)
	cancel.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()


func _cancel() -> void:
	cancelled.emit()
	queue_free()
