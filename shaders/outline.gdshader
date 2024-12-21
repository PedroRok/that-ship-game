shader_type canvas_item;

uniform bool enable:instance_index(0);
uniform vec4 outline_color:source_color;

void fragment() {
	if (enable) 
	{
		float pixel_size_x = 1.0/float(textureSize(TEXTURE,0).x);
		float pixel_size_y = 1.0/float(textureSize(TEXTURE,0).y);
		vec2 pixel_size = vec2(pixel_size_x, pixel_size_y);
		if (texture(TEXTURE, UV).a == 0.)
		{ 
			for(int x = -1; x <= 1; x++)
			{
				for(int y = -1; y <= 1; y++)
				{
					vec2 pixel_offset = vec2(float(x),float(y));
					if( texture(TEXTURE, UV+(pixel_offset*pixel_size)).a > 0.)
					{
						vec4 resulting_color = outline_color;
						resulting_color.a = 1.0;
						COLOR = resulting_color;
					}
				}
			}
		}else
		{
			COLOR = texture(TEXTURE, UV);
		}
	}
}