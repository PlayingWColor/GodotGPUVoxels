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

vec3 rotateX(vec3 inPos, float amount, vec3 center)
{
	inPos.y -= center.y;
	inPos.z -= center.z;
	float originalY = inPos.y;
	float originalZ = inPos.z;
	inPos.y = originalY*cos(amount)-originalZ*sin(amount);
	inPos.z = originalZ*cos(amount)+originalY*sin(amount);
	inPos.y += center.y;
	inPos.z += center.z;
	return inPos;
}

vec3 rotateY(vec3 inPos, float amount, vec3 center)
{
	inPos.x -= center.x;
	inPos.z -= center.z;
	float originalX = inPos.x;
	float originalZ = inPos.z;
	inPos.x = originalX*cos(amount)-originalZ*sin(amount);
	inPos.z = originalZ*cos(amount)+originalX*sin(amount);
	inPos.x += center.x;
	inPos.z += center.z;
	return inPos;
}

vec3 rotateZ(vec3 inPos, float amount, vec3 center)
{
	inPos.x -= center.x;
	inPos.y -= center.y;
	float originalX = inPos.x;
	float originalY = inPos.y;
	inPos.x = originalX*cos(amount)-originalY*sin(amount);
	inPos.y = originalY*cos(amount)+originalX*sin(amount);
	inPos.x += center.x;
	inPos.y += center.y;
	return inPos;
}

void main() {
	
	uint index = gl_WorkGroupID.x * SIZECUBED + gl_WorkGroupID.y * SIZECUBED * 2 + gl_WorkGroupID.z * SIZECUBED * 4 + gl_LocalInvocationIndex;
	
	float indexOffset = index + offset[0].x + offset[0].y * 8 + offset[0].z * 64;
	
	//egg
	vec3 center = vec3(8.0,4.0,8.0);
	
	vec3 transform = gl_GlobalInvocationID.xyz + offset[0].xyz;

	transform = rotateX(rotateY(transform, time[0]*6, center), PI*0.1, center);
	
	transform.y += sin(time[0]*6) - 1;
	
	if(distance(vec3(8,5,8), transform) < 6 || distance(vec3(8,10,8), transform) < 4 || distance(vec3(8,8,8), transform) < 5)
	{
		imageStore(blockdata, ivec3(gl_GlobalInvocationID.xyz), vec4(1,1,1,1));
	}
	else
	{
		imageStore(blockdata, ivec3(gl_GlobalInvocationID.xyz), vec4(0,0,0,0));
	}
	
	

}