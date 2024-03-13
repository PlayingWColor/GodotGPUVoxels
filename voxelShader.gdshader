shader_type spatial;

uniform sampler2D mainTexture;

void fragment() {
	
	vec3 worldPos = (INV_VIEW_MATRIX * vec4(VERTEX,0.0)).xyz;
	worldPos += CAMERA_POSITION_WORLD;
	// Place fragment code here.
	vec3 xColor = texture(mainTexture, worldPos.yz).xyz;
	vec3 yColor = texture(mainTexture, worldPos.xz).xyz;
	vec3 zColor = texture(mainTexture, worldPos.xy).xyz;
	
	vec3 normal = abs(NORMAL);
	
	vec3 color = xColor * normal.x + yColor * normal.y + zColor * normal.z;
	
	ALBEDO = color;
}
