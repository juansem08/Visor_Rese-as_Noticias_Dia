import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

(:background)
class NewsApp extends Application.AppBase {

    private var _view as NewsView? = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        // Asegura que el aviso diario quede programado con los ajustes actuales.
        Config.programarAviso();

        var view = new NewsView();
        _view = view;
        // Muestra lo guardado (si hay) y pide al backend las noticias de hoy.
        view.actualizar(false);
        return [view, new NewsDelegate(view)];
    }
}
