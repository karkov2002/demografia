class_name ModalPopup
extends Control
## Base des fenêtres modales : voile sombre sur tout l'écran, qui bloque les clics derrière, et fenêtre
## centrée sur fond sombre dont le contenu est empilé verticalement.

const SURFACE := Color("1a1a19")
const INK := Color(0.92, 0.91, 0.88)
const MUTED_INK := Color(0.62, 0.61, 0.58)


## Construit le voile et la fenêtre ; renvoie la pile où ajouter le contenu.
func _build_frame() -> VBoxContainer:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.color = Color(0.0, 0.0, 0.0, 0.6)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	return content


static func _label(text: String, font_size: int, color: Color,
		alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Gros bouton de validation, centré.
static func _main_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return button
