import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// Pruebas de los ajustes del teléfono. Solo se compilan con `monkeyc --unit-test`
// y se ejecutan con `monkeydo <app>.prg fr165 /t`. No forman parte de la app publicada.

(:debug)
function marcarTemas(temas as Array<Boolean>) as Void {
    for (var i = 0; i < Config.PROPIEDADES_TEMA.size(); i++) {
        Application.Properties.setValue(Config.PROPIEDADES_TEMA[i], temas[i]);
    }
}

(:test)
function pruebaTemaPorDefectoMundo(logger as Logger) as Boolean {
    marcarTemas([true, false, false, false, false, false, false]);
    logger.debug("tema = " + Config.temaActual());
    return Config.temaActual().equals("mundo");
}

(:test)
function pruebaVariosTemas(logger as Logger) as Boolean {
    marcarTemas([true, false, true, false, false, true, false]);
    logger.debug("tema = " + Config.temaActual());
    return Config.temaActual().equals("mundo,deportes,salud");
}

(:test)
function pruebaTemasSinMundo(logger as Logger) as Boolean {
    marcarTemas([false, true, false, false, true, false, true]);
    logger.debug("tema = " + Config.temaActual());
    return Config.temaActual().equals("tecnologia,ciencia,cultura")
        && Config.nombreTema(Config.temaActual()).equals("TECNOLOGÍA");
}

(:test)
function pruebaNingunTemaUsaMundo(logger as Logger) as Boolean {
    marcarTemas([false, false, false, false, false, false, false]);
    var ok = Config.temaActual().equals("mundo");
    marcarTemas([true, false, false, false, false, false, false]);
    return ok;
}

(:test)
function pruebaAvisoActivoYDesactivado(logger as Logger) as Boolean {
    Application.Properties.setValue("AvisoActivo", false);
    var apagado = !Config.avisoActivo();
    Config.programarAviso();   // con el aviso apagado no debe fallar
    Application.Properties.setValue("AvisoActivo", true);
    var encendido = Config.avisoActivo();
    Config.programarAviso();   // con el aviso encendido tampoco
    return apagado && encendido;
}

(:test)
function pruebaHoraYMinuto(logger as Logger) as Boolean {
    Application.Properties.setValue("HoraAviso", 19);
    Application.Properties.setValue("MinutoAviso", 45);
    var ok = Config.horaAviso() == 19 && Config.minutoAviso() == 45;
    Application.Properties.setValue("HoraAviso", 30);     // inválida -> 7
    ok = ok && Config.horaAviso() == 7;
    Application.Properties.setValue("HoraAviso", 7);
    Application.Properties.setValue("MinutoAviso", 0);
    return ok;
}

(:test)
function pruebaHoraEnFormato12h(logger as Logger) as Boolean {
    logger.debug(Ui.horaTexto(0, 0) + " | " + Ui.horaTexto(7, 0) + " | " + Ui.horaTexto(12, 30) + " | " + Ui.horaTexto(19, 45));
    return Ui.horaTexto(0, 0).equals("12:00 a. m.")
        && Ui.horaTexto(7, 0).equals("7:00 a. m.")
        && Ui.horaTexto(12, 30).equals("12:30 p. m.")
        && Ui.horaTexto(19, 45).equals("7:45 p. m.");
}

(:test)
function pruebaAjustesDeLectura(logger as Logger) as Boolean {
    Application.Properties.setValue("TamanoTexto", 2);
    Application.Properties.setValue("Vibrar", false);
    Application.Properties.setValue("AbrirDirecto", true);
    var ok = Config.tamanoTexto() == 2 && !Config.vibrar() && Config.abrirDirecto();
    Application.Properties.setValue("TamanoTexto", 0);
    Application.Properties.setValue("Vibrar", true);
    Application.Properties.setValue("AbrirDirecto", false);
    return ok && Config.tamanoTexto() == 0 && Config.vibrar() && !Config.abrirDirecto();
}
