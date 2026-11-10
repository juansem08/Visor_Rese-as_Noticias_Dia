import Toybox.Lang;
import Toybox.WatchUi;

// Controles del Forerunner 165 (según la guía de estilo):
//   deslizar arriba / botón DOWN  -> siguiente (portada -> 01 -> 02 -> 03 -> "Estás al día")
//   deslizar abajo  / botón UP    -> anterior
//   botón START                   -> leer (portada) · actualizar (noticia) · reintentar (sin conexión)
//   toque                         -> LEER RESUMEN / siguiente noticia / REINTENTAR
//   botón BACK                    -> salir
class NewsDelegate extends WatchUi.BehaviorDelegate {

    private var _view as NewsView;

    function initialize(view as NewsView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.siguiente();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.anterior();
        return true;
    }

    // Botón físico START. Se atiende aquí porque en pantallas táctiles un toque
    // también genera onSelect, y no queremos que tocar recargue las noticias.
    function onKey(evento as WatchUi.KeyEvent) as Boolean {
        if (evento.getKey() == WatchUi.KEY_ENTER) {
            _view.start();
            return true;
        }
        return false;
    }

    // Toque en la pantalla (el START físico ya se consumió en onKey).
    function onSelect() as Boolean {
        _view.tocar();
        return true;
    }
}
