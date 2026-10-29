import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    ScrollView {
        anchors.fill: parent
        anchors.margins: 30
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            width: parent.width
            spacing: 21
            Label { text: 'Настройки'; font.pixelSize: 29; font.weight: Font.DemiBold }
            Label { text: 'Автор, папка результата и удобство работы'; color: Theme.muted; font.pixelSize: 14 }
            Rectangle {
                Layout.fillWidth: true
                Layout.maximumWidth: 840
                implicitHeight: sortingSettings.implicitHeight + 46
                radius: 11
                color: Theme.panel
                border.color: Theme.line
                ColumnLayout {
                    id: sortingSettings
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 23
                    spacing: 15
                    Label { text: 'Сортировка'; font.pixelSize: 18; font.weight: Font.DemiBold }
                    Label { text: 'Ваша фамилия'; color: '#bdcde2'; font.pixelSize: 13 }
                    TextField {
                        id: authorField
                        Layout.fillWidth: true
                        Layout.maximumWidth: 420
                        Layout.preferredHeight: 43
                        text: backend.author
                        placeholderText: 'Например: Иванов'
                        placeholderTextColor: '#7289a5'
                        color: Theme.text
                        font.family: 'Segoe UI'
                        font.pixelSize: 14
                        padding: 12
                        enabled: !backend.busy
                        selectByMouse: true
                        background: Rectangle { radius: 7; color: '#0f1825'; border.color: authorField.activeFocus ? Theme.blue : '#32445c' }
                        onEditingFinished: backend.setAuthor(text)
                        Accessible.name: 'Ваша фамилия для распознавания автора'
                    }
                    Label { text: 'Фамилия ищется в названии и начале документа. Поле можно оставить пустым — тогда автор будет требовать проверки.'; color: Theme.muted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line; Layout.topMargin: 3; Layout.bottomMargin: 3 }
                    Label { text: 'Куда складывать файлы'; font.pixelSize: 13; color: '#bdcde2' }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 43
                            radius: 7
                            color: '#101b2a'
                            border.color: '#32445c'
                            Label { anchors.fill: parent; anchors.margins: 12; text: backend.output; elide: Text.ElideMiddle; font.pixelSize: 13 }
                        }
                        ActionButton { text: 'Изменить'; iconName: 'folder'; enabled: !backend.busy; onClicked: backend.chooseOutput() }
                    }
                    Toggle { Layout.fillWidth: true; text: 'Включать вложенные папки'; checked: backend.recursive; enabled: !backend.busy; onToggled: backend.setRecursive(checked) }
                    Toggle { Layout.fillWidth: true; text: 'Также проверять рабочий стол'; checked: backend.includeDesktop; enabled: !backend.busy; onToggled: backend.setDesktop(checked) }
                    Label { text: 'Папки проектов, приложений и хранилища Obsidian пропускаются. Файлы, изменённые менее 10 минут назад, остаются на месте.'; color: Theme.muted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.maximumWidth: 840
                implicitHeight: appearanceSettings.implicitHeight + 46
                radius: 11
                color: Theme.panel
                border.color: Theme.line
                ColumnLayout {
                    id: appearanceSettings
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 23
                    spacing: 14
                    Label { text: 'Интерфейс'; font.pixelSize: 18; font.weight: Font.DemiBold }
                    Toggle { Layout.fillWidth: true; text: 'Плавные анимации'; checked: backend.animations; onToggled: backend.setAnimations(checked) }
                    Label { text: 'Размер интерфейса следует масштабу экрана Windows. Иконка загружается из исходного изображения, значки интерфейса масштабируются без растягивания.'; color: Theme.muted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                }
            }
            Label { text: 'YFL — YourFileOrganizer · 0.2.0\nРаботает локально. Автоматическое перемещение и автозапуск не включаются.'; color: '#7e94b0'; font.pixelSize: 12; lineHeight: 1.5; Layout.bottomMargin: 12 }
        }
    }
}
