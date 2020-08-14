function right_tile_collide(obj)
	local edges = calc_edges(obj)
	return solid_tile(edges.r, edges.b)
end

function left_tile_collide(obj)
	local edges = calc_edges(obj)
	return solid_tile(edges.l, edges.b)
end

function ceil_tile_collide(obj)
	local edges = calc_edges(obj)
	return solid_tile(edges.l, edges.t) or solid_tile(edges.r, edges.t)
end

function floor_tile_collide(obj)
	local edges = calc_edges(obj)
	return solid_tile(edges.l, edges.b) or solid_tile(edges.r, edges.b)
end

function floor_ledge_collide(obj)
	local edges = calc_edges(obj)
	return ledge_tile(edges.l, edges.b) or ledge_tile(edges.r, edges.b)
end

function on_ground(obj)
	local edges = calc_edges(obj)
	return solid_tile(edges.l, edges.b+1) or solid_tile(edges.r, edges.b+1)
end

function on_ledge(obj)
	local edges = calc_edges(obj)
	return (not ledge_tile(edges.l, edges.b) and ledge_tile(edges.l, edges.b+1)) or
		(not ledge_tile(edges.r, edges.b) and ledge_tile(edges.r, edges.b+1))
end

function ledge_below(obj)
	local edges = calc_edges(obj)
	return (ledge_tile(edges.l, edges.b+7) and not ledge_tile(edges.l, edges.b-1)) or
		(ledge_tile(edges.r, edges.b+7) and not ledge_tile(edges.r, edges.b-1))
end

function calc_edges(obj)
	local x, y, hox, hoy, hw, hh = obj.p.x, obj.p.y, obj.sprite.hitbox.o.x, obj.sprite.hitbox.o.y, obj.sprite.hitbox.w, obj.sprite.hitbox.h
	if obj.flip then
		return {
			r = x+8-hox-1, 
			l = x+8-hox-hw, 
			t = obj.p.y+hoy, 
			b = obj.p.y+hoy+hh-1
		}
	else
		return {
			r = x+hox+hw-1, 
			l = x+hox, 
			t = y+hoy, 
			b = y+hoy+hh-1
		}
	end
end

function ledge_tile(x, y)
	return is_flag_at(x/8, y/8, 0)
end

function solid_tile(x, y)
	return is_flag_at(x/8, y/8, 1)
end

function jug_tile(x, y)
	return is_flag_at(x/8, y/8, 2)
end

function crimp_tile(x, y)
	return is_flag_at(x/8, y/8, 3)
end

function crack_tile(x, y)
	return is_flag_at(x/8, y/8, 4)
end

function is_flag_at(x, y, f)
	return fget(mget(x, y), f)
end
