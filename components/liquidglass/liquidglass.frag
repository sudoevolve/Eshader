// 默认常量（当未绑定或传入为非正数时作为回退）
const float DEFAULT_SHAPE_WIDTH = 0.30;
const float DEFAULT_SHAPE_HEIGHT = 0.30;
const float DEFAULT_LENS_REFRACTION = 0.10;
const float DEFAULT_CHROMATIC_ABERRATION = 0.02;

float _clamp(float a){
    return clamp(a,0.,1.);
}

float box( in vec2 p, in vec2 b, in vec4 r )
{
    r.xy = (p.x>0.0)?r.xy : r.zw;
    r.x  = (p.y>0.0)?r.x  : r.y;
    vec2 q = abs(p)-b+r.x;
    return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r.x;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    fragColor = vec4(0);
    vec2 ir = iResolution.xy;
    float effShapeW = (shapeWidth <= 0.0 ? DEFAULT_SHAPE_WIDTH : shapeWidth);
    float effShapeH = (shapeHeight <= 0.0 ? DEFAULT_SHAPE_HEIGHT : shapeHeight);
    float effLensRef = (lens_refraction <= 0.0 ? DEFAULT_LENS_REFRACTION : lens_refraction);
    float effCA = max(0.0, chromaticAberration);
    float pressed = (iMouse.z > 0.0 || iMouse.w > 0.0) ? 1.0 : 0.0;
    float tPress = max(0.0, iTime - pressStartTime);
    float ramp = clamp(tPress / 0.15, 0.0, 1.0);
    float ease = smoothstep(0.0, 1.0, ramp);
    float clickEase = (pressing > 0.5) ? ease : (1.0 - ease);
    float clickScale = (effectsEnabled > 0.5 ? (1.0 + 0.02 * clickEase) : 1.0);
    vec2 wh = vec2(effShapeW,effShapeH)/2.0*ir.x/ir.y * clickScale;
    vec4 vr = vec4(radius)/2.0*ir.x/ir.y * clickScale;
    vec2 uv = fragCoord/ir;
    vec2 mouse = iMouse.xy;
    if (length(mouse)<1.0) {
        mouse = ir/2.0;
    }
    vec2 m2 = (uv-mouse/ir);

    vec2 dragRaw = iMouse.xy - iMouse.zw;
    vec2 dragBox = vec2(dragRaw.x / ir.y, dragRaw.y / ir.y);
    float dragLen = length(dragBox);
    vec2 dir = dragLen > 1e-6 ? dragBox / dragLen : vec2(1.0, 0.0);
    float dtHold = max(0.0, iTime - lastMoveTime);
    float holdBlend = smoothstep(0.02, 0.12, dtHold);
    vec2  velBox   = dragVel;
    float speedLen = length(velBox);
    float speedDyn = mix(speedLen, speedLen * exp(-3.0 * dtHold), holdBlend);
    float stretchNow = pressed > 0.5 ? clamp(speedDyn * 0.03, 0.0, 0.25) : 0.0;
    float dtRelease = max(0.0, iTime - dragReleaseTime);
    float releaseAmp = (pressed < 0.5 ? dragReleaseAmp : 0.0);
    float damp       = 5.0;
    float freq       = 7.0;
    float holdDecay  = exp(-6.0 * max(0.0, iTime - lastMoveTime));
    float residual   = releaseAmp * holdDecay * 0.8 * exp(-damp * dtRelease) * cos(6.2831853 * freq * dtRelease);
    vec2 relDirBox = normalize(vec2(dragReleaseDir.x * (ir.x / ir.y), dragReleaseDir.y));
    vec2 useDir = (pressed > 0.5)
                    ? (speedLen > 1e-6 ? velBox / max(speedLen, 1e-6) : dir)
                    : (length(dragReleaseDir) < 1e-6 ? dir : relDirBox);
    float stretch = (effectsEnabled > 0.5) ? clamp(stretchNow + residual, -0.12, 0.35) : 0.0;
    float alongScale = 1.0 + stretch;
    float perpScale  = max(0.85, 1.0 / (1.0 + stretch));
    vec2 u = useDir;
    vec2 v = vec2(-useDir.y, useDir.x);
    vec2 p0 = vec2(m2.x*ir.x/ir.y, m2.y);
    vec2 q  = vec2(dot(p0, u), dot(p0, v));
    q.x /= alongScale;
    q.y /= perpScale;
    vec2 pStretch = q.x * u + q.y * v;

    float rb1 =  _clamp( -box(pStretch, wh, vr)/sharp*32.0);
    float rb2 =  _clamp(-box(pStretch, wh+1.0/ir.y, vr)/sharp*16.0) - _clamp(-box(pStretch, wh, vr)/sharp*16.0);
    float rb3 = _clamp(-box(pStretch, wh+4.0/ir.y, vr)/sharp*4.0) - _clamp(-box(pStretch, wh-4.0/ir.y, vr)/sharp*4.0);
    float transition = smoothstep(0.0, 1.0, rb1);

    if (transition>0.0) {
        vec2 lens = (uv-0.5)*sin(pow(
            _clamp(-box(pStretch, wh, vr)/effLensRef),
        0.25)*1.57)+0.5;

        vec2 caOffset = effCA * m2;
        float total = 0.0;
        vec4 sumColor = vec4(0.0);
        for (float x = -4.0; x <= 4.0; x++) {
            for (float y = -4.0; y <= 4.0; y++) {
                vec2 blur = vec2(x, y) * blurOffsetScale / ir;
                vec3 col;
                col.r = texture(iChannel0, lens + blur + caOffset).r;
                col.g = texture(iChannel0, lens + blur).g;
                col.b = texture(iChannel0, lens + blur - caOffset).b;
                sumColor += vec4(col, 1.0);
                total += 1.0;
            }
        }
        fragColor = sumColor / total;

        float gradient = _clamp(clamp(m2.y,0.0,0.2)+0.1)/2.0 + _clamp(clamp(-m2.y,-1.0,0.2)*rb3+0.1)/2.0;
        vec4 lighting = fragColor+1.0*vec4(rb2)+gradient*1.0;
        fragColor = mix(texture(iChannel0, uv), lighting, transition);
    } else {
        fragColor = texture(iChannel0, uv);
    }
}

