import Toybox.Application.Storage;
import Toybox.Attention;
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

        // Si se cambiaron los temas en el teléfono, las noticias guardadas son de otros
        // temas: no se muestran (se ve "Preparando" hasta que lleguen las nuevas).
        if (!_tema.equals(Config.temaActual())) {
            descartarNoticias();
        }

        // Ajuste "Abrir directo en la primera noticia"
        if (Config.abrirDirecto() && _noticias.size() > 0) {
            _pantalla = PANTALLA_NOTICIA;
            _leidas = 1;
        }
    }

    // Se llama cuando cambian los ajustes en el teléfono (temas, tamaño del texto, etc.).
    function aplicarAjustes() as Void {
        _ajusteIndice = -1;
        if (!_tema.equals(Config.temaActual())) {
            descartarNoticias();
        }
        WatchUi.requestUpdate();
    }

    private function descartarNoticias() as Void {
        _noticias = [] as Array<String>;
        _categorias = [] as Array<String>;
        _fecha = "";
        _tema = Config.temaActual();
        _indice = 0;
        _leidas = 0;
        _pantalla = PANTALLA_PORTADA;
        _ajusteIndice = -1;
        Storage.deleteValue(CLAVE_NOTICIAS);
        Storage.deleteValue(CLAVE_CATEGORIAS);
        Storage.deleteValue(CLAVE_FECHA);
        Storage.deleteValue(CLAVE_TEMA);
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

        // Resumen distinto (otro día u otro tema): se empieza desde la portada
        // (o desde la primera noticia si así está configurado).
        if (!habiaNoticias || !temaNuevo.equals(_tema) || !fechaNueva.equals(_fecha)) {
            _indice = 0;
            _leidas = 0;
            _pantalla = PANTALLA_PORTADA;
            if (Config.abrirDirecto()) {
                _pantalla = PANTALLA_NOTICIA;
                _leidas = 1;
            }
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

    // ======================================================================
    // Controles (ver NewsDelegate)
    // ======================================================================

    // Deslizar arriba / DOWN
    function siguiente() as Void {
        if (_noticias.size() == 0) {
            return;
        }
        if (_pantalla == PANTALLA_PORTADA) {
            abrirNoticia(_indice, 1);
        } else if (_pantalla == PANTALLA_NOTICIA) {
            if (_indice < _noticias.size() - 1) {
                abrirNoticia(_indice + 1, 1);
            } else {
                _pantalla = PANTALLA_FIN;
                WatchUi.requestUpdate();
            }
        }
    }

    // Deslizar abajo / UP
    function anterior() as Void {
        if (_noticias.size() == 0) {
            return;
        }
        if (_pantalla == PANTALLA_NOTICIA) {
            if (_indice > 0) {
                abrirNoticia(_indice - 1, -1);
            } else {
                _pantalla = PANTALLA_PORTADA;
                WatchUi.requestUpdate();
            }
        } else if (_pantalla == PANTALLA_FIN) {
            abrirNoticia(_noticias.size() - 1, -1);
        }
    }

    // START: leer en la portada, actualizar en la noticia, volver a empezar en "Estás al día",
    // reintentar si no hay noticias.
    function start() as Void {
        if (_noticias.size() == 0) {
            actualizar(false);
        } else if (_pantalla == PANTALLA_PORTADA) {
            abrirNoticia(_indice, 1);
        } else if (_pantalla == PANTALLA_NOTICIA) {
            actualizar(false);
        } else {
            _indice = 0;
            _pantalla = PANTALLA_PORTADA;
            WatchUi.requestUpdate();
        }
    }

    // Toque en pantalla: pulsa el botón visible (LEER RESUMEN / REINTENTAR)
    // y, leyendo, pasa a la siguiente noticia.
    function tocar() as Void {
        if (_noticias.size() == 0) {
            if (!_cargando) {
                actualizar(false);
            }
        } else if (_pantalla != PANTALLA_FIN) {
            siguiente();
        }
    }

    private function abrirNoticia(indice as Number, direccion as Number) as Void {
        _indice = indice;
        _pantalla = PANTALLA_NOTICIA;
        _leidas = _leidas | (1 << indice);
        // Pulso corto al pasar de noticia (ajuste "Vibrar al pasar de noticia").
        if (Config.vibrar() && (Attention has :vibrate)) {
            Attention.vibrate([new Attention.VibeProfile(30, 40)] as Array<Attention.VibeProfile>);
        }
        // El titular entra desde abajo al avanzar y desde arriba al retroceder.
        _offset = direccion * 64;
        animar();
        WatchUi.requestUpdate();
    }

    // ======================================================================
    // Animación
    // ======================================================================

    private function preparandoVisible() as Boolean {
        return _noticias.size() == 0 && (_cargando || _codigoError == null);
    }

    private function animar() as Void {
        if (!_timerActivo && (_offset != 0 || preparandoVisible())) {
            _timer.start(method(:onTick), 50, true);
            _timerActivo = true;
        }
    }

    function onTick() as Void {
        _fase += 1;
        if (_offset != 0) {
            _offset = _offset / 2;
            if (_offset > -2 && _offset < 2) {
                _offset = 0;
            }
        }
        if (_offset == 0 && !preparandoVisible()) {
            _timer.stop();
            _timerActivo = false;
        }
        WatchUi.requestUpdate();
    }

    // ======================================================================
    // Dibujo
    // ======================================================================

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        Ui.escala = w / 390.0;
        var cx = w / 2;
        var cy = h / 2;

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        dc.setColor(Ui.NEGRO, Ui.NEGRO);
        dc.clear();

        if (_noticias.size() == 0) {
            if (preparandoVisible()) {
                dibujarPreparando(dc, cx, cy);
            } else {
                dibujarSinConexion(dc, cx, cy);
            }
        } else if (_pantalla == PANTALLA_PORTADA) {
            dibujarPortada(dc, cx, cy);
        } else if (_pantalla == PANTALLA_NOTICIA) {
            dibujarNoticia(dc, w, cx, cy);
        } else {
            dibujarFin(dc, cx, cy);
        }
    }

    // ---------- Portada: NOTICIAS DEL DÍA ----------

    private function dibujarPortada(dc as Dc, cx as Number, cy as Number) as Void {
        Ui.brillo(dc, Ui.s(85), Ui.s(70), Ui.s(180), Ui.BRILLO_MORADO);
        Ui.brillo(dc, Ui.s(320), Ui.s(330), Ui.s(150), Ui.BRILLO_LIMA);
        Ui.anillo(dc, cx, cy, 0, Ui.LIMA);
        Ui.marcaStart(dc, cx, cy);

        // Cápsula superior: estado + fecha del resumen
        var fecha = Ui.fechaCorta(_fecha);
        var esHoy = _fecha.equals(Ui.hoyIso());
        var colorPunto = Ui.LIMA;
        var texto = esHoy ? "HOY · " + fecha : fecha;
        if (_cargando) {
            colorPunto = Ui.MORADO;
            texto = "ACTUALIZANDO";
        } else if (_codigoError != null) {
            colorPunto = Ui.NARANJA;
            texto = "GUARDADAS · " + fecha;
        }
        Ui.capsulaSimple(dc, cx, Ui.s(64), :punto, colorPunto, texto, Ui.BLANCO, Ui.fEtiqueta);

        Ui.titulo(dc, cx, Ui.s(140), "NOTICIAS", Ui.BLANCO);
        Ui.titulo(dc, cx, Ui.s(196), "DEL DÍA", Ui.LIMA);

        // Selector 1 · 2 · 3 (la actual con anillo lima; las leídas con número lima)
        var total = _noticias.size();
        var separacion = Ui.s(56);
        var x0 = cx - (total - 1) * separacion / 2;
        for (var i = 0; i < total; i++) {
            var x = x0 + i * separacion;
            var y = Ui.s(256);
            var actual = (i == _indice);
            var leida = (_leidas & (1 << i)) != 0;
            dc.setColor(actual ? Ui.LIMA : 0x333333, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(Ui.s(3));
            dc.drawCircle(x, y, Ui.s(21));
            dc.setPenWidth(1);
            var color = actual ? Ui.BLANCO : (leida ? Ui.LIMA : Ui.GRIS);
            Ui.textoCentrado(dc, x, y, Ui.fNumero, (i + 1).toString(), color);
        }

        Ui.botonAccion(dc, cx, Ui.s(318), "LEER RESUMEN", :flecha);
    }

    // ---------- Noticia: carrusel vertical ----------

    private function dibujarNoticia(dc as Dc, w as Number, cx as Number, cy as Number) as Void {
        var total = _noticias.size();
        var sinConexion = (_codigoError != null && !_cargando);

        Ui.brillo(dc, cx, Ui.s(20), Ui.s(170), sinConexion ? Ui.BRILLO_NARANJA : Ui.BRILLO_MORADO);

        // Número gigante de fondo
        dc.setColor(Ui.FONDO_NUMERO, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - Ui.s(14), Ui.s(215), Ui.fFondo, (_indice + 1).format("%02d"),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Anillo: se llena un tercio por noticia, con la perilla al final
        Ui.anillo(dc, cx, cy, _indice + 1, Ui.LIMA);
        Ui.perilla(dc, cx, cy, 90 - 120 * (_indice + 1) + 2);

        // Etiqueta de categoría
        var categoria = (_indice < _categorias.size()) ? _categorias[_indice] : Config.nombreTema(_tema);
        Ui.pildora(dc, cx, Ui.s(64), categoria);

        // Titular (área 288 x 168), entra deslizándose
        var areaW = Ui.s(288);
        var areaH = Ui.s(168);
        var centroY = Ui.s(170);
        ajustar(areaW, areaH);
        dc.setClip(cx - areaW / 2, centroY - areaH / 2, areaW, areaH);
        Ui.textoCentrado(dc, cx, centroY + _offset, _ajusteFuente, _ajusteTexto, Ui.BLANCO);
        dc.clearClip();

        // Cápsula del pie: fecha + posición, o estado
        var numero = (_indice + 1).format("%02d");
        var deTotal = "/" + total.format("%02d");
        if (_cargando) {
            Ui.capsula(dc, cx, Ui.s(280), :giro, Ui.MORADO,
                ["Actualizando", "  ·  ", numero, deTotal] as Array<String>,
                [Ui.MORADO, Ui.GRIS_OSCURO, Ui.LIMA, Ui.GRIS] as Array<Number>,
                [Ui.fTexto, Ui.fEtiqueta, Ui.fNumero, Ui.fNumero] as Array<FontType>,
                0x15111F, 0x3A2D5C);
        } else if (sinConexion) {
            Ui.capsula(dc, cx, Ui.s(280), :sinRed, Ui.NARANJA,
                ["Sin conexión · guardadas"] as Array<String>,
                [Ui.NARANJA] as Array<Number>,
                [Ui.fTexto] as Array<FontType>,
                0x1E140A, 0x5A3A1A);
        } else {
            Ui.capsula(dc, cx, Ui.s(280), null, 0,
                [Ui.fechaCorta(_fecha), "  ·  ", numero, deTotal] as Array<String>,
                [Ui.GRIS_CLARO, Ui.GRIS_OSCURO, Ui.LIMA, Ui.GRIS] as Array<Number>,
                [Ui.fEtiqueta, Ui.fEtiqueta, Ui.fNumero, Ui.fNumero] as Array<FontType>,
                Ui.VIDRIO, Ui.VIDRIO_BORDE);
        }

        if (sinConexion) {
            dibujarAyudaReintentar(dc, cx, Ui.s(318));
        } else {
            Ui.dibujarIcono(dc, :abajo, cx, Ui.s(322), Ui.GRIS_OSCURO);
        }
    }

    // "↻ START · REINTENTAR"
    private function dibujarAyudaReintentar(dc as Dc, cx as Number, y as Number) as Void {
        var fuente = Ui.fEtiqueta;
        var texto = "START · REINTENTAR";
        var ancho = dc.getTextWidthInPixels(texto, fuente) + Ui.s(20);
        var x = cx - ancho / 2;
        Ui.dibujarIcono(dc, :refrescar, x + Ui.s(6), y, Ui.GRIS);
        dc.setColor(Ui.GRIS, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + Ui.s(20), y, fuente, texto, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Elige la fuente más grande con la que el titular completo cabe en el área.
    private function ajustar(areaW as Number, areaH as Number) as Void {
        if (_ajusteIndice == _indice) {
            return;
        }
        var texto = _noticias[_indice];
        // Ajuste "Tamaño del texto": grande empieza en la fuente mayor, pequeño en la menor.
        var todas = [Ui.fTitular, Ui.fTitularM, Ui.fTitularS] as Array<FontType>;
        var fuentes = todas.slice(Config.tamanoTexto(), null);
        for (var i = 0; i < fuentes.size(); i++) {
            var ajustado = Graphics.fitTextToArea(texto, fuentes[i], areaW, areaH, false);
            if (ajustado != null) {
                _ajusteTexto = ajustado;
                _ajusteFuente = fuentes[i];
                _ajusteIndice = _indice;
                return;
            }
        }
        // Último recurso: fuente mínima, recortando si hiciera falta.
        var recortado = Graphics.fitTextToArea(texto, Ui.fTexto, areaW, areaH, true);
        _ajusteTexto = (recortado != null) ? recortado : texto;
        _ajusteFuente = Ui.fTexto;
        _ajusteIndice = _indice;
    }

    // ---------- Fin: ESTÁS AL DÍA ----------

    private function dibujarFin(dc as Dc, cx as Number, cy as Number) as Void {
        Ui.brillo(dc, cx, Ui.s(110), Ui.s(150), Ui.BRILLO_LIMA);

        // Anillo punteado interior
        dc.setColor(0x2A2350, Graphics.COLOR_TRANSPARENT);
        for (var a = 0; a < 360; a += 6) {
            var p = Ui.punto(cx, cy, Ui.s(166), a);
            dc.fillCircle(p[0], p[1], 1);
        }
        Ui.anillo(dc, cx, cy, 3, Ui.LIMA);

        // Check
        dc.setColor(Ui.LIMA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, Ui.s(95), Ui.s(37));
        Ui.dibujarIcono(dc, :check, cx, Ui.s(95), Ui.NEGRO);

        Ui.titulo(dc, cx, Ui.s(180), "ESTÁS AL DÍA", Ui.BLANCO);

        var leidas = 0;
        for (var i = 0; i < _noticias.size(); i++) {
            if ((_leidas & (1 << i)) != 0) {
                leidas += 1;
            }
        }
        Ui.textoCentrado(dc, cx, Ui.s(218), Ui.fTexto,
            leidas + " de " + _noticias.size() + " noticias leídas", Ui.GRIS);

        var proximo = "Aviso diario desactivado";
        if (Config.avisoActivo()) {
            proximo = "Próximo resumen · " + Ui.horaTexto(Config.horaAviso(), Config.minutoAviso());
        }
        Ui.capsulaSimple(dc, cx, Ui.s(262), :reloj, Ui.GRIS_CLARO, proximo, Ui.BLANCO, Ui.fTexto);

        Ui.textoCentrado(dc, cx, Ui.s(304), Ui.fEtiqueta, "BACK PARA SALIR", Ui.GRIS_OSCURO);
    }

    // ---------- Cargando: PREPARANDO TU RESUMEN ----------

    private function dibujarPreparando(dc as Dc, cx as Number, cy as Number) as Void {
        Ui.brillo(dc, cx, cy, Ui.s(170), 0x1A1238);

        var r = Ui.s(Ui.RADIO_ANILLO);
        var r2 = r - Ui.s(20);

        // Pistas
        dc.setPenWidth(Ui.s(Ui.GROSOR_ANILLO));
        dc.setColor(Ui.PISTA, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        dc.setPenWidth(Ui.s(6));
        dc.setColor(0x141414, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r2);
        dc.setPenWidth(1);

        // Arcos girando en sentidos opuestos
        var giro = _fase * 6;
        Ui.arco(dc, cx, cy, r, Ui.s(Ui.GROSOR_ANILLO), Ui.LIMA, 200 - giro, 90 - giro);
        Ui.arco(dc, cx, cy, r2, Ui.s(6), Ui.MORADO, 320 + giro, 250 + giro);
        Ui.arco(dc, cx, cy, r2, Ui.s(6), Ui.GRIS_OSCURO, 230 + giro, 195 + giro);

        Ui.textoCentrado(dc, cx, Ui.s(110), Ui.fEtiqueta, Ui.fechaCorta(Ui.hoyIso()), Ui.GRIS);
        Ui.titulo(dc, cx, Ui.s(154), "PREPARANDO", Ui.BLANCO);
        Ui.titulo(dc, cx, Ui.s(206), "TU RESUMEN", Ui.LIMA);

        // Tres puntos: el activo avanza
        var activo = (_fase / 6) % 3;
        for (var i = 0; i < 3; i++) {
            dc.setColor((i == activo) ? Ui.LIMA : 0x3A3A3A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx + (i - 1) * Ui.s(17), Ui.s(244), Ui.s(4));
        }

        Ui.textoCentrado(dc, cx, Ui.s(284), Ui.fTexto,
            "Pidiendo las noticias\na tu teléfono", Ui.GRIS_CLARO);
    }

    // ---------- Error sin noticias guardadas: SIN CONEXIÓN ----------

    private function dibujarSinConexion(dc as Dc, cx as Number, cy as Number) as Void {
        Ui.brillo(dc, cx, Ui.s(10), Ui.s(190), Ui.BRILLO_NARANJA);
        Ui.anillo(dc, cx, cy, 0, Ui.LIMA);
        Ui.marcaStart(dc, cx, cy);

        // Reloj - - x - - teléfono
        var y = Ui.s(92);
        var sep = Ui.s(76);
        Ui.circuloVidrio(dc, cx - sep, y, Ui.s(26), :pulsera);
        Ui.circuloVidrio(dc, cx + sep, y, Ui.s(26), :telefono);
        Ui.guiones(dc, cx - sep + Ui.s(32), cx - Ui.s(16), y, Ui.GRIS_OSCURO);
        Ui.guiones(dc, cx + Ui.s(16), cx + sep - Ui.s(32), y, Ui.GRIS_OSCURO);
        dc.setColor(Ui.NARANJA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, y, Ui.s(11));
        Ui.dibujarIcono(dc, :equis, cx, y, Ui.NEGRO);

        var codigo = _codigoError;
        var titulo = "SIN CONEXIÓN";
        var detalle = "Conecta el teléfono y abre\nGarmin Connect";
        if (codigo != null && codigo > 0) {
            titulo = "SIN NOTICIAS";
            detalle = "El servidor respondió\ncon error " + codigo;
        } else if (codigo != null && codigo != Communications.BLE_CONNECTION_UNAVAILABLE) {
            detalle = "Revisa la conexión del\nteléfono (código " + codigo + ")";
        }
        Ui.titulo(dc, cx, Ui.s(160), titulo, Ui.BLANCO);
        Ui.textoCentrado(dc, cx, Ui.s(214), Ui.fTexto, detalle, Ui.GRIS_CLARO);

        Ui.botonAccion(dc, cx, Ui.s(276), "REINTENTAR", :refrescar);
    }
}
