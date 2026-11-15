class_name Loc
extends RefCounted
## Pure bilingual localization helper ("es" Spanish / "en" English).
## Kept in domain/services with zero SceneTree or Autoload dependencies.

static var lang: String = "es"


static func set_lang(new_lang: String) -> void:
	lang = "en" if new_lang.to_lower() == "en" else "es"


static func is_en() -> bool:
	return lang == "en"


static func pick(es: String, en: String) -> String:
	return en if lang == "en" else es
