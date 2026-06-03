#ifdef GL_ES
precision highp float;
#endif

uniform float time;
uniform vec2 resolution;
uniform vec2 glitch_intensity;

// Datos nativos inyectados directamente por el Axiom Reactor en Rust
uniform mat4 render_matrix;    // Matriz de rotación física de la torre hexagonal
uniform vec4 u_sphere_data;    // x, y, z del orbe + factor de deformación

uniform int lattice_mode;      // 0: SILVER_MIRROR, 1: CRYOGENIC_CYAN, 2: SOVEREIGN_GOLD

// Función matemática SDF para pintar el Orbe 3D real de metal líquido
float sdfSphere(vec3 p, vec3 center, float radius, float distortion) {
    vec3 q = p - center;
    float wave = sin(q.x * 14.0 + time * 8.0) * cos(q.y * 14.0 + time * 8.0) * 0.02 * distortion;
    return length(q) - (radius + wave);
}

// Función matemática SDF para pintar las placas hexagonales con volumen
float sdfHexPrism(vec3 p, vec2 h) {
    const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
    vec3 cp = p;
    
    // Aplicamos la matriz de rotación de tu Rust
    cp = (render_matrix * vec4(cp, 1.0)).xyz;
    
    vec3 q = abs(cp);
    q.xy -= 2.0 * min(dot(k.xy, q.xy), 0.0) * k.xy;
    q.xy -= vec2(clamp(q.x, -k.z * h.x, k.z * h.x), h.x);
    return length(max(q.xy, 0.0)) * sign(q.y) - h.y;
}

void main() {
    // Normalización del espacio del lienzo
    vec2 uv = (gl_FragCoord.xy * 2.0 - resolution.xy) / resolution.y;
    
    // CORRECCIÓN SOBERANA DE CÁMARA: La alejamos a Z=5.0 y la subimos en Y=0.8 para ver desde arriba
    vec3 ray_origin = vec3(0.0, 0.8, 5.0);
    // Apuntamos el vector de visión ligeramente hacia abajo para pillar perspectiva 3D real
    vec3 ray_direction = normalize(vec3(uv.x, uv.y - 0.2, -1.8));
    
    vec3 final_color = vec3(0.01, 0.01, 0.02); // Espacio profundo
    float distance_traveled = 0.0;
    
    for (int i = 0; i < 50; i++) {
        vec3 current_position = ray_origin + distance_traveled * ray_direction;
        
        // Evaluamos el orbe flotando arriba
        float sphere_dist = sdfSphere(current_position, vec3(u_sphere_data.x, 0.6, u_sphere_data.z), 0.35, u_sphere_data.w);
        
        // Evaluamos la oblea hexagonal abajo reducida de tamaño (Radio 0.8, Grosor 0.1)
        float hex_dist = sdfHexPrism(current_position - vec3(0.0, -0.3, 0.0), vec2(0.8, 0.1));
        
        float closest_distance = min(sphere_dist, hex_dist);
        
        if (closest_distance < 0.001) {
            vec3 normal = normalize(current_position - vec3(0.0, 0.2, 0.0));
            float lighting = max(dot(normal, vec3(0.4, 1.0, 0.4)), 0.2);
            
            if (closest_distance == sphere_dist) {
                // Mercurio líquido reflectivo
                vec3 reflection = reflect(ray_direction, normal);
                final_color = vec3(0.85, 0.88, 0.95) * lighting + pow(max(dot(reflection, vec3(0.0, 1.0, 0.0)), 0.0), 8.0);
            } else {
                // Obleas hexagonales cromáticas
                if (lattice_mode == 0) {
                    final_color = vec3(0.55, 0.58, 0.65) * lighting; // Plata Espejo
                } else if (lattice_mode == 1) {
                    final_color = vec3(0.0, 0.85, 1.0) * (lighting * 1.6); // Cian Criogénico
                } else if (lattice_mode == 2) {
                    float crack = step(0.93, sin(current_position.x * 25.0) * cos(current_position.z * 25.0));
                    final_color = mix(vec3(0.05, 0.05, 0.07), vec3(1.0, 0.75, 0.1), crack) * lighting; // Negro y Oro
                }
            }
            break;
        }
        
        distance_traveled += closest_distance;
        if (distance_traveled > 10.0) break;
    }
    
    // Halo cuántico en los bordes
    float edge_glow = smoothstep(0.4, 1.1, length(uv));
    final_color += vec3(edge_glow * 0.04, 0.02, edge_glow * 0.07);
    
    gl_FragColor = vec4(final_color, 1.0);
}