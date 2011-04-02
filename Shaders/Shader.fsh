varying vec2 positionV;
varying vec2 texCoordV;
varying vec4 colourV;

uniform vec2 p;

uniform sampler2D background;
uniform sampler2D hole;

void main(void)
{
    vec4 holeColour = texture2D(hole, texCoordV);
    gl_FragColor = colourV + (1.0 - holeColour.a) * texture2D(background, positionV);
}
