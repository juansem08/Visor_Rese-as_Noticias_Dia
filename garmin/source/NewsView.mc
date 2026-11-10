import Toybox.Application.Storage;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

const CLAVE_NOTICIAS = "noticias";
const CLAVE_CATEGORIAS = "categorias";
const CLAVE_FECHA = "fecha";
const CLAVE_TEMA = "tema";

// Pantallas cuando ya hay noticias
const PANTALLA_PORTADA = 0;   // "NOTICIAS DEL DÍA" + LEER RESUMEN
const PANTALLA_NOTICIA = 1;   // carrusel vertical 01/03 · 02/03 · 03/03
const PANTALLA_FIN = 2;       // "ESTÁS AL DÍA"
// Sin noticias se muestra "PREPARANDO TU RESUMEN" o "SIN CONEXIÓN".

class NewsView extends WatchUi.View {

    private var _noticias as Array<String> = [] as Array<String>;
    private var _categorias as Array<String> = [] as Array<String>;
    private var _fecha as String = "";
    private var _tema as String = "";
    private var _indice as Number = 0;
    private var _pantalla as Number = PANTALLA_PORTADA;
    private var _leidas as Number = 0;            // bits: noticia i leída
    private var _cargando as Boolean = false;
    private var _codigoError as Number? = null;

    // Animaciones: deslizamiento del titular y giro de "preparando"
    private var _offset as Number = 0;
    private var _fase as Number = 0;
    private var _timer as Timer.Timer;
    private var _timerActivo as Boolean = false;

    // Titular ya ajustado (se recalcula solo al cambiar de noticia)
    private var _ajusteIndice as Number = -1;
    private var _ajusteTexto as String = "";
    private var _ajusteFuente as FontType = Graphics.FONT_SMALL;

    // Guarda en el reloj las noticias recibidas (desde la app o el servicio en segundo plano).
    static function guardar(datos as Dictionary) as Void {
        Storage.setValue(CLAVE_NOTICIAS, datos.get("noticias") as Array<String>);
        Storage.setValue(CLAVE_CATEGORIAS, datos.get("categorias") as Array<String>);
        Storage.setValue(CLAVE_FECHA, datos.get("fecha") as String);
        Storage.setValue(CLAVE_TEMA, datos.get("tema") as String);
    }

    function initialize() {
        View.initialize();
        Ui.cargarFuentes();
        _timer = new Timer.Timer();
        _tema = Config.temaActual();

        // Noticias guardadas de la última vez: se ven al instante, aun sin conexión.
        _noticias = Config.textosDe(Storage.getValue(CLAVE_NOTICIAS));
        _categorias = Config.textosDe(Storage.getValue(CLAVE_CATEGORIAS));
        var fecha = Storage.getValue(CLAVE_FECHA);
        if (fecha instanceof String) {
            _fecha = fecha;
        }
        var tema = Storage.getValue(CLAVE_TEMA);
        if (tema instanceof String) {
            _tema = tema;
        }
    }

    function onShow() as Void {
        animar();
    }

    function onHide() as Void {
        _timer.stop();
        _timerActivo = false;
        _offset = 0;
    }

}
