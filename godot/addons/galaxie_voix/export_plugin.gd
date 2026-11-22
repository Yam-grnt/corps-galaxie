@tool
extends EditorPlugin
## Ajoute l'extension Android « GalaxieVoix » (reconnaissance vocale embarquée) aux exports Android.
## L'AAR contient tout : le moteur sherpa-onnx (classes et bibliothèque native arm64), le modèle français et la
## détection de voix. Il ne dépend d'aucune bibliothèque à télécharger au moment de l'export.
## Il est fabriqué à partir de plugin-voix/ (JAVA_HOME et ANDROID_HOME pointant sur .toolchain) :
##   node plugin-voix\preparer.js
##   godot\android\build\gradlew.bat -p plugin-voix assembleRelease
##   copy plugin-voix\build\outputs\aar\galaxie-voix-release.aar godot\addons\galaxie_voix\bin\

var _export: ExportVoix


func _enter_tree() -> void:
	_export = ExportVoix.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class ExportVoix extends EditorExportPlugin:
	func _get_name() -> String:
		return "GalaxieVoix"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["galaxie_voix/bin/galaxie-voix-release.aar"])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray()      # plus rien à télécharger : tout est dans l'AAR