#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;                  // Float index 0, 1
uniform float uTime;                 // Float index 2
uniform float uChromaticAberration;  // Float index 3 (0.024)
uniform float uCornerRadius;         // Float index 4 (30.0)
uniform float uIsDark;               // Float index 5 (1.0 or 0.0)
uniform float uIsGenerating;         // Float index 6 (1.0 or 0.0)
uniform float uIOR;                  // Float index 7 (1.25)

out vec4 fragColor;

float sdfSquircle(vec2 p, vec2 b, float r, float k) {
    float shortest = min(b.x, b.y);
    r = min(r, shortest);
    vec2 d = abs(p) - b + r;
    float s = max(d.x, d.y);
    if (s <= 0.0) return s - r;
    vec2 q = max(d, 0.0);
    float cornerDist = pow(pow(q.x/r, k) + pow(q.y/r, k), 1.0/k);
    return (cornerDist - 1.0) * r;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 center = uSize * 0.5;
    vec2 p = fragCoord - center;
    vec2 halfSize = center;

    float sd = sdfSquircle(p, halfSize, uCornerRadius, 2.0);

    if (sd > 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float distInside = -sd;

    // Thin, sleek Capillary Meniscus (5.0px)
    float capillaryLength = 5.0;
    float capillaryMeniscus = exp(-distInside / capillaryLength);

    // Continuous 3D normal vector from spatial SDF derivatives
    float dx = dFdx(sd);
    float dy = dFdy(sd);
    vec2 edgeGrad = normalize(vec2(dx, dy) + 0.0001);

    // Gentle fluid surface tension waves
    float waveSpeed = uIsGenerating > 0.5 ? 2.0 : 0.8;
    float waveAmp = uIsGenerating > 0.5 ? 0.025 : 0.008;
    float fluidWave = sin(p.x * 0.025 + uTime * waveSpeed) * cos(p.y * 0.035 - uTime * (waveSpeed * 0.7)) * waveAmp;

    // Sleek thin surface normal
    float slopeFactor = capillaryMeniscus * 1.5;
    vec3 N = normalize(vec3(edgeGrad * slopeFactor, 1.0 - capillaryMeniscus * 0.35 + fluidWave));

    // Snell's Law Refraction Ray
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    vec3 R_ray = refract(-viewDir, N, 1.0 / uIOR);

    // Sleek thin edge displacement
    float liquidElasticPull = pow(capillaryMeniscus, 1.4) * 1.2;
    vec2 elasticDisplacement = R_ray.xy * (1.0 + liquidElasticPull);

    // Thin, crisp chromatic dispersion along the slim perimeter
    float ca = uChromaticAberration * capillaryMeniscus * 1.8;
    float rOffset = dot(elasticDisplacement, vec2(1.1, 0.5)) * (1.0 + ca);
    float gOffset = dot(elasticDisplacement, vec2(1.1, 0.5));
    float bOffset = dot(elasticDisplacement, vec2(1.1, 0.5)) * (1.0 - ca);

    // Studio Key Lighting & Specular Highlights
    float lightAngle = 0.62 * 3.14159265;
    vec3 lightDir = normalize(vec3(cos(lightAngle), -sin(lightAngle), 0.75));
    vec3 halfVec = normalize(lightDir + viewDir);
    float NdotH = max(dot(N, halfVec), 0.0);
    float specular = pow(NdotH, 24.0) * 0.50;

    // Secondary Ambient Fill Reflection
    vec3 fillLightDir = normalize(vec3(-0.5, 0.7, 0.5));
    float NdotFill = max(dot(N, fillLightDir), 0.0);
    float fillReflection = pow(NdotFill, 14.0) * 0.18;

    // Fresnel Dielectric Reflection
    float cosTheta = clamp(dot(N, viewDir), 0.0, 1.0);
    float fresnel = 0.04 + 0.96 * pow(1.0 - cosTheta, 3.8);

    // Thin Top-Lip Sheen & Slim Rim Highlight
    float topLipSheen = smoothstep(1.5, 0.0, distInside) * smoothstep(-0.2, 0.9, -N.y) * 0.40;
    float rimDiffraction = smoothstep(1.0, 0.0, distInside) * 0.28;

    // Spectral rainbow dispersion fringe
    vec3 chromaticTint = vec3(
        0.5 + 0.5 * sin(rOffset * 4.0),
        0.5 + 0.5 * sin(gOffset * 4.0 + 2.094),
        0.5 + 0.5 * sin(bOffset * 4.0 + 4.188)
    ) * ca * 0.80;

    // Liquid substrate tint
    vec3 liquidBase = mix(vec3(0.98, 0.99, 1.0), vec3(0.12, 0.16, 0.24), uIsDark);
    vec3 finalRgb = liquidBase + chromaticTint;

    finalRgb += vec3(0.92, 0.96, 1.0) * fresnel * 0.45;
    finalRgb += vec3(1.0) * (specular + fillReflection + topLipSheen + rimDiffraction);

    // Transmission alpha for slim, elegant frosted glass
    float meniscusAlpha = capillaryMeniscus * 0.22;
    float baseAlpha = mix(0.14, 0.12, uIsDark);
    float finalAlpha = clamp(baseAlpha + meniscusAlpha + fresnel * 0.15 + specular * 0.22, 0.0, 0.75);

    fragColor = vec4(finalRgb * finalAlpha, finalAlpha);
}
