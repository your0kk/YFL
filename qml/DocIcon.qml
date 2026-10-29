import QtQuick
import QtQuick.Shapes

Item {
    id: doc
    property string extension: 'PDF'
    property color tint: '#ef6268'
    implicitWidth: 32
    implicitHeight: 38
    Rectangle { x: 5; y: 1; width: 24; height: 32; radius: 3; color: '#dce5ef' }
    Shape {
        x: 20
        y: 1
        width: 9
        height: 9
        antialiasing: true
        ShapePath { fillColor: '#899aaf'; strokeColor: 'transparent'; PathSvg { path: 'M0 0 L9 9 L0 9 Z' } }
    }
    Rectangle {
        x: 0
        y: 17
        width: 31
        height: 18
        radius: 3
        color: doc.tint
        Label { anchors.centerIn: parent; color: '#ffffff'; font.pixelSize: doc.extension.length > 3 ? 8 : 10; font.bold: true; text: doc.extension === 'DOCX' || doc.extension === 'DOC' ? 'W' : doc.extension === 'XLSX' || doc.extension === 'XLS' ? 'X' : doc.extension === 'PPTX' || doc.extension === 'PPT' ? 'P' : doc.extension }
    }
}
