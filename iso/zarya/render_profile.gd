extends RefCounted
# Rendering only: map geometry, authored lights, textures and story are untouched.
static func apply(viewport: Viewport, environment: Environment) -> void:
	viewport.msaa_3d=Viewport.MSAA_2X
	# A restrained indirect fill retains shapes inside local-light shadows.
	environment.ambient_light_color=Color("#71828b")
	environment.ambient_light_energy=0.24
	environment.ambient_light_sky_contribution=0.0
