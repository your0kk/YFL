pragma Singleton
import QtQuick

QtObject {
    readonly property color background: '#0e1219'
    readonly property color panel: '#121923'
    readonly property color surface: '#18212d'
    readonly property color line: '#263345'
    readonly property color text: '#f1f5fb'
    readonly property color muted: '#9daec3'
    readonly property color blue: '#368dff'
    readonly property color green: '#51d4a1'
    readonly property color amber: '#edc17d'
    readonly property int motion: backend.animations ? 160 : 0
}
