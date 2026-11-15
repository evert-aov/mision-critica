shader_type canvas_item;
render_mode unshaded;

uniform int body_type = 0;
uniform float spin = 0.0;
uniform float pixel_count = 96.0;
uniform float body_extent = 1.1;
uniform vec3 light_direction = vec3(-0.65, -0.45, 0.65);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 blend = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), blend.x), blend.y);
}

float terrain(vec2 p) {
	return noise(p) * 0.58 + noise(p * 2.1 + 4.7) * 0.28 + noise(p * 4.3 + 9.2) * 0.14;
}

void fragment() {
	vec2 grid = (floor(UV * pixel_count) + 0.5) / pixel_count;
	vec2 disc = (grid - 0.5) * body_extent * 2.0;
	float r = length(disc);
	vec4 result = vec4(0.0);
	if (r <= 1.0) {
		vec3 normal = vec3(disc, sqrt(max(0.0, 1.0 - dot(disc, disc))));
		float longitude = atan(normal.x, normal.z) + spin;
		float latitude = asin(clamp(normal.y, -1.0, 1.0));
		vec2 surface = vec2(longitude * 3.3, latitude * 4.5);
		float land = terrain(surface + vec2(18.0, 8.0));
		vec3 albedo;
		if (body_type == 0) {
			albedo = mix(vec3(0.025, 0.18, 0.40), vec3(0.04, 0.40, 0.65), land);
			if (land > 0.51) {
				albedo = mix(vec3(0.13, 0.36, 0.21), vec3(0.56, 0.55, 0.29), smoothstep(0.54, 0.76, land));
			}
			float clouds = terrain(surface * 1.5 + vec2(3.0 + spin * 0.6, 14.0));
			albedo = mix(albedo, vec3(0.87, 0.94, 0.98), smoothstep(0.60, 0.73, clouds) * 0.86);
			albedo = mix(albedo, vec3(0.82, 0.94, 1.0), smoothstep(1.12, 1.48, abs(latitude)));
		} else if (body_type == 1) {
			albedo = mix(vec3(0.27, 0.29, 0.34), vec3(0.68, 0.70, 0.71), land);
			vec2 crater_grid = surface * 2.2;
			vec2 cell = floor(crater_grid);
			vec2 local = fract(crater_grid) - vec2(0.35 + hash21(cell) * 0.25, 0.4 + hash21(cell + 3.0) * 0.2);
			float crater = length(local);
			float radius = 0.12 + hash21(cell + 7.0) * 0.19;
			albedo *= 1.0 - (1.0 - smoothstep(radius * 0.65, radius, crater)) * 0.38;
			albedo += vec3(0.16) * (1.0 - smoothstep(0.02, 0.07, abs(crater - radius)));
		} else if (body_type == 2) {
			albedo = mix(vec3(0.35, 0.12, 0.07), vec3(0.86, 0.40, 0.19), land);
			float canyon = abs(latitude + 0.1 + sin(longitude * 4.0) * 0.08);
			albedo *= mix(0.65, 1.0, smoothstep(0.025, 0.09, canyon));
			albedo = mix(albedo, vec3(0.92, 0.83, 0.72), smoothstep(1.14, 1.43, abs(latitude)));
		} else if (body_type == 3) {
			float bands = terrain(surface + vec2(sin(latitude * 9.0) * 1.7, spin));
			albedo = mix(vec3(0.58, 0.30, 0.10), vec3(0.96, 0.81, 0.46), bands);
		} else {
			float granules = terrain(surface * 3.0 + vec2(spin * 2.0, 8.0));
			albedo = mix(vec3(1.0, 0.30, 0.025), vec3(1.0, 0.89, 0.32), granules);
		}
		float daylight = max(dot(normal, normalize(light_direction)), 0.0);
		float shade = floor((0.12 + daylight * 0.88) * 9.0) / 9.0;
		vec3 atmosphere = body_type == 0 ? vec3(0.12, 0.48, 0.87) : vec3(0.60, 0.23, 0.10);
		float rim = pow(1.0 - normal.z, 4.0) * (body_type == 1 ? 0.0 : 0.24);
		result = vec4(albedo * shade + atmosphere * rim, 1.0);
		if (body_type == 4) {
			result = vec4(albedo * (0.85 + normal.z * 0.15), 1.0);
		}
	} else if (body_type == 4 && r < 1.22) {
		result = vec4(1.0, 0.56, 0.10, pow((1.22 - r) / 0.22, 2.0) * 0.5);
	} else if (r < 1.08 && body_type != 1) {
		vec3 atmosphere = body_type == 0 ? vec3(0.12, 0.48, 0.87) : vec3(0.73, 0.28, 0.10);
		result = vec4(atmosphere, (1.08 - r) * 2.8);
	}
	COLOR = result;
}
