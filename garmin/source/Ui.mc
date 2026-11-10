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

}
