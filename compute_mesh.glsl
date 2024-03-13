#[compute]
#version 450

#define SIZECUBED 512 

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

struct Vertex {
  vec3 pos;
  vec3 normal;
  vec2 uvs;
};

layout(r8, set = 0, binding = 0) uniform image3D blockdata;
layout(std430, set = 0, binding = 1) buffer blockverts
{
	vec3 verts[];
};
layout(std430, set = 0, binding = 2) buffer blocknormals
{
	vec3 normals[];
};
layout(std430, set = 0, binding = 3) buffer blockuvs
{
	vec2 uvs[];
};
layout(std430, set = 0, binding = 4) buffer blockindices
{
	int indices[];
};

const vec3 vecTable[36] =
{
	//front (z)
	vec3(0,1,0),
	vec3(1,0,0),
	vec3(0,0,0),
	
	vec3(1,1,0),
	vec3(1,0,0),
	vec3(0,1,0),
	
	//left
	vec3(0,0,-1),
	vec3(0,1,0),
	vec3(0,0,0),
	
	vec3(0,1,-1),
	vec3(0,1,0),
	vec3(0,0,-1),
	
	//right
	vec3(1,0,-1),
	vec3(1,1,0),
	vec3(1,1,-1),
	
	vec3(1,0,0),
	vec3(1,1,0),
	vec3(1,0,-1),

	//up
	vec3(0,1,-1),
	vec3(1,1,0),
	vec3(0,1,0),
	
	vec3(1,1,-1),
	vec3(1,1,0),
	vec3(0,1,-1),
	
	//down
	vec3(0,0,0),
	vec3(1,0,0),
	vec3(0,0,-1),

	vec3(0,0,-1),
	vec3(1,0,0),
	vec3(1,0,-1),

	//back
	vec3(1,1,-1),
	vec3(0,1,-1),
	vec3(1,0,-1),

	vec3(0,0,-1),
	vec3(1,0,-1),
	vec3(0,1,-1)
	
	
};
			
// The code we want to execute in each invocation
void main() {
	
	vec4 info = imageLoad(blockdata, ivec3(gl_GlobalInvocationID.xyz));
	vec4 infoLeft = imageLoad(blockdata, ivec3(gl_GlobalInvocationID.xyz)+ivec3(-1,0,0));
	vec4 infoRight = imageLoad(blockdata, ivec3(gl_GlobalInvocationID.xyz)+ivec3(1,0,0));
	vec4 infoUp = imageLoad(blockdata, ivec3(gl_GlobalInvocationID.xyz)+ivec3(0,1,0));
	vec4 infoDown = imageLoad(blockdata, ivec3(gl_GlobalInvocationID.xyz)+ivec3(0,-1,0));
	vec4 infoFront = imageLoad(blockdata, ivec3(gl_GlobalInvocationID.xyz)+ivec3(0,0,1));
	vec4 infoBack = imageLoad(blockdata, ivec3(gl_GlobalInvocationID.xyz)+ivec3(0,0,-1));
	
	uint index = gl_WorkGroupID.x * SIZECUBED + gl_WorkGroupID.y * SIZECUBED * 2 + gl_WorkGroupID.z * SIZECUBED * 4 + gl_LocalInvocationIndex;
	index *= 36;
	
	for(int i = 0; i < 36; i++)
	{
		indices[index+i] = int(index)+i;
	}

	if(info.x == 1)
	{
		if(infoFront.x == 0)
		{
			for(int i = 0; i < 6; i++)
			{
				verts[index+i] = vec3(gl_GlobalInvocationID.xyz)+vecTable[i];
				normals[index+i] = vec3(0,0,1);
			}
		}
		else
		{
			for(int i = 0; i < 6; i++)
			{
				verts[index+i] = vec3(0,0,0);
				normals[index+i] = vec3(0,0,0);
			}
		}
		
		if(infoBack.x == 0)
		{
			for(int i = 30; i < 36; i++)
			{
				verts[index+i] = vec3(gl_GlobalInvocationID.xyz)+vecTable[i];
				normals[index+i] = vec3(0,0,-1);
			}
		}
		else
		{
			for(int i = 30; i < 36; i++)
			{
				verts[index+i] = vec3(0,0,0);
				normals[index+i] = vec3(0,0,0);
			}
		}
		
		if(infoLeft.x == 0)
		{
			for(int i = 6; i < 12; i++)
			{
				verts[index+i] = vec3(gl_GlobalInvocationID.xyz)+vecTable[i];
				normals[index+i] = vec3(-1,0,0);
			}
		}
		else
		{
			for(int i = 6; i < 12; i++)
			{
				verts[index+i] = vec3(0,0,0);
				normals[index+i] = vec3(0,0,0);
			}
		}
		
		if(infoRight.x == 0)
		{
			for(int i = 12; i < 18; i++)
			{
				verts[index+i] = vec3(gl_GlobalInvocationID.xyz)+vecTable[i];
				normals[index+i] = vec3(1,0,0);
			}
		}
		else
		{
			for(int i = 12; i < 18; i++)
			{
				verts[index+i] = vec3(0,0,0);
				normals[index+i] = vec3(0,0,0);
			}
		}
		
		if(infoUp.x == 0)
		{
			for(int i = 18; i < 24; i++)
			{
				verts[index+i] = vec3(gl_GlobalInvocationID.xyz)+vecTable[i];
				normals[index+i] = vec3(0,1,0);
			}
		}
		else
		{
			for(int i = 18; i < 24; i++)
			{
				verts[index+i] = vec3(0,0,0);
				normals[index+i] = vec3(0,0,0);
			}
		}
		
		if(infoDown.x == 0)
		{
			for(int i = 24; i < 30; i++)
			{
				verts[index+i] = vec3(gl_GlobalInvocationID.xyz)+vecTable[i];
				normals[index+i] = vec3(0,-1,0);
			}
		}
		else
		{
			for(int i = 24; i < 30; i++)
			{
				verts[index+i] = vec3(0,0,0);
				normals[index+i] = vec3(0,0,0);
			}
		}
	}
	else
	{

			for(int i = 0; i < 36; i++)
			{
				verts[index+i] = vec3(0,0,0);
				normals[index+i] = vec3(0,0,0);
			}
			
	}
	
	
	
}