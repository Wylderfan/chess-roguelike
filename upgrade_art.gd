class_name UpgradeArt
extends RefCounted
# Original vector sigils; render actual equipped abilities only. The generic
# two-socket composition is ready for a future registered second ability.
const ICONS = {"pawn_retreat": preload("res://assets/abilities/pawn_retreat.svg")}
const TIER_COLORS = {"common": Color("68bda9"), "rare": Color("b39ce2"), "legendary": Color("e8bd64")}
static func draw_upgrade(canvas: CanvasItem, rect: Rect2, data: Dictionary) -> void:
	var abilities: Array = data.get("abilities", [])
	var rarity: String = data.get("rarity", "common")
	if abilities.is_empty() and rarity == "common": return
	var color: Color = TIER_COLORS.get(rarity, TIER_COLORS.common)
	var unit = rect.size.x
	var center = rect.get_center()
	# Open-corner frame leaves the chess silhouette and selection highlights clear.
	var frame = rect.grow(-unit * 0.09)
	var arm = unit * 0.13
	if rarity != "common":
		for corner in [frame.position, Vector2(frame.end.x,frame.position.y), frame.end, Vector2(frame.position.x,frame.end.y)]:
			var inward = (center-corner).sign()
			canvas.draw_line(corner, corner+Vector2(inward.x*arm,0), Color("22342f"), 5, true)
			canvas.draw_line(corner, corner+Vector2(0,inward.y*arm), Color("22342f"), 5, true)
			canvas.draw_line(corner, corner+Vector2(inward.x*arm,0), color, 2, true)
			canvas.draw_line(corner, corner+Vector2(0,inward.y*arm), color, 2, true)
		var crown = rect.position+Vector2(unit*.19,unit*.18)
		var radius = unit*.055
		canvas.draw_colored_polygon(PackedVector2Array([crown+Vector2(0,-radius),crown+Vector2(radius,0),crown+Vector2(0,radius),crown+Vector2(-radius,0)]),color)
		if rarity == "legendary": canvas.draw_circle(crown, radius*1.7, color, false, 1.2, true)
	var slots = 1 if rarity == "common" else 2
	var side = unit * .30
	for index in slots:
		var location = rect.position + Vector2(unit*.68 if index == 0 else unit*.04, unit*.66)
		var socket = Rect2(location,Vector2.ONE*side)
		if index < abilities.size() and ICONS.has(abilities[index]):
			canvas.draw_texture_rect(ICONS[abilities[index]], socket, false)
		else:
			canvas.draw_circle(socket.get_center(), side*.34, Color("26392f"), true,-1,true)
			canvas.draw_circle(socket.get_center(), side*.34, color, false,1.5,true)
			canvas.draw_circle(socket.get_center(), side*.12, color.darkened(.4), true,-1,true)
	if abilities.size() == 2:
		# Linked dual sigils, not a fabricated power or duplicate ability.
		canvas.draw_arc(rect.position+Vector2(unit*.51,unit*.71),unit*.31,.24,PI-.24,24,color,2,true)
