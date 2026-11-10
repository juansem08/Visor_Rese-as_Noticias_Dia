import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Guía de estilo del Forerunner 165 (AMOLED redonda 390x390):
// negro puro para ahorrar batería, acento lima y brillos suaves de color por estado.
// Todas las medidas están pensadas para 390 px y se escalan con s().
module Ui {

    // ---------- Paleta ----------
    const NEGRO = 0x000000;
    const LIMA = 0xC8FF2E;          // acento
    const BLANCO = 0xFFFFFF;        // titular
    const PISTA = 0x1E1E1E;         // pista del anillo
    const MORADO = 0xB794FF;        // actualizando
    const NARANJA = 0xFF9F43;       // sin conexión
    const GRIS = 0x8C8C8C;
    const GRIS_CLARO = 0xBDBDBD;
    const GRIS_OSCURO = 0x5C5C5C;
    const FONDO_NUMERO = 0x111111;  // número gigante de fondo
    const VIDRIO = 0x171717;        // cápsula de vidrio
    const VIDRIO_BORDE = 0x2E2E2E;

    // Brillos (picos de color sobre negro)
    const BRILLO_MORADO = 0x24164A;
    const BRILLO_LIMA = 0x223200;
    const BRILLO_NARANJA = 0x3A2208;

    // ---------- Medidas de la guía ----------
    const RADIO_ANILLO = 184;
    const GROSOR_ANILLO = 8;
    const ARCO_SEGMENTO = 116;      // 3 arcos de 116° (+ 4° de separación)
    const START_DESDE = 22;         // arco que señala el botón START
    const START_HASTA = 38;

    var escala as Float = 1.0;

    function s(v as Numeric) as Number {
        return (v * escala).toNumber();
    }
    // ---------- Color ----------

    function mezclar(a as Number, b as Number, t as Float) as Number {
        var r = canal(a, b, 16, t);
        var g = canal(a, b, 8, t);
        var bl = canal(a, b, 0, t);
        return (r << 16) | (g << 8) | bl;
    }

    function canal(a as Number, b as Number, desplazamiento as Number, t as Float) as Number {
        var ca = (a >> desplazamiento) & 0xFF;
        var cb = (b >> desplazamiento) & 0xFF;
        return ca + ((cb - ca) * t).toNumber();
    }
    // Brillo radial suave: círculos concéntricos de negro al color (sin transparencias).
    function brillo(dc as Dc, x as Number, y as Number, radio as Number, color as Number) as Void {
        var pasos = 28;
        for (var i = 0; i < pasos; i++) {
            var t = (i + 1).toFloat() / pasos;
            dc.setColor(mezclar(NEGRO, color, t * t), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, radio * (pasos - i) / pasos);
        }
    }
}
