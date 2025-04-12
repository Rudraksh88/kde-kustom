/*
    SPDX-FileCopyrightText: 2016 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

// This component is for app icons (Telegram, Flameshot, etc)

AbstractItem {
    id: taskIcon

    itemId: model.Id
    text: model.Title || model.ToolTipTitle
    mainText: model.ToolTipTitle !== "" ? model.ToolTipTitle : model.Title
    subText: model.ToolTipSubTitle
    textFormat: Text.AutoText

    opacity: taskIcon.containsMouse && !taskIcon.inHiddenLayout ? 0.5 : 0.45


    Kirigami.Icon {
        id: iconItem
        parent: taskIcon.iconContainer
        anchors.fill: iconItem.parent

        source: {
            if (model.status === PlasmaCore.Types.NeedsAttentionStatus) {
                if (model.AttentionIcon) {
                    return model.AttentionIcon
                }
                if (model.AttentionIconName) {
                    return model.AttentionIconName
                }
            }
            return model.Icon || model.IconName
        }
        // active: taskIcon.containsMouse && !taskIcon.inHiddenLayout

        opacity: taskIcon.containsMouse && !taskIcon.inHiddenLayout ? 1.0 : 0.7
        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            onClicked: taskIcon.onClicked(mouse)
            onWheel: taskIcon.onWheel(wheel)
            onEntered: taskIcon.containsMouse = true
            onExited: taskIcon.containsMouse = false
        }
    }

    onActivated: pos => {
        const service = model.Service;
        const operation = service.operationDescription("Activate");
        operation.x = pos.x; //mouseX
        operation.y = pos.y; //mouseY
        const job = service.startOperationCall(operation);
        job.finished.connect(() => {
            if (!job.result) {
                // On error try to invoke the context menu.
                // Workaround primarily for apps using libappindicator.
                openContextMenu(pos);
            }
        })
    }

    onContextMenu: mouse => {
        if (mouse === null) {
            openContextMenu(Plasmoid.popupPosition(taskIcon, taskIcon.width / 2, taskIcon.height / 2));
        } else {
            openContextMenu(Plasmoid.popupPosition(taskIcon, mouse.x, mouse.y));
        }
    }

    onClicked: mouse => {
        const pos = Plasmoid.popupPosition(taskIcon, mouse.x, mouse.y);

        switch (mouse.button) {
        case Qt.LeftButton:
            taskIcon.activated(pos)
            break;
        case Qt.RightButton:
            openContextMenu(pos);
            break;
        case Qt.MiddleButton:
            const service = model.Service;
            const operation = service.operationDescription("SecondaryActivate");
            operation.x = pos.x;
            operation.y = pos.y;
            service.startOperationCall(operation);
            break;
        }
    }

    function openContextMenu(pos = Qt.point(width/2, height/2)) {
        const service = model.Service;
        const operation = service.operationDescription("ContextMenu");
        operation.x = pos.x;
        operation.y = pos.y;

        const job = service.startOperationCall(operation);
        job.finished.connect(() => {
            Plasmoid.showStatusNotifierContextMenu(job, taskIcon);
        });
    }

    onWheel: wheel => {
        //don't send activateVertScroll with a delta of 0, some clients seem to break (kmix)
        if (wheel.angleDelta.y !== 0) {
            const service = model.Service;
            const operation = service.operationDescription("Scroll");
            operation.delta = wheel.angleDelta.y;
            operation.direction = "Vertical";
            service.startOperationCall(operation);
        }
        if (wheel.angleDelta.x !== 0) {
            const service = model.Service;
            const operation = service.operationDescription("Scroll");
            operation.delta = wheel.angleDelta.x;
            operation.direction = "Horizontal";
            service.startOperationCall(operation);
        }
    }
}
