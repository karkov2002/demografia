class_name NumberFormat
extends RefCounted
## Écriture compacte des quantités affichées : entières jusqu'à 999, puis avec un suffixe et au plus
## 3 chiffres significatifs (1k, 2.54k, 25.4k, 254k, 1.2M, 3G…), pour que les textes restent courts.

const SUFFIXES := ["", "k", "M", "G", "T", "P", "E"]


static func compact(value: float) -> String:
	var magnitude := absf(value)
	if magnitude < 999.5:
		return str(roundi(value))
	var tier := 0
	while magnitude >= 999.5 and tier < SUFFIXES.size() - 1:
		magnitude /= 1000.0
		tier += 1
	var decimals := 2 if magnitude < 10.0 else (1 if magnitude < 100.0 else 0)
	var text := String.num(magnitude, decimals)
	if "." in text:
		text = text.rstrip("0").trim_suffix(".")
	return ("-" if value < 0.0 else "") + text + SUFFIXES[tier]


## Comme compact, précédé de son signe : +12, -3, +2.54k, 0.
static func signed(value: float) -> String:
	var text := compact(value)
	if text == "0" or text.begins_with("-"):
		return text
	return "+" + text
