extends RefCounted
## Every phenotype has a distinct living animation and movement wake.
## Visual only: collisions, speed and growth are unchanged.

static func phenotype_color(id: String, t: float) -> Color:
	match id:
		"bubblegum":
			return Color(1.0, 0.38 + 0.09 * sin(t * 2.0), 0.61)
		"arctic":
			return Color(0.28, 0.75 + 0.09 * sin(t * 1.8), 0.97)
		"solar":
			return Color(1.0, 0.51 + 0.12 * sin(t * 2.8), 0.16)
		"rainbow":
			return Color.from_hsv(fposmod(t * 0.10, 1.0), 0.87, 0.97)
		"galaxy":
			return Color(0.27 + 0.04 * sin(t), 0.19, 0.51 + 0.07 * cos(t))
		"gold":
			return Color(0.95, 0.72 + 0.13 * sin(t * 2.1), 0.28)
		_:
			return Color(0.26, 0.94, 0.78)


static func _is_inside(pt: Vector2, poly: PackedVector2Array) -> bool:
	return Geometry2D.is_point_in_polygon(pt, poly)


static func draw_wake(canvas: CanvasItem, cell: Dictionary, id: String, t: float) -> void:
	var trail: Array = cell.get("trail", [])
	if trail.size() < 2:
		return
	var color := phenotype_color(id, t)
	var center: Vector2 = cell["pos"]
	var radius := sqrt(maxf(1.0, float(cell["mass"])) * 50.0 / PI)
	for i in range(1,trail.size()):
		var p: Vector2 = trail[i-1]
		var q: Vector2 = trail[i]
		var life := float(i) / float(trail.size())
		var alpha := life * life
		match id:
			"rainbow":
				var rainbow := Color.from_hsv(fposmod(float(i) / float(trail.size()) + t * 0.22,1.0), 0.88, 1.0, 0.52 * alpha)
				canvas.draw_line(p,q,rainbow, maxf(2.0,radius * 0.13 * alpha),true)
				var rainbow2 := Color.from_hsv(fposmod(float(i) / float(trail.size()) + t * 0.22 + 0.46,1.0),0.92,1.0,0.27*alpha)
				canvas.draw_line(p + Vector2(0,12),q + Vector2(0,12),rainbow2,3.5,true)
			"galaxy":
				canvas.draw_line(p,q,Color(0.50,0.39,1.0,0.20*alpha), radius * 0.18 * alpha + 2.0,true)
				if i % 2 == 0:
					canvas.draw_circle(p, 2.8 + alpha * 2.0, Color(0.91,0.90,1.0,0.65*alpha))
			"solar":
				canvas.draw_line(p,q,Color(1.0,0.45,0.12,0.30*alpha), maxf(2.0,radius * 0.14 * alpha),true)
				if i % 3 == 0:
					canvas.draw_circle(p, 2.6 + alpha * 2.0, Color(1.0,0.85,0.36,0.72*alpha))
			"arctic":
				canvas.draw_line(p,q,Color(0.55,0.93,1.0,0.28*alpha),maxf(2.0,radius * 0.12 * alpha),true)
				if i % 3 == 0:
					canvas.draw_arc(p,4.0+alpha*4.0,0.0,TAU,12,Color(0.9,1.0,1.0,0.5*alpha),1.5,true)
			"bubblegum":
				if i % 2 == 0:
					canvas.draw_circle(p, 2.0 + alpha * 4.0, Color(1.0,0.68,0.82,0.5*alpha))
				canvas.draw_line(p,q,Color(1.0,0.57,0.78,0.19*alpha),maxf(2.0,radius * 0.07 * alpha),true)
			"gold":
				canvas.draw_line(p,q,Color(1.0,0.83,0.32,0.24*alpha),3.0+alpha*5.0,true)
				if i % 2 == 0:
					canvas.draw_circle(p,1.7+3.0*alpha,Color(1.0,0.93,0.68,0.66*alpha))
			_:
				if i % 3 == 0:
					canvas.draw_circle(p,2.0+3.5*alpha,Color(color.r,color.g,color.b,0.30*alpha))

	# A faint pulse travels behind the living cell even when not using a skin.
	if id in ["rainbow","solar","galaxy","arctic","gold"]:
		var halo_t := 0.5 + 0.5 * sin(t * 3.1)
		canvas.draw_arc(center,radius * (1.10+0.045*halo_t),t*0.45,t*0.45+PI*1.12,48,Color(color.r,color.g,color.b,0.20),2.0,true)


static func draw_tissue(canvas: CanvasItem, polygon: PackedVector2Array, cell: Dictionary, id: String, t: float) -> void:
	if polygon.size() < 3:
		return
	var center: Vector2 = cell["pos"]
	var radius := sqrt(maxf(1.0,float(cell["mass"])) * 50.0 / PI)
	if id == "rainbow":
		# A true prismatic membrane, not merely one hue-changing flat circle.
		var vertex_colors := PackedColorArray()
		for i in range(polygon.size()):
			var a: float = (polygon[i] - center).angle()
			vertex_colors.append(Color.from_hsv(fposmod(a / TAU + 0.45 + t*0.12,1.0),0.72,0.98))
		canvas.draw_polygon(polygon,vertex_colors)
	elif id == "galaxy":
		canvas.draw_colored_polygon(polygon,Color(0.13,0.075,0.28))
	else:
		canvas.draw_colored_polygon(polygon,phenotype_color(id,t))

	var color := phenotype_color(id,t)
	# Interior pigments stay inside actual remaining tissue after a bite.
	for i in range(21):
		var angle := float(i) * 2.39996 + 0.1
		var orbit := radius * (0.12 + 0.032 * float(i % 14))
		var p := center + Vector2.from_angle(angle + 0.085*sin(t*1.4+float(i))) * orbit
		if not _is_inside(p,polygon):
			continue
		match id:
			"mint":
				if i%3 == 0:
					canvas.draw_arc(p,2.7+float(i%4),0.0,TAU,15,Color(0.85,1.0,0.98,0.24),1.5,true)
			"bubblegum":
				var petals := 4 if i%4==0 else 2
				for k in range(petals):
					var v := Vector2.from_angle(t*0.24+float(k)*TAU/float(petals))*(3.2+float(i%3))
					if _is_inside(p+v,polygon):
						canvas.draw_circle(p+v,2.7,Color(1.0,0.85,0.92,0.55))
				canvas.draw_circle(p,1.7,Color(1.0,0.41,0.62,0.53))
			"arctic":
				var spin := t*0.18+float(i)
				for n in range(3):
					var direction := Vector2.from_angle(spin+float(n)*PI/3.0)
					canvas.draw_line(p-direction*4.0,p+direction*4.0,Color(0.93,1.0,1.0,0.62),1.5,true)
			"solar":
				var spark := 1.8+2.4*(0.5+0.5*sin(t*5.0+float(i)))
				canvas.draw_circle(p,spark,Color(1.0,0.94,0.61,0.74))
			"rainbow":
				var hue := fposmod(float(i)/21.0+t*0.22,1.0)
				canvas.draw_circle(p,3.2,Color.from_hsv(hue,0.91,1.0,0.77))
			"galaxy":
				var star := 1.0 + 2.2 * (0.5+0.5*sin(t*2.2+float(i)*1.7))
				canvas.draw_circle(p,star,Color(0.82+0.17*sin(float(i)),0.9,1.0,0.64))
			"gold":
				canvas.draw_circle(p,2.2+2.0*(0.5+0.5*sin(t*3.1+float(i))),Color(1.0,0.95,0.66,0.67))
	if id == "arctic":
		# Crystal-like radial facets meet inside the membrane only.
		for i in range(6):
			var d := Vector2.from_angle(float(i)*TAU/6.0+t*0.06)
			var p1 := center+d*radius*0.18
			var p2 := center+d*radius*0.57
			if _is_inside(p1,polygon) and _is_inside(p2,polygon):
				canvas.draw_line(p1,p2,Color(0.89,1.0,1.0,0.29),2.0,true)
	if id == "galaxy":
		for i in range(2):
			var orbit_color := Color(0.58,0.47,0.96,0.29)
			canvas.draw_arc(center,radius*(0.30+0.16*float(i)),t*0.30+float(i),t*0.30+float(i)+PI*1.2,60,orbit_color,1.7,true)


static func draw_aura(canvas: CanvasItem, cell: Dictionary, id: String, t: float) -> void:
	var center: Vector2 = cell["pos"]
	var radius := sqrt(maxf(1.0,float(cell["mass"])) * 50.0 / PI)
	var tint := phenotype_color(id,t)
	match id:
		"solar":
			for i in range(3):
				var angle := t*(0.47+float(i)*0.07)+float(i)*TAU/3.0
				canvas.draw_arc(center,radius*(1.05+0.035*sin(t*2.3+float(i))),angle,angle+0.78,40,Color(1.0,0.65,0.19,0.72),3.7,true)
				var p := center+Vector2.from_angle(angle+0.78)*radius*1.1
				canvas.draw_circle(p,3.8,Color(1.0,0.88,0.51,0.68))
		"arctic":
			for i in range(3):
				var angle := -t*0.25+float(i)*TAU/3.0
				canvas.draw_arc(center,radius*1.06,angle,angle+0.48,30,Color(0.65,0.96,1.0,0.48),2.3,true)
		"rainbow":
			for i in range(4):
				var angle := t*(0.55+float(i)*0.05)+float(i)*TAU/4.0
				var p := center+Vector2.from_angle(angle)*radius*1.06
				canvas.draw_circle(p,2.8+sin(t*3.0+float(i))*0.8,Color.from_hsv(fposmod(float(i)/4.0+t*0.12,1.0),0.85,1.0,0.95))
		"galaxy":
			for i in range(3):
				var angle := t*0.33+float(i)*TAU/3.0
				canvas.draw_arc(center,radius*1.11,angle,angle+0.35,25,Color(0.75,0.65,1.0,0.45),2.3,true)
				var p := center+Vector2.from_angle(angle+0.35)*radius*1.11
				canvas.draw_circle(p,3.2,Color(0.88,0.89,1.0,0.76))
		"gold":
			for i in range(4):
				var angle := -t*0.30+float(i)*TAU/4.0
				var p := center+Vector2.from_angle(angle)*radius*1.09
				canvas.draw_circle(p,3.2,Color(1.0,0.96,0.74,0.84))
			canvas.draw_arc(center,radius*1.03,-PI*0.75,-PI*0.25,42,Color(1.0,0.85,0.4,0.63),2.6,true)
		"bubblegum":
			for i in range(3):
				var angle := t*0.30+float(i)*TAU/3.0
				var p := center+Vector2.from_angle(angle)*radius*1.03
				canvas.draw_arc(p,4.0+2.0*sin(t+float(i)),0,TAU,15,Color(1.0,0.82,0.90,0.52),1.5,true)
		_:
			canvas.draw_arc(center,radius*1.02,-0.7+t*0.14,0.55+t*0.14,35,Color(tint.r,tint.g,tint.b,0.24),1.6,true)


static func preview(canvas: CanvasItem, id: String, pos: Vector2, radius: float, t: float) -> void:
	var color := phenotype_color(id,t)
	canvas.draw_circle(pos,radius,color)
	if id == "rainbow":
		for i in range(8):
			var a := float(i)*TAU/8.0
			var p := pos+Vector2.from_angle(a)*radius*0.65
			canvas.draw_circle(p,5.4,Color.from_hsv(fposmod(float(i)/8.0+t*0.12,1.0),0.85,1.0))
	elif id == "galaxy":
		canvas.draw_circle(pos,radius*0.75,Color(0.15,0.08,0.33))
		for i in range(6):
			var p := pos+Vector2.from_angle(float(i)*2.4+t*0.20)*radius*0.65
			canvas.draw_circle(p,2.3,Color.WHITE)
	elif id == "arctic":
		for i in range(6):
			var d := Vector2.from_angle(float(i)*TAU/6.0)
			canvas.draw_line(pos+d*radius*0.15,pos+d*radius*0.69,Color(0.93,1.0,1.0,0.65),1.8,true)
	elif id == "solar":
		for i in range(8):
			var d := Vector2.from_angle(float(i)*TAU/8.0+t*0.28)
			canvas.draw_line(pos+d*radius*0.66,pos+d*radius*1.14,Color(1.0,0.89,0.44,0.8),2.8,true)
	elif id == "gold":
		for i in range(5):
			var d := Vector2.from_angle(float(i)*TAU/5.0+t*0.13)
			canvas.draw_circle(pos+d*radius*0.67,2.3,Color(1.0,1.0,0.79,0.84))
	elif id == "bubblegum":
		for i in range(5):
			var p := pos+Vector2.from_angle(float(i)*2.4+t*0.14)*radius*0.58
			canvas.draw_circle(p,3.2,Color(1.0,0.88,0.94,0.85))
	else:
		canvas.draw_circle(pos+Vector2(-5,-5),radius*0.27,Color(1.0,1.0,1.0,0.17))
	canvas.draw_arc(pos,radius,0,TAU,48,Color(0.025,0.20,0.23,0.88),4.0,true)
	canvas.draw_arc(pos,radius,0,TAU,48,color.lightened(0.42),1.8,true)
