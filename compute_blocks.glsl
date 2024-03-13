#[compute]
#version 450

#define PI 3.14159265359
#define SIZECUBED 512 

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(r8, set = 0, binding = 0) uniform image3D blockdata;

layout(std430, set = 0, binding = 1) buffer blockoffset
{
	vec3 offset[];
};

void main() {

	uint index = gl_WorkGroupID.x * SIZECUBED + gl_WorkGroupID.y * SIZECUBED * 2 + gl_WorkGroupID.z * SIZECUBED * 4 + gl_LocalInvocationIndex;
	
	//adding blocks all the way to the top
	if(distance(vec3(8,8,8), gl_GlobalInvocationID.xyz + offset[0].xyz) < 8)
	{
		imageStore(blockdata, ivec3(gl_GlobalInvocationID.xyz), vec4(1,1,1,1));
	}
	else
	{
		imageStore(blockdata, ivec3(gl_GlobalInvocationID.xyz), vec4(0,0,0,0));
	}
	
}