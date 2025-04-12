/*
    SPDX-FileCopyrightText: 2018 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// This top-level item is an opaque background that goes behind the colored
// background, for contrast. It's not an Item since that it would be square,
// and not round, as required here
Rectangle {
    id: badgeRect

    property alias text: label.text
    property alias textColor: label.color
    property int number: 0
    property bool previewed: false

    implicitWidth: Math.max(height, Math.round(label.contentWidth + (previewed ? 8 : 4) + radius / 2)) // Add some padding around.

    radius: height / 2

    // color: Kirigami.Theme.backgroundColor
    color: "transparent"

    // Colored background
    Rectangle {
        anchors.fill: parent
        radius: height / 2

        // color: Qt.alpha(Kirigami.Theme.highlightColor, 0.3)
        color: previewed ? Qt.alpha('white', 0.08) : '#000000'
        // border.color: Kirigami.Theme.highlightColor
        // border.width: 1

        layer.enabled: previewed ? true : false
        layer.effect: MultiEffect {
            brightness: 0.8
            contrast: 0.08
            saturation: 1.2
        }
    }

    // Number
    PlasmaComponents3.Label {
        id: label
        anchors.centerIn: parent
        width: height
        height: Math.min(Kirigami.Units.gridUnit * 2, Math.round(parent.height))
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        fontSizeMode: Text.VerticalFit
        color: 'white'
        opacity: 0.8
        font: Qt.font({
            family: 'Helvetica Now Text',
            // letterSpacing: 1,
            weight: 800,
            pixelSize: previewed ? Math.min(1024, Math.round(parent.height * 0.568)) : Math.round(parent.height * 0.6),
            // features: { 'tnum': 1, 'ss01': 0 }
        })
        // font.pointSize: 1024
        // font.pixelSize: 1024
        // minimumPointSize: 5

        // Keep the text short, so it doesn't overflow the badge
        // font.pixelSize: Math.min(1024, Math.round(parent.height * 0.6))

        // text: {
        //     if (badgeRect.number < 0) {
        //         return i18nc("Invalid number of new messages, overlay, keep short", "—");
        //     } else if (badgeRect.number > 9999) {
        //         // return i18nc("Over 9999 new messages, overlay, keep short", "9K+");
        //         return "9K+";
        //     } else {
        //         return badgeRect.number.toLocaleString(Qt.locale(), 'f', 0);
        //     }
        // }
        text: {
            if (number < 0) {
                return i18nc("Invalid number of new messages, overlay, keep short", "—");
            } else if (number > 9999) {
                // return i18nc("Over 9999 new messages, overlay, keep short", "9K+");
                return "9K+";
            } else {
                // return number.toLocaleString(Qt.locale(), 'f', 0);
                number > 1000 ? (number / 1000).toFixed(0) + 'K+' : number
            }
        }
        textFormat: Text.PlainText
    }
}
