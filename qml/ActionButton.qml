import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: control
    property bool primary: false
    property bool quiet: false
    property string iconName: ''
    property int buttonHeight: 42
    implicitHeight: buttonHeight
    implicitWidth: contentItem.implicitWidth + 30
    padding: 15
    spacing: 9
    hoverEnabled: true
    activeFocusOnTab: true
    Accessible.name: text
    scale: down ? 0.982 : 1
    Behavior on scale { NumberAnimation { duration: Theme.motion / 2; easing.type: Easing.OutCubic } }
    background: Rectangle {
        radius: 8
        color: !control.enabled ? '#1b2738' : control.primary ? (control.down ? '#1768d1' : control.hovered ? '#52a1ff' : Theme.blue) : control.quiet ? (control.hovered ? '#202d3f' : 'transparent') : (control.hovered ? '#24354b' : '#17212e')
        border.width: control.visualFocus ? 2 : control.primary || control.quiet ? 0 : 1
        border.color: control.visualFocus ? '#b2d5ff' : '#354961'
        Behavior on color { ColorAnimation { duration: Theme.motion } }
        Rectangle { visible: control.primary && control.enabled; height: 1; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8; color: '#65ffffff' }
    }
    contentItem: RowLayout {
        spacing: 9
        StrokeIcon { visible: control.iconName !== ''; name: control.iconName; ink: !control.enabled ? '#63758c' : control.primary ? '#ffffff' : Theme.muted; Layout.preferredWidth: 19; Layout.preferredHeight: 19 }
        Label { text: control.text; color: !control.enabled ? '#63758c' : control.primary ? '#ffffff' : Theme.text; font.pixelSize: 13; font.weight: control.primary ? Font.DemiBold : Font.Normal; Layout.alignment: Qt.AlignCenter }
    }
}
