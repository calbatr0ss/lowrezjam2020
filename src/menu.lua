function init_menu()
	donothing = 0
end

function update_menu()
	if btnp(input.o) or btnp(input.x) then
		init_game()
	end
end

function draw_menu()
	draw_screen()
	update_last_btns()
end
