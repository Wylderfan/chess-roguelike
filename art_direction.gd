class_name CastlePrint
extends RefCounted
# Original authored artwork. No animation touches board geometry or input timing.
const ROOM = preload("res://assets/art/knight-room.svg")
const WHITE = [null, preload("res://assets/art/white-pawn.svg"), preload("res://assets/art/white-knight.svg"), preload("res://assets/art/white-bishop.svg"), preload("res://assets/art/white-rook.svg"), preload("res://assets/art/white-queen.svg"), preload("res://assets/art/white-king.svg")]
const BLACK = [null, preload("res://assets/art/black-pawn.svg"), preload("res://assets/art/black-knight.svg"), preload("res://assets/art/black-bishop.svg"), preload("res://assets/art/black-rook.svg"), preload("res://assets/art/black-queen.svg"), preload("res://assets/art/black-king.svg")]
const INK = Color("20363e")
const PAPER = Color("ead7b2")
const COPPER = Color("b66a4d")
static func backdrop(c: CanvasItem, size: Vector2, screen: String, title: Font, body: Font) -> void:
	var front = screen in ["menu", "settings"]
	c.draw_rect(Rect2(Vector2.ZERO,size), PAPER if front else INK)
	if front:
		# A printed page edge, not a texture overlay on interactive content.
		c.draw_rect(Rect2(Vector2(18,18),size-Vector2(36,36)), Color("b49b74"),false,1)
		if size.x >= 940:
			var art_width = minf(size.x * .51, (size.y-60)*600/700)
			c.draw_texture_rect(ROOM,Rect2(Vector2(size.x-art_width-28,28),Vector2(art_width,art_width*700/600)),false)
			c.draw_string(body,Vector2(64,88),"THE CASTLE PRINT",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("795641"))
			c.draw_string(title,Vector2(59,181),"KNIGHT",HORIZONTAL_ALIGNMENT_LEFT,-1,78,INK)
			c.draw_string(title,Vector2(59,258),"CHESS",HORIZONTAL_ALIGNMENT_LEFT,-1,78,INK)
			c.draw_line(Vector2(64,289),Vector2(393,289),COPPER,3,true)
			c.draw_string(body,Vector2(64,317),"A BOARD. TWO ARMIES. YOUR NEXT MOVE.",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("795641"))
		else:
			c.draw_string(title,Vector2(38,74),"KNIGHT CHESS",HORIZONTAL_ALIGNMENT_LEFT,-1,40,INK)
			var w = 256.0
			c.draw_texture_rect(ROOM,Rect2(Vector2((size.x-w)/2,88),Vector2(w,w*700/600)),false)
		c.draw_string(body,Vector2(40,size.y-31),"EST. AT THE BOARD   /   PLAY YOUR OWN POSITION",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("795641"))
	else:
		# Long horizontal wall joints and one red printer's mark frame the game.
		c.draw_line(Vector2(28,21),Vector2(size.x-28,21),Color("657778"),1)
		c.draw_rect(Rect2(30,32,52,62),Color("b66a4d"))
		c.draw_texture_rect(WHITE[2],Rect2(33,34,46,54),false)
		c.draw_string(title,Vector2(100,66),"KNIGHT CHESS",HORIZONTAL_ALIGNMENT_LEFT,-1,32,PAPER)
		c.draw_string(body,Vector2(102,88),"THE CASTLE PRINT   /   A BOARD. TWO ARMIES.",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("c8ad7f"))
		c.draw_line(Vector2(size.x-32,115),Vector2(size.x-32,size.y-30),Color("516469"),1)
static func frame(c: CanvasItem, board: Rect2) -> void:
	c.draw_rect(board.grow(19),Color("10272f"))
	c.draw_rect(board.grow(14),Color("784b3b"))
	c.draw_rect(board.grow(15),Color("c19964"),false,2)
	c.draw_rect(board.grow(5),Color("d2b27f"),false,2)
	c.draw_rect(board.grow(2),Color("162b33"),false,3)
	for corner in [board.position-Vector2(10,10), Vector2(board.end.x+10,board.position.y-10),board.end+Vector2(10,10),Vector2(board.position.x-10,board.end.y+10)]:
		c.draw_colored_polygon(PackedVector2Array([corner+Vector2(0,-4),corner+Vector2(4,0),corner+Vector2(0,4),corner+Vector2(-4,0)]),PAPER)
	for i in 16:
		var x = board.position.x + i * board.size.x/16
		c.draw_line(Vector2(x,board.end.y+9),Vector2(x+board.size.x/32,board.end.y+9),Color("b78156"),1)
static func square(c: CanvasItem, rect: Rect2, light: bool) -> void:
	c.draw_rect(rect,Color("dfc89e") if light else Color("698284"))
	# Two short engraved strokes per inlay; centers remain quiet for legibility.
	var tint = Color("c7ae83") if light else Color("587276")
	c.draw_line(rect.position+Vector2(5,5),rect.position+Vector2(rect.size.x*.29,5),tint,1)
	c.draw_line(rect.end-Vector2(rect.size.x*.23,5),rect.end-Vector2(5,5),tint,1)
static func piece(c: CanvasItem, rect: Rect2, value: int) -> void:
	c.draw_texture_rect((WHITE if value > 0 else BLACK)[absi(value)],rect.grow(-rect.size.x*.035),false)
static func button_box(background: Color, border: Color, focus = false) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(3 if focus else 1)
	box.border_width_bottom = 2
	box.set_corner_radius_all(0)
	box.content_margin_left=12; box.content_margin_right=12
	box.content_margin_top=10; box.content_margin_bottom=10
	return box
static func menu_skin(page: Control) -> void:
	for item in page.get_children():
		if item is Label: item.add_theme_color_override("font_color",INK)
		if item is Button:
			var primary = item.text == "Create Sandbox Game"
			for state in ["normal","hover","pressed","focus"]:
				var bg = Color("9e4e38") if primary else PAPER
				if state in ["hover","pressed","focus"]: bg=Color("b36649") if primary else Color("d9bd8d")
				item.add_theme_stylebox_override(state,button_box(bg,INK,state=="focus"))
			for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
				item.add_theme_color_override(key,Color("fff0ce") if primary else INK)
