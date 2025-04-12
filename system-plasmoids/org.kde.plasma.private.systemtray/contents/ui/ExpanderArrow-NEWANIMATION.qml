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

    // Helper function to determine the correct icon based on panel location
    function getIconForState(isCollapsed) {
        if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
            return isCollapsed ? "arrow-down" : "arrow-up";
        } else if (Plasmoid.location === PlasmaCore.Types.LeftEdge) {
            return isCollapsed ? "arrow-right" : "arrow-left";
        } else if (Plasmoid.location === PlasmaCore.Types.RightEdge) {
            return isCollapsed ? "arrow-left" : "arrow-right";
        } else {
            return isCollapsed ? "arrow-up" : "arrow-down";
        }
    }

    // Helper function to determine translation direction
    function getTranslationDirection() {
        if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
            return Qt.point(0, -1); // translate up
        } else if (Plasmoid.location === PlasmaCore.Types.LeftEdge) {
            return Qt.point(-1, 0); // translate left
        } else if (Plasmoid.location === PlasmaCore.Types.RightEdge) {
            return Qt.point(1, 0); // translate right
        } else {
            return Qt.point(0, 1); // translate down
        }
    }

    // Collapsed state icon (visible when not expanded)
    Kirigami.Icon {
        id: collapsedIcon
        anchors.fill: parent

        readonly property point translationDirection: getTranslationDirection()
        readonly property real translationDistance: parent.height / 2

        // Opacity based on expanded state and hover
        opacity: systemTrayState.expanded ? 0 : mouseArea.containsMouse ? 1 : 0.7

        // Translation animation
        transform: Translate {
            x: systemTrayState.expanded ? collapsedIcon.translationDirection.x * collapsedIcon.translationDistance : 0
            y: systemTrayState.expanded ? collapsedIcon.translationDirection.y * collapsedIcon.translationDistance : 0

            Behavior on x {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutBounce
                    easing.amplitude: 0.5
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutBounce
                    easing.amplitude: 0.5
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }

        source: getIconForState(true)
    }

    // Expanded state icon (visible when expanded)
    Kirigami.Icon {
        id: expandedIcon
        anchors.fill: parent

        readonly property point translationDirection: getTranslationDirection()
        readonly property real translationDistance: parent.height / 2

        // Start from translated position when not visible
        transform: Translate {
            x: systemTrayState.expanded ? 0 : -expandedIcon.translationDirection.x * expandedIcon.translationDistance
            y: systemTrayState.expanded ? 0 : -expandedIcon.translationDirection.y * expandedIcon.translationDistance

            Behavior on x {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutBounce
                    easing.amplitude: 0.5
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutBounce
                    easing.amplitude: 0.5
                }
            }
        }

        opacity: systemTrayState.expanded ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }

        source: getIconForState(false)
    }
}