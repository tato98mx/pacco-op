// Servidor de señalización para WebRTC. Solo reenvía mensajes entre 2 jugadores.
// Cada sala (código de 4 letras) es un Durable Object. Usa el plan gratuito.

export class Room {
  constructor(state, env) {
    this.peers = new Map(); // id (1 = host, 2 = invitado) -> WebSocket
  }

  async fetch(request) {
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected websocket", { status: 426 });
    }
    const role = new URL(request.url).searchParams.get("role");
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.accept();

    const reject = (reason) => {
      server.send(JSON.stringify({ type: "error", reason }));
      server.close(1000, reason);
      return new Response(null, { status: 101, webSocket: client });
    };

    let id;
    if (role === "host") {
      if (this.peers.has(1)) return reject("room_taken");
      id = 1;
    } else {
      if (!this.peers.has(1)) return reject("no_room");
      if (this.peers.has(2)) return reject("room_full");
      id = 2;
    }

    this.peers.set(id, server);
    server.send(JSON.stringify({ type: "welcome", id }));
    if (id === 2) this.peers.get(1).send(JSON.stringify({ type: "peer_joined", id: 2 }));

    server.addEventListener("message", (ev) => {
      if (typeof ev.data !== "string" || ev.data.length > 8192) return;
      let msg;
      try { msg = JSON.parse(ev.data); } catch { return; }
      const target = this.peers.get(msg.to);
      if (target) target.send(JSON.stringify({ ...msg, from: id }));
    });

    const leave = () => {
      if (this.peers.get(id) === server) this.peers.delete(id);
      for (const [, ws] of this.peers) {
        try { ws.send(JSON.stringify({ type: "peer_left", id })); } catch {}
      }
    };
    server.addEventListener("close", leave);
    server.addEventListener("error", leave);

    return new Response(null, { status: 101, webSocket: client });
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const m = url.pathname.match(/^\/ws\/([A-Za-z]{4})$/);
    if (!m) return new Response("pacco-signal ok", { status: 200 });
    const code = m[1].toUpperCase();
    const stub = env.ROOM.get(env.ROOM.idFromName(code));
    return stub.fetch(request);
  },
};
