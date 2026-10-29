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
            spacing: 20
            Label { text: 'Как YFL выбирает папку'; font.pixelSize: 29; font.weight: Font.DemiBold }
            Label { text: 'Содержимое документа важнее одного расширения'; font.pixelSize: 14; color: Theme.muted }
            GridLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 1040
                columns: parent.width < 1000 ? 2 : 4
                columnSpacing: 15
                rowSpacing: 15
                Repeater {
                    model: [
                        {title:'Мои работы', icon:'files', color:'#6aaeff', text:'Фамилия из настроек найдена в названии или в начале документа.', note:'Это признак автора. Готовность работы не подтверждается.'},
                        {title:'Методички и задания', icon:'book', color:'#b899f0', text:'В заголовке найдены методические указания, образец или инструкция.', note:'Шаблон с вашей фамилией тоже может быть методичкой.'},
                        {title:'Работы других авторов', icon:'folder', color:'#7fcbc1', text:'В документе есть подпись другого исполнителя.', note:'Такие работы складываются отдельно от ваших.'},
                        {title:'Требуют проверки', icon:'info', color:'#edc17d', text:'Неясен автор, неоднозначен текст или файл не удалось прочитать.', note:'Раздел можно изменить перед перемещением.'}
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 238
                        radius: 11
                        color: Theme.panel
                        border.color: Theme.line
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 21
                            spacing: 12
                            StrokeIcon { name: modelData.icon; ink: modelData.color; Layout.preferredWidth: 27; Layout.preferredHeight: 27 }
                            Label { text: modelData.title; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            Label { text: modelData.text; color: '#bfcee1'; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true; lineHeight: 1.25 }
                            Item { Layout.fillHeight: true }
                            Label { text: modelData.note; color: Theme.muted; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.maximumWidth: 1040
                implicitHeight: explanation.implicitHeight + 42
                color: '#142236'
                radius: 11
                border.color: '#2a425e'
                ColumnLayout {
                    id: explanation
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 21
                    spacing: 11
                    Label { text: 'Внутри раздела — по типу работы'; font.pixelSize: 17; font.weight: Font.DemiBold }
                    Label { text: 'Лабораторные, практические, самостоятельные, курсовые, дипломные, презентации и другие учебные материалы.'; color: '#b8cce5'; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    Label { text: 'Например: Учёба / Мои работы / Лабораторные / ваш файл.docx'; color: '#70b2ff'; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere }
                }
            }
            Label { text: 'Поддерживается чтение PDF с текстовым слоем, DOCX, XLSX, PPTX, TXT, Markdown, RTF и OpenDocument. Старые DOC/XLS/PPT и сканы без текста требуют ручной проверки. Правила работают локально и могут ошибаться — перед переносом посмотрите предложенную папку.'; color: Theme.muted; font.pixelSize: 12; Layout.maximumWidth: 1040; Layout.fillWidth: true; wrapMode: Text.WordWrap; lineHeight: 1.45; Layout.bottomMargin: 12 }
        }
    }
}
