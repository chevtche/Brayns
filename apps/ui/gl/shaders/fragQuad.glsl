#version 420
#extension GL_EXT_gpu_shader4 : enable

in vec2 texCoord;

uniform sampler2D colorBuffer;
uniform sampler2D depthBuffer;

out vec4 color;

vec3 rgb2Hsl( in vec3 rgb )
{
    float r = rgb.r;
    float g = rgb.g;
    float b = rgb.b;

    float max = max( r, max( g, b ));
    float min = min( r, min( g, b ));
    float h, s, l = (max + min) / 2;

    if( max == min )
    {
        h = s = 0; // achromatic
    }
    else
    {
        float d = max - min;
        s = l > 0.5 ? d / (2 - max - min) : d / (max + min);

        if( max == r )
            h = (g - b) / d + (g < b ? 6 : 0);
        else if( max == g )
            h = (b - r) / d + 2;
        else
            h = (r - g) / d + 4;

        h /= 6;
    }

    return vec3( h, s, l );
}

vec3 hsl2Rgb( in vec3 c )
{
    vec3 rgb = clamp( abs( mod( c.x * 6.0 + vec3( 0.0, 4.0, 2.0 ), 6.0 ) - 3.0 ) - 1.0, 0.0, 1.0 );
    return c.z + c.y * ( rgb - 0.5 ) * ( 1.0 - abs( 2.0 * c.z - 1.0 ));
}

void main()
{
    vec3 hslColor = rgb2Hsl( vec3( texture( colorBuffer, texCoord )));

    hslColor.y = 0.13;
    hslColor.x = 0.4;

    color = vec4( hsl2Rgb( hslColor ), 1.0f );

    /*if( length( texture( colorBuffer, texCoord )) > 1.9 )
        color = texture( colorBuffer, texCoord );
    else
        color = vec4( 0.0, 0.0, 0.0, 1.0);*/
}
