import Foundation

/// Original phrases written for Detox. Direct, close, concrete; never shaming.
public enum Phrases {
    public static let all = [
        "Esto que buscas seguirá ahí mañana. Tu descanso de hoy, no.",
        "Te prometiste esta noche. Cumplirla es el regalo.",
        "El impulso dura unos segundos. Respira y deja que pase.",
        "No te falta nada en esa pantalla.",
        "Mañana te agradecerás haber cerrado esto ahora.",
        "Ya decidiste. Ahora solo toca sostenerlo.",
        "Aburrirse un rato también descansa la mente.",
        "Cada noche que cumples, la siguiente cuesta menos.",
        "Lo urgente de ahí dentro casi nunca lo es.",
        "Elige lo que quieres sentir al despertar.",
        "Tu atención es tuya. No la regales a estas horas.",
        "Apaga la luz de la pantalla y deja entrar la de mañana.",
        "Un minuto de pausa vale más que una hora de scroll.",
        "Si te cuesta, es que está funcionando.",
        "Nada de lo que veas ahora te hará dormir mejor.",
        "Vuelve a ti: a tu respiración, a tu cuarto, a tu silencio.",
        "Este momento de ganas pasará. Tu compromiso, no.",
        "Hoy cuidas al que se levantará mañana.",
        "El descanso no se recupera después. Se protege ahora.",
        "Has llegado hasta aquí. Sigue un poco más.",
        "Lo que alimentas crece. Esta noche alimenta la calma.",
        "Cierra los ojos, cuenta diez respiraciones y decide después.",
    ]

    public static func random() -> String { all.randomElement()! }
}
