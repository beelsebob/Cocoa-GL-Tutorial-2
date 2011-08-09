#version 150

in vec2 positionV;
in vec2 texCoordV;
in vec4 colourV;

out vec4 fragColour;

uniform vec2 p;

uniform sampler2D background;
uniform sampler2D hole;

void main(void)
{
    vec4 holeColour = texture(hole, texCoordV);
    fragColour = colourV + (1.0 - holeColour.a) * texture(background, positionV);
}
