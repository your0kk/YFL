import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property string name: 'folder'
    property color ink: Theme.muted
    property real lineWidth: 1.65
    implicitWidth: 22
    implicitHeight: 22
    property var paths: ({
        folder: 'M3 7 L3 19 Q3 21 5 21 L20 21 Q22 21 22 19 L22 8 Q22 6 20 6 L12 6 L10 3 L5 3 Q3 3 3 5 Z',
        files: 'M5 3 L14 3 L20 9 L20 21 L5 21 Z M14 3 L14 9 L20 9 M8 13 L16 13 M8 17 L14 17',
        rules: 'M4 6 L20 6 M4 12 L20 12 M4 18 L20 18 M8 3 L8 9 M16 9 L16 15 M10 15 L10 21',
        history: 'M21 12 A9 9 0 1 1 3 12 A9 9 0 1 1 21 12 M12 6 L12 12 L16 14',
        settings: 'M9 3 L15 3 L16 6 L19 7 L22 10 L20 13 L20 16 L16 19 L14 22 L10 22 L8 19 L4 17 L3 13 L5 10 L5 7 L9 5 Z M16 12 A4 4 0 1 1 8 12 A4 4 0 1 1 16 12',
        download: 'M12 3 L12 16 M6 10 L12 16 L18 10 M4 17 L4 21 L20 21 L20 17',
        desktop: 'M3 3 L21 3 L21 16 L3 16 Z M12 16 L12 21 M7 21 L17 21',
        book: 'M12 5 Q7 2 3 4 L3 20 Q7 18 12 21 Q17 18 21 20 L21 4 Q17 2 12 5 L12 21',
        search: 'M17 10 A7 7 0 1 1 3 10 A7 7 0 1 1 17 10 M15 15 L22 22',
        plus: 'M12 4 L12 20 M4 12 L20 12',
        arrow: 'M4 12 L21 12 M15 6 L21 12 L15 18',
        chevron: 'M8 5 L15 12 L8 19',
        down: 'M5 9 L12 16 L19 9',
        refresh: 'M20 8 A9 9 0 1 0 21 15 M20 2 L20 8 L14 8',
        check: 'M4 12 L9 17 L20 6',
        close: 'M5 5 L19 19 M19 5 L5 19',
        minimize: 'M5 13 L19 13',
        maximize: 'M5 5 L19 5 L19 19 L5 19 Z',
        info: 'M21 12 A9 9 0 1 1 3 12 A9 9 0 1 1 21 12 M12 11 L12 17 M12 7 L12 8',
        undo: 'M9 4 L3 10 L9 16 M3 10 L14 10 Q21 10 21 17 L21 21',
        shield: 'M12 2 L21 6 L20 14 Q18 20 12 23 Q6 20 4 14 L3 6 Z M7 12 L11 16 L17 9',
        export: 'M12 3 L12 16 M7 11 L12 16 L17 11 M4 17 L4 21 L20 21 L20 17'
    })
    Shape {
        width: 24
        height: 24
        scale: Math.min(root.width, root.height) / 26
        anchors.centerIn: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.ink
            strokeWidth: root.lineWidth
            fillColor: 'transparent'
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.paths[root.name] || root.paths.folder }
        }
    }
}
