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

    // ======================================================================
    // Datos
    // ======================================================================

    // forzar = true cuando cambian los ajustes: se pide aunque haya una petición en curso.
    function actualizar(forzar as Boolean) as Void {
        if (_cargando && !forzar) {
            return;
        }
        _cargando = true;
        animar();
        WatchUi.requestUpdate();
        Config.pedirNoticias(method(:onRespuesta));
    }

    function onRespuesta(codigo as Number, data as Dictionary or String or Null) as Void {
        var datos = Config.extraer(codigo, data);
        if (datos != null) {
            // Ignora respuestas de un tema que el usuario ya cambió.
            if (!(datos.get("tema") as String).equals(Config.temaActual())) {
                return;
            }
            _cargando = false;
            NewsView.guardar(datos);
            recibir(datos);
            return;
        }
        _cargando = false;
        _codigoError = codigo;
        WatchUi.requestUpdate();
    }

    function recibir(datos as Dictionary) as Void {
        var temaNuevo = datos.get("tema") as String;
        var fechaNueva = datos.get("fecha") as String;
        var habiaNoticias = _noticias.size() > 0;

        // Resumen distinto (otro día u otro tema): se empieza desde la portada.
        if (!habiaNoticias || !temaNuevo.equals(_tema) || !fechaNueva.equals(_fecha)) {
            _indice = 0;
            _leidas = 0;
            _pantalla = PANTALLA_PORTADA;
        }
        _noticias = datos.get("noticias") as Array<String>;
        var categorias = datos.get("categorias");
        _categorias = (categorias instanceof Array) ? categorias as Array<String> : [] as Array<String>;
        _fecha = fechaNueva;
        _tema = temaNuevo;
        _codigoError = null;
        _ajusteIndice = -1;
        if (_indice >= _noticias.size()) {
            _indice = 0;
        }
        WatchUi.requestUpdate();
    }

}
