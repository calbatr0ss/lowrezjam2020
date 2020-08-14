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
	if obj.flip then
		return {
			r = obj.p.x+8-obj.sprite.hitbox.o.x-1, 
			l = obj.p.x+8-obj.sprite.hitbox.o.x-obj.sprite.hitbox.w, 
			t = obj.p.y+obj.sprite.hitbox.o.y, 
			b = obj.p.y+obj.sprite.hitbox.o.y+obj.sprite.hitbox.h-1
		}
	else
		return {
			r = obj.p.x+obj.sprite.hitbox.o.x+obj.sprite.hitbox.w-1, 
			l = obj.p.x+obj.sprite.hitbox.o.x, 
			t = obj.p.y+obj.sprite.hitbox.o.y, 
			b = obj.p.y+obj.sprite.hitbox.o.y+obj.sprite.hitbox.h-1
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
