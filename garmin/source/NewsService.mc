import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

// Se ejecuta en segundo plano a la hora elegida en el teléfono:
// descarga las noticias del día y pide al reloj que avise para abrir la app.
(:background)
class NewsService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        // Deja programado el aviso de mañana.
        Config.programarAviso();
        Config.pedirNoticias(method(:onRespuesta));
    }

    function onRespuesta(codigo as Number, data as Dictionary or String or Null) as Void {
        // Vibra y muestra "¿Abrir Noticias del Dia?" en el reloj.
        Background.requestApplicationWake("Tus 3 noticias del dia estan listas");
        // Entrega las noticias a la app (o null si falló; la app las pedirá al abrirse).
        Background.exit(Config.extraer(codigo, data));
    }
}
