import QtQuick
import QtQuick.Controls

Switch {
    id: control
    implicitHeight: 38
    leftPadding: 0
    rightPadding: 0
    spacing: 10
    hoverEnabled: true
    activeFocusOnTab: true
    indicator: Rectangle {
        x: control.width - width
        y: (control.height - height) / 2
        width: 38
        height: 22
        radius: 11
        color: control.checked ? Theme.blue : '#354154'
        border.color: control.visualFocus ? '#bad9ff' : 'transparent'
        border.width: 2
        opacity: control.enabled ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: Theme.motion } }
        Rectangle {
            width: 16
            height: 16
            radius: 8
            x: control.checked ? 19 : 3
            y: 3
            color: '#f3f7ff'
            Behavior on x { NumberAnimation { duration: Theme.motion; easing.type: Easing.OutCubic } }
        }
    }
    contentItem: Label {
        text: control.text
        color: control.enabled ? Theme.text : Theme.muted
        font.pixelSize: 13
        rightPadding: 48
        wrapMode: Text.WordWrap
    }
}
