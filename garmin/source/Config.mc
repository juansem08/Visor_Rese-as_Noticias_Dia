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

    // Mismo orden que la lista de settings.xml y que TEMAS en lib/news.ts
    const TEMAS = ["mundo", "tecnologia", "deportes", "economia", "ciencia", "salud", "cultura"] as Array<String>;
    const NOMBRES = ["MUNDO", "TECNOLOGÍA", "DEPORTES", "ECONOMÍA", "CIENCIA", "SALUD", "CULTURA"] as Array<String>;

    // ---------- Ajustes del teléfono ----------

    function leerNumero(clave as String, porDefecto as Number, minimo as Number, maximo as Number) as Number {
        var valor = Application.Properties.getValue(clave);
        if (valor instanceof Number && valor >= minimo && valor <= maximo) {
            return valor;
        }
        return porDefecto;
    }

    function temaActual() as String {
        return TEMAS[leerNumero("Tema", 0, 0, TEMAS.size() - 1)];
    }

    function nombreTema(tema as String) as String {
        for (var i = 0; i < TEMAS.size(); i++) {
            if (TEMAS[i].equals(tema)) {
                return NOMBRES[i];
            }
        }
        return NOMBRES[0];
    }

    function avisoActivo() as Boolean {
        var valor = Application.Properties.getValue("AvisoActivo");
        if (valor instanceof Boolean) {
            return valor;
        }
        return true;
    }

    function horaAviso() as Number {
        return leerNumero("HoraAviso", 7, 0, 23);
    }

    function minutoAviso() as Number {
        return leerNumero("MinutoAviso", 0, 0, 59);
    }
}

