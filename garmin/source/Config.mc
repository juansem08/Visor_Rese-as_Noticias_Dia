import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Time;

// URL del backend. En el reloj real DEBE ser HTTPS (p. ej. desplegado en Vercel).
// En el simulador puedes usar "http://localhost:3000/api/news" desactivando
// "Settings > Use Device HTTPS Requirements".
(:background)
// TODO: al publicar en Vercel, cambiar por "https://TU-PROYECTO.vercel.app/api/news"
const BACKEND_URL = "http://localhost:3000/api/news";

// Lógica compartida entre la app y el servicio en segundo plano.
(:background)
module Config {
}
