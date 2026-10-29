import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: window
    objectName: 'yflWindow'
    visible: true
    width: Math.min(1320, Screen.desktopAvailableWidth - 48)
    height: Math.min(850, Screen.desktopAvailableHeight - 56)
    minimumWidth: 1020
    minimumHeight: 650
    title: 'YFL — YourFileOrganizer'
    color: Theme.background
    flags: Qt.Window | Qt.FramelessWindowHint
    property string page: 'files'
    property string noticeTitle: ''
    property string noticeText: ''
    property bool noticeVisible: false
    property var detail: backend.detail
    property bool hasDetail: detail.fileName !== undefined
    property bool allowClose: false
    property int sidebarWidth: width < 1170 ? 174 : 194
    property int inspectorWidth: width < 1170 ? 274 : 308

    function navigate(name) {
        page = name
        if (name === 'history') backend.loadHistory()
        reveal.restart()
    }
    function confirmMove() {
        if (backend.analyzed && backend.selectedCount > 0 && !backend.busy) {
            confirm.action = 'move'
            confirm.open()
        }
    }
    onClosing: function(close) {
        if (backend.busy && !allowClose) {
            close.accepted = false
            backend.cancel()
            noticeTitle = 'Останавливаю операцию'
            noticeText = 'Дождитесь текущего файла и закройте окно ещё раз.'
            noticeVisible = true
            toastTimer.restart()
        }
    }
    Connections {
        target: backend
        function onNotice(title, message) {
            window.noticeTitle = title
            window.noticeText = message
            window.noticeVisible = true
            toastTimer.restart()
        }
    }
    Timer { id: toastTimer; interval: 6500; onTriggered: window.noticeVisible = false }
    NumberAnimation { id: reveal; target: pageStack; property: 'opacity'; from: 0.6; to: 1; duration: Theme.motion; easing.type: Easing.OutCubic }

    Rectangle { anchors.fill: parent; color: Theme.background; border.color: '#354357'; border.width: 1; radius: window.visibility === Window.Maximized ? 0 : 10 }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 1
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 45
            color: '#121a25'
            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: 144
                onPressed: window.startSystemMove()
                onDoubleClicked: window.visibility === Window.Maximized ? window.showNormal() : window.showMaximized()
            }
            RowLayout {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 17
                spacing: 10
                Image { source: backend.logo; Layout.preferredWidth: 27; Layout.preferredHeight: 27; sourceSize.width: 128; sourceSize.height: 128; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true }
                Label { text: 'YFL — YourFileOrganizer'; font.pixelSize: 13; font.weight: Font.DemiBold }
            }
            Row {
                anchors.right: parent.right
                height: parent.height
                Repeater {
                    model: ['minimize', 'maximize', 'close']
                    delegate: Button {
                        required property string modelData
                        width: 46
                        height: 44
                        hoverEnabled: true
                        Accessible.name: modelData === 'close' ? 'Закрыть' : modelData === 'minimize' ? 'Свернуть' : 'Развернуть'
                        background: Rectangle { color: parent.hovered ? (modelData === 'close' ? '#c33d54' : '#263449') : 'transparent'; Behavior on color { ColorAnimation { duration: Theme.motion } } }
                        contentItem: StrokeIcon { name: modelData; ink: Theme.text; width: 18; height: 18 }
                        onClicked: modelData === 'close' ? window.close() : modelData === 'minimize' ? window.showMinimized() : window.visibility === Window.Maximized ? window.showNormal() : window.showMaximized()
                    }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 53
            color: '#111923'
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 12
                Repeater {
                    model: [{label:'Файлы', page:'files', icon:'folder'}, {label:'Правила', page:'rules', icon:'rules'}, {label:'История', page:'history', icon:'history'}]
                    delegate: Button {
                        required property var modelData
                        Layout.preferredWidth: 121
                        Layout.fillHeight: true
                        hoverEnabled: true
                        enabled: !backend.busy
                        background: Rectangle {
                            color: parent.hovered ? '#192638' : 'transparent'
                            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 7; height: 3; radius: 2; color: Theme.blue; opacity: window.page === modelData.page ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.motion } } }
                        }
                        contentItem: RowLayout {
                            spacing: 9
                            StrokeIcon { name: modelData.icon; ink: window.page === modelData.page ? '#62a9ff' : Theme.muted; Layout.preferredWidth: 21; Layout.preferredHeight: 21 }
                            Label { text: modelData.label; font.weight: window.page === modelData.page ? Font.DemiBold : Font.Normal; color: window.page === modelData.page ? Theme.text : Theme.muted; Layout.alignment: Qt.AlignVCenter }
                        }
                        onClicked: window.navigate(modelData.page)
                    }
                }
                Item { Layout.fillWidth: true }
                ActionButton { text: 'Настройки'; iconName: 'settings'; quiet: true; enabled: !backend.busy; onClicked: window.navigate('settings') }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
        }

        StackLayout {
            id: pageStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: window.page === 'files' ? 0 : window.page === 'rules' ? 1 : window.page === 'history' ? 2 : 3

            Item {
                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        Layout.preferredWidth: window.sidebarWidth
                        Layout.fillHeight: true
                        color: '#121b27'
                        Rectangle { anchors.right: parent.right; height: parent.height; width: 1; color: Theme.line }
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6
                            Label { text: 'Папки'; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.muted; Layout.leftMargin: 11; Layout.topMargin: 12; Layout.bottomMargin: 12 }
                            FolderButton { Layout.fillWidth: true; text: 'Загрузки'; iconName: 'download'; active: backend.source.endsWith('Downloads'); count: active ? backend.count : -1; enabled: !backend.busy; onClicked: backend.quickFolder('Downloads') }
                            FolderButton { Layout.fillWidth: true; text: 'Рабочий стол'; iconName: 'desktop'; tint: '#b1bdcd'; active: backend.source.endsWith('Desktop'); enabled: !backend.busy; onClicked: backend.quickFolder('Desktop') }
                            FolderButton { Layout.fillWidth: true; text: 'Документы'; iconName: 'files'; tint: '#a0b6d7'; active: backend.source.endsWith('Documents'); enabled: !backend.busy; onClicked: backend.quickFolder('Documents') }
                            FolderButton { Layout.fillWidth: true; text: 'Учёба'; iconName: 'book'; tint: '#c5a0ff'; enabled: !backend.busy; onClicked: backend.quickFolder('study'); ToolTip.text: 'Открыть разобранные учебные файлы'; ToolTip.visible: hovered }
                            Repeater {
                                model: backend.customFolders
                                delegate: FolderButton { required property var modelData; Layout.fillWidth: true; text: modelData.label; active: backend.source === modelData.path; enabled: !backend.busy; onClicked: backend.setSource(modelData.path) }
                            }
                            Rectangle { Layout.fillWidth: true; Layout.margins: 9; height: 1; color: Theme.line }
                            ActionButton { Layout.fillWidth: true; Layout.leftMargin: 3; Layout.rightMargin: 3; text: 'Добавить папку'; iconName: 'plus'; quiet: true; enabled: !backend.busy; onClicked: backend.addFolder() }
                            Item { Layout.fillHeight: true }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 70
                                radius: 8
                                color: '#172432'
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 9
                                    StrokeIcon { name: 'shield'; ink: Theme.green; Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
                                    ColumnLayout { spacing: 3; Label { text: 'Только на вашем ПК'; font.pixelSize: 11; color: '#c6dfd5' } Label { text: 'Без отправки файлов'; font.pixelSize: 10; color: Theme.muted } }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: window.width < 1170 ? 18 : 24
                        spacing: 16
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Label { text: 'Этот компьютер'; color: Theme.muted; font.pixelSize: 12 }
                            Label { text: '/'; color: '#52657d'; font.pixelSize: 12 }
                            Label { text: backend.sourceName; color: '#c7d5e8'; font.pixelSize: 12; elide: Text.ElideMiddle; Layout.fillWidth: true; ToolTip.text: backend.source; ToolTip.visible: sourceHover.hovered; HoverHandler { id: sourceHover } }
                            ActionButton { text: 'Выбрать папку'; iconName: 'folder'; buttonHeight: 34; quiet: true; enabled: !backend.busy; onClicked: backend.chooseSource() }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: backend.sourceName === 'Загрузки' ? 'Разберём загрузки' : 'Разберём файлы'; font.pixelSize: window.width < 1170 ? 25 : 29; font.weight: Font.DemiBold }
                                Label { text: backend.busy ? 'Работаю с документами…' : backend.analyzed ? backend.count + ' файлов проверено · проверьте будущие папки' : backend.stage === 'done' ? 'Готово. Каждый перенос сохранён в истории.' : 'Сначала проверка. Затем — понятный план.'; color: Theme.muted; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                            ActionButton { text: backend.count > 0 ? 'Обновить' : 'Проверить'; iconName: 'refresh'; buttonHeight: 38; enabled: !backend.busy; onClicked: backend.scan() }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                radius: 7
                                color: '#151e2a'
                                border.color: searchField.activeFocus ? Theme.blue : Theme.line
                                Behavior on border.color { ColorAnimation { duration: Theme.motion } }
                                StrokeIcon { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; name: 'search'; width: 19; height: 19; ink: searchField.activeFocus ? '#6aaeff' : Theme.muted }
                                TextField {
                                    id: searchField
                                    anchors.fill: parent
                                    leftPadding: 40
                                    rightPadding: 12
                                    placeholderText: 'Поиск по файлам'
                                    placeholderTextColor: '#7f91aa'
                                    color: Theme.text
                                    selectionColor: '#2d619c'
                                    font.family: 'Segoe UI'
                                    font.pixelSize: 13
                                    background: Item {}
                                    onTextChanged: backend.search(text)
                                    Accessible.name: 'Поиск по файлам'
                                }
                            }
                            ComboBox {
                                id: typeFilter
                                Layout.preferredWidth: 127
                                Layout.preferredHeight: 40
                                model: ['Все типы', 'PDF', 'Word', 'Excel', 'PowerPoint', 'Текст', 'Нужна проверка']
                                font.family: 'Segoe UI'
                                font.pixelSize: 12
                                onActivated: backend.filterType(currentText)
                                background: Rectangle { radius: 7; color: '#151e2a'; border.color: typeFilter.activeFocus ? Theme.blue : Theme.line }
                                contentItem: Label { text: typeFilter.displayText; leftPadding: 12; rightPadding: 26; font.pixelSize: 12; elide: Text.ElideRight }
                                indicator: StrokeIcon { name: 'down'; x: parent.width - 24; y: 12; width: 16; height: 16 }
                                popup: Popup {
                                    y: typeFilter.height + 4
                                    width: Math.max(160, typeFilter.width)
                                    padding: 5
                                    background: Rectangle { color: '#1a2738'; radius: 8; border.color: '#3a4d65' }
                                    contentItem: ListView { implicitHeight: contentHeight; model: typeFilter.popup.visible ? typeFilter.delegateModel : null; clip: true; currentIndex: typeFilter.highlightedIndex }
                                }
                                delegate: ItemDelegate { required property string modelData; required property int index; width: typeFilter.popup.width - 10; height: 36; text: modelData; highlighted: typeFilter.highlightedIndex === index; contentItem: Label { text: modelData; font.pixelSize: 12; leftPadding: 7 } background: Rectangle { color: parent.highlighted || parent.hovered ? '#29476c' : 'transparent'; radius: 5 } }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 9
                            color: '#111923'
                            border.color: Theme.line
                            clip: true
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 1
                                spacing: 0
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    color: '#17212d'
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 15
                                        spacing: 14
                                        Button {
                                            padding: 0
                                            Layout.preferredWidth: 19
                                            Layout.preferredHeight: 19
                                            enabled: !backend.busy && backend.count > 0
                                            Accessible.name: 'Выбрать или снять все файлы'
                                            background: Rectangle { radius: 4; border.width: 1; border.color: '#657a95'; color: backend.selectedCount > 0 ? '#236bd2' : 'transparent' }
                                            contentItem: StrokeIcon { name: 'check'; visible: backend.selectedCount > 0; ink: '#ffffff' }
                                            onClicked: backend.toggleAll()
                                        }
                                        Label { text: 'Имя'; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true }
                                        Label { text: 'Тип'; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 82 }
                                        Label { text: 'Размер'; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 68; horizontalAlignment: Text.AlignRight }
                                    }
                                }
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    ListView {
                                        id: files
                                        objectName: 'fileList'
                                        anchors.fill: parent
                                        clip: true
                                        model: backend.files
                                        boundsBehavior: Flickable.StopAtBounds
                                        ScrollBar.vertical: ScrollBar { policy: files.contentHeight > files.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded }
                                        delegate: ItemDelegate {
                                            id: row
                                            required property int itemId
                                            required property string fileName
                                            required property string fileType
                                            required property string extension
                                            required property string fileSize
                                            required property color fileColor
                                            required property bool isChecked
                                            required property string fileStatus
                                            required property bool needsReview
                                            width: files.width
                                            height: 57
                                            hoverEnabled: true
                                            activeFocusOnTab: true
                                            onClicked: backend.select(itemId)
                                            onDoubleClicked: backend.revealSelected()
                                            Keys.onSpacePressed: backend.toggle(itemId)
                                            background: Rectangle {
                                                color: backend.selectedId === row.itemId ? '#1d324e' : row.hovered ? '#192638' : 'transparent'
                                                Behavior on color { ColorAnimation { duration: Theme.motion } }
                                                Rectangle { anchors.bottom: parent.bottom; height: 1; width: parent.width; color: '#1e2b3b' }
                                                Rectangle { anchors.left: parent.left; height: parent.height; width: 3; color: Theme.blue; opacity: backend.selectedId === row.itemId ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.motion } } }
                                            }
                                            contentItem: RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 16
                                                anchors.rightMargin: 15
                                                spacing: 14
                                                Button {
                                                    padding: 0
                                                    Layout.preferredWidth: 19
                                                    Layout.preferredHeight: 19
                                                    enabled: !backend.busy && row.fileStatus === 'Готов к переносу'
                                                    Accessible.name: 'Выбрать ' + row.fileName
                                                    background: Rectangle { radius: 4; border.width: 1; border.color: row.isChecked ? '#65acff' : parent.visualFocus ? '#bedaff' : '#667a92'; color: row.isChecked ? Theme.blue : 'transparent'; opacity: parent.enabled ? 1 : 0.5; Behavior on color { ColorAnimation { duration: Theme.motion } } }
                                                    contentItem: StrokeIcon { name: 'check'; ink: '#ffffff'; visible: row.isChecked }
                                                    onClicked: backend.toggle(row.itemId)
                                                }
                                                DocIcon { extension: row.extension; tint: row.fileColor; Layout.preferredWidth: 29; Layout.preferredHeight: 36 }
                                                Label { text: row.fileName; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideMiddle; color: row.fileStatus === 'Перемещён' ? '#8ebaa8' : Theme.text }
                                                Rectangle { visible: row.needsReview; width: 6; height: 6; radius: 3; color: Theme.amber; ToolTip.text: 'Проверьте раздел перед перемещением'; ToolTip.visible: reviewHover.hovered; HoverHandler { id: reviewHover } }
                                                Label { text: row.fileType; color: '#a7b8ce'; font.pixelSize: 12; Layout.preferredWidth: 82; elide: Text.ElideRight }
                                                Label { text: row.fileSize; color: '#c5d3e4'; font.pixelSize: 12; Layout.preferredWidth: 68; horizontalAlignment: Text.AlignRight }
                                            }
                                            ToolTip.text: row.fileName
                                            ToolTip.visible: hovered
                                            ToolTip.delay: 1000
                                        }
                                        add: Transition { NumberAnimation { property: 'opacity'; from: 0; to: 1; duration: Theme.motion } }
                                    }
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width - 44, 370)
                                        spacing: 14
                                        visible: backend.shownCount === 0
                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 62
                                            height: 62
                                            radius: 18
                                            color: '#192d48'
                                            StrokeIcon { anchors.centerIn: parent; width: 31; height: 31; name: backend.busy ? 'refresh' : backend.count > 0 ? 'search' : 'folder'; ink: '#69adff'; RotationAnimator on rotation { running: backend.busy && backend.animations; from: 0; to: 360; loops: Animation.Infinite; duration: 1400 } }
                                        }
                                        Label { text: backend.busy ? 'Проверяю документы' : backend.count > 0 ? 'Ничего не найдено' : backend.stage === 'empty' ? 'Подходящих файлов нет' : 'Начнём с проверки'; font.pixelSize: 20; font.weight: Font.DemiBold; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
                                        Label { text: backend.busy ? 'Ищу тип работы и признаки автора. Файлы остаются на месте.' : backend.count > 0 ? 'Попробуйте другой запрос или тип файла.' : backend.stage === 'empty' ? 'Выберите другую папку или включите проверку подпапок в настройках.' : 'YFL прочитает документы и покажет, куда предлагает их переместить.'; font.pixelSize: 13; color: Theme.muted; Layout.fillWidth: true; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; lineHeight: 1.35 }
                                        ActionButton { Layout.alignment: Qt.AlignHCenter; visible: !backend.busy && backend.count === 0; text: backend.stage === 'empty' ? 'Выбрать папку' : 'Проверить файлы'; primary: true; iconName: backend.stage === 'empty' ? 'folder' : 'search'; onClicked: backend.stage === 'empty' ? backend.chooseSource() : backend.scan() }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: backend.count > 0 ? 'Показано ' + backend.shownCount + ' из ' + backend.count : 'PDF, Word, Excel, PowerPoint и текст'; color: '#8298b4'; font.pixelSize: 11; Layout.fillWidth: true }
                            ActionButton { visible: backend.count > 0; text: 'Сохранить список'; iconName: 'export'; quiet: true; buttonHeight: 28; enabled: !backend.busy; onClicked: backend.exportList() }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: window.inspectorWidth
                        Layout.fillHeight: true
                        color: '#121b27'
                        Rectangle { height: parent.height; width: 1; color: Theme.line }
                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 22
                            contentWidth: availableWidth
                            clip: true
                            ColumnLayout {
                                width: parent.width
                                spacing: 17
                                Label { text: 'Куда переместится файл'; font.pixelSize: 18; font.weight: Font.DemiBold; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                Item { Layout.preferredHeight: 5 }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 14
                                    DocIcon { visible: window.hasDetail; extension: window.detail.extension || ''; tint: window.detail.fileColor || '#8fa6c4'; Layout.preferredWidth: 36; Layout.preferredHeight: 42 }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Label { text: window.hasDetail ? window.detail.fileName : 'Выберите файл'; font.pixelSize: 16; font.weight: Font.DemiBold; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideMiddle; Layout.fillWidth: true }
                                        Label { text: window.hasDetail ? window.detail.fileType + ' · ' + window.detail.fileSize : 'План появится после проверки'; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                    }
                                }
                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line; Layout.topMargin: 4; Layout.bottomMargin: 5 }
                                Label { text: 'Сейчас'; color: Theme.muted; font.pixelSize: 12 }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 11
                                    StrokeIcon { name: 'folder'; ink: '#a9b8ca'; Layout.preferredWidth: 25; Layout.preferredHeight: 25 }
                                    Label { text: window.hasDetail ? window.detail.sourceFolderLabel : backend.sourceName; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: '#c6d3e4'; ToolTip.text: window.hasDetail ? window.detail.sourceFolder : backend.source; ToolTip.visible: sourcePathHover.hovered; HoverHandler { id: sourcePathHover } }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 15
                                    Item {
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 42
                                        Rectangle { width: 1; height: parent.height; anchors.horizontalCenter: parent.horizontalCenter; color: '#39689b' }
                                        Rectangle { width: 6; height: 6; radius: 3; anchors.horizontalCenter: parent.horizontalCenter; y: 18; color: Theme.blue; SequentialAnimation on y { running: backend.busy && backend.animations; loops: Animation.Infinite; NumberAnimation { to: 34; duration: 850; easing.type: Easing.InOutQuad } NumberAnimation { to: 4; duration: 0 } } }
                                    }
                                    Label { text: window.hasDetail ? window.detail.fileStatus === 'Перемещён' ? 'Уже перемещён' : 'После сортировки' : 'Папка результата'; color: Theme.muted; font.pixelSize: 12 }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 11
                                    StrokeIcon { name: 'folder'; ink: '#58aaff'; Layout.preferredWidth: 25; Layout.preferredHeight: 25 }
                                    Label { text: window.hasDetail ? window.detail.destinationLabel : backend.output; font.pixelSize: 13; font.weight: Font.DemiBold; color: '#67afff'; wrapMode: Text.WordWrap; Layout.fillWidth: true; ToolTip.text: window.hasDetail ? window.detail.destination : backend.output; ToolTip.visible: destinationHover.hovered; HoverHandler { id: destinationHover } }
                                }
                                ActionButton { text: window.hasDetail ? 'Изменить папку' : 'Папка результата'; iconName: 'folder'; enabled: !backend.busy && (!window.hasDetail || window.detail.fileStatus === 'Готов к переносу'); onClicked: window.hasDetail ? backend.changeDestination() : backend.chooseOutput(); Layout.topMargin: 1 }
                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line; Layout.topMargin: 5; Layout.bottomMargin: 3 }
                                Label { text: 'Почему эта папка'; font.pixelSize: 13; font.weight: Font.DemiBold }
                                Label { text: window.hasDetail ? window.detail.reason : 'Тип работы и признаки автора будут определены по названию и тексту документа.'; color: window.hasDetail && window.detail.needsReview ? Theme.amber : '#c3d2e5'; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true; lineHeight: 1.35 }
                                Label { visible: window.hasDetail; text: window.detail.readStatus || ''; color: '#7e94b0'; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                ActionButton { visible: window.hasDetail && window.detail.fileStatus === 'Готов к переносу'; text: 'Изменить раздел'; iconName: 'rules'; quiet: true; enabled: !backend.busy; onClicked: categoryMenu.open() }
                                Menu {
                                    id: categoryMenu
                                    background: Rectangle { color: '#1b2b40'; border.color: '#3a526e'; radius: 8 }
                                    Repeater {
                                        model: ['Мои работы', 'Методички и задания', 'Работы других авторов', 'Требуют проверки']
                                        delegate: MenuItem { required property string modelData; text: modelData; contentItem: Label { text: modelData; font.pixelSize: 12 } background: Rectangle { color: parent.highlighted ? '#2b4c75' : 'transparent'; radius: 5 } onTriggered: backend.changeCategory(modelData) }
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: hint.implicitHeight + 26
                                    radius: 8
                                    color: '#172637'
                                    border.color: '#2c4059'
                                    RowLayout {
                                        id: hint
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 13
                                        spacing: 10
                                        StrokeIcon { name: 'info'; ink: '#69aeff'; Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
                                        Label { text: 'Проверьте папки перед сортировкой. Ненужные файлы можно снять с выбора.'; font.pixelSize: 11; color: '#a9bdd5'; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RulesPage { }
            HistoryPage { onRequestUndo: { confirm.action = 'undo'; confirm.open() } }
            SettingsPage { }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 79
            color: '#111a26'
            Rectangle { width: parent.width; height: 1; color: Theme.line }
            Rectangle {
                anchors.top: parent.top
                height: 2
                width: backend.busy ? parent.width * 0.27 : 0
                color: Theme.blue
                x: -width
                NumberAnimation on x { running: backend.busy && backend.animations; from: -window.width * 0.27; to: window.width; duration: 1600; loops: Animation.Infinite; easing.type: Easing.InOutQuad }
                visible: backend.busy
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 23
                anchors.rightMargin: 23
                spacing: 13
                ColumnLayout {
                    spacing: 5
                    Layout.fillWidth: true
                    RowLayout {
                        spacing: 10
                        Rectangle { width: 7; height: 7; radius: 4; color: backend.busy ? Theme.blue : backend.stage === 'done' ? Theme.green : '#5b789c' }
                        Label { text: backend.busy ? 'Обрабатываю файлы' : backend.stage === 'done' ? 'Файлы разложены' : backend.selectedCount > 0 ? 'Выбрано ' + backend.selectedCount + ' файлов · ' + backend.selectedSize : 'Всё под вашим контролем'; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Button { visible: backend.count > 0 && !backend.busy && window.page === 'files'; text: backend.selectedCount > 0 ? 'Снять выбор' : 'Выбрать все'; font.pixelSize: 11; contentItem: Label { text: parent.text; font.pixelSize: 11; color: '#69acff' } background: Item {} onClicked: backend.toggleAll() }
                    }
                    Label { text: backend.status; color: Theme.muted; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideMiddle }
                }
                ActionButton { visible: backend.busy; text: 'Остановить'; enabled: backend.busy; onClicked: backend.cancel() }
                ActionButton { visible: !backend.busy && window.page === 'files'; text: 'Настроить правила'; iconName: 'rules'; onClicked: window.navigate('settings') }
                ActionButton { visible: !backend.busy && window.page === 'files'; text: backend.analyzed ? 'Рассортировать' : backend.stage === 'done' ? 'Открыть результат' : 'Проверить файлы'; iconName: backend.analyzed ? 'arrow' : backend.stage === 'done' ? 'folder' : 'search'; primary: true; buttonHeight: 46; enabled: !backend.analyzed || backend.selectedCount > 0; onClicked: backend.analyzed ? window.confirmMove() : backend.stage === 'done' ? backend.openResult() : backend.scan() }
            }
        }
    }

    Rectangle {
        z: 10
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 22
        anchors.bottomMargin: 97
        width: Math.min(420, window.width - 50)
        implicitHeight: toastBody.implicitHeight + 30
        radius: 10
        color: '#20344e'
        border.color: '#4a77a8'
        opacity: window.noticeVisible ? 1 : 0
        visible: opacity > 0
        transform: Translate { y: window.noticeVisible ? 0 : 10; Behavior on y { NumberAnimation { duration: Theme.motion; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: Theme.motion } }
        ColumnLayout {
            id: toastBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 15
            spacing: 6
            RowLayout { Layout.fillWidth: true; Label { text: window.noticeTitle; font.weight: Font.DemiBold; Layout.fillWidth: true } Button { width: 20; height: 20; background: Item {} contentItem: StrokeIcon { name: 'close'; width: 16; height: 16 } Accessible.name: 'Закрыть уведомление'; onClicked: window.noticeVisible = false } }
            Label { text: window.noticeText; color: '#b9cce3'; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        }
    }

    Popup {
        id: confirm
        property string action: 'move'
        anchors.centerIn: parent
        width: Math.min(490, window.width - 60)
        padding: 27
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        Overlay.modal: Rectangle { color: '#b3060c15' }
        background: Rectangle { color: '#192639'; radius: 14; border.color: '#425c7c' }
        enter: Transition { NumberAnimation { property: 'opacity'; from: 0; to: 1; duration: Theme.motion } }
        exit: Transition { NumberAnimation { property: 'opacity'; from: 1; to: 0; duration: Theme.motion } }
        contentItem: ColumnLayout {
            spacing: 17
            StrokeIcon { name: confirm.action === 'move' ? 'folder' : 'undo'; ink: '#75b3ff'; width: 30; height: 30; Layout.preferredWidth: 30; Layout.preferredHeight: 30 }
            Label { text: confirm.action === 'move' ? 'Переместить выбранные файлы?' : 'Вернуть последний перенос?'; font.pixelSize: 21; font.weight: Font.DemiBold; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            Label { text: confirm.action === 'move' ? 'Выбрано ' + backend.selectedCount + ' файлов (' + backend.selectedSize + '). Имена сохранятся, а каждый перенос попадёт в историю. При необходимости файлы можно вернуть.' : 'Файлы последнего запуска вернутся по прежним путям. Изменённые файлы и занятые имена будут пропущены.'; color: '#b3c5dc'; wrapMode: Text.WordWrap; Layout.fillWidth: true; lineHeight: 1.4 }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 7
                Item { Layout.fillWidth: true }
                ActionButton { text: 'Отмена'; onClicked: confirm.close() }
                ActionButton { text: confirm.action === 'move' ? 'Переместить' : 'Вернуть файлы'; primary: true; onClicked: { confirm.close(); confirm.action === 'move' ? backend.apply() : backend.undo() } }
            }
        }
    }

    MouseArea { width: 5; anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; enabled: window.visibility !== Window.Maximized; cursorShape: Qt.SizeHorCursor; onPressed: window.startSystemResize(Qt.LeftEdge) }
    MouseArea { width: 5; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; enabled: window.visibility !== Window.Maximized; cursorShape: Qt.SizeHorCursor; onPressed: window.startSystemResize(Qt.RightEdge) }
    MouseArea { height: 5; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; enabled: window.visibility !== Window.Maximized; cursorShape: Qt.SizeVerCursor; onPressed: window.startSystemResize(Qt.BottomEdge) }
    MouseArea { height: 5; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; enabled: window.visibility !== Window.Maximized; cursorShape: Qt.SizeVerCursor; onPressed: window.startSystemResize(Qt.TopEdge) }
}
