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
import Qt5Compat.GraphicalEffects as GE

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kwindowsystem

ColumnLayout {
    id: root

    required property int index
    required property /*QModelIndex*/ var submodelIndex
    required property int appPid
    required property string display
    required property bool isMinimized
    required property bool isOnAllVirtualDesktops
    required property /*list<var>*/ var virtualDesktops // Can't use list<var> because of QTBUG-127600
    required property list<string> activities

    // HACK: Avoid blank space in the tooltip after closing a window
    ListView.onPooled: width = height = 0
    ListView.onReused: width = height = undefined

    readonly property string title: {
        if (!toolTipDelegate.isWin) {
            return toolTipDelegate.genericName;
        }

        let text = display;
        if (toolTipDelegate.isGroup && text === "") {
            return "";
        }

        // Normally the window title will always have " — [app name]" at the end of
        // the window-provided title. But if it doesn't, this is intentional 100%
        // of the time because the developer or user has deliberately removed that
        // part, so just display it with no more fancy processing.
        if (!text.match(/\s+(—|-|–)/)) {
            return text;
        }

        // KWin appends increasing integers in between pointy brackets to otherwise equal window titles.
        // In this case save <#number> as counter and delete it at the end of text.
        text = `${(text.match(/.*(?=\s+(—|-|–))/) || [""])[0]}${(text.match(/<\d+>/) || [""]).pop()}`;

        // In case the window title had only redundant information (i.e. appName), text is now empty.
        // Add a hyphen to indicate that and avoid empty space.
        if (text === "") {
            text = "—";
        }

        // Remove any app name descriptions like Web Browser, File Manager, etc.
        text = text.replace(new RegExp(`\\s+(${toolTipDelegate.appName}|${toolTipDelegate.genericName})$`), "");

        return text;
    }

    readonly property bool titleIncludesTrack: toolTipDelegate.playerData !== null && title.includes(toolTipDelegate.playerData.track)

    spacing: Kirigami.Units.smallSpacing

    // text labels + close button
    RowLayout {
        id: header
        // match spacing of DefaultToolTip.qml in plasma-framework
        spacing: toolTipDelegate.isWin ? Kirigami.Units.smallSpacing : Kirigami.Units.gridUnit

        // This number controls the overall size of the window tooltips
        Layout.maximumWidth: toolTipDelegate.tooltipInstanceMaximumWidth
        Layout.minimumWidth: toolTipDelegate.isWin ? Layout.maximumWidth : 0
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        // match margins of DefaultToolTip.qml in plasma-framework
        Layout.margins: toolTipDelegate.isWin ? 0 : Kirigami.Units.gridUnit / 2

        // all textlabels
        ColumnLayout {
            spacing: 0
            // app name
            // Kirigami.Heading {
            //     id: appNameHeading
            //     level: 3
            //     maximumLineCount: 1
            //     lineHeight: toolTipDelegate.isWin ? 1 : appNameHeading.lineHeight
            //     Layout.fillWidth: true
            //     elide: Text.ElideRight
            //     text: toolTipDelegate.appName
            //     opacity: root.index === 0 ? 1 : 0
            //     visible: text.length !== 0
            //     textFormat: Text.PlainText
            // }

            PlasmaComponents3.Label {
                id: appNameHeading
                // level: 3
                maximumLineCount: 1
                lineHeight: toolTipDelegate.isWin ? 1 : 1//appNameHeading.lineHeight
                Layout.fillWidth: true
                Layout.topMargin: toolTipDelegate.isWin ? 6 : playerController.visible ? -4.5 : -5.5 // Player controller for minimized no window task
                Layout.bottomMargin: toolTipDelegate.isWin && !winTitle.visible ? 6 : winTitle.visible ? 0 : -7
                Layout.leftMargin: toolTipDelegate.isWin ? 1 : -4
                Layout.rightMargin: toolTipDelegate.isWin ? 1 : -4
                elide: Text.ElideRight
                text: toolTipDelegate.appName
                opacity: root.index === 0 ? 0.35 : 0
                color: "white"
                visible: text.length !== 0
                textFormat: Text.PlainText
                font: Qt.font({
                    weight: 800,
                    letterSpacing: 0.32, // => 0.3
                    features: { 'cpsp' : 1 },
                    hintingPreference: Font.PreferNoHinting
                })

                // Add brightness effect
                layer.enabled: true
                layer.effect: MultiEffect {
                    brightness: 0.88 // 0.8 // This will make the text brighter (while preserving opacity)
                    contrast: 0.1 //0.07 // This will make the text more opaque
                    saturation: 1.0 // 1.0 // This causes artifacts
                }
            }

            // window title
            PlasmaComponents3.Label {
                id: winTitle
                maximumLineCount: 1
                Layout.fillWidth: true
                Layout.bottomMargin: visible && toolTipDelegate.isWin ? 4 : -6
                Layout.topMargin: visible && thumbnailSourceItem.visible ? 0 : 4
                Layout.leftMargin: toolTipDelegate.isWin ? 1 : 0
                Layout.rightMargin: toolTipDelegate.isWin ? 1 : 0
                elide: Text.ElideRight
                text: root.titleIncludesTrack ? "" : root.title
                color: "#08FFFFFF"
                // text: root.titleIncludesTrack ? "" : toolTipDelegate.genericName // <- This is the description
                opacity: 1.0
                visible: root.title.length !== 0 && root.title !== appNameHeading.text && root.title !== toolTipDelegate.genericName
                textFormat: Text.PlainText
                font: Qt.font({
                    // letterSpacing: 0.2,
                    weight: 630, // => 500
                    features: { 'cpsp' : 1 }
                })

                // Add brightness effect
                layer.enabled: true
                layer.effect: MultiEffect {
                    brightness: 8.8 // 0.8 // This will make the text brighter (while preserving opacity)
                    contrast: 5.8 //0.07 // This will make the text more opaque
                    // saturation: 3.0 // 1.0 // This causes artifacts
                }
            }

            // subtext
            PlasmaComponents3.Label {
                id: subtext
                maximumLineCount: 2
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: toolTipDelegate.isWin ? root.generateSubText() : ""
                color: "white"
                opacity: 0.25
                visible: text.length !== 0 && text !== appNameHeading.text
                textFormat: Text.PlainText
                font: Qt.font({
                    // letterSpacing: 0.2,
                    weight: 500,
                    features: { 'cpsp' : 1 }
                })
            }

            Layout.leftMargin: winTitle.visible ? 2 : 0
            Layout.rightMargin: winTitle.visible ? 2 : 0
        }

        // Count badge.
        // The badge itself is inside an item to better center the text in the bubble
        Item {
            // Layout.alignment: Qt.AlignRight | Qt.AlignTop

            // Central align on the y-axis if not toolTipDelegate.isWin
            Layout.alignment: thumbnailSourceItem.visible ? Qt.AlignRight | Qt.AlignTop : Qt.AlignHCenter | Qt.AlignVCenter

            // Layout.preferredHeight: closeButton.height
            // Layout.preferredWidth: closeButton.width
            // Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium * 0.35
            // Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium

            // Set width equal to the Badge width
            Layout.preferredWidth: badge.implicitWidth

            Layout.rightMargin: thumbnailSourceItem.visible ? 4 : -5
            Layout.topMargin: thumbnailSourceItem.visible ? 16 : 0
            Layout.leftMargin: thumbnailSourceItem.visible ? 2 : -3

            visible: root.index === 0 && toolTipDelegate.smartLauncherCountVisible

            Badge {
                id: badge
                anchors.centerIn: parent
                height: Kirigami.Units.iconSizes.smallMedium * 1
                number: toolTipDelegate.smartLauncherCount

                // Set previewed to true if mouse is over the app icon
                previewed: appNameHeading.visible
            }
        }

        // close button
        // PlasmaComponents3.ToolButton {
        //     id: closeButton
        //     Layout.alignment: Qt.AlignTop
        //     visible: toolTipDelegate.isWin
        //     icon.name: "window-close-symbolic"
        //     Layout.rightMargin: -3

        //     // 3 if window is visible, 1 if playercontroller is visible, 0 otherwise
        //     Layout.topMargin: toolTipDelegate.isWin && !playerController.visible ? 2 : playerController.visible ? 3 : 0
        //     onClicked: {
        //         backend.cancelHighlightWindows();
        //         tasksModel.requestClose(root.submodelIndex);
        //     }
        // }

        // Draw the button using Canvas
        // Rectangle {
        //     id: customCloseButton
        //     width: 22
        //     height: 22
        //     radius: width / 2  // Makes it circular
        //     color: mouseArea.containsMouse ? "#29ffffff" : "transparent"  // Red on hover, grey normally
        //     // opacity: mouseArea.containsMouse ? 1 : 0.5  // Full opacity on hover, half normally

        //     // Smooth color transition
        //     Behavior on color {
        //         ColorAnimation {
        //             duration: 130
        //         }
        //     }

        //     // Custom X icon using Canvas
        //     Canvas {
        //         id: closeIcon
        //         anchors.fill: parent
        //         anchors.margins: 6  // Padding for the X

        //         onPaint: {
        //             var ctx = getContext("2d");
        //             ctx.clearRect(0, 0, width, height);
        //             // ctx.strokeStyle = "#66ffffff";  // White X
        //             // 80% opacity white on hover else 50% opacity white
        //             ctx.strokeStyle = "#A3FFFFFF";

        //             ctx.lineWidth = 2.2;

        //             // Draw X
        //             ctx.beginPath();
        //             ctx.moveTo(0, 0);
        //             ctx.lineTo(width, height);
        //             ctx.moveTo(width, 0);
        //             ctx.lineTo(0, height);
        //             ctx.stroke();
        //         }
        //     }

        //     MouseArea {
        //         id: mouseArea
        //         anchors.fill: parent
        //         hoverEnabled: true

        //         onClicked: {
        //             // Maintain the same functionality as the original
        //             if (backend) backend.cancelHighlightWindows();
        //             if (tasksModel && root.submodelIndex) {
        //                 tasksModel.requestClose(root.submodelIndex);
        //             }
        //         }
        //     }

        //     // Properties to maintain compatibility
        //     visible: toolTipDelegate ? toolTipDelegate.isWin : true

        //     // Layout properties (if needed in a Layout)
        //     Layout.alignment: Qt.AlignTop
        //     // Layout.rightMargin: -3
        //     Layout.rightMargin: 1
        //     Layout.topMargin: {
        //         if (!toolTipDelegate) return 0;
        //         if (toolTipDelegate.isWin && !playerController.visible) return 4;
        //         if (playerController.visible) return 4;
        //         return 0;
        //     }
        // }

        Rectangle {
            id: customCloseButton
            width: 22
            height: 22
            // radius: width / 2
            // color: mouseArea.containsMouse ? "#32ffffff" : "transparent"
            color: "transparent"

            // Behavior on color {
            //     ColorAnimation {
            //         duration: 130
            //     }
            // }

            Rectangle {
                id: closeCircleBg
                anchors.fill: parent
                radius: width / 2
                color: "white"
                opacity: mouseArea.containsMouse ? 0.1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 130
                    }
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    brightness: 0.8
                    contrast: 0.07
                    saturation: 1.0
                }
            }

            Image {
                anchors.fill: parent
                anchors.margins: 4
                source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='#ffffff' stroke-width='3' stroke-linecap='round' stroke-linejoin='round' class='lucide lucide-x'><path d='M18 6 6 18'/><path d='m6 6 12 12'/></svg>"
                sourceSize: Qt.size(width + 5, height + 5)
                smooth: true
                antialiasing: true
                opacity: 0.8
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true

                onClicked: {
                    if (backend) backend.cancelHighlightWindows();
                    if (tasksModel && root.submodelIndex) {
                        tasksModel.requestClose(root.submodelIndex);
                    }
                }
            }

            visible: toolTipDelegate ? toolTipDelegate.isWin : true
            Layout.alignment: Qt.AlignTop
            Layout.rightMargin: playerController.visible ? -0.75 : !winTitle.visible ? 0 : 2
            Layout.topMargin: {
                if (!toolTipDelegate) return 0;
                if (!winTitle.visible) return 3;
                if (badge.visible) return 4.8;
                if (toolTipDelegate.isWin && !playerController.visible) return 4.8;
                if (playerController.visible) return 4;
                return 0;
            }
        }
    }

    // thumbnail container
    Item {
        id: thumbnailSourceItem

        Layout.fillWidth: true
        // Layout.preferredHeight: Kirigami.Units.gridUnit * 10

        // Use the thumbnail source's height
        Layout.preferredHeight: 10 * thumbnailSourceItem.width / 16

        Layout.bottomMargin: toolTipDelegate.isWin ? 5 : 0

        clip: true
        visible: toolTipDelegate.isWin

        readonly property /*undefined|WId where WId = int|string*/ var winId:
            toolTipDelegate.isWin ? toolTipDelegate.windows[root.index] : undefined

        // There's no PlasmaComponents3 version
        // PlasmaExtras.Highlight {
        //     anchors.fill: hoverHandler
        //     visible: (hoverHandler.item as MouseArea)?.containsMouse ?? false
        //     pressed: (hoverHandler.item as MouseArea)?.containsPress ?? false
        //     hovered: true
        // }

        /* Stock */
        // PlasmaExtras.Highlight {
        //     anchors.fill: hoverHandler
        //     visible: hoverHandler.item && (hoverHandler.item as MouseArea)?.actuallyContainsMouse && (hoverHandler.item as MouseArea)?.hasMouseMoved
        //     pressed: (hoverHandler.item as MouseArea)?.containsPress ?? false
        //     hovered: true
        // }

        /* Persistent background */
        // PlasmaExtras.Highlight {
        //     anchors.fill: hoverHandler
        //     visible: true
        //     opacity: hoverHandler.item && (hoverHandler.item as MouseArea)?.actuallyContainsMouse && (hoverHandler.item as MouseArea)?.hasMouseMoved ? 1 : 0.5
        //     pressed: (hoverHandler.item as MouseArea)?.containsPress ?? false
        //     hovered: true
        // }

        /* Using brightness effect */
        // PlasmaExtras.Highlight {
        //     id: highlight
        //     anchors.fill: hoverHandler
        //     opacity: hoverHandler.item && (hoverHandler.item as MouseArea)?.actuallyContainsMouse && (hoverHandler.item as MouseArea)?.hasMouseMoved ? 1 : 0.5

        //     // Add layer effect for brightness
        //     layer.enabled: true
        //     layer.effect: GE.BrightnessContrast {
        //         brightness: hoverHandler.item && (hoverHandler.item as MouseArea)?.actuallyContainsMouse && (hoverHandler.item as MouseArea)?.hasMouseMoved ? 0.65 : 0.5
        //         contrast: 0.0

        //         // Animation for brightness
        //         SequentialAnimation {
        //             running: true
        //             PauseAnimation {
        //                 duration: Kirigami.Units.humanMoment
        //             }
        //             NumberAnimation {
        //                 duration: Kirigami.Units.longDuration
        //                 easing.type: Easing.OutCubic
        //                 property: "brightness"
        //                 target: layer.effect
        //                 to: 0.65
        //             }
        //         }

        //     }

        //     pressed: (hoverHandler.item as MouseArea)?.containsPress ?? false
        //     hovered: true
        // }

        PlasmaExtras.Highlight {
            id: highlight
            anchors.fill: hoverHandler

            opacity: {
                if (hoverHandler.item && (hoverHandler.item as MouseArea)?.actuallyContainsMouse && (hoverHandler.item as MouseArea)?.hasMouseMoved) {
                    return 1.0
                }
                return 0.64
            }

            Behavior on opacity {
                enabled: true
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }

            layer.enabled: true
            layer.effect: GE.BrightnessContrast {
                id: brightnessEffect

                brightness: {
                    if (hoverHandler.item && (hoverHandler.item as MouseArea)?.actuallyContainsMouse && (hoverHandler.item as MouseArea)?.hasMouseMoved) {
                        return 0.8
                    }
                    return 0.64
                }

                Behavior on brightness {
                    enabled: true
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }

                contrast: 0.0
            }

            pressed: (hoverHandler.item as MouseArea)?.containsPress ?? false
            hovered: true
        }


        Loader {
            id: thumbnailLoader
            active: !toolTipDelegate.isLauncher
                && !albumArtImage.visible
                && (Number.isInteger(thumbnailSourceItem.winId) || pipeWireLoader.item && !pipeWireLoader.item.hasThumbnail)
                && root.index !== -1
            asynchronous: true
            visible: active
            anchors.margins: Kirigami.Units.smallSpacing * 2

            width: parent.width
            height: parent.height

            sourceComponent: root.isMinimized || pipeWireLoader.active ? iconItem : x11Thumbnail

            Component {
                id: iconItem
                Kirigami.Icon {
                    id: realIconItem
                    source: toolTipDelegate.icon
                    animated: false
                    visible: valid
                    opacity: pipeWireLoader.active ? 0 : 1

                    // Set a fixed size for the icon
                    width: Kirigami.Units.iconSizes.huge
                    height: Kirigami.Units.iconSizes.huge
                    scale: 0.4

                    // Center in parent
                    anchors.centerIn: parent

                    SequentialAnimation {
                        running: true
                        PauseAnimation {
                            duration: Kirigami.Units.humanMoment
                        }
                        NumberAnimation {
                            id: showAnimation
                            duration: Kirigami.Units.longDuration
                            easing.type: Easing.OutCubic
                            property: "opacity"
                            target: realIconItem
                            to: 1
                        }
                    }
                }
            }

            Component {
                id: x11Thumbnail
                PlasmaCore.WindowThumbnail {
                    winId: thumbnailSourceItem.winId
                }
            }
        }

        Loader {
            id: pipeWireLoader
            anchors.fill: hoverHandler
            // Indent a little bit so that neither the thumbnail nor the drop
            // shadow can cover up the highlight
            anchors.margins: thumbnailLoader.anchors.margins

            active: !toolTipDelegate.isLauncher && !albumArtImage.visible && KWindowSystem.isPlatformWayland && root.index !== -1
            asynchronous: true
            //In a loader since we might not have PipeWire available yet (WITH_PIPEWIRE could be undefined in plasma-workspace/libtaskmanager/declarative/taskmanagerplugin.cpp)
            source: "PipeWireThumbnail.qml"
        }

        Loader {
            active: (pipeWireLoader.item?.hasThumbnail ?? false) || (thumbnailLoader.status === Loader.Ready && !root.isMinimized)
            asynchronous: true
            visible: active
            anchors.fill: pipeWireLoader.active ? pipeWireLoader : thumbnailLoader

            sourceComponent: GE.DropShadow {
                horizontalOffset: 0
                verticalOffset: 3
                radius: 8
                samples: Math.round(radius * 1.5)
                color: "Black"
                source: pipeWireLoader.active ? pipeWireLoader.item : thumbnailLoader.item // source could be undefined when albumArt is available, so put it in a Loader.
            }
        }

        Loader {
            active: albumArtImage.visible && albumArtImage.status === Image.Ready && root.index !== -1 // Avoid loading when the instance is going to be destroyed
            asynchronous: true
            visible: active
            anchors.centerIn: hoverHandler

            sourceComponent: ShaderEffect {
                id: albumArtBackground
                readonly property Image source: albumArtImage

                // Manual implementation of Image.PreserveAspectCrop
                readonly property real scaleFactor: Math.max(hoverHandler.width / source.paintedWidth, hoverHandler.height / source.paintedHeight)
                width: Math.round(source.paintedWidth * scaleFactor)
                height: Math.round(source.paintedHeight * scaleFactor)
                layer.enabled: true
                opacity: 0.25
                layer.effect: GE.FastBlur {
                    source: albumArtBackground
                    anchors.fill: source
                    radius: 30
                }
            }
        }

        Image {
            id: albumArtImage
            // also Image.Loading to prevent loading thumbnails just because the album art takes a split second to load
            // if this is a group tooltip, we check if window title and track match, to allow distinguishing the different windows
            // if this app is a browser, we also check the title, so album art is not shown when the user is on some other tab
            // in all other cases we can safely show the album art without checking the title
            readonly property bool available: (status === Image.Ready || status === Image.Loading)
                && (!(toolTipDelegate.isGroup || backend.applicationCategories(launcherUrl).includes("WebBrowser")) || root.titleIncludesTrack)

            anchors.fill: hoverHandler
            // Indent by one pixel to make sure we never cover up the entire highlight
            anchors.margins: 10
            sourceSize: Qt.size(parent.width, parent.height)

            asynchronous: true
            source: toolTipDelegate.playerData?.artUrl ?? ""
            fillMode: Image.PreserveAspectFit
            visible: available
        }

        // hoverHandler has to be unloaded after the instance is pooled in order to avoid getting the old containsMouse status when the same instance is reused, so put it in a Loader.
        Loader {
            id: hoverHandler
            active: root.index !== -1
            anchors.fill: parent
            sourceComponent: ToolTipWindowMouseArea {
                rootTask: toolTipDelegate.parentTask
                modelIndex: root.submodelIndex
                winId: thumbnailSourceItem.winId
            }

            // // Add color for debugging
            // Rectangle {
            //     id: debugRect
            //     color: "red"
            //     anchors.fill: parent
            //     opacity: 0.5

            //     visible: hoverHandler.item.containsMouse
            // }
        }
    }

    // Player controls row, load on demand so group tooltips could be loaded faster
    Loader {
        id: playerController
        active: toolTipDelegate.playerData && root.index !== -1 // Avoid loading when the instance is going to be destroyed
        asynchronous: true
        visible: active
        Layout.fillWidth: true
        Layout.maximumWidth: header.Layout.maximumWidth
        // Layout.leftMargin: header.Layout.margins
        // Layout.rightMargin: header.Layout.margins

        Layout.leftMargin: winTitle.visible ? 2 : 0
        Layout.rightMargin: winTitle.visible ? 2 : 0
        Layout.bottomMargin: visible && !volumeControls.visible ? 2 : 0
        Layout.topMargin: toolTipDelegate.isWin ? -1 : 0

        source: "PlayerController.qml"
    }

    // Volume controls
    Loader {
        id: volumeControls
        active: toolTipDelegate.parentTask !== null
             && pulseAudio.item !== null
             && toolTipDelegate.parentTask.audioIndicatorsEnabled
             && toolTipDelegate.parentTask.hasAudioStream
             && root.index !== -1 // Avoid loading when the instance is going to be destroyed
        asynchronous: true
        visible: active
        Layout.fillWidth: true
        Layout.maximumWidth: header.Layout.maximumWidth
        // Layout.leftMargin: header.Layout.margins
        // Layout.rightMargin: header.Layout.margins
        Layout.leftMargin: toolTipDelegate.isWin ? 4 : 4
        // Layout.rightMargin: toolTipDelegate.isWin ? 4 : 6
        Layout.bottomMargin: 4
        sourceComponent: RowLayout {
            PlasmaComponents3.ToolButton { // Mute button
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                icon.name: if (checked) {
                    "audio-volume-muted"
                } else if (slider.displayValue <= 25) {
                    "audio-volume-low"
                } else if (slider.displayValue <= 75) {
                    "audio-volume-medium"
                } else {
                    "audio-volume-high"
                }
                onClicked: toolTipDelegate.parentTask.toggleMuted()
                checked: toolTipDelegate.parentTask.muted

                PlasmaComponents3.ToolTip {
                    text: parent.checked
                        ? i18nc("button to unmute app", "Unmute %1", toolTipDelegate.parentTask.appName)
                        : i18nc("button to mute app", "Mute %1", toolTipDelegate.parentTask.appName)
                }
            }

            PlasmaComponents3.Slider {
                id: slider

                readonly property int displayValue: Math.round(value / to * 100)
                readonly property int loudestVolume: toolTipDelegate.parentTask.audioStreams
                    .reduce((loudestVolume, stream) => Math.max(loudestVolume, stream.volume), 0)

                Layout.fillWidth: true
                from: pulseAudio.item.minimalVolume
                to: pulseAudio.item.normalVolume
                value: loudestVolume
                stepSize: to / 100
                opacity: toolTipDelegate.parentTask.muted ? 0.5 : 1

                Accessible.name: i18nc("Accessibility data on volume slider", "Adjust volume for %1", toolTipDelegate.parentTask.appName)

                onMoved: toolTipDelegate.parentTask.audioStreams.forEach((stream) => {
                    let v = Math.max(from, value)
                    if (v > 0 && loudestVolume > 0) { // prevent divide by 0
                        // adjust volume relative to the loudest stream
                        v = Math.min(Math.round(stream.volume / loudestVolume * v), to)
                    }
                    stream.model.Volume = v
                    stream.model.Muted = v === 0
                })
            }

            PlasmaComponents3.Label { // percent label
                Layout.alignment: Qt.AlignHCenter
                Layout.minimumWidth: percentMetrics.advanceWidth
                Layout.leftMargin: 4
                Layout.rightMargin: 6
                horizontalAlignment: Qt.AlignRight
                text: i18nc("volume percentage", "%1%", slider.displayValue)
                textFormat: Text.PlainText
                TextMetrics {
                    id: percentMetrics
                    text: i18nc("only used for sizing, should be widest possible string", "100%")
                }
                font: Qt.font({
                    weight: Font.Bold,
                    letterSpacing: 0.3
                })
            }
        }
    }

    function generateSubText(): string {
        const subTextEntries = [];

        if (!Plasmoid.configuration.showOnlyCurrentDesktop && virtualDesktopInfo.numberOfDesktops > 1) {
            if (!isOnAllVirtualDesktops && virtualDesktops.length > 0) {
                const virtualDesktopNameList = virtualDesktops.map(virtualDesktop => {
                    const index = virtualDesktopInfo.desktopIds.indexOf(virtualDesktop);
                    return virtualDesktopInfo.desktopNames[index];
                });

                subTextEntries.push(i18nc("Comma-separated list of desktops", "On %1",
                    virtualDesktopNameList.join(", ")));
            } else if (isOnAllVirtualDesktops) {
                subTextEntries.push(i18nc("Comma-separated list of desktops", "Pinned to all desktops"));
            }
        }

        if (activities.length === 0 && activityInfo.numberOfRunningActivities > 1) {
            subTextEntries.push(i18nc("Which virtual desktop a window is currently on",
                "Available on all activities"));
        } else if (activities.length > 0) {
            const activityNames = activities
                .filter(activity => activity !== activityInfo.currentActivity)
                .map(activity => activityInfo.activityName(activity))
                .filter(activityName => activityName !== "");

            if (Plasmoid.configuration.showOnlyCurrentActivity) {
                if (activityNames.length > 0) {
                    subTextEntries.push(i18nc("Activities a window is currently on (apart from the current one)",
                        "Also available on %1", activityNames.join(", ")));
                }
            } else if (activityNames.length > 0) {
                subTextEntries.push(i18nc("Which activities a window is currently on",
                    "Available on %1", activityNames.join(", ")));
            }
        }

        return subTextEntries.join("\n");
    }
}
