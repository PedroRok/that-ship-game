shader_type canvas_item;

uniform vec4 BackColor : source_color = vec4(0.0, 0.4, 0.58, 1.0);
uniform vec4 CloudColor : source_color = vec4(0.18, 0.70, 0.87, 1.0);
uniform float speed : hint_range(0.0, 5.0) = 0.1;

//const float TAU = 6.28318530718;

float Func(float pX)
{
	return 0.6*(0.5*sin(0.1*pX) + 0.5*sin(0.553*pX) + 0.7*sin(1.2*pX));
}


float FuncR(float pX)
{
	return 0.5 + 0.25*(1.0 + sin(mod(40.0*pX, TAU)));
}


float Layer(vec2 pQ, float pT)
{
	vec2 Qt = 10.0*pQ;
	pT *= 0.5;
	Qt.x += pT;

	float Xi = floor(Qt.x);
	float Xf = Qt.x - Xi -0.5;

	vec2 C;
	float Yi;
	float D = 1.0 - step(Qt.y,  Func(Qt.x));

	// Disk:
	Yi = Func(Xi + 0.5);
	C = vec2(Xf, Qt.y - Yi );
	D =  min(D, length(C) - FuncR(Xi+ pT/80.0));

	// Previous disk:
	Yi = Func(Xi+1.0 + 0.5);
	C = vec2(Xf-1.0, Qt.y - Yi );
	D =  min(D, length(C) - FuncR(Xi+1.0+ pT/80.0));

	// Next Disk:
	Yi = Func(Xi-1.0 + 0.5);
	C = vec2(Xf+1.0, Qt.y - Yi );
	D =  min(D, length(C) - FuncR(Xi-1.0+ pT/80.0));

	return min(1.0, D);
}

vec2 tile(vec2 _st, float _zoom){
    _st *= _zoom;
    return fract(_st);
}

void fragment() {
	//vec2 uv = 8.0 * (SCREEN_UV - UV * 2.0);
	vec2 uv = 8.0 * (0.2-UV - SCREEN_UV /2.);
	
	uv = vec2(
        float(int(uv.x * 80.0)) / 80.0,
        float(int(uv.y * 80.0)) / 80.0
    );

	// Render:
	vec3 Color= BackColor.rgb;
	float iteration = 0.;
	for(float J = 0.0; J <= 1.0; J += 0.2)
	{
		// Cloud Layer:
		float Lt =  TIME * -speed * (0.5  + 2.0 * J) * (1.0 + 0.1 * sin(226.0 * J)) + 17.0 * J;
		vec2 Lp = vec2(0.0, 0.3 + 2.5 * ( J - 0.3));
		float L = Layer(uv + Lp - (UV - SCREEN_UV * iteration), Lt);
		// Blur and color:
		float Blur = 0.0 * (0.5 * abs(2.0 - 5.0 * J)) / (11.0 - 5.0 * J);
		float V = mix( 0.0, 1.0, 1.0 - smoothstep( 0.0, 0.01 +0.2 * Blur, L ) );
		vec3 Lc=  mix(CloudColor.rgb, vec3(1.0), J -1.2);
		Color =mix(Color, Lc,  V);
		iteration += 1.0;
	}
	
	
	// Determine the edge
	vec2 texture_coords = vec2(UV.x, UV.y); // Static texture without TIME offset
	
	float alpha = 1.0;

	
	
	
	COLOR = vec4(Color,alpha);
}