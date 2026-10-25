# PacCo-op

Pac-Man cooperativo online (2 jugadores) con rescate, bombas de tóner y disparos.
Godot 4.3 · export Web · WebRTC P2P · Cloudflare Worker (señalización) · GitHub Pages.

## Pasos (los únicos que requieren tu cuenta)

### 1) Señalización en Cloudflare
```
cd signaling
npx wrangler login
npx wrangler deploy
```
Copia la URL resultante (https://pacco-signal.XXXX.workers.dev) y cámbiala a `wss://...`
en `autoload/network.gd` (constante `SIGNALING_URL`).

### 2) Juego en GitHub Pages
```
git init && git add . && git commit -m "PacCo-op"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/pacco-op.git
git push -u origin main
```
En GitHub: Settings → Pages → Source: **GitHub Actions**. El workflow exporta y publica solo.
URL final: https://TU_USUARIO.github.io/pacco-op/

### 3) iPhone
Abre la URL en Safari → Compartir → "Añadir a pantalla de inicio" (modo pantalla completa).
Un jugador toca **Crear sala** y pasa el código de 4 letras; el otro toca **Unirse**.

## Controles
- Táctil: deslizar = mover · doble toque = bomba · toque con 2 dedos = disparo
- Mando: stick/cruceta · X (Xbox) / Cuadrado (PS) = bomba · A / Equis = disparo
- Teclado (pruebas): flechas/WASD · Espacio = bomba · Z = disparo

## Reglas implementadas
- 3 vidas compartidas; cada captura cuesta 1 (el rescate es gratis). Limpiar el laberinto da +1 (máx. 5).
- Caído → orbe de alma 10 s; el compañero lo toca para revivirlo (2 s de invulnerabilidad).
- Game Over cuando nadie queda en pie.
- Bomba: 2.5 s de mecha, radio 2 casillas por pasillo. Disparos: máx. 2, línea recta.
- Fantasmas: chaser / ambusher / flanker / blocker (con escudo), esquivan balas y huyen de bombas.

## Balance (constantes a ajustar)
`ghost.gd`: SPEED, DODGE_CD, SHIELD_CD, RESPAWN · `bomb.gd`: RADIUS_TILES · `player.gd`: SPEED, MAX_AMMO

## Notas técnicas
- Host autoritativo: el jugador 1 simula todo; el cliente envía solo su dirección/acciones.
- Si la red falla en algunas redes móviles (NAT estricto), hace falta un servidor TURN (Cloudflare Calls tiene capa gratis).
