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

    // ---------- Aviso diario ----------

    // Programa el servicio en segundo plano para la próxima hora:minuto elegida.
    function programarAviso() as Void {
        if (!(Toybox has :Background)) {
            return;
        }
        try {
            if (!avisoActivo()) {
                Background.deleteTemporalEvent();
                return;
            }
            var hora = horaAviso();
            var minuto = minutoAviso();
            var cuando = Time.today().add(new Time.Duration(hora * 3600 + minuto * 60));
            if (cuando.compare(Time.now()) <= 0) {
                cuando = cuando.add(new Time.Duration(86400));
            }
            Background.registerForTemporalEvent(cuando);
        } catch (e) {
            // Si el sistema rechaza la programación, la app sigue funcionando sin aviso.
        }
    }

    // ---------- Red ----------

    function pedirNoticias(callback as Method) as Void {
        Communications.makeWebRequest(
            BACKEND_URL,
            { "tema" => temaActual() },
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            callback
        );
    }
}

