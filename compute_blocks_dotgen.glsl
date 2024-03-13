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

layout(std430, set = 0, binding = 2) buffer blocktime
{
	float time[];
};

void main() {
	
	uint index = gl_WorkGroupID.x * SIZECUBED + gl_WorkGroupID.y * SIZECUBED * 2 + gl_WorkGroupID.z * SIZECUBED * 4 + gl_LocalInvocationIndex;
	
	float indexOffset = index + offset[0].x + offset[0].y * 8 + offset[0].z * 64;
	
	//adding blocks all the way to the top
	if(mod(time[0]*20,SIZECUBED) > indexOffset && mod(indexOffset,6) == 1)
	{
		imageStore(blockdata, ivec3(gl_GlobalInvocationID.xzy), vec4(1,1,1,1));
	}
	else
	{
		imageStore(blockdata, ivec3(gl_GlobalInvocationID.xzy), vec4(0,0,0,0));
	}

}