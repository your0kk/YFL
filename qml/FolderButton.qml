import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: control
    property bool active: false
    property string iconName: 'folder'
    property color tint: '#8dbbff'
    property int count: -1
    implicitHeight: 44
    leftPadding: 13
    rightPadding: 10
    hoverEnabled: true
    activeFocusOnTab: true
    background: Rectangle {
        radius: 7
        color: control.active ? '#1b4b88' : control.hovered ? '#1b293b' : 'transparent'
        border.width: control.visualFocus ? 2 : control.active ? 1 : 0
        border.color: control.visualFocus ? '#a9cfff' : '#3169ad'
        Behavior on color { ColorAnimation { duration: Theme.motion } }
    }
    contentItem: RowLayout {
        spacing: 11
        StrokeIcon { name: control.iconName; ink: control.active ? '#d9eaff' : control.tint; Layout.preferredWidth: 21; Layout.preferredHeight: 21 }
        Label { text: control.text; font.pixelSize: 13; font.weight: control.active ? Font.DemiBold : Font.Normal; Layout.fillWidth: true; elide: Text.ElideRight }
        Rectangle {
            visible: control.count >= 0
            implicitWidth: Math.max(26, number.implicitWidth + 13)
            implicitHeight: 23
            radius: 12
            color: '#1e3656'
            Label { id: number; anchors.centerIn: parent; text: control.count; color: '#bad8ff'; font.pixelSize: 11 }
        }
    }
}
