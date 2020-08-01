function right_tile_collide(obj)
	local edges=calc_edges(obj)
	return solid_tile(edges.r,edges.b)
end

function left_tile_collide(obj)
	local edges=calc_edges(obj)
	return solid_tile(edges.l,edges.b)
end

function ceil_tile_collide(obj)
	local edges=calc_edges(obj)
	return solid_tile(edges.l,edges.t) or solid_tile(edges.r,edges.t)
end

function floor_tile_collide(obj)
	local edges=calc_edges(obj)
	return solid_tile(edges.l,edges.b) or solid_tile(edges.r,edges.b)
end

function on_ground(obj)
	local edges=calc_edges(obj)
	return solid_tile(edges.l,edges.b+1) or solid_tile(edges.r,edges.b+1)
end

function against_tile(obj)
	local edges=calc_edges(obj)
	return solid_tile(edges.l,edges.b+1) or solid_tile(edges.r,edges.b+1) or
		solid_tile(edges.l,edges.t-1) or solid_tile(edges.r,edges.t-1) or
		solid_tile(edges.l-1,edges.b) or solid_tile(edges.l-1,edges.t) or
		solid_tile(edges.r+1,edges.b) or solid_tile(edges.r+1,edges.t)
end

function calc_edges(obj)
	if obj.flip then
		return {
			r=obj.x+8-obj.sprite.hitbox.ox-1,
			l=obj.x+8-obj.sprite.hitbox.ox-obj.sprite.hitbox.w,
			t=obj.y+obj.sprite.hitbox.oy,
			b=obj.y+obj.sprite.hitbox.oy+obj.sprite.hitbox.h-1
		}
	else
		return {
			r=obj.x+obj.sprite.hitbox.ox+obj.sprite.hitbox.w-1,
			l=obj.x+obj.sprite.hitbox.ox,
			t=obj.y+obj.sprite.hitbox.oy,
			b=obj.y+obj.sprite.hitbox.oy+obj.sprite.hitbox.h-1
		}
	end
end

function solid_tile(x,y)
	return is_flag_at(x/8,y/8,1)
end

function is_flag_at(x,y,f)
	return fget(mget(x,y),f)
end
