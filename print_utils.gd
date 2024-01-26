extends Node

var server_bbcode = "[color=green][b]Server > [/b][/color]"

func print_server(text: String):
	print_rich(server_bbcode + text)
