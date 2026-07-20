class_name EventBus
extends RefCounted
## Global signal bus decoupling gameplay from UI/camera.
## Access the shared instance as EventBus.bus.

# load() by path avoids self-referencing the class name in a static
# initializer, which the editor cannot always resolve mid-registration.
static var bus = load("res://scripts/event_bus.gd").new()

signal enemy_killed
signal player_health_changed(hp: int, max_hp: int)
signal weapon_upgraded(display_name: String)
signal player_died
signal level_won
signal shake(amount: float)
signal toast(text: String)
signal boss_engaged(display_name: String, max_hp: int)
signal boss_health_changed(hp: int, max_hp: int)
signal boss_died
