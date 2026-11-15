extends AudioStreamPlayer

const TRACKS = [
	preload("res://audio/music/a_cat_goes_to_work.mp3"),
	preload("res://audio/music/whats_stopping_you.mp3"),
	preload("res://audio/music/why_do_i_have_to_get_up_tomorrow.mp3"),
	preload("res://audio/music/meow_dosbomb.mp3"),
	preload("res://audio/music/a_letter.mp3"),
]
var next_track = 0

func _ready():
	finished.connect(play_next)
	play_next()

func play_next():
	stream = TRACKS[next_track]
	next_track = (next_track + 1) % TRACKS.size()
	play()
