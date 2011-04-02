uniform vec2 p;

attribute vec4 position;
attribute vec4 colour;

varying vec2 texCoordV;
varying vec2 positionV;
varying vec4 colourV;

void main (void)
{
    colourV     = colour;
    texCoordV   = position.xy + vec2(0.5);
    positionV   = vec2(0.5) * (position.xy + p + vec2(1.0));
    gl_Position = position    + vec4(p, 0.0, 0.0);
}
