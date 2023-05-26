extends Node

var socket = WebSocketPeer.new()
var last_state = WebSocketPeer.STATE_CLOSED
var tls: TLSOptions = null
@onready var textToSend = $/root/Top/ConnectedSection/LiveChat/ColorRect/TextInput
var msgTemplate = preload("res://message.tscn")
var nameTemplate = preload("res://names.tscn")
@onready var msgStack = $/root/Top/ConnectedSection/LiveChat/ColorRect/VBoxContainer
@onready var nameField = $/root/Top/EntrySection/LineEdit

var template = {
	"tick" = 0,
	"msg" = [], ## name - message
}

func _ready():
	$/root/Top/ConnectedSection/LiveChat/ColorRect/TextInput.text_submitted.connect(_append_msg)
	$/root/Top/EntrySection/Button.pressed.connect(_attemptConn)
	get_tree().get_root().propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

func clear_dict():
	template["tick"] += 1
	template["msg"] = []

func _attemptConn():
	if socket.get_ready_state() == socket.STATE_CLOSED:
		var err = socket.connect_to_url("ws://127.0.0.1:7766", tls)
		if err != OK:
			print("Error: ", err)

func _append_msg(txt):
	template["msg"] = [nameField.text ,txt]
	print("Sending: ", JSON.stringify(template))
	socket.send_text(JSON.stringify(template))
	clear_dict()
	textToSend.clear()

func poll():
	if socket.get_ready_state() != socket.STATE_CLOSED:
		socket.poll()
	if socket.get_ready_state() == socket.STATE_OPEN:
		## Send a packet w/ 0 tick, giving the server a name
		if template["tick"] == 0:
			_append_msg("")
		
	while socket.get_ready_state() == socket.STATE_OPEN and socket.get_available_packet_count():
		var pkt = socket.get_packet()
		pkt = pkt.get_string_from_utf8()
		pkt = JSON.parse_string(pkt)
		if pkt["msg"]:
			print("Received: ", pkt)
		## Process packet
		var newPlayers = []
		for msg in pkt["msg"]:
			if msg[1] != "": ## Contains message data
				var t = msgTemplate.instantiate()
				t.get_node("Panel/MarginContainer/RichTextLabel").text = msg[0] + " : " + msg[1]
				msgStack.add_child(t)
			else: ## Contains player updated data
				newPlayers.append(msg[0])
		if newPlayers:
			var nameContainer = $/root/Top/ConnectedSection/LiveClients/ColorRect/VBoxContainer
			var nameList = $/root/Top/ConnectedSection/LiveClients/ColorRect/VBoxContainer.get_children()
			for n in nameList: n.queue_free()
			##var name = nameTemplate.instantiate()
			##name.get_node($MarginContainer/Panel/RichTextLabel).text = 
			for n in newPlayers:
				var name = nameTemplate.instantiate()
				name.get_node("MarginContainer/Panel/RichTextLabel").text = n
				nameContainer.add_child(name)

func _process(delta):
	poll()
