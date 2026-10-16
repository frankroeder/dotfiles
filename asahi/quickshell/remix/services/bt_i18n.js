// Bluetooth pane strings in eight languages. The tables are uBruckhaus/omarchy-bluetooth-monitor's I18n.js
// (MIT), as published; the keys after `// ---- pane` are this pane's own. Language = the pane setting, else LC_ALL / LC_MESSAGES / LANG.
// Conservative ES2018, node-testable via module.exports (bt_i18n_test.js).

var LANGUAGES = [
  { code: "en", name: "English" }, { code: "de", name: "Deutsch" }, { code: "fr", name: "Français" }, { code: "es", name: "Español" },
  { code: "it", name: "Italiano" }, { code: "pt", name: "Português" }, { code: "nl", name: "Nederlands" }, { code: "pl", name: "Polski" }
]

var TABLES = {
  en: {
    settings: "Settings", back: "Back", backTip: "Back (Backspace, Esc)", language: "Language", systemLanguage: "System ({0})",
    tipAccess: "No access to the receivers yet. Click to allow it.", tipNone: "No receiver or battery-powered device found.",
    off: "off", charging: "charging", charged: "charged", notConnected: "not connected", noBattery: "no battery reading", slotN: "slot {0}",
    connectedOf: "{0} of {1} devices connected", receiversN: ["1 dongle", "{0} dongles"], accessNeeded: "Access needed",
    nothingFound: "Nothing found", looking: "Looking for devices …", lowestBattery: "Lowest battery {0}%",
    setupStep: "Not ready yet · step 1 of 1",
    setupText: "Linux only lets root talk to the receivers. Allowing access installs one udev rule (the same one Solaar uses) that gives the logged-in user access to Logitech receivers and devices. You will be asked for your password once.",
    waitingPassword: "Waiting for password …", allowAccess: "Allow access",
    noneText: "No Logitech receiver and no battery-powered Bluetooth device found.", error: "Error: {0}", devices: "Devices",
    receivers: "Receivers", dpi: "Pointer speed (DPI)", dpiDefault: "default", wheelMode: "Scroll wheel mode", smartshift: "SmartShift",
    smartshiftTip: "Ratchet that switches to free spin when you flick the wheel", ratchet: "Ratchet", ratchetTip: "Always click by click",
    freespin: "Free spin", freespinTip: "Always spins freely", sensitivity: "Sensitivity",
    sensitivityHint: "Lower values switch to free spin with a gentler flick.", natural: "Natural scrolling",
    naturalHint: "Content follows the wheel, like on a touchpad", hires: "High-resolution scrolling",
    hiresHint: "Smoother, finer steps in apps that support it", fnswap: "Swap Fn keys",
    fnswapOn: "On: top row gives media and special functions, hold Fn for F1–F12",
    fnswapOff: "Off: top row gives F1–F12, hold Fn for media and special functions", slotsUsed: "{0} of {1} slots used",
    noDevicePaired: "No device paired", refresh: "Refresh", conn_unifying: "Unifying dongle", conn_bolt: "Bolt dongle",
    conn_nano: "Nano dongle", conn_lightspeed: "Lightspeed dongle", conn_bluetooth: "Bluetooth", conn_usb: "USB cable",
    conn_wireless: "Wireless", unnamed: "Logitech device", errNotConnected: "That device is not connected right now.",
    errChange: "Could not change the setting ({0}).", lowAt: "Low battery warning", criticalAt: "Critical battery warning",
    atOrBelow: "at {0}% or less", otherDevices: "Other Bluetooth devices",
    otherDevicesHint: "Trackpads, earphones, controllers and more (battery only)", connections: "Connections", thisPc: "This PC",
    btAdapter: "Bluetooth adapter", dongleSub: "{0} of {1} slots", radioHint: "Dotted line: radio link. Solid line: plugged in or built in.",
    deviceOff: "off", btBuiltin: "Built-in Bluetooth", btBuiltinSub: "Inside this PC", btDongle: "Bluetooth dongle", btDongleSub: "USB stick",
    access: "Receiver access", accessGranted: "Granted", accessMissing: "Not granted", showHidden: "Show hidden devices ({0})",
    hideHidden: "Hide hidden devices", hide: "Hide from list", unhide: "Show in list", hiddenTag: "hidden", bluetooth: "Bluetooth",
    bluetoothTip: "Pair, connect and switch Bluetooth on or off", btTurnOn: "Turn Bluetooth on", btTurnOff: "Turn Bluetooth off",
    btSecConnected: "Connected", btSecPaired: "Paired", btSecAvailable: "Available", btScanning: "Scanning for devices…",
    btScanningShort: "Scanning", btOffHint: "Turn Bluetooth on to scan", btNoAdapter: "No Bluetooth adapter", btOn: "On", btOffState: "Off",
    btConnect: "Connect", btDisconnect: "Disconnect", btPair: "Pair", btForget: "Forget", btReallyForget: "Really forget?",
    btConnecting: "Connecting…", btDisconnecting: "Disconnecting…", btForgetting: "Forgetting…",
    // ---- pane
    btManager: "Bluetooth manager", btScan: "Scan", btSecWired: "USB & receivers", hiddenCount: "{0} hidden", unhideAll: "Show all again",
    offDetail: "Paired devices reconnect once it is back on.", pairHint: "Put the device in pairing mode.",
    scanHint: "Scan to discover devices nearby.", updatedAt: "updated {0}", alerts: "Battery alerts",
    alertsHint: "The bar's Bluetooth icon turns into the device's icon: orange when low, red when critical.",
    hiddenNone: "The eye on a device hides it from the map, the list and the bar's warnings.",
    nfConnected: "Connected", nfConnectFailed: "Could not connect", nfDisconnected: "Disconnected", nfPaired: "Paired",
    nfPairFailed: "Pairing failed", nfForgotten: "Forgotten", nfForgetFailed: "Could not forget",
    barTooltip: "Tooltip on the bar icon", barTooltipHint: "Hovering the bar's Bluetooth icon lists every device's battery.",
    turningOn: "Turning on…", turningOff: "Turning off…"
  },
  de: {
    settings: "Einstellungen", back: "Zurück", backTip: "Zurück (Rücktaste, Esc)", language: "Sprache", systemLanguage: "System ({0})",
    tipAccess: "Noch kein Zugriff auf die Empfänger. Zum Erlauben klicken.", tipNone: "Kein Empfänger und kein Gerät mit Akku gefunden.",
    off: "aus", charging: "lädt", charged: "geladen", notConnected: "nicht verbunden", noBattery: "kein Akkustand", slotN: "Platz {0}",
    connectedOf: "{0} von {1} Geräten verbunden", receiversN: ["1 Dongle", "{0} Dongles"], accessNeeded: "Zugriff nötig",
    nothingFound: "Nichts gefunden", looking: "Suche Geräte …", lowestBattery: "Niedrigster Akku {0}%",
    setupStep: "Noch nicht bereit · Schritt 1 von 1",
    setupText: "Unter Linux darf nur root mit den Empfängern sprechen. „Zugriff erlauben“ installiert eine udev-Regel (dieselbe wie Solaar), die dem angemeldeten Benutzer Zugriff auf Logitech-Empfänger und -Geräte gibt. Das Passwort wird einmal abgefragt.",
    waitingPassword: "Warte auf Passwort …", allowAccess: "Zugriff erlauben",
    noneText: "Kein Logitech-Empfänger und kein Bluetooth-Gerät mit Akku gefunden.", error: "Fehler: {0}", devices: "Geräte",
    receivers: "Empfänger", dpi: "Zeigergeschwindigkeit (DPI)", dpiDefault: "Standard", wheelMode: "Scrollrad-Modus", smartshift: "SmartShift",
    smartshiftTip: "Rastet, wechselt aber in den Freilauf, wenn du das Rad anschnippst", ratchet: "Rastend", ratchetTip: "Immer Klick für Klick",
    freespin: "Freilauf", freespinTip: "Dreht immer frei", sensitivity: "Empfindlichkeit",
    sensitivityHint: "Niedrigere Werte schalten schon bei sanftem Anschnippen in den Freilauf.", natural: "Natürliches Scrollen",
    naturalHint: "Der Inhalt folgt dem Rad, wie auf einem Touchpad", hires: "Hochauflösendes Scrollen",
    hiresHint: "Feinere, weichere Schritte in Apps, die es unterstützen", fnswap: "Fn-Tasten tauschen",
    fnswapOn: "An: obere Reihe gibt Medien- und Sonderfunktionen, Fn halten für F1–F12",
    fnswapOff: "Aus: obere Reihe gibt F1–F12, Fn halten für Medien- und Sonderfunktionen", slotsUsed: "{0} von {1} Plätzen belegt",
    noDevicePaired: "Kein Gerät gekoppelt", refresh: "Aktualisieren", conn_unifying: "Unifying-Dongle", conn_bolt: "Bolt-Dongle",
    conn_nano: "Nano-Dongle", conn_lightspeed: "Lightspeed-Dongle", conn_bluetooth: "Bluetooth", conn_usb: "USB-Kabel",
    conn_wireless: "Funk", unnamed: "Logitech-Gerät", errNotConnected: "Dieses Gerät ist gerade nicht verbunden.",
    errChange: "Einstellung konnte nicht geändert werden ({0}).", lowAt: "Warnung bei niedrigem Akku", criticalAt: "Warnung bei kritischem Akku",
    atOrBelow: "bei {0}% oder weniger", otherDevices: "Andere Bluetooth-Geräte",
    otherDevicesHint: "Trackpads, Kopfhörer, Controller und mehr (nur Akku)", connections: "Verbindungen", thisPc: "Dieser PC",
    btAdapter: "Bluetooth-Adapter", dongleSub: "{0} von {1} Plätzen",
    radioHint: "Gepunktete Linie: Funkverbindung. Durchgezogen: eingesteckt oder eingebaut.", deviceOff: "aus",
    btBuiltin: "Eingebautes Bluetooth", btBuiltinSub: "Im PC eingebaut", btDongle: "Bluetooth-Dongle", btDongleSub: "USB-Stick",
    access: "Zugriff auf Empfänger", accessGranted: "Erlaubt", accessMissing: "Nicht erlaubt", showHidden: "Ausgeblendete Geräte zeigen ({0})",
    hideHidden: "Ausgeblendete Geräte verbergen", hide: "Aus der Liste ausblenden", unhide: "In der Liste zeigen", hiddenTag: "ausgeblendet",
    bluetooth: "Bluetooth", bluetoothTip: "Koppeln, verbinden und Bluetooth ein- oder ausschalten", btTurnOn: "Bluetooth einschalten",
    btTurnOff: "Bluetooth ausschalten", btSecConnected: "Verbunden", btSecPaired: "Gekoppelt", btSecAvailable: "Verfügbar",
    btScanning: "Suche nach Geräten …", btScanningShort: "Suche läuft", btOffHint: "Bluetooth einschalten, um zu suchen",
    btNoAdapter: "Kein Bluetooth-Adapter", btOn: "Ein", btOffState: "Aus", btConnect: "Verbinden", btDisconnect: "Trennen", btPair: "Koppeln",
    btForget: "Entfernen", btReallyForget: "Wirklich entfernen?", btConnecting: "Verbinde …", btDisconnecting: "Trenne …",
    btForgetting: "Entferne …",
    // ---- pane
    btManager: "Bluetooth-Verwaltung", btScan: "Suchen", btSecWired: "USB & Empfänger", hiddenCount: "{0} ausgeblendet",
    unhideAll: "Alle wieder zeigen", offDetail: "Gekoppelte Geräte verbinden sich wieder, sobald es an ist.",
    pairHint: "Gerät in den Kopplungsmodus versetzen.", scanHint: "Suchen, um Geräte in der Nähe zu finden.", updatedAt: "aktualisiert {0}",
    alerts: "Akku-Warnungen", alertsHint: "Das Bluetooth-Symbol in der Leiste wird zum Symbol des Geräts: orange bei niedrigem, rot bei kritischem Akku.",
    hiddenNone: "Das Auge an einem Gerät blendet es aus Karte, Liste und den Warnungen der Leiste aus.",
    nfConnected: "Verbunden", nfConnectFailed: "Verbinden fehlgeschlagen", nfDisconnected: "Getrennt", nfPaired: "Gekoppelt",
    nfPairFailed: "Koppeln fehlgeschlagen", nfForgotten: "Entfernt", nfForgetFailed: "Entfernen fehlgeschlagen",
    barTooltip: "Tooltip am Leistensymbol", barTooltipHint: "Beim Überfahren des Bluetooth-Symbols in der Leiste erscheint der Akkustand jedes Geräts.",
    turningOn: "Wird eingeschaltet …", turningOff: "Wird ausgeschaltet …"
  },
  fr: {
    settings: "Réglages", back: "Retour", backTip: "Retour (Retour arrière, Échap)", language: "Langue", systemLanguage: "Système ({0})",
    tipAccess: "Pas encore d’accès aux récepteurs. Cliquez pour l’autoriser.", tipNone: "Aucun récepteur ni appareil à batterie trouvé.",
    off: "éteint", charging: "en charge", charged: "chargé", notConnected: "non connecté", noBattery: "pas de niveau de batterie",
    slotN: "emplacement {0}", connectedOf: "{0} sur {1} appareils connectés", receiversN: ["1 dongle", "{0} dongles"],
    accessNeeded: "Accès requis", nothingFound: "Rien trouvé", looking: "Recherche des appareils …", lowestBattery: "Batterie la plus basse {0}%",
    setupStep: "Pas encore prêt · étape 1 sur 1",
    setupText: "Sous Linux, seul root peut parler aux récepteurs. Autoriser l’accès installe une règle udev (la même que Solaar) qui donne à l’utilisateur connecté l’accès aux récepteurs et appareils Logitech. Votre mot de passe sera demandé une fois.",
    waitingPassword: "En attente du mot de passe …", allowAccess: "Autoriser l’accès",
    noneText: "Aucun récepteur Logitech ni appareil Bluetooth à batterie trouvé.", error: "Erreur : {0}", devices: "Appareils",
    receivers: "Récepteurs", dpi: "Vitesse du pointeur (DPI)", dpiDefault: "par défaut", wheelMode: "Mode de la molette", smartshift: "SmartShift",
    smartshiftTip: "Crantée, passe en rotation libre quand vous lancez la molette", ratchet: "Crantée", ratchetTip: "Toujours cran par cran",
    freespin: "Rotation libre", freespinTip: "Tourne toujours librement", sensitivity: "Sensibilité",
    sensitivityHint: "Des valeurs plus basses passent en rotation libre avec un lancer plus doux.", natural: "Défilement naturel",
    naturalHint: "Le contenu suit la molette, comme sur un pavé tactile", hires: "Défilement haute résolution",
    hiresHint: "Pas plus fins et plus fluides dans les applis compatibles", fnswap: "Inverser les touches Fn",
    fnswapOn: "Activé : la rangée du haut donne les fonctions multimédia, maintenir Fn pour F1–F12",
    fnswapOff: "Désactivé : la rangée du haut donne F1–F12, maintenir Fn pour les fonctions multimédia",
    slotsUsed: "{0} emplacements sur {1} utilisés", noDevicePaired: "Aucun appareil appairé", refresh: "Actualiser",
    conn_unifying: "Dongle Unifying", conn_bolt: "Dongle Bolt", conn_nano: "Dongle Nano", conn_lightspeed: "Dongle Lightspeed",
    conn_bluetooth: "Bluetooth", conn_usb: "Câble USB", conn_wireless: "Sans fil", unnamed: "Appareil Logitech",
    errNotConnected: "Cet appareil n’est pas connecté pour le moment.", errChange: "Impossible de modifier le réglage ({0}).",
    lowAt: "Alerte batterie faible", criticalAt: "Alerte batterie critique", atOrBelow: "à {0}% ou moins", otherDevices: "Autres appareils Bluetooth",
    otherDevicesHint: "Pavés tactiles, écouteurs, manettes et plus (batterie seulement)", connections: "Connexions", thisPc: "Ce PC",
    btAdapter: "Adaptateur Bluetooth", dongleSub: "{0} sur {1} emplacements",
    radioHint: "Pointillés : liaison radio. Trait plein : branché ou intégré.", deviceOff: "éteint", btBuiltin: "Bluetooth intégré",
    btBuiltinSub: "Dans ce PC", btDongle: "Dongle Bluetooth", btDongleSub: "Clé USB", access: "Accès aux récepteurs", accessGranted: "Autorisé",
    accessMissing: "Non autorisé", showHidden: "Afficher les appareils masqués ({0})", hideHidden: "Cacher les appareils masqués",
    hide: "Masquer de la liste", unhide: "Afficher dans la liste", hiddenTag: "masqué", bluetooth: "Bluetooth",
    bluetoothTip: "Appairer, connecter et activer ou désactiver le Bluetooth", btTurnOn: "Activer le Bluetooth",
    btTurnOff: "Désactiver le Bluetooth", btSecConnected: "Connectés", btSecPaired: "Appairés", btSecAvailable: "Disponibles",
    btScanning: "Recherche d’appareils…", btScanningShort: "Recherche", btOffHint: "Activez le Bluetooth pour rechercher",
    btNoAdapter: "Aucun adaptateur Bluetooth", btOn: "Activé", btOffState: "Désactivé", btConnect: "Connecter", btDisconnect: "Déconnecter",
    btPair: "Appairer", btForget: "Oublier", btReallyForget: "Vraiment oublier ?", btConnecting: "Connexion…", btDisconnecting: "Déconnexion…",
    btForgetting: "Suppression…",
    // ---- pane
    btManager: "Gestionnaire Bluetooth", btScan: "Rechercher", btSecWired: "USB et récepteurs", hiddenCount: "Masqués : {0}",
    unhideAll: "Tout réafficher", offDetail: "Les appareils appairés se reconnectent dès qu’il est réactivé.",
    pairHint: "Mettez l’appareil en mode d’appairage.", scanHint: "Lancez une recherche pour trouver les appareils à proximité.",
    updatedAt: "mis à jour {0}", alerts: "Alertes de batterie",
    alertsHint: "L’icône Bluetooth de la barre devient celle de l’appareil : orange si la batterie est faible, rouge si elle est critique.",
    hiddenNone: "L’œil d’un appareil le masque de la carte, de la liste et des alertes de la barre.",
    nfConnected: "Connecté", nfConnectFailed: "Connexion impossible", nfDisconnected: "Déconnecté", nfPaired: "Appairé",
    nfPairFailed: "Échec de l’appairage", nfForgotten: "Oublié", nfForgetFailed: "Impossible d’oublier",
    barTooltip: "Info-bulle sur l’icône de la barre", barTooltipHint: "Survoler l’icône Bluetooth de la barre affiche la batterie de chaque appareil.",
    turningOn: "Activation…", turningOff: "Désactivation…"
  },
  es: {
    settings: "Ajustes", back: "Atrás", backTip: "Atrás (Retroceso, Esc)", language: "Idioma", systemLanguage: "Sistema ({0})",
    tipAccess: "Aún no hay acceso a los receptores. Haz clic para permitirlo.", tipNone: "No se encontró ningún receptor ni dispositivo con batería.",
    off: "apagado", charging: "cargando", charged: "cargado", notConnected: "no conectado", noBattery: "sin nivel de batería", slotN: "ranura {0}",
    connectedOf: "{0} de {1} dispositivos conectados", receiversN: ["1 dongle", "{0} dongles"], accessNeeded: "Se necesita acceso",
    nothingFound: "No se encontró nada", looking: "Buscando dispositivos …", lowestBattery: "Batería más baja {0}%",
    setupStep: "Aún no está listo · paso 1 de 1",
    setupText: "En Linux solo root puede hablar con los receptores. Permitir el acceso instala una regla udev (la misma que usa Solaar) que da al usuario conectado acceso a los receptores y dispositivos Logitech. Se pedirá tu contraseña una vez.",
    waitingPassword: "Esperando la contraseña …", allowAccess: "Permitir acceso",
    noneText: "No se encontró ningún receptor Logitech ni dispositivo Bluetooth con batería.", error: "Error: {0}", devices: "Dispositivos",
    receivers: "Receptores", dpi: "Velocidad del puntero (DPI)", dpiDefault: "predeterminado", wheelMode: "Modo de la rueda", smartshift: "SmartShift",
    smartshiftTip: "Con trinquete que pasa a giro libre al impulsar la rueda", ratchet: "Trinquete", ratchetTip: "Siempre clic a clic",
    freespin: "Giro libre", freespinTip: "Siempre gira libremente", sensitivity: "Sensibilidad",
    sensitivityHint: "Valores más bajos pasan a giro libre con un impulso más suave.", natural: "Desplazamiento natural",
    naturalHint: "El contenido sigue a la rueda, como en un panel táctil", hires: "Desplazamiento de alta resolución",
    hiresHint: "Pasos más finos y suaves en las apps compatibles", fnswap: "Intercambiar teclas Fn",
    fnswapOn: "Activado: la fila superior da funciones multimedia, mantén Fn para F1–F12",
    fnswapOff: "Desactivado: la fila superior da F1–F12, mantén Fn para funciones multimedia", slotsUsed: "{0} de {1} ranuras en uso",
    noDevicePaired: "Ningún dispositivo emparejado", refresh: "Actualizar", conn_unifying: "Dongle Unifying", conn_bolt: "Dongle Bolt",
    conn_nano: "Dongle Nano", conn_lightspeed: "Dongle Lightspeed", conn_bluetooth: "Bluetooth", conn_usb: "Cable USB",
    conn_wireless: "Inalámbrico", unnamed: "Dispositivo Logitech", errNotConnected: "Ese dispositivo no está conectado ahora.",
    errChange: "No se pudo cambiar el ajuste ({0}).", lowAt: "Aviso de batería baja", criticalAt: "Aviso de batería crítica",
    atOrBelow: "al {0}% o menos", otherDevices: "Otros dispositivos Bluetooth",
    otherDevicesHint: "Paneles táctiles, auriculares, mandos y más (solo batería)", connections: "Conexiones", thisPc: "Este PC",
    btAdapter: "Adaptador Bluetooth", dongleSub: "{0} de {1} ranuras",
    radioHint: "Línea punteada: enlace por radio. Línea continua: conectado o integrado.", deviceOff: "apagado",
    btBuiltin: "Bluetooth integrado", btBuiltinSub: "Dentro de este PC", btDongle: "Dongle Bluetooth", btDongleSub: "Llave USB",
    access: "Acceso a los receptores", accessGranted: "Permitido", accessMissing: "No permitido", showHidden: "Mostrar dispositivos ocultos ({0})",
    hideHidden: "Ocultar dispositivos ocultos", hide: "Ocultar de la lista", unhide: "Mostrar en la lista", hiddenTag: "oculto",
    bluetooth: "Bluetooth", bluetoothTip: "Emparejar, conectar y encender o apagar el Bluetooth", btTurnOn: "Encender Bluetooth",
    btTurnOff: "Apagar Bluetooth", btSecConnected: "Conectados", btSecPaired: "Emparejados", btSecAvailable: "Disponibles",
    btScanning: "Buscando dispositivos…", btScanningShort: "Buscando", btOffHint: "Enciende el Bluetooth para buscar",
    btNoAdapter: "No hay adaptador Bluetooth", btOn: "Encendido", btOffState: "Apagado", btConnect: "Conectar", btDisconnect: "Desconectar",
    btPair: "Emparejar", btForget: "Olvidar", btReallyForget: "¿Olvidar de verdad?", btConnecting: "Conectando…",
    btDisconnecting: "Desconectando…", btForgetting: "Olvidando…",
    // ---- pane
    btManager: "Gestor de Bluetooth", btScan: "Buscar", btSecWired: "USB y receptores", hiddenCount: "Ocultos: {0}", unhideAll: "Mostrar todos",
    offDetail: "Los dispositivos emparejados se reconectan en cuanto se vuelva a encender.",
    pairHint: "Pon el dispositivo en modo de emparejamiento.", scanHint: "Busca para encontrar dispositivos cercanos.",
    updatedAt: "actualizado {0}", alerts: "Avisos de batería",
    alertsHint: "El icono de Bluetooth de la barra pasa a ser el del dispositivo: naranja con batería baja, rojo con batería crítica.",
    hiddenNone: "El ojo de un dispositivo lo oculta del mapa, de la lista y de los avisos de la barra.",
    nfConnected: "Conectado", nfConnectFailed: "No se pudo conectar", nfDisconnected: "Desconectado", nfPaired: "Emparejado",
    nfPairFailed: "Falló el emparejamiento", nfForgotten: "Olvidado", nfForgetFailed: "No se pudo olvidar",
    barTooltip: "Información sobre el icono de la barra", barTooltipHint: "Al pasar el ratón por el icono de Bluetooth de la barra se ve la batería de cada dispositivo.",
    turningOn: "Encendiendo…", turningOff: "Apagando…"
  },
  it: {
    settings: "Impostazioni", back: "Indietro", backTip: "Indietro (Backspace, Esc)", language: "Lingua", systemLanguage: "Sistema ({0})",
    tipAccess: "Nessun accesso ai ricevitori. Clicca per consentirlo.", tipNone: "Nessun ricevitore o dispositivo a batteria trovato.",
    off: "spento", charging: "in carica", charged: "carico", notConnected: "non connesso", noBattery: "nessun livello di batteria",
    slotN: "slot {0}", connectedOf: "{0} di {1} dispositivi connessi", receiversN: ["1 dongle", "{0} dongle"],
    accessNeeded: "Accesso necessario", nothingFound: "Niente trovato", looking: "Ricerca dispositivi …", lowestBattery: "Batteria più bassa {0}%",
    setupStep: "Non ancora pronto · passo 1 di 1",
    setupText: "Su Linux solo root può comunicare con i ricevitori. Consentire l’accesso installa una regola udev (la stessa di Solaar) che dà all’utente connesso l’accesso a ricevitori e dispositivi Logitech. La password verrà chiesta una volta.",
    waitingPassword: "In attesa della password …", allowAccess: "Consenti accesso",
    noneText: "Nessun ricevitore Logitech né dispositivo Bluetooth a batteria trovato.", error: "Errore: {0}", devices: "Dispositivi",
    receivers: "Ricevitori", dpi: "Velocità del puntatore (DPI)", dpiDefault: "predefinito", wheelMode: "Modalità rotella", smartshift: "SmartShift",
    smartshiftTip: "A scatti, passa alla rotazione libera quando dai un colpo alla rotella", ratchet: "A scatti",
    ratchetTip: "Sempre scatto per scatto", freespin: "Rotazione libera", freespinTip: "Gira sempre liberamente", sensitivity: "Sensibilità",
    sensitivityHint: "Valori più bassi passano alla rotazione libera con un colpo più leggero.", natural: "Scorrimento naturale",
    naturalHint: "Il contenuto segue la rotella, come su un touchpad", hires: "Scorrimento ad alta risoluzione",
    hiresHint: "Passi più fini e fluidi nelle app che lo supportano", fnswap: "Scambia tasti Fn",
    fnswapOn: "Attivo: la fila superiore dà funzioni multimediali, tieni Fn per F1–F12",
    fnswapOff: "Disattivo: la fila superiore dà F1–F12, tieni Fn per funzioni multimediali", slotsUsed: "{0} di {1} slot usati",
    noDevicePaired: "Nessun dispositivo associato", refresh: "Aggiorna", conn_unifying: "Dongle Unifying", conn_bolt: "Dongle Bolt",
    conn_nano: "Dongle Nano", conn_lightspeed: "Dongle Lightspeed", conn_bluetooth: "Bluetooth", conn_usb: "Cavo USB",
    conn_wireless: "Wireless", unnamed: "Dispositivo Logitech", errNotConnected: "Quel dispositivo non è connesso al momento.",
    errChange: "Impossibile cambiare l’impostazione ({0}).", lowAt: "Avviso batteria scarica", criticalAt: "Avviso batteria critica",
    atOrBelow: "al {0}% o meno", otherDevices: "Altri dispositivi Bluetooth",
    otherDevicesHint: "Trackpad, auricolari, controller e altro (solo batteria)", connections: "Connessioni", thisPc: "Questo PC",
    btAdapter: "Adattatore Bluetooth", dongleSub: "{0} di {1} slot",
    radioHint: "Linea tratteggiata: collegamento radio. Linea continua: inserito o integrato.", deviceOff: "spento",
    btBuiltin: "Bluetooth integrato", btBuiltinSub: "Dentro questo PC", btDongle: "Dongle Bluetooth", btDongleSub: "Chiavetta USB",
    access: "Accesso ai ricevitori", accessGranted: "Consentito", accessMissing: "Non consentito",
    showHidden: "Mostra i dispositivi nascosti ({0})", hideHidden: "Nascondi i dispositivi nascosti", hide: "Nascondi dall’elenco",
    unhide: "Mostra nell’elenco", hiddenTag: "nascosto", bluetooth: "Bluetooth", bluetoothTip: "Abbina, connetti e accendi o spegni il Bluetooth",
    btTurnOn: "Accendi il Bluetooth", btTurnOff: "Spegni il Bluetooth", btSecConnected: "Connessi", btSecPaired: "Abbinati",
    btSecAvailable: "Disponibili", btScanning: "Ricerca dispositivi…", btScanningShort: "Ricerca", btOffHint: "Accendi il Bluetooth per cercare",
    btNoAdapter: "Nessun adattatore Bluetooth", btOn: "Acceso", btOffState: "Spento", btConnect: "Connetti", btDisconnect: "Disconnetti",
    btPair: "Abbina", btForget: "Dimentica", btReallyForget: "Dimenticare davvero?", btConnecting: "Connessione…",
    btDisconnecting: "Disconnessione…", btForgetting: "Rimozione…",
    // ---- pane
    btManager: "Gestione Bluetooth", btScan: "Cerca", btSecWired: "USB e ricevitori", hiddenCount: "Nascosti: {0}", unhideAll: "Mostra tutti",
    offDetail: "I dispositivi abbinati si riconnettono appena viene riacceso.", pairHint: "Metti il dispositivo in modalità di abbinamento.",
    scanHint: "Cerca per trovare i dispositivi vicini.", updatedAt: "aggiornato {0}", alerts: "Avvisi batteria",
    alertsHint: "L’icona Bluetooth della barra diventa quella del dispositivo: arancione con batteria scarica, rossa con batteria critica.",
    hiddenNone: "L’occhio di un dispositivo lo nasconde dalla mappa, dall’elenco e dagli avvisi della barra.",
    nfConnected: "Connesso", nfConnectFailed: "Connessione non riuscita", nfDisconnected: "Disconnesso", nfPaired: "Abbinato",
    nfPairFailed: "Abbinamento non riuscito", nfForgotten: "Dimenticato", nfForgetFailed: "Impossibile dimenticare",
    barTooltip: "Suggerimento sull’icona della barra", barTooltipHint: "Passando sull’icona Bluetooth della barra compare la batteria di ogni dispositivo.",
    turningOn: "Accensione…", turningOff: "Spegnimento…"
  },
  pt: {
    settings: "Configurações", back: "Voltar", backTip: "Voltar (Backspace, Esc)", language: "Idioma", systemLanguage: "Sistema ({0})",
    tipAccess: "Ainda sem acesso aos recetores. Clique para permitir.", tipNone: "Nenhum recetor ou dispositivo com bateria encontrado.",
    off: "desligado", charging: "a carregar", charged: "carregado", notConnected: "não ligado", noBattery: "sem nível de bateria",
    slotN: "posição {0}", connectedOf: "{0} de {1} dispositivos ligados", receiversN: ["1 dongle", "{0} dongles"],
    accessNeeded: "Acesso necessário", nothingFound: "Nada encontrado", looking: "A procurar dispositivos …",
    lowestBattery: "Bateria mais baixa {0}%", setupStep: "Ainda não está pronto · passo 1 de 1",
    setupText: "No Linux só o root pode falar com os recetores. Permitir o acesso instala uma regra udev (a mesma do Solaar) que dá ao utilizador com sessão iniciada acesso a recetores e dispositivos Logitech. A palavra-passe será pedida uma vez.",
    waitingPassword: "À espera da palavra-passe …", allowAccess: "Permitir acesso",
    noneText: "Nenhum recetor Logitech nem dispositivo Bluetooth com bateria encontrado.", error: "Erro: {0}", devices: "Dispositivos",
    receivers: "Recetores", dpi: "Velocidade do ponteiro (DPI)", dpiDefault: "predefinido", wheelMode: "Modo da roda", smartshift: "SmartShift",
    smartshiftTip: "Com cliques, passa a rotação livre quando impulsiona a roda", ratchet: "Com cliques", ratchetTip: "Sempre clique a clique",
    freespin: "Rotação livre", freespinTip: "Gira sempre livremente", sensitivity: "Sensibilidade",
    sensitivityHint: "Valores mais baixos passam a rotação livre com um impulso mais suave.", natural: "Deslocamento natural",
    naturalHint: "O conteúdo segue a roda, como num touchpad", hires: "Deslocamento de alta resolução",
    hiresHint: "Passos mais finos e suaves nas apps compatíveis", fnswap: "Trocar teclas Fn",
    fnswapOn: "Ligado: a fila de cima dá funções multimédia, mantenha Fn para F1–F12",
    fnswapOff: "Desligado: a fila de cima dá F1–F12, mantenha Fn para funções multimédia", slotsUsed: "{0} de {1} posições usadas",
    noDevicePaired: "Nenhum dispositivo emparelhado", refresh: "Atualizar", conn_unifying: "Dongle Unifying", conn_bolt: "Dongle Bolt",
    conn_nano: "Dongle Nano", conn_lightspeed: "Dongle Lightspeed", conn_bluetooth: "Bluetooth", conn_usb: "Cabo USB",
    conn_wireless: "Sem fios", unnamed: "Dispositivo Logitech", errNotConnected: "Esse dispositivo não está ligado agora.",
    errChange: "Não foi possível alterar a definição ({0}).", lowAt: "Aviso de bateria fraca", criticalAt: "Aviso de bateria crítica",
    atOrBelow: "a {0}% ou menos", otherDevices: "Outros dispositivos Bluetooth",
    otherDevicesHint: "Touchpads, auriculares, comandos e mais (só bateria)", connections: "Ligações", thisPc: "Este PC",
    btAdapter: "Adaptador Bluetooth", dongleSub: "{0} de {1} posições",
    radioHint: "Linha pontilhada: ligação rádio. Linha contínua: ligado à porta ou integrado.", deviceOff: "desligado",
    btBuiltin: "Bluetooth integrado", btBuiltinSub: "Dentro deste PC", btDongle: "Dongle Bluetooth", btDongleSub: "Pen USB",
    access: "Acesso aos recetores", accessGranted: "Permitido", accessMissing: "Não permitido", showHidden: "Mostrar dispositivos ocultos ({0})",
    hideHidden: "Ocultar dispositivos ocultos", hide: "Ocultar da lista", unhide: "Mostrar na lista", hiddenTag: "oculto", bluetooth: "Bluetooth",
    bluetoothTip: "Emparelhar, ligar e ativar ou desativar o Bluetooth", btTurnOn: "Ativar Bluetooth", btTurnOff: "Desativar Bluetooth",
    btSecConnected: "Ligados", btSecPaired: "Emparelhados", btSecAvailable: "Disponíveis", btScanning: "A procurar dispositivos…",
    btScanningShort: "A procurar", btOffHint: "Ative o Bluetooth para procurar", btNoAdapter: "Sem adaptador Bluetooth", btOn: "Ativado",
    btOffState: "Desativado", btConnect: "Ligar", btDisconnect: "Desligar", btPair: "Emparelhar", btForget: "Esquecer",
    btReallyForget: "Esquecer mesmo?", btConnecting: "A ligar…", btDisconnecting: "A desligar…", btForgetting: "A esquecer…",
    // ---- pane
    btManager: "Gestor de Bluetooth", btScan: "Procurar", btSecWired: "USB e recetores", hiddenCount: "Ocultos: {0}", unhideAll: "Mostrar todos",
    offDetail: "Os dispositivos emparelhados voltam a ligar-se assim que for reativado.",
    pairHint: "Ponha o dispositivo em modo de emparelhamento.", scanHint: "Procure para encontrar dispositivos próximos.",
    updatedAt: "atualizado {0}", alerts: "Avisos de bateria",
    alertsHint: "O ícone Bluetooth da barra passa a ser o do dispositivo: laranja com bateria fraca, vermelho com bateria crítica.",
    hiddenNone: "O olho de um dispositivo oculta-o do mapa, da lista e dos avisos da barra.",
    nfConnected: "Ligado", nfConnectFailed: "Não foi possível ligar", nfDisconnected: "Desligado", nfPaired: "Emparelhado",
    nfPairFailed: "Falha no emparelhamento", nfForgotten: "Esquecido", nfForgetFailed: "Não foi possível esquecer",
    barTooltip: "Dica no ícone da barra", barTooltipHint: "Passar o rato sobre o ícone Bluetooth da barra mostra a bateria de cada dispositivo.",
    turningOn: "A ativar…", turningOff: "A desativar…"
  },
  nl: {
    settings: "Instellingen", back: "Terug", backTip: "Terug (Backspace, Esc)", language: "Taal", systemLanguage: "Systeem ({0})",
    tipAccess: "Nog geen toegang tot de ontvangers. Klik om toe te staan.", tipNone: "Geen ontvanger of apparaat met batterij gevonden.",
    off: "uit", charging: "laadt", charged: "opgeladen", notConnected: "niet verbonden", noBattery: "geen batterijstand", slotN: "plek {0}",
    connectedOf: "{0} van {1} apparaten verbonden", receiversN: ["1 dongle", "{0} dongles"], accessNeeded: "Toegang nodig",
    nothingFound: "Niets gevonden", looking: "Apparaten zoeken …", lowestBattery: "Laagste batterij {0}%",
    setupStep: "Nog niet klaar · stap 1 van 1",
    setupText: "Onder Linux mag alleen root met de ontvangers praten. Toegang toestaan installeert één udev-regel (dezelfde als Solaar) die de aangemelde gebruiker toegang geeft tot Logitech-ontvangers en -apparaten. Je wachtwoord wordt één keer gevraagd.",
    waitingPassword: "Wachten op wachtwoord …", allowAccess: "Toegang toestaan",
    noneText: "Geen Logitech-ontvanger en geen Bluetooth-apparaat met batterij gevonden.", error: "Fout: {0}", devices: "Apparaten",
    receivers: "Ontvangers", dpi: "Aanwijzersnelheid (DPI)", dpiDefault: "standaard", wheelMode: "Scrollwielmodus", smartshift: "SmartShift",
    smartshiftTip: "Klikkend, schakelt naar vrijloop als je het wiel aanslingert", ratchet: "Klikkend", ratchetTip: "Altijd klik voor klik",
    freespin: "Vrijloop", freespinTip: "Draait altijd vrij", sensitivity: "Gevoeligheid",
    sensitivityHint: "Lagere waarden schakelen al bij zacht aanslingeren naar vrijloop.", natural: "Natuurlijk scrollen",
    naturalHint: "De inhoud volgt het wiel, zoals op een touchpad", hires: "Scrollen met hoge resolutie",
    hiresHint: "Fijnere, vloeiendere stappen in apps die het ondersteunen", fnswap: "Fn-toetsen omwisselen",
    fnswapOn: "Aan: bovenste rij geeft media- en speciale functies, houd Fn ingedrukt voor F1–F12",
    fnswapOff: "Uit: bovenste rij geeft F1–F12, houd Fn ingedrukt voor media- en speciale functies",
    slotsUsed: "{0} van {1} plekken in gebruik", noDevicePaired: "Geen apparaat gekoppeld", refresh: "Vernieuwen",
    conn_unifying: "Unifying-dongle", conn_bolt: "Bolt-dongle", conn_nano: "Nano-dongle", conn_lightspeed: "Lightspeed-dongle",
    conn_bluetooth: "Bluetooth", conn_usb: "USB-kabel", conn_wireless: "Draadloos", unnamed: "Logitech-apparaat",
    errNotConnected: "Dat apparaat is nu niet verbonden.", errChange: "Instelling kon niet worden gewijzigd ({0}).",
    lowAt: "Waarschuwing lage batterij", criticalAt: "Waarschuwing kritieke batterij", atOrBelow: "bij {0}% of minder",
    otherDevices: "Andere Bluetooth-apparaten", otherDevicesHint: "Trackpads, oordopjes, controllers en meer (alleen batterij)",
    connections: "Verbindingen", thisPc: "Deze pc", btAdapter: "Bluetooth-adapter", dongleSub: "{0} van {1} plekken",
    radioHint: "Stippellijn: radioverbinding. Doorgetrokken: ingeplugd of ingebouwd.", deviceOff: "uit", btBuiltin: "Ingebouwde Bluetooth",
    btBuiltinSub: "In deze pc", btDongle: "Bluetooth-dongle", btDongleSub: "USB-stick", access: "Toegang tot ontvangers",
    accessGranted: "Toegestaan", accessMissing: "Niet toegestaan", showHidden: "Verborgen apparaten tonen ({0})",
    hideHidden: "Verborgen apparaten verbergen", hide: "Uit de lijst verbergen", unhide: "In de lijst tonen", hiddenTag: "verborgen",
    bluetooth: "Bluetooth", bluetoothTip: "Koppelen, verbinden en Bluetooth aan- of uitzetten", btTurnOn: "Bluetooth aanzetten",
    btTurnOff: "Bluetooth uitzetten", btSecConnected: "Verbonden", btSecPaired: "Gekoppeld", btSecAvailable: "Beschikbaar",
    btScanning: "Zoeken naar apparaten…", btScanningShort: "Zoeken", btOffHint: "Zet Bluetooth aan om te zoeken",
    btNoAdapter: "Geen Bluetooth-adapter", btOn: "Aan", btOffState: "Uit", btConnect: "Verbinden", btDisconnect: "Verbreken",
    btPair: "Koppelen", btForget: "Vergeten", btReallyForget: "Echt vergeten?", btConnecting: "Verbinden…", btDisconnecting: "Verbreken…",
    btForgetting: "Vergeten…",
    // ---- pane
    btManager: "Bluetooth-beheer", btScan: "Zoeken", btSecWired: "USB & ontvangers", hiddenCount: "{0} verborgen", unhideAll: "Alles weer tonen",
    offDetail: "Gekoppelde apparaten verbinden opnieuw zodra het weer aan staat.", pairHint: "Zet het apparaat in koppelmodus.",
    scanHint: "Zoek om apparaten in de buurt te vinden.", updatedAt: "bijgewerkt {0}", alerts: "Batterijwaarschuwingen",
    alertsHint: "Het Bluetooth-pictogram in de balk wordt dat van het apparaat: oranje bij lage, rood bij kritieke batterij.",
    hiddenNone: "Het oog bij een apparaat verbergt het uit de kaart, de lijst en de waarschuwingen in de balk.",
    nfConnected: "Verbonden", nfConnectFailed: "Verbinden mislukt", nfDisconnected: "Verbroken", nfPaired: "Gekoppeld",
    nfPairFailed: "Koppelen mislukt", nfForgotten: "Vergeten", nfForgetFailed: "Vergeten mislukt",
    barTooltip: "Tooltip bij het balkpictogram", barTooltipHint: "Met de muis op het Bluetooth-pictogram in de balk zie je de batterij van elk apparaat.",
    turningOn: "Aanzetten…", turningOff: "Uitzetten…"
  },
  pl: {
    settings: "Ustawienia", back: "Wstecz", backTip: "Wstecz (Backspace, Esc)", language: "Język", systemLanguage: "Systemowy ({0})",
    tipAccess: "Brak dostępu do odbiorników. Kliknij, aby zezwolić.", tipNone: "Nie znaleziono odbiornika ani urządzenia z baterią.",
    off: "wyłączone", charging: "ładuje się", charged: "naładowane", notConnected: "niepołączone", noBattery: "brak poziomu baterii",
    slotN: "gniazdo {0}", connectedOf: "Połączone urządzenia: {0} z {1}", receiversN: ["1 dongle", "{0} dongle", "{0} dongli"],
    accessNeeded: "Potrzebny dostęp", nothingFound: "Nic nie znaleziono", looking: "Szukanie urządzeń …", lowestBattery: "Najniższa bateria {0}%",
    setupStep: "Jeszcze niegotowe · krok 1 z 1",
    setupText: "W Linuksie tylko root może rozmawiać z odbiornikami. Zezwolenie na dostęp instaluje jedną regułę udev (tę samą co Solaar), która daje zalogowanemu użytkownikowi dostęp do odbiorników i urządzeń Logitech. Hasło zostanie zapytane raz.",
    waitingPassword: "Czekanie na hasło …", allowAccess: "Zezwól na dostęp",
    noneText: "Nie znaleziono odbiornika Logitech ani urządzenia Bluetooth z baterią.", error: "Błąd: {0}", devices: "Urządzenia",
    receivers: "Odbiorniki", dpi: "Szybkość wskaźnika (DPI)", dpiDefault: "domyślnie", wheelMode: "Tryb kółka", smartshift: "SmartShift",
    smartshiftTip: "Skokowe, przechodzi w swobodny obrót po mocnym zakręceniu", ratchet: "Skokowe", ratchetTip: "Zawsze skok po skoku",
    freespin: "Swobodny obrót", freespinTip: "Zawsze obraca się swobodnie", sensitivity: "Czułość",
    sensitivityHint: "Niższe wartości przechodzą w swobodny obrót przy delikatniejszym zakręceniu.", natural: "Naturalne przewijanie",
    naturalHint: "Treść podąża za kółkiem, jak na touchpadzie", hires: "Przewijanie w wysokiej rozdzielczości",
    hiresHint: "Drobniejsze, płynniejsze kroki w obsługujących aplikacjach", fnswap: "Zamień klawisze Fn",
    fnswapOn: "Wł.: górny rząd daje funkcje multimedialne, przytrzymaj Fn dla F1–F12",
    fnswapOff: "Wył.: górny rząd daje F1–F12, przytrzymaj Fn dla funkcji multimedialnych", slotsUsed: "Zajęte gniazda: {0} z {1}",
    noDevicePaired: "Brak sparowanych urządzeń", refresh: "Odśwież", conn_unifying: "Dongle Unifying", conn_bolt: "Dongle Bolt",
    conn_nano: "Dongle Nano", conn_lightspeed: "Dongle Lightspeed", conn_bluetooth: "Bluetooth", conn_usb: "Kabel USB",
    conn_wireless: "Bezprzewodowo", unnamed: "Urządzenie Logitech", errNotConnected: "To urządzenie nie jest teraz połączone.",
    errChange: "Nie udało się zmienić ustawienia ({0}).", lowAt: "Ostrzeżenie o niskiej baterii", criticalAt: "Ostrzeżenie o krytycznej baterii",
    atOrBelow: "przy {0}% lub mniej", otherDevices: "Inne urządzenia Bluetooth",
    otherDevicesHint: "Touchpady, słuchawki, kontrolery i inne (tylko bateria)", connections: "Połączenia", thisPc: "Ten komputer",
    btAdapter: "Adapter Bluetooth", dongleSub: "{0} z {1} gniazd", radioHint: "Linia kropkowana: łącze radiowe. Ciągła: podłączone lub wbudowane.",
    deviceOff: "wył.", btBuiltin: "Wbudowany Bluetooth", btBuiltinSub: "W tym komputerze", btDongle: "Dongle Bluetooth", btDongleSub: "Moduł USB",
    access: "Dostęp do odbiorników", accessGranted: "Przyznany", accessMissing: "Nieprzyznany", showHidden: "Pokaż ukryte urządzenia ({0})",
    hideHidden: "Ukryj ukryte urządzenia", hide: "Ukryj na liście", unhide: "Pokaż na liście", hiddenTag: "ukryte", bluetooth: "Bluetooth",
    bluetoothTip: "Paruj, łącz i włączaj lub wyłączaj Bluetooth", btTurnOn: "Włącz Bluetooth", btTurnOff: "Wyłącz Bluetooth",
    btSecConnected: "Połączone", btSecPaired: "Sparowane", btSecAvailable: "Dostępne", btScanning: "Wyszukiwanie urządzeń…",
    btScanningShort: "Wyszukiwanie", btOffHint: "Włącz Bluetooth, aby wyszukać", btNoAdapter: "Brak adaptera Bluetooth", btOn: "Włączony",
    btOffState: "Wyłączony", btConnect: "Połącz", btDisconnect: "Rozłącz", btPair: "Paruj", btForget: "Zapomnij",
    btReallyForget: "Na pewno zapomnieć?", btConnecting: "Łączenie…", btDisconnecting: "Rozłączanie…", btForgetting: "Usuwanie…",
    // ---- pane
    btManager: "Menedżer Bluetooth", btScan: "Szukaj", btSecWired: "USB i odbiorniki", hiddenCount: "Ukryte: {0}", unhideAll: "Pokaż wszystkie",
    offDetail: "Sparowane urządzenia połączą się ponownie po włączeniu.", pairHint: "Przełącz urządzenie w tryb parowania.",
    scanHint: "Wyszukaj, aby znaleźć urządzenia w pobliżu.", updatedAt: "zaktualizowano {0}", alerts: "Ostrzeżenia baterii",
    alertsHint: "Ikona Bluetooth na pasku zmienia się w ikonę urządzenia: pomarańczową przy niskiej, czerwoną przy krytycznej baterii.",
    hiddenNone: "Oko przy urządzeniu ukrywa je na mapie, liście i w ostrzeżeniach paska.",
    nfConnected: "Połączono", nfConnectFailed: "Nie udało się połączyć", nfDisconnected: "Rozłączono", nfPaired: "Sparowano",
    nfPairFailed: "Parowanie nie powiodło się", nfForgotten: "Zapomniano", nfForgetFailed: "Nie udało się zapomnieć",
    barTooltip: "Podpowiedź na ikonie paska", barTooltipHint: "Najechanie na ikonę Bluetooth na pasku pokazuje baterię każdego urządzenia.",
    turningOn: "Włączanie…", turningOff: "Wyłączanie…"
  }
}

function supported(code) {
  for (var i = 0; i < LANGUAGES.length; i++) if (LANGUAGES[i].code === code) return true
  return false
}

function languageName(code) {
  for (var i = 0; i < LANGUAGES.length; i++) if (LANGUAGES[i].code === code) return LANGUAGES[i].name
  return code
}

// First of LC_ALL, LC_MESSAGES, LANG that names a language ("de_DE.UTF-8" -> de); C / POSIX / unset skip; else en.
function systemLanguage(lcAll, lcMessages, lang) {
  var vals = [lcAll, lcMessages, lang]
  for (var i = 0; i < vals.length; i++) {
    var code = String(vals[i] || "").toLowerCase().split(/[_.@-]/)[0]
    if (!code || code === "c" || code === "posix") continue
    return supported(code) ? code : "en"
  }
  return "en"
}

function resolve(setting, systemCode) {
  return supported(setting) ? setting : systemCode
}

function format(text, args) {
  return String(text).replace(/\{(\d+)\}/g, function(m, i) { return args && args[i] !== undefined ? String(args[i]) : m })
}

function lookup(lang, key) {
  var table = TABLES[lang] || TABLES.en
  return table[key] !== undefined ? table[key] : (TABLES.en[key] !== undefined ? TABLES.en[key] : key)
}

function tr(lang, key, args) {
  var v = lookup(lang, key)
  return format(Array.isArray(v) ? v[v.length - 1] : v, args)
}

// Plural forms: Polish one / few / many, French and Portuguese 0 and 1 singular, the rest 1 singular.
function trn(lang, key, n, args) {
  var v = lookup(lang, key)
  if (!Array.isArray(v)) return format(v, args)
  var idx
  if (lang === "pl" && v.length > 2) idx = n === 1 ? 0 : (n % 10 >= 2 && n % 10 <= 4 && !(n % 100 >= 12 && n % 100 <= 14) ? 1 : 2)
  else if (lang === "fr" || lang === "pt") idx = n <= 1 ? 0 : v.length - 1
  else idx = n === 1 ? 0 : v.length - 1
  return format(v[idx], args)
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { LANGUAGES: LANGUAGES, TABLES: TABLES, supported: supported, languageName: languageName, systemLanguage: systemLanguage,
    resolve: resolve, format: format, tr: tr, trn: trn }
}
