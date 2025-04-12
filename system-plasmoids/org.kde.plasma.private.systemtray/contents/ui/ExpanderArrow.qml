/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmaCore.ToolTipArea {
    id: tooltip

    readonly property int arrowAnimationDuration: Kirigami.Units.shortDuration
    property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    property int iconSize: Kirigami.Units.iconSizes.smallMedium
    implicitWidth: iconSize
    implicitHeight: iconSize
    activeFocusOnTab: true

    Accessible.name: subText
    Accessible.description: i18n("Show all the items in the system tray in a popup")
    Accessible.role: Accessible.Button
    Accessible.onPressAction: systemTrayState.expanded = !systemTrayState.expanded

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_Enter:
        case Qt.Key_Return:
        case Qt.Key_Select:
            systemTrayState.expanded = !systemTrayState.expanded;
        }
    }

    subText: systemTrayState.expanded ? i18n("Close popup") : i18n("Show hidden icons")

    property bool wasExpanded

    TapHandler {
        onPressedChanged: {
            if (pressed) {
                tooltip.wasExpanded = systemTrayState.expanded;
            }
        }
        onTapped: (eventPoint, button) => {
            systemTrayState.expanded = !tooltip.wasExpanded;
            expandedRepresentation.hiddenLayout.currentIndex = -1;
        }
    }

    // Mouse Area for icon hover animations
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: false
        acceptedButtons: Qt.NoButton  // This makes it not capture clicks
    }

    Kirigami.Icon {
        anchors.fill: parent

        // Rotate based on expanded state
        rotation: {
            if (systemTrayState.expanded) {
                if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
                    return 180;
                } else if (Plasmoid.location === PlasmaCore.Types.LeftEdge) {
                    return 180;
                } else if (Plasmoid.location === PlasmaCore.Types.RightEdge) {
                    return 180;
                } else {
                    return 180;
                }
            } else {
                return 0;
            }

            // Rotate about the bottom center
            transformOrigin: Item.Bottom
        }

        Behavior on rotation {
            RotationAnimation {
                duration: tooltip.arrowAnimationDuration
            }
        }

        // Opacity based on expanded state and hover
        opacity: mouseArea.containsMouse ? 1 : 0.77

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }

        // Source based on panel location
        source: {
            if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
                return "arrow-down";
            } else if (Plasmoid.location === PlasmaCore.Types.LeftEdge) {
                return "arrow-right";
            } else if (Plasmoid.location === PlasmaCore.Types.RightEdge) {
                return "arrow-left";
            } else {
                return "arrow-up-tray";
            }
        }
    }
}