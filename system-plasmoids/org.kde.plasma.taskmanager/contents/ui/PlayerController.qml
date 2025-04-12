/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2017 Roman Gilg <subdiff@gmail.com>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

RowLayout {
    enabled: toolTipDelegate.playerData.canControl

    readonly property bool isPlaying: toolTipDelegate.playerData.playbackStatus === Mpris.PlaybackStatus.Playing

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2 //Kirigami.Units.smallSpacing
        Layout.bottomMargin: isWin ? 6 : 5 //Kirigami.Units.smallSpacing
        Layout.leftMargin: isWin ? 2 : 4
        Layout.rightMargin: isWin ? Kirigami.Units.smallSpacing : Kirigami.Units.gridUnit
        spacing: 0

        ScrollableTextWrapper {
            id: songTextWrapper

            Layout.fillWidth: true
            Layout.preferredHeight: songText.height
            implicitWidth: songText.implicitWidth

            textItem: PlasmaComponents3.Label {
                id: songText
                maximumLineCount: artistText.visible ? 1 : 2
                wrapMode: Text.NoWrap
                elide: parent.state ? Text.ElideNone : Text.ElideRight
                text: toolTipDelegate.playerData.track
                textFormat: Text.PlainText
                color: "white"
                opacity: 0.35
                font: Qt.font({
                    // => weight: Font.Bold,
                    // => letterSpacing: 0.3
                    weight: 800,
                    letterSpacing: 0.32,
                    features: { 'cpsp' : 1 },
                })
            }

            // Add brightness effect
            layer.enabled: true
            layer.effect: MultiEffect {
                brightness: 0.88 // 0.8 // This will make the text brighter (while preserving opacity)
                contrast: 0.1 //0.07 // This will make the text more opaque
                saturation: 1.0 // 1.0 // This causes artifacts
            }
        }

        ScrollableTextWrapper {
            id: artistTextWrapper

            Layout.fillWidth: true
            Layout.preferredHeight: artistText.height
            implicitWidth: artistText.implicitWidth
            visible: artistText.text.length > 0

            textItem: PlasmaExtras.DescriptiveLabel {
                id: artistText
                wrapMode: Text.NoWrap
                elide: parent.state ? Text.ElideNone : Text.ElideRight
                text: toolTipDelegate.playerData.artist
                // font: Kirigami.Theme.smallFont
                textFormat: Text.PlainText
                color: "#08FFFFFF"
                opacity: 1.0 // => 0.4
                font: Qt.font({
                    // letterSpacing: 0.2,
                    // => weight: 500
                    weight: 630,
                    features: { 'cpsp' : 1 }
                })
                layer.enabled: true
                layer.effect: MultiEffect {
                    brightness: 8.8
                    contrast: 5.8
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignRight
        spacing: 0

        PlasmaComponents3.ToolButton {
            enabled: toolTipDelegate.playerData.canGoPrevious
            icon.name: mirrored ? "go-previous-symbolic-rtl" : "arrow-left"
            onClicked: toolTipDelegate.playerData.Previous()

            // Icon size
            icon.width: Kirigami.Units.iconSizes.small
            icon.height: Kirigami.Units.iconSizes.small
        }

        PlasmaComponents3.ToolButton {
            enabled: isPlaying ? toolTipDelegate.playerData.canPause : toolTipDelegate.playerData.canPlay
            icon.name: isPlaying ? "currenttrack_pause" : "media-playback-start-symbolic"
            onClicked: {
                if (!isPlaying) {
                    toolTipDelegate.playerData.Play();
                } else {
                    toolTipDelegate.playerData.Pause();
                }
            }
            icon.width: Kirigami.Units.iconSizes.small
            icon.height: Kirigami.Units.iconSizes.small
        }

        PlasmaComponents3.ToolButton {
            enabled: toolTipDelegate.playerData.canGoNext
            icon.name: mirrored ? "go-previous-symbolic" : "arrow-right"
            onClicked: toolTipDelegate.playerData.Next()
            // icon.width: Kirigami.Units.iconSizes.small
            icon.width: Kirigami.Units.iconSizes.small
            icon.height: Kirigami.Units.iconSizes.small
        }
    }
}
