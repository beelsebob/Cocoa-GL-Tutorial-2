#version 150

uniform vec2 p;

in vec4 position;
in vec4 colour;

out vec2 texCoordV;
out vec2 positionV;
out vec4 colourV;

void main (void)
{
    colourV     = colour;
    texCoordV   = position.xy + vec2(0.5);
    positionV   = vec2(0.5) * (position.xy + p + vec2(1.0));
    gl_Position = position    + vec4(p, 0.0, 0.0);
}
