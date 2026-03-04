//Calculates the acceleration of each object and integrates its position.

#define TIME_SCALE 2.
#define dKdl .188
#define dKda .0188

// storage register/texel addresses
const vec2 txCMP = vec2(0.0,0.0);
const vec2 txCMV = vec2(1.0,0.0);
const vec2 txAM  = vec2(2.0,0.0);
const vec2 txO1  = vec2(3.0,0.0);
const vec2 txO2  = vec2(4.0,0.0);
const vec2 txO3  = vec2(5.0,0.0);

const vec3 g_boxSize = vec3(.4);
const vec3 ptOnBody1 = vec3(g_boxSize.x*.5, g_boxSize.y*.15, g_boxSize.z*.5); 
const vec3 ptOnBody2 = vec3(g_boxSize.x*.5, -g_boxSize.y*.5, -g_boxSize.z*.5); 
const vec3 g_posFix2 = vec3(0.,1.,0.);
const float dSpringLen = .25;
const float dSpringK = 100.;
const float boxMass = 2.;

float hash( int n ) { return fract(sin(float(n))*43758.5453123); }

struct Body {
    vec3 vCMPosition,
         vCMVelocity, 
         vAngularMomentum;
    mat3 mOrientation;
};
  
float keyPress(int ascii) {
	return texture(iChannel2,vec2((.5+float(ascii))/256.,0.25)).x ;
}


//--------------------------------------------------------------------
// from iq shader Brick [https://www.shadertoy.com/view/MddGzf]
//--------------------------------------------------------------------
    
float isInside( vec2 p, vec2 c ) { vec2 d = abs(p-0.5-c) - 0.5; return -max(d.x,d.y); }

vec3 load(in vec2 re) {
    return texture(iChannel0, (0.5+re) / iChannelResolution[0].xy, -100.0 ).xyz;
}

void store( in vec2 re, in vec3 va, inout vec4 fragColor, in vec2 fragCoord) {
    fragColor = ( isInside(fragCoord,re) > 0.0 ) ? vec4(va,0.) : fragColor;
}
   
// --------------------------------------------------------------------------------------------


Body getBody() {
    return Body(load(txCMP), load(txCMV), load(txAM), mat3(load(txO1), load(txO2), load(txO3)));
}

void saveBody(Body body, inout vec4 fragColor, in vec2 fragCoord) {
	store(txCMP, body.vCMPosition,  	fragColor, fragCoord);
	store(txCMV, body.vCMVelocity,  	fragColor, fragCoord);
	store(txAM,  body.vAngularMomentum, fragColor, fragCoord);
	store(txO1,  body.mOrientation[0],  fragColor, fragCoord);
	store(txO2,  body.mOrientation[1],  fragColor, fragCoord);
	store(txO3,  body.mOrientation[2],  fragColor, fragCoord);
}
                    

mat3 orthonormalize(mat3 m) {
    vec3 v0 = normalize(m[0]), v2 = normalize(cross(v0, m[1])), v1 = normalize(cross(v2,v0));
    return mat3(v0,v1,v2);
}
       
mat3 skewSymmetric(vec3 v) {
    return mat3(
          0., v.z,  -v.y,
        -v.z,   0.,  v.x,
         v.y,  -v.x,   0.);
}

// for cube Size: meter, Mass: kg
mat3 inverseInertiaTensor(vec3 s, float m) {
	return mat3(
        3./(m*dot(s.yz,s.yz)), 0., 0.,
        0., 3./(m*dot(s.zx,s.zx)), 0.,
        0., 0., 3./(m*dot(s.xy, s.xy)));
}

// for sphere Rayon: meter, Mass: kg
mat3 inverseInertiaTensorSphere(float r, float m) {
    float it = (2.*m*r*r);
	return mat3(
        it, 0., 0.,
        0., it, 0.,
        0., 0., it);
}

//http://allenchou.net/2013/12/game-physics-motion-dynamics-implementations/
// for Cylinder Rayon: meter, Mass: kg
mat3 inverseInertiaTensorCylinder(float r, float h, float m) {
	return mat3(
        4./(m*h*h/3.+m*r*r), 0., 0.,
        0., 4./(m*h*h/3.+m*r*r), 0.,
        0., 0., 2./(m*r*r));
}

Body Integrate3D(float mass, mat3 mInverseBodyInertiaTensor, 
                 Body obj, vec3 vCMForce, vec3 vTorque, float dt) {
    // compute auxiliary quantities
    mat3 mInverseWorldInertiaTensor = obj.mOrientation * mInverseBodyInertiaTensor * transpose(obj.mOrientation);
    vec3 vAngularVelocity = mInverseWorldInertiaTensor * obj.vAngularMomentum;
       		
    vCMForce -= obj.vCMVelocity * dKdl/dt; // Air friction
    vTorque -= vAngularVelocity * dKda/dt;
    
    obj.vCMVelocity	+= dt * vCMForce /mass;
    
    obj.mOrientation	 += skewSymmetric(vAngularVelocity) * obj.mOrientation  * dt;
    obj.vAngularMomentum += vTorque * dt;
    obj.mOrientation = orthonormalize(obj.mOrientation);

    // integrate primary quantities
    obj.vCMPosition	+= obj.vCMVelocity * dt;
    
    return obj;
}

vec3 getSpringForce(vec3 vSpringPos, vec3 vConnexionPos) {
	// force of this string
    vec3 v = vSpringPos - vConnexionPos;
	float dLen = length(v);
    float dSpringF = dSpringK * clamp(dLen - dSpringLen, 0., dSpringLen*4.);
	return v * (dSpringF / dLen);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{   
    // don't compute gameplay outside of the data area
    if( fragCoord.x > 6. || fragCoord.y>.5 ) discard;
       
    vec2 res = iResolution.xy / iResolution.y;
    int id = int(fragCoord.x);  
    Body body;
  
    //Initialization (iFrame == 0 doesn't seem to work when the page is initially loaded)
    if(iFrame < 30) { //iTime < 1.0) {
        vec2 rpos = vec2(float(id) * 1.85, float(id) * -0.03); 
        body = Body(vec3(0.), vec3(0.), vec3(0.), mat3(1,0,0,0,1,0,0,0,1));
    }
    else {

        body = getBody();
        
        vec3 sumF = vec3(0), sumTorque = vec3(0);
       
        // Gravity
        sumF += vec3(0.,-9.81,0.) * boxMass; 
        
        // Mouse
        vec2 m = iMouse.xy/iResolution.y - .5;
        vec3 posFix = vec3(m.x,1.,m.y);
		// connexion pt in world base
        vec3 vConnexionPos = body.vCMPosition + body.mOrientation*ptOnBody1; 
        vec3 springForce = getSpringForce(posFix, vConnexionPos);

        // sum forces applied to object
        sumF += springForce;
        sumTorque += cross(vConnexionPos - body.vCMPosition, springForce);

        if (keyPress(32) < .5) { // SPACE
        	
		// connexion pt in world base
        	vec3 vConnexionPos2 = body.vCMPosition + body.mOrientation*ptOnBody2; 
       		vec3 springForce2 = getSpringForce(g_posFix2, vConnexionPos2);
        
            // sum forces applied to object
            sumF += springForce2;
            sumTorque += cross(vConnexionPos2 - body.vCMPosition, springForce2);
        }
                
        body = Integrate3D(boxMass, inverseInertiaTensor(g_boxSize, boxMass), body, sumF, sumTorque, /*iTimeDelta */ .015*TIME_SCALE);
    }
    
    fragColor = vec4(0.0);
    saveBody(body, fragColor, fragCoord);                   
}
                           
                           
    