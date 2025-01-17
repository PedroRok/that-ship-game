@tool
class_name WinShowValue
extends HBoxContainer

@export
var label_value : String
@export
var value : int

@export
var delay_to_show : int = 0
@export
var show_time : int = 0

@onready
var label : Label = $ValueLabel

@onready
var icon : TextureRect = $Icon

func _ready() -> void:
	# Certifique-se de que o Label tenha uma fonte configurada no tema ou manualmente
	var font: Font = label.get_theme_font("font")
	if not font:
		print("Erro: Nenhuma fonte definida no tema ou no Label!")
		return
	
	# Usa a largura atual do Label como base
	var total_width: int = int(label.size.x * 2.)
	if total_width <= 0:
		print("Erro: O tamanho do Label não está definido corretamente.")
		return
	
	# Gera e aplica o texto ajustado
	label.text = generate_aligned_text(label_value, str(value), total_width, font)
	label.visible_ratio = 0.0
	
	var tween : Tween = get_tree().create_tween()
	tween.tween_interval(delay_to_show)
	tween.tween_property(label, "visible_ratio", 1, show_time)
	tween.finished.connect(Callable(self, "show_icon"))
	show_icon(false)

func generate_aligned_text(left_text: String, right_text: String, total_width: int, font: Font) -> String:
	# Calcula o espaço usado pelos textos à esquerda e à direita
	var left_text_width: float = font.get_string_size(left_text).x
	var right_text_width: float = font.get_string_size(right_text).x
	
	# Calcula o espaço restante para os pontos
	var space: float = total_width - (left_text_width + right_text_width)
	if space <= 0:
		# Se não houver espaço suficiente, retorna os textos sem pontos
		return left_text + " " + right_text

	# Calcula a largura de um único ponto
	var dot_width: float = font.get_string_size(".").x
	
	# Calcula quantos pontos cabem no espaço restante
	var dots_count: int = int(space / dot_width)
	var dots: String = ".".repeat(dots_count)
	
	return left_text + dots + right_text
	

func show_icon(show : bool = true) ->void:
	if show:
		icon.modulate.a = 1
	else:
		icon.modulate.a = 0
