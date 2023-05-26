extends Node


var tcp = TCPServer.new()
var lobby : Array[WS]
var tcp_bowl : Array[StreamPeerTCP]
var logNode = preload("res://entry.tscn")
@onready var vbox = $/root/Control/Panel/MarginContainer/VBoxContainer
var jsonTemp = {
	"msg" = []
}

func _ready():
	tcp.listen(7766)
	
	var newEntry = logNode.instantiate()
	newEntry.get_node("MarginContainer/Panel/MarginContainer/RichTextLabel").text = "SERVER Started"
	if tcp.is_listening():
		vbox.add_child(newEntry)


class WS:
	var _ws : WebSocketPeer
	var _tcp : StreamPeerTCP
	var _id : int
	var _name : String
	var _json : Dictionary
	
	func _init(p_tcp: StreamPeerTCP):
		_ws = WebSocketPeer.new()
		_ws.accept_stream(p_tcp)
		_tcp = p_tcp
		_id = randi_range(2, 1 << 30)


func send_msg(msg : String):
	pass


func rec_msg(ws) -> String:
	var pkt = ws.socket.get_packet()
	return pkt.get_string_from_utf8()

func clear_dict():
	jsonTemp["msg"] = []

## pc = potentialClient
func _process(delta):
	if tcp.is_listening():
		if tcp.is_connection_available():
			var pc = tcp.take_connection()
			## Filter double connections 
			if pc not in tcp_bowl:
				## Create client
				tcp_bowl.append(pc)
				lobby.append(WS.new(pc))
		## Poll established clients, get any messages
		var removal2 = 0 
		for c in lobby:
			c._ws.poll()
			##print(tcp_bowl[0].get_status())
			var packets = c._ws.get_available_packet_count()
			if packets > 0:
				var pkt = c._ws.get_packet()
				c._json = JSON.parse_string(pkt.get_string_from_utf8())
		## Deal with closed conns, remove from poolS
		var wsPos = null
		var bowlPos = null
		for c in lobby:
			if c._tcp.get_status() == StreamPeerTCP.STATUS_NONE or c._ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
					var newEntry = logNode.instantiate()
					newEntry.get_node("MarginContainer/Panel/MarginContainer/RichTextLabel").text = c._name + " disconnected"
					## Get SB, duplicate, override
					vbox.add_child(newEntry)
					wsPos = lobby.find(c)
					bowlPos = tcp_bowl.find(c._tcp)
		if typeof(wsPos) == TYPE_INT:
			lobby.remove_at(wsPos)
			tcp_bowl.remove_at(bowlPos)
			## Update all clients that someone left
			for p in lobby: jsonTemp["msg"].append([p._name, ""])
		##print("bowl size : lobby size ", len(tcp_bowl), len(lobby))
		for c in lobby:
			if not c._json.is_empty():
				## Catch special cases represented w/ tick
				if c._json["tick"] == 0:
					## DISPLAY SERVER SIDE 
					var newEntry = logNode.instantiate()
					newEntry.get_node("MarginContainer/Panel/MarginContainer/RichTextLabel").text = c._json["msg"][0] + " joined"
					vbox.add_child(newEntry)
					c._name = c._json["msg"][0]
					## Update all clients on a new person joining
					for p in lobby: jsonTemp["msg"].append([p._name, ""])
				## Prepare every message received to echo out
				if c._json["msg"][1]:
					jsonTemp["msg"].append(c._json["msg"])
					var newEntry = logNode.instantiate()
					newEntry.get_node("MarginContainer/Panel/MarginContainer/RichTextLabel").text = c._json["msg"][0] + " - " + c._json["msg"][1]
					vbox.add_child(newEntry)
				c._json.clear()
		## Echo all messages to all LIVE clients
		for c in lobby:
			if c._ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
				c._ws.send_text(JSON.stringify(jsonTemp))
		print(JSON.stringify(jsonTemp))
		clear_dict()


