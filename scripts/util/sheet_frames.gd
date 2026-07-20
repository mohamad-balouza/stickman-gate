class_name SheetFrames
## Builds SpriteFrames from the 32x32 grid sheets produced by
## tools/gen_assets.py (row0 idle x4, row1 run x6, row2 jump+fall,
## row3 shoot x2, row4 death x5).

const FRAME_W := 32
const FRAME_H := 32

static func build(sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add(frames, sheet, "idle", 0, 0, 4, 6.0, true)
	_add(frames, sheet, "run", 1, 0, 6, 12.0, true)
	_add(frames, sheet, "jump", 2, 0, 1, 5.0, false)
	_add(frames, sheet, "fall", 2, 1, 1, 5.0, false)
	_add(frames, sheet, "shoot", 3, 0, 2, 12.0, false)
	_add(frames, sheet, "death", 4, 0, 5, 10.0, false)
	return frames

static func _add(frames: SpriteFrames, sheet: Texture2D, anim: String, row: int, start_col: int, count: int, fps: float, looped: bool, size: int = 32) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, looped)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2((start_col + i) * size, row * size, size, size)
		frames.add_frame(anim, at)

## Frames for the 96x96 boss sheet: idle(4) / windup(2)+lunge(2) / death(6).
static func build_boss(sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add(frames, sheet, "idle", 0, 0, 4, 5.0, true, 96)
	_add(frames, sheet, "windup", 1, 0, 2, 8.0, true, 96)
	_add(frames, sheet, "lunge", 1, 2, 2, 8.0, true, 96)
	_add(frames, sheet, "death", 2, 0, 6, 6.0, false, 96)
	return frames
