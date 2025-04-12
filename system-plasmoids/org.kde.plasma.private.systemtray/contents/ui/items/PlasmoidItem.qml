/*
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2022 ivan tkachenko <me@ratijas.tk>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid

AbstractItem {
    id: plasmoidContainer

    property Item applet: model.applet ?? null
    text: applet?.plasmoid.title ?? ""

    itemId: applet?.plasmoid.pluginName ?? ""
    mainText: applet?.toolTipMainText ?? ""
    subText: applet?.toolTipSubText ?? ""
    mainItem: applet?.toolTipItem ?? null
    textFormat: applet?.toolTipTextFormat ?? 0 /* Text.AutoText, the default value */
    active: systemTrayState.activeApplet !== applet

    // FIXME: Use an input type agnostic way to activate whatever the primary
    // action of a plasmoid is supposed to be, even if it's just expanding the
    // Plasmoid. Not all plasmoids are supposed to expand and not all plasmoids
    // do anything with onActivated.
    onActivated: pos => {
        if (applet) {
            applet.plasmoid.activated()
        }
    }

    // opacity: containsMouse || plasmoidContainer.applet?.expanded ? 1 : 0.75

    // Full opacity for hidden (items in the hidden layout)
    // Else, when hovered over icon in tray or expanded, show full opacity
    /* Conditions:
     * (containsMouse && !plasmoidContainer.inHiddenLayout) => when hovered over icon in tray
     * plasmoidContainer.applet?.expanded                   => when the full representation is visible
     * plasmoidContainer.inHiddenLayout                     => when the item is in the hidden layout
    */
    opacity: (containsMouse && !plasmoidContainer.inHiddenLayout) || plasmoidContainer.applet?.expanded || plasmoidContainer.inHiddenLayout ? 0.45 : 0.3// 0.75

    Rectangle {
        id: hoverBackground
        color: '#FFFFFF' // 3% alpha white // or dominantColor if specified in the config
        radius: 3
        anchors.fill: parent
        z: -1
        // anchors.topMargin: -2.3
        // anchors.bottomMargin: -2.3

        // Add negative margins to make the background slightly larger than the content (instead of using padding)
        // Use this as some percentage of the widget's height (so that it scales with the widget)
        anchors.topMargin: -2.5
        anchors.bottomMargin: -2.5
        anchors.leftMargin: -5
        anchors.rightMargin: -5

        // Only when the full representation is visible
        opacity: plasmoidContainer.applet?.expanded ? 0.1 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            brightness: 0.8
            contrast: 1.0
            saturation: 1.0
        }

        /* Note
            * The color and fx values here are chosen out of experimentation with various combinations
            * And these values blend the background color nicely (taking a hint of the color while still being white),
            * with the surface underneath, without being very intrusive.

            * color: '#08FFFFFF' alpha based white (just for a subtle white overlay)
            * fx: brightness: 0.8, contrast: 1.6, saturation: 1.0 lower values for performance
            * opacity: 1.0 (hovered) so that it doesn't affect the fx values
        */
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 200
        }
    }

    onClicked: mouse => {
        if (!applet) {
            return
        }
        //forward click event to the applet
        const appletItem = applet.compactRepresentationItem ?? applet.fullRepresentationItem
        const mouseArea = findMouseArea(appletItem)

        if (mouseArea && mouse.button !== Qt.RightButton) {
            mouseArea.clicked(mouse)
        } else if (mouse.button === Qt.LeftButton) {//falback
            activated(null)
        }
    }
    onPressed: mouse => {
        // Only Plasmoids can show context menu on the mouse pressed event.
        // SNI has few problems, for example legacy applications that still use XEmbed require mouse to be released.
        if (mouse.button === Qt.RightButton) {
            contextMenu(mouse);
        } else {
            const appletItem = applet.compactRepresentationItem ?? applet.fullRepresentationItem
            const mouseArea = findMouseArea(appletItem)
            if (mouseArea) {
                // The correct way here would be to invoke the "pressed"
                // signal; however, mouseArea.pressed signal is overridden
                // by its bool value, and our only option is to call the
                // handler directly.
                mouseArea.onPressed(mouse)
            }
        }
    }
    onContextMenu: mouse => {
        if (applet) {
            effectivePressed = false;
            Plasmoid.showPlasmoidMenu(applet, 0, inHiddenLayout ? applet.height : 0);
        }
    }
    onWheel: wheel => {
        if (!applet) {
            return
        }
        //forward wheel event to the applet
        const appletItem = applet.compactRepresentationItem ?? applet.fullRepresentationItem
        const mouseArea = findMouseArea(appletItem)
        if (mouseArea) {
            mouseArea.wheel(wheel)
        }
    }

    function __isSuitableMouseArea(child: Item): bool {
        const item = child.parent;
        return child instanceof MouseArea
            && child.enabled
            // check if MouseArea covers the entire item
            && (child.anchors.fill === item
                || (child.x === 0
                    && child.y === 0
                    && child.width === item.width
                    && child.height === item.height));
    }

    //some heuristics to find MouseArea
    function findMouseArea(item: Item): MouseArea {
        if (!item) {
            return null
        }

        if (item instanceof MouseArea) {
            return item
        }

        return item.children.find(__isSuitableMouseArea) ?? null;
    }

    //This is to make preloading effective, minimizes the scene changes
    function preloadFullRepresentationItem(fullRepresentationItem) {
        if (fullRepresentationItem && fullRepresentationItem.parent === null) {
            fullRepresentationItem.width = expandedRepresentation.width
            fullRepresentationItem.height = expandedRepresentation.height
            fullRepresentationItem.parent = preloadedStorage;
        }
    }

    onAppletChanged: {
        if (applet) {
            applet.parent = iconContainer
            applet.anchors.fill = applet.parent
            applet.visible = true

            preloadFullRepresentationItem(applet.fullRepresentationItem)
        }
    }

    Connections {
        enabled: plasmoidContainer.applet !== null
        target: findMouseArea(
            plasmoidContainer.applet?.compactRepresentationItem ??
            plasmoidContainer.applet?.fullRepresentationItem ??
            plasmoidContainer.applet
        )

        function onContainsPressChanged() {
            plasmoidContainer.effectivePressed = target.containsPress;
        }

        // TODO For touch/stylus only, since the feature is not desired for mouse users
        function onPressAndHold(mouse) {
            if (mouse.button === Qt.LeftButton) {
                plasmoidContainer.contextMenu(mouse)
            }
        }
    }

    Connections {
        target: plasmoidContainer.applet?.plasmoid ?? null

        //activation using global keyboard shortcut
        function onActivated() {
            plasmoidContainer.effectivePressed = true;
            Qt.callLater(() => {
                plasmoidContainer.effectivePressed = false;
            });
        }
    }

    Connections {
        target: plasmoidContainer.applet

        function onFullRepresentationItemChanged(fullRepresentationItem) {
            preloadFullRepresentationItem(fullRepresentationItem)
        }

        function onExpandedChanged(expanded) {
            if (expanded) {
                effectivePressed = false;
            }
        }
    }

    PlasmaComponents3.BusyIndicator {
        anchors.fill: parent
        z: 999
        running: plasmoidContainer.applet?.plasmoid.busy ?? false
    }

    Binding {
        property: "hideOnWindowDeactivate"
        value: !Plasmoid.configuration.pin
        target: plasmoidContainer.applet
        when: plasmoidContainer.applet !== null
        restoreMode: Binding.RestoreBinding
    }
}
