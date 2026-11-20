-- Spanish (Spain). Loads only when the game client is set to esES; every
-- other language, esMX included, keeps the English strings.
local _, NN = ...
if GetLocale() ~= "esES" then return end

local T = {
  ADDON_TITLE = "NewbieNudge",
  CHAT_PREFIX = "|cff7fd5ffNewbieNudge|r: ",
  PANEL_TITLE = "Recordatorios",
  ROW_HINT_CLICK = "Clic izquierdo para ir allí.",
  ROW_HINT_SNOOZE = "Clic derecho: posponer %d minutos. Mayús+clic derecho: posponer hasta la próxima conexión.",
  ROW_STALE = "No se actualiza durante el combate.",
  MORE_ROWS = "…y %d más",
  SLASH_HELP = "Comandos: /nudge (opciones), /nudge lock, /nudge list, /nudge on <nombre>, /nudge off <nombre>, /nudge reset, /nudge test",
  SLASH_LIST_HEADER = "Recordatorios de este personaje:",
  SLASH_LIST_LINE = "  %s (%s): %s",
  STATE_ON = "activado",
  STATE_OFF = "desactivado",
  STATE_SNOOZED = "pospuesto",
  STATE_NA = "no aplica a este personaje",
  SLASH_UNKNOWN_RULE = "No hay ningún recordatorio llamado '%s'. Usa /nudge list.",
  SLASH_RULE_SET = "%s ahora está %s.",
  SLASH_RESET_DONE = "Posposiciones borradas.",
  SLASH_LOCKED = "Panel bloqueado.",
  SLASH_UNLOCKED = "Panel desbloqueado: arrastra la barra de título para moverlo. /nudge lock al terminar.",
  SLASH_TEST_ON = "Modo de prueba: se muestran todos los recordatorios con texto de ejemplo. /nudge reset para salir.",
  RULE_ERROR = "El recordatorio '%s' ha dado un error y queda desactivado hasta la próxima conexión. Por favor, infórmalo: %s",
  OPT_GENERAL = "General",
  OPT_REMINDERS = "Recordatorios",
  OPT_LOCK = "Bloquear la posición del panel",
  OPT_LOCK_TT = "Si está desbloqueado, arrastra la barra de título para mover el panel.",
  OPT_SCALE = "Escala del panel",
  OPT_SNOOZE = "Duración de la posposición (minutos)",
  OPT_COMBAT_STRIP = "Mostrar tira compacta en combate",
  OPT_COMBAT_STRIP_TT = "En combate el panel se reduce a una fila de iconos. Desactívalo para ocultarlo en combate.",
  OPT_RESET_SNOOZE = "Borrar posposiciones",
  OPT_RESET_POS = "Restablecer posición",
  OPT_BUTTON_DO = "Restablecer",
  OPT_NOT_RELEVANT = "No aplica a este personaje",
}

for key, value in pairs(T) do NN.L[key] = value end
