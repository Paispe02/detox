import DetoxCore
import Foundation

extension CommandError {
    public var userMessage: String {
        switch self {
        case .notFound: return "Ese bloqueo ya no existe."
        case .invalid(let field):
            switch field {
            case "nombre": return "Ponle un nombre."
            case "objetivos": return "Elige al menos una web, servicio o app."
            case "días": return "Elige al menos un día de la semana."
            case "fechas": return "Revisa las fechas: el fin no puede ser anterior al inicio ni a hoy."
            case "pausa": return "La pausa debe durar entre 5 y 60 minutos."
            case "contraseña": return "La contraseña necesita al menos 4 caracteres."
            case "terminado": return "Este bloqueo ya terminó."
            case "amigo reciente": return "Solo puede tener la llave un amigo registrado antes de que empezara este bloqueo."
            default:
                if field.hasPrefix("app: ") { return "«\(field.dropFirst(5))» no se puede bloquear: elige una app normal de la carpeta Aplicaciones." }
                if field.hasPrefix("dominio: ") { return "«\(field.dropFirst(9))» no es un dominio válido. Escribe algo como instagram.com." }
                return "Algo no cuadra (\(field))."
            }
        case .tightening: return "Un bloqueo en marcha solo puede endurecerse."
        case .notDeletable: return "Un bloqueo en marcha no se puede borrar."
        case .noExit(let endsAt): return "Este bloqueo no tiene salida hasta el \(Formatting.longDate(endsAt))."
        case .notActive: return "Ahora mismo no está bloqueando: no hace falta desbloquearlo."
        case .wrongCredential: return "Contraseña o código incorrecto."
        case .rateLimited(let until): return "Demasiados intentos. Vuelve a intentarlo a las \(Formatting.clock(until))."
        case .cancelRequiresFriend: return "Solo la llave de un amigo puede cancelar un bloqueo."
        case .friendInUse: return "Este amigo tiene la llave de un bloqueo en marcha."
        case .friendNotConfirmed: return "Ese amigo aún no ha confirmado su código."
        case .unknownFriend: return "Ese amigo ya no está registrado."
        case .daemonUnavailable: return "El servicio de Detox está desactivado."
        }
    }
}
