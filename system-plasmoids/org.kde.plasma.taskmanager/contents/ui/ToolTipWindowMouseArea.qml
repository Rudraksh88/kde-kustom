// /*
//     SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
//     SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
//     SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>

//     SPDX-License-Identifier: LGPL-2.0-or-later
// */

// pragma ComponentBehavior: Bound

// import QtQuick

// MouseArea {
//     required property /*QModelIndex*/var modelIndex
//     required property /*undefined|WId where WId = int|string*/ var winId
//     required property Task rootTask

//     acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
//     hoverEnabled: true
//     enabled: winId !== undefined


//     onClicked: (mouse) => {
//         switch (mouse.button) {
//         case Qt.LeftButton:
//             tasksModel.requestActivate(modelIndex);
//             rootTask.hideImmediately();
//             backend.cancelHighlightWindows();
//             break;
//         case Qt.MiddleButton:
//             backend.cancelHighlightWindows();
//             tasksModel.requestClose(modelIndex);
//             break;
//         case Qt.RightButton:
//             tasks.createContextMenu(rootTask, modelIndex).show();
//             break;
//         }
//     }

//     // onContainsMouseChanged: {
//     //     tasks.windowsHovered([winId], containsMouse);
//     // }

//     // Cancel highlight when hovering the icon in the panel and not the thumbnail preview
//     // onEntered: backend.cancelHighlightWindows()
//     // onEntered: backend.cancelHighlightWindows()

//     onEntered: {
//         // Only trigger window preview if we're not hovering the task icon
//         if (winId !== undefined && !rootTask.containsMouse) {
//             backend.windowsHovered([winId], true);
//         } else {
//             backend.cancelHighlightWindows();
//         }
//     }

//     onExited: {
//         backend.cancelHighlightWindows();
//     }

//     Rectangle {
//         id: debugRectangle
//         color: "green"
//         anchors.fill: parent
//         opacity: 0.5

//         // Visible on hover
//         visible: containsMouse
//     }
// }

pragma ComponentBehavior: Bound

import QtQuick

MouseArea {
    id: mouseArea
    required property /*QModelIndex*/var modelIndex
    required property /*undefined|WId where WId = int|string*/ var winId
    required property Task rootTask

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    hoverEnabled: true
    enabled: winId !== undefined

    property bool actuallyContainsMouse: false
    property point initialMousePos: Qt.point(0, 0)
    property bool hasMouseMoved: false

    Timer {
        id: hoverTimer
        interval: 50
        onTriggered: {
            if (mouseArea.containsMouse) {
                actuallyContainsMouse = true;
                // Only show window preview if mouse has moved since tooltip appeared
                if (hasMouseMoved && winId !== undefined && !rootTask.containsMouse) {
                    backend.windowsHovered([winId], true);
                }
            }
        }
    }

    Component.onCompleted: {
        // Capture initial mouse position when tooltip appears
        initialMousePos = Qt.point(mouseX, mouseY)
    }

    onPositionChanged: {
        // Check if mouse has moved more than a few pixels from initial position
        let dx = mouseX - initialMousePos.x
        let dy = mouseY - initialMousePos.y
        if (Math.abs(dx) > 2 || Math.abs(dy) > 2) {
            hasMouseMoved = true
        }
        if (containsMouse && hasMouseMoved) {
            hoverTimer.restart()
        }
    }

    onExited: {
        actuallyContainsMouse = false
        hasMouseMoved = false
        backend.cancelHighlightWindows()
        hoverTimer.stop()
    }

    onClicked: (mouse) => {
        switch (mouse.button) {
        case Qt.LeftButton:
            tasksModel.requestActivate(modelIndex);
            rootTask.hideImmediately();
            backend.cancelHighlightWindows();
            break;
        case Qt.MiddleButton:
            backend.cancelHighlightWindows();
            tasksModel.requestClose(modelIndex);
            break;
        case Qt.RightButton:
            tasks.createContextMenu(rootTask, modelIndex).show();
            break;
        }
    }

    // Rectangle {
    //     id: debugRectangle
    //     color: "green"
    //     anchors.fill: parent
    //     opacity: 0.5
    //     visible: parent.actuallyContainsMouse && parent.hasMouseMoved
    // }
}