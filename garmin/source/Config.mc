import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// URL del backend. En el reloj real DEBE ser HTTPS (p. ej. desplegado en Vercel).
// En el simulador puedes usar "http://localhost:3000/api/news" desactivando
// "Settings > Use Device HTTPS Requirements".
(:background)
const BACKEND_URL = "https://visordenoticias.vercel.app/api/news";

// Lógica compartida entre la app y el servicio en segundo plano.
(:background)
module Config {

    // Mismo orden que settings.xml y que TEMAS en lib/news.ts
    const TEMAS = ["mundo", "tecnologia", "deportes", "economia", "ciencia", "salud", "cultura"] as Array<String>;
    const NOMBRES = ["MUNDO", "TECNOLOGÍA", "DEPORTES", "ECONOMÍA", "CIENCIA", "SALUD", "CULTURA"] as Array<String>;
    const PROPIEDADES_TEMA = ["TemaMundo", "TemaTecnologia", "TemaDeportes", "TemaEconomia",
                              "TemaCiencia", "TemaSalud", "TemaCultura"] as Array<String>;

    // ---------- Ajustes del teléfono ----------

    function leerNumero(clave as String, porDefecto as Number, minimo as Number, maximo as Number) as Number {
        var valor = Application.Properties.getValue(clave);
        if (valor instanceof Number && valor >= minimo && valor <= maximo) {
            return valor;
        }
        return porDefecto;
    }

    function leerBooleano(clave as String, porDefecto as Boolean) as Boolean {
        var valor = Application.Properties.getValue(clave);
        if (valor instanceof Boolean) {
            return valor;
        }
        return porDefecto;
    }

    // Temas marcados en el teléfono, en orden: "mundo" o "mundo,deportes,salud".
    // Es también la clave con la que el backend responde (campo "tema").
    function temaActual() as String {
        var texto = "";
        for (var i = 0; i < TEMAS.size(); i++) {
            if (leerBooleano(PROPIEDADES_TEMA[i], i == 0)) {
                texto = (texto.length() == 0) ? TEMAS[i] : texto + "," + TEMAS[i];
            }
        }
        return (texto.length() == 0) ? TEMAS[0] : texto;
    }

    // Etiqueta de respaldo: el primer tema de la lista.
    function nombreTema(tema as String) as String {
        for (var i = 0; i < TEMAS.size(); i++) {
            var largo = TEMAS[i].length();
            if (tema.length() >= largo && (tema.substring(0, largo) as String).equals(TEMAS[i])) {
                return NOMBRES[i];
            }
        }
        return NOMBRES[0];
    }

    function avisoActivo() as Boolean {
        return leerBooleano("AvisoDiarioActivo", true);
    }

    // 0 = grande, 1 = mediano, 2 = pequeño
    function tamanoTexto() as Number {
        return leerNumero("TamanoTexto", 0, 0, 2);
    }

    function vibrar() as Boolean {
        return leerBooleano("Vibrar", true);
    }

    function abrirDirecto() as Boolean {
        return leerBooleano("AbrirDirecto", false);
    }

    function horaAviso() as Number {
        return leerNumero("AvisoHora", 7, 0, 23);
    }

    function minutoAviso() as Number {
        return leerNumero("AvisoMinutos", 0, 0, 59);
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

    // Fecha local del reloj, "YYYY-MM-DD".
    function hoyIso() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return info.year.format("%04d") + "-" + (info.month as Number).format("%02d") + "-" + info.day.format("%02d");
    }

    function pedirNoticias(callback as Method) as Void {
        Communications.makeWebRequest(
            BACKEND_URL,
            // "dia" hace que cada día sea una URL distinta: la caché de Vercel
            // nunca puede devolver el resumen de ayer a la hora del aviso.
            { "tema" => temaActual(), "dia" => hoyIso() },
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            callback
        );
    }

    // Valida la respuesta del backend. Devuelve
    // { "noticias" => Array<String>, "categorias" => Array<String>, "fecha" => String, "tema" => String } o null.
    function extraer(codigo as Number, data) as Dictionary? {
        if (codigo != 200 || !(data instanceof Dictionary)) {
            return null;
        }
        var textos = textosDe(data.get("noticias"));
        if (textos.size() == 0) {
            return null;
        }
        var fecha = data.get("fecha");
        var tema = data.get("tema");
        return {
            "noticias" => textos,
            "categorias" => textosDe(data.get("categorias")),
            "fecha" => (fecha instanceof String) ? fecha : "",
            "tema" => (tema instanceof String) ? tema : temaActual()
        };
    }

    // Hasta 3 textos de una lista JSON (ignora lo que no sea texto).
    function textosDe(lista) as Array<String> {
        var textos = [] as Array<String>;
        if (lista instanceof Array) {
            for (var i = 0; i < lista.size() && textos.size() < 3; i++) {
                var t = lista[i];
                if (t instanceof String) {
                    textos.add(t);
                }
            }
        }
        return textos;
    }
}
