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
    // ---------- Anillo ----------

    function grados(a as Number) as Number {
        var r = a % 360;
        return (r < 0) ? r + 360 : r;
    }

    function punto(cx as Number, cy as Number, r as Number, angulo as Number) as [Number, Number] {
        var rad = angulo * Math.PI / 180.0;
        return [(cx + r * Math.cos(rad)).toNumber(), (cy - r * Math.sin(rad)).toNumber()];
    }

    // Arco con puntas redondeadas, en sentido horario de "desde" a "hasta" (grados matemáticos).
    function arco(dc as Dc, cx as Number, cy as Number, r as Number, ancho as Number,
                  color as Number, desde as Number, hasta as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(ancho);
        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, grados(desde), grados(hasta));
        dc.setPenWidth(1);
        var a = punto(cx, cy, r, desde);
        var b = punto(cx, cy, r, hasta);
        dc.fillCircle(a[0], a[1], ancho / 2);
        dc.fillCircle(b[0], b[1], ancho / 2);
    }
    // Anillo de progreso: 3 arcos de 116° desde arriba en sentido horario.
    // "llenos" arcos van en "color"; el resto en el color de pista.
    function anillo(dc as Dc, cx as Number, cy as Number, llenos as Number, color as Number) as Void {
        var r = s(RADIO_ANILLO);
        var ancho = s(GROSOR_ANILLO);
        for (var k = 0; k < 3; k++) {
            var desde = 90 - 120 * k - 2;
            arco(dc, cx, cy, r, ancho, (k < llenos) ? color : PISTA, desde, desde - ARCO_SEGMENTO);
        }
    }
    // Perilla al final del progreso (círculo lima con centro negro).
    function perilla(dc as Dc, cx as Number, cy as Number, angulo as Number) as Void {
        var p = punto(cx, cy, s(RADIO_ANILLO), angulo);
        dc.setColor(LIMA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(p[0], p[1], s(11));
        dc.setColor(NEGRO, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(p[0], p[1], s(5));
    }
    // Arco corto junto al botón START (22°–38°).
    function marcaStart(dc as Dc, cx as Number, cy as Number) as Void {
        arco(dc, cx, cy, s(RADIO_ANILLO), s(GROSOR_ANILLO), LIMA, START_HASTA, START_DESDE);
    }
    // ---------- Texto ----------

    // La fuente más grande de la lista con la que "texto" cabe en "maxAncho".
    function fuenteQueQuepa(dc as Dc, texto as String, maxAncho as Number, fuentes as Array<FontType>) as FontType {
        for (var i = 0; i < fuentes.size() - 1; i++) {
            if (dc.getTextWidthInPixels(texto, fuentes[i]) <= maxAncho) {
                return fuentes[i];
            }
        }
        return fuentes[fuentes.size() - 1];
    }

    function titulo(dc as Dc, cx as Number, y as Number, texto as String, color as Number) as Void {
        var fuente = fuenteQueQuepa(dc, texto, s(310), [fTitulo, fTituloS] as Array<FontType>);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, fuente, texto, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function textoCentrado(dc as Dc, cx as Number, y as Number, fuente as FontType, texto as String, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, fuente, texto, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
    // ---------- Componentes ----------

    // Etiqueta de categoría: píldora lima con texto negro.
    function pildora(dc as Dc, cx as Number, cy as Number, texto as String) as Void {
        var fuente = fEtiqueta;
        var alto = dc.getFontHeight(fuente) + s(10);
        var ancho = dc.getTextWidthInPixels(texto, fuente) + alto;
        dc.setColor(LIMA, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - ancho / 2, cy - alto / 2, ancho, alto, alto / 2);
        textoCentrado(dc, cx, cy, fuente, texto, NEGRO);
    }
    // Cápsula de vidrio con icono opcional y texto en varios colores y fuentes.
    function capsula(dc as Dc, cx as Number, cy as Number, icono as Symbol?, colorIcono as Number,
                     textos as Array<String>, colores as Array<Number>, fuentes as Array<FontType>,
                     fondo as Number, borde as Number) as Void {
        var anchoTexto = 0;
        var altoFuente = 0;
        for (var i = 0; i < textos.size(); i++) {
            anchoTexto += dc.getTextWidthInPixels(textos[i], fuentes[i]);
            var h = dc.getFontHeight(fuentes[i]);
            if (h > altoFuente) {
                altoFuente = h;
            }
        }
        var anchoIcono = (icono != null) ? s(22) : 0;
        var contenido = anchoTexto + anchoIcono;
        var alto = altoFuente + s(14);
        var ancho = contenido + s(36);

        dc.setColor(fondo, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - ancho / 2, cy - alto / 2, ancho, alto, alto / 2);
        dc.setColor(borde, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(s(2));
        dc.drawRoundedRectangle(cx - ancho / 2, cy - alto / 2, ancho, alto, alto / 2);
        dc.setPenWidth(1);

        var x = cx - contenido / 2;
        if (icono != null) {
            dibujarIcono(dc, icono, x + s(7), cy, colorIcono);
            x += anchoIcono;
        }
        for (var i = 0; i < textos.size(); i++) {
            dc.setColor(colores[i], Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, cy, fuentes[i], textos[i], Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            x += dc.getTextWidthInPixels(textos[i], fuentes[i]);
        }
    }

    function capsulaSimple(dc as Dc, cx as Number, cy as Number, icono as Symbol?, colorIcono as Number,
                           texto as String, colorTexto as Number, fuente as FontType) as Void {
        capsula(dc, cx, cy, icono, colorIcono, [texto] as Array<String>, [colorTexto] as Array<Number>,
            [fuente] as Array<FontType>, VIDRIO, VIDRIO_BORDE);
    }
    // Botón de acción START: píldora lima, texto negro y círculo negro con icono lima.
    function botonAccion(dc as Dc, cx as Number, cy as Number, texto as String, icono as Symbol) as Void {
        var fuente = fEtiqueta;
        var alto = s(46);
        var radioCirculo = s(16);
        var anchoTexto = dc.getTextWidthInPixels(texto, fuente);
        var ancho = s(20) + anchoTexto + s(12) + radioCirculo * 2 + s(7);
        var x = cx - ancho / 2;

        dc.setColor(LIMA, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, cy - alto / 2, ancho, alto, alto / 2);
        dc.setColor(NEGRO, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + s(20), cy, fuente, texto, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var circuloX = x + ancho - s(7) - radioCirculo;
        dc.fillCircle(circuloX, cy, radioCirculo);
        dibujarIcono(dc, icono, circuloX, cy, LIMA);
    }
    // Círculo de vidrio con un icono dentro (pantalla sin conexión).
    function circuloVidrio(dc as Dc, x as Number, y as Number, radio as Number, icono as Symbol) as Void {
        dc.setColor(VIDRIO, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, radio);
        dc.setColor(VIDRIO_BORDE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(s(2));
        dc.drawCircle(x, y, radio);
        dc.setPenWidth(1);
        dibujarIcono(dc, icono, x, y, BLANCO);
    }
}
