import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    signal requestUndo()
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 30
        spacing: 18
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout { Layout.fillWidth: true; spacing: 6; Label { text: 'История перемещений'; font.pixelSize: 29; font.weight: Font.DemiBold } Label { text: 'Исходные пути сохранены. Последний перенос можно вернуть.'; color: Theme.muted; font.pixelSize: 13 } }
            ActionButton { text: 'Вернуть последний перенос'; iconName: 'undo'; enabled: !backend.busy && backend.history.length > 0; onClicked: requestUndo() }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            color: Theme.panel
            border.color: Theme.line
            ListView {
                id: historyList
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                model: backend.history
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    required property var modelData
                    width: historyList.width
                    height: 104
                    color: historyHover.hovered ? '#1a2b40' : 'transparent'
                    HoverHandler { id: historyHover }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 17
                        spacing: 15
                        StrokeIcon { name: modelData.status === 'Возвращён' ? 'undo' : 'arrow'; ink: modelData.status === 'Возвращён' ? Theme.muted : '#6dadff'; Layout.preferredWidth: 23; Layout.preferredHeight: 23 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Label { text: modelData.name; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideMiddle }
                            Label { text: 'Было: ' + modelData.source; color: '#849ab7'; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideMiddle }
                            Label { text: 'Стало: ' + modelData.destination; color: '#a8c4e7'; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideMiddle }
                        }
                        ColumnLayout { Layout.preferredWidth: 156; spacing: 8; Label { text: modelData.status; color: modelData.status === 'Перемещён' ? '#6bd9ab' : Theme.muted; font.pixelSize: 12; Layout.alignment: Qt.AlignRight } Label { text: modelData.date; color: '#7e94b0'; font.pixelSize: 11; Layout.alignment: Qt.AlignRight } }
                    }
                }
            }
            ColumnLayout {
                anchors.centerIn: parent
                visible: backend.history.length === 0
                spacing: 12
                StrokeIcon { name: 'history'; ink: '#6594cc'; Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 38; Layout.preferredHeight: 38 }
                Label { text: 'Перемещений пока нет'; font.pixelSize: 21; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignHCenter }
                Label { text: 'После первой сортировки здесь появятся исходные и новые пути.'; color: Theme.muted; font.pixelSize: 13; Layout.alignment: Qt.AlignHCenter }
            }
        }
        Label { text: 'Показано последних записей: ' + backend.history.length; color: Theme.muted; font.pixelSize: 11 }
    }
}
