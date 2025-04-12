/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.taskmanager as TaskManagerApplet
import org.kde.plasma.plasmoid

import "code/layoutmetrics.js" as LayoutMetrics
import "code/tools.js" as TaskTools

PlasmaCore.ToolTipArea {
    id: task

    activeFocusOnTab: true

    // To achieve a bottom to top layout, the task manager is rotated by 180 degrees(see main.qml).
    // This makes the tasks mirrored, so we mirror them again to fix that.
    rotation: Plasmoid.configuration.reverseMode && Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 180 : 0

    implicitHeight: inPopup
                    ? LayoutMetrics.preferredHeightInPopup()
                    : Math.max(tasksRoot.height / tasksRoot.plasmoid.configuration.maxStripes,
                             LayoutMetrics.preferredMinHeight())
    implicitWidth: tasksRoot.vertical
        ? Math.max(LayoutMetrics.preferredMinWidth(), Math.min(LayoutMetrics.preferredMaxWidth(), tasksRoot.width / tasksRoot.plasmoid.configuration.maxStripes))
        : 0

    Layout.fillWidth: true
    Layout.fillHeight: !inPopup
    Layout.maximumWidth: tasksRoot.vertical
        ? -1
        : ((model.IsLauncher && !tasks.iconsOnly) ? tasksRoot.height / taskList.rows : LayoutMetrics.preferredMaxWidth())
    Layout.maximumHeight: tasksRoot.vertical ? LayoutMetrics.preferredMaxHeight() : -1

    required property var model
    required property int index
    required property /*main.qml*/ Item tasksRoot

    readonly property int pid: model.AppPid
    readonly property string appName: model.AppName
    readonly property string appId: model.AppId.replace(/\.desktop/, '')
    readonly property bool isIcon: tasksRoot.iconsOnly || model.IsLauncher
    property bool toolTipOpen: false
    property bool inPopup: false
    property bool isWindow: model.IsWindow
    property int childCount: model.ChildCount
    property int previousChildCount: 0
    property alias labelText: label.text
    property QtObject contextMenu: null
    readonly property bool smartLauncherEnabled: !inPopup && !model.IsStartup
    property QtObject smartLauncherItem: null

    property Item audioStreamIcon: null
    property var audioStreams: []
    property bool delayAudioStreamIndicator: false
    property bool completed: false
    readonly property bool audioIndicatorsEnabled: Plasmoid.configuration.indicateAudioStreams
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)

    property bool isLaunching: model.IsStartup

    readonly property bool highlighted: (inPopup && activeFocus) || (!inPopup && containsMouse)
        || (task.contextMenu && task.contextMenu.status === PlasmaExtras.Menu.Open)
        || (!!tasksRoot.groupDialog && tasksRoot.groupDialog.visualParent === task)

    active: (Plasmoid.configuration.showToolTips || tasksRoot.toolTipOpenedByClick === task) && !inPopup && !tasksRoot.groupDialog
    interactive: model.IsWindow || mainItem.playerData
    location: Plasmoid.location
    mainItem: model.IsWindow ? openWindowToolTipDelegate : pinnedAppToolTipDelegate

    onIsLaunchingChanged: {
        if (!bounceAnimation.running) {
            bounceAnimation.start();
        } else {
            bounceAnimation.complete();
        }
    }

    onXChanged: {
        if (!completed) {
            return;
        }
        if (oldX < 0) {
            oldX = x;
            return;
        }
        moveAnim.x = oldX - x + translateTransform.x;
        moveAnim.y = translateTransform.y;
        oldX = x;
        moveAnim.restart();
    }
    onYChanged: {
        if (!completed) {
            return;
        }
        if (oldY < 0) {
            oldY = y;
            return;
        }
        moveAnim.y = oldY - y + translateTransform.y;
        moveAnim.x = translateTransform.x;
        oldY = y;
        moveAnim.restart();
    }

    property real oldX: -1
    property real oldY: -1
    SequentialAnimation {
        id: moveAnim
        property real x
        property real y
        onRunningChanged: {
            if (running) {
                ++task.parent.animationsRunning;
            } else {
                --task.parent.animationsRunning;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: translateTransform
                properties: "x"
                from: moveAnim.x
                to: 0
                easing.type: Easing.OutQuad
                duration: Kirigami.Units.longDuration
            }
            NumberAnimation {
                target: translateTransform
                properties: "y"
                from: moveAnim.y
                to: 0
                easing.type: Easing.OutQuad
                duration: Kirigami.Units.longDuration
            }
        }
    }
    transform: Translate {
        id: translateTransform
    }

    Accessible.name: model.display
    Accessible.description: {
        if (!model.display) {
            return "";
        }

        if (model.IsLauncher) {
            return i18nc("@info:usagetip %1 application name", "Launch %1", model.display)
        }

        let smartLauncherDescription = "";
        if (iconBox.active) {
            smartLauncherDescription += i18ncp("@info:tooltip", "There is %1 new message.", "There are %1 new messages.", task.smartLauncherItem.count);
        }

        if (model.IsGroupParent) {
            switch (Plasmoid.configuration.groupedTaskVisualization) {
            case 0:
                break; // Use the default description
            case 1: {
                if (Plasmoid.configuration.showToolTips) {
                    return `${i18nc("@info:usagetip %1 task name", "Show Task tooltip for %1", model.display)}; ${smartLauncherDescription}`;
                }
                // fallthrough
            }
            case 2: {
                if (effectWatcher.registered) {
                    return `${i18nc("@info:usagetip %1 task name", "Show windows side by side for %1", model.display)}; ${smartLauncherDescription}`;
                }
                // fallthrough
            }
            default:
                return `${i18nc("@info:usagetip %1 task name", "Open textual list of windows for %1", model.display)}; ${smartLauncherDescription}`;
            }
        }

        return `${i18n("Activate %1", model.display)}; ${smartLauncherDescription}`;
    }
    Accessible.role: Accessible.Button
    Accessible.onPressAction: leftTapHandler.leftClick()

    onToolTipVisibleChanged: toolTipVisible => {
        task.toolTipOpen = toolTipVisible;
        if (!toolTipVisible) {
            tasksRoot.toolTipOpenedByClick = null;
        } else {
            tasksRoot.toolTipAreaItem = task;
        }
    }

    onContainsMouseChanged: {
        if (containsMouse) {
            task.forceActiveFocus(Qt.MouseFocusReason);
            task.updateMainItemBindings();
        } else {
            tasksRoot.toolTipOpenedByClick = null;
        }
    }

    onHighlightedChanged: {
        // ensure it doesn't get stuck with a window highlighted
        backend.cancelHighlightWindows();
    }

    onPidChanged: updateAudioStreams({delay: false})
    onAppNameChanged: updateAudioStreams({delay: false})

    onIsWindowChanged: {
        if (model.IsWindow) {
            taskInitComponent.createObject(task);
            updateAudioStreams({delay: false});
        }
    }

    onChildCountChanged: {
        if (TaskTools.taskManagerInstanceCount < 2 && childCount > previousChildCount) {
            tasksModel.requestPublishDelegateGeometry(modelIndex(), backend.globalRect(task), task);
        }

        previousChildCount = childCount;
    }

    onIndexChanged: {
        hideToolTip();

        if (!inPopup && !tasksRoot.vertical
                && !Plasmoid.configuration.separateLaunchers) {
            tasksRoot.requestLayout();
        }
    }

    onSmartLauncherEnabledChanged: {
        if (smartLauncherEnabled && !smartLauncherItem) {
            const component = Qt.createComponent("org.kde.plasma.private.taskmanager", "SmartLauncherItem");
            const smartLauncher = component.createObject(task);
            component.destroy();

            smartLauncher.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);

            smartLauncherItem = smartLauncher;
        }
    }

    onHasAudioStreamChanged: {
        const audioStreamIconActive = hasAudioStream && audioIndicatorsEnabled;
        if (!audioStreamIconActive) {
            if (audioStreamIcon !== null) {
                audioStreamIcon.destroy();
                audioStreamIcon = null;
            }
            return;
        }
        // Create item on demand instead of using Loader to reduce memory consumption,
        // because only a few applications have audio streams.
        const component = Qt.createComponent("AudioStream.qml");
        audioStreamIcon = component.createObject(task);
        component.destroy();
    }
    onAudioIndicatorsEnabledChanged: task.hasAudioStreamChanged()

    Keys.onMenuPressed: event => contextMenuTimer.start()
    Keys.onReturnPressed: event => TaskTools.activateTask(modelIndex(), model, event.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered)
    Keys.onEnterPressed: event => Keys.returnPressed(event);
    Keys.onSpacePressed: event => Keys.returnPressed(event);
    Keys.onUpPressed: event => Keys.leftPressed(event)
    Keys.onDownPressed: event => Keys.rightPressed(event)
    Keys.onLeftPressed: event => {
        if (!inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksModel.move(task.index, task.index - 1);
        } else {
            event.accepted = false;
        }
    }
    Keys.onRightPressed: event => {
        if (!inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksModel.move(task.index, task.index + 1);
        } else {
            event.accepted = false;
        }
    }

    function modelIndex(): /*QModelIndex*/ var {
        return inPopup
            ? tasksModel.makeModelIndex(groupDialog.visualParent.index, index)
            : tasksModel.makeModelIndex(index);
    }

    function showContextMenu(args: var): void {
        task.hideImmediately();
        contextMenu = tasksRoot.createContextMenu(task, modelIndex(), args);
        contextMenu.show();
    }

    function updateAudioStreams(args: var): void {
        if (args) {
            // When the task just appeared (e.g. virtual desktop switch), show the audio indicator
            // right away. Only when audio streams change during the lifetime of this task, delay
            // showing that to avoid distraction.
            delayAudioStreamIndicator = !!args.delay;
        }

        var pa = pulseAudio.item;
        if (!pa || !task.isWindow) {
            task.audioStreams = [];
            return;
        }

        // Check appid first for app using portal
        // https://docs.pipewire.org/page_portal.html
        var streams = pa.streamsForAppId(task.appId);
        if (!streams.length) {
            streams = pa.streamsForPid(model.AppPid);
            if (streams.length) {
                pa.registerPidMatch(model.AppName);
            } else {
                // We only want to fall back to appName matching if we never managed to map
                // a PID to an audio stream window. Otherwise if you have two instances of
                // an application, one playing and the other not, it will look up appName
                // for the non-playing instance and erroneously show an indicator on both.
                if (!pa.hasPidMatch(model.AppName)) {
                    streams = pa.streamsForAppName(model.AppName);
                }
            }
        }

        task.audioStreams = streams;
    }

    function toggleMuted(): void {
        if (muted) {
            task.audioStreams.forEach(item => item.unmute());
        } else {
            task.audioStreams.forEach(item => item.mute());
        }
    }

    // Will also be called in activateTaskAtIndex(index)
    function updateMainItemBindings(): void {
        if ((mainItem.parentTask === this && mainItem.rootIndex.row === index)
            || (tasksRoot.toolTipOpenedByClick === null && !active)
            || (tasksRoot.toolTipOpenedByClick !== null && tasksRoot.toolTipOpenedByClick !== this)) {
            return;
        }

        mainItem.blockingUpdates = (mainItem.isGroup !== model.IsGroupParent); // BUG 464597 Force unload the previous component

        mainItem.parentTask = this;
        mainItem.rootIndex = tasksModel.makeModelIndex(index, -1);

        mainItem.appName = Qt.binding(() => model.AppName);
        mainItem.pidParent = Qt.binding(() => model.AppPid);
        mainItem.windows = Qt.binding(() => model.WinIdList);
        mainItem.isGroup = Qt.binding(() => model.IsGroupParent);
        mainItem.icon = Qt.binding(() => model.decoration);
        mainItem.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);
        mainItem.isLauncher = Qt.binding(() => model.IsLauncher);
        mainItem.isMinimized = Qt.binding(() => model.IsMinimized);
        mainItem.display = Qt.binding(() => model.display);
        mainItem.genericName = Qt.binding(() => model.GenericName);
        mainItem.virtualDesktops = Qt.binding(() => model.VirtualDesktops);
        mainItem.isOnAllVirtualDesktops = Qt.binding(() => model.IsOnAllVirtualDesktops);
        mainItem.activities = Qt.binding(() => model.Activities);

        mainItem.smartLauncherCountVisible = Qt.binding(() => smartLauncherItem?.countVisible ?? false);
        mainItem.smartLauncherCount = Qt.binding(() => mainItem.smartLauncherCountVisible ? smartLauncherItem.count : 0);

        mainItem.blockingUpdates = false;
        tasksRoot.toolTipAreaItem = this;
    }

    Connections {
        target: pulseAudio.item
        ignoreUnknownSignals: true // Plasma-PA might not be available
        function onStreamsChanged(): void {
            task.updateAudioStreams({delay: true})
        }
    }

    TapHandler {
        id: menuTapHandler
        acceptedButtons: Qt.LeftButton
        acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Stylus
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onLongPressed: {
            // When we're a launcher, there's no window controls, so we can show all
            // places without the menu getting super huge.
            if (model.IsLauncher) {
                showContextMenu({showAllPlaces: true})
            } else {
                showContextMenu();
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        gesturePolicy: TapHandler.WithinBounds // Release grab when menu appears
        onPressedChanged: if (pressed) contextMenuTimer.start()
    }

    Timer {
        id: contextMenuTimer
        interval: 0
        onTriggered: menuTapHandler.longPressed()
    }

    TapHandler {
        id: leftTapHandler
        acceptedButtons: Qt.LeftButton
        onTapped: (eventPoint, button) => leftClick()

        function leftClick(): void {
            if (Plasmoid.configuration.showToolTips && task.active) {
                hideToolTip();
            }
            TaskTools.activateTask(modelIndex(), model, point.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered);
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.MiddleButton) {
                if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.NewInstance) {
                    tasksModel.requestNewInstance(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.Close) {
                    tasksRoot.taskClosedWithMouseMiddleButton = model.WinIdList.slice()
                    tasksModel.requestClose(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.ToggleMinimized) {
                    tasksModel.requestToggleMinimized(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.ToggleGrouping) {
                    tasksModel.requestToggleGrouping(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.BringToCurrentDesktop) {
                    tasksModel.requestVirtualDesktops(modelIndex(), [virtualDesktopInfo.currentDesktop]);
                }
            } else if (button === Qt.BackButton || button === Qt.ForwardButton) {
                const playerData = mpris2Source.playerForLauncherUrl(model.LauncherUrlWithoutIcon, model.AppPid);
                if (playerData) {
                    if (button === Qt.BackButton) {
                        playerData.Previous();
                    } else {
                        playerData.Next();
                    }
                } else {
                    eventPoint.accepted = false;
                }
            }

            backend.cancelHighlightWindows();
        }
    }

    // Original
    // KSvg.FrameSvgItem {
    //     id: frame

    //     anchors {
    //         fill: parent

    //         topMargin: (!tasksRoot.vertical && taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
    //         bottomMargin: (!tasksRoot.vertical && taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
    //         leftMargin: ((inPopup || tasksRoot.vertical) && taskList.columns > 1) ? LayoutMetrics.iconMargin : 0
    //         rightMargin: ((inPopup || tasksRoot.vertical) && taskList.columns > 1) ? LayoutMetrics.iconMargin : 0
    //     }

    //     imagePath: "widgets/tasks"
    //     property bool isHovered: task.highlighted && Plasmoid.configuration.taskHoverEffect
    //     property string basePrefix: "normal"
    //     prefix: isHovered ? TaskTools.taskPrefixHovered(basePrefix, Plasmoid.location) : TaskTools.taskPrefix(basePrefix, Plasmoid.location)

    //     // Avoid repositioning delegate item after dragFinished
    //     DragHandler {
    //         id: dragHandler
    //         grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType

    //         function setRequestedInhibitDnd(value: bool): void {
    //             // This is modifying the value in the panel containment that
    //             // inhibits accepting drag and drop, so that we don't accidentally
    //             // drop the task on this panel.
    //             let item = this;
    //             while (item.parent) {
    //                 item = item.parent;
    //                 if (item.appletRequestsInhibitDnD !== undefined) {
    //                     item.appletRequestsInhibitDnD = value
    //                 }
    //             }
    //         }

    //         onActiveChanged: {
    //             if (active) {
    //                 icon.grabToImage(result => {
    //                     if (!dragHandler.active) {
    //                         // BUG 466675 grabToImage is async, so avoid updating dragSource when active is false
    //                         return;
    //                     }
    //                     setRequestedInhibitDnd(true);
    //                     tasksRoot.dragSource = task;
    //                     dragHelper.Drag.imageSource = result.url;
    //                     dragHelper.Drag.mimeData = {
    //                         "text/x-orgkdeplasmataskmanager_taskurl": backend.tryDecodeApplicationsUrl(model.LauncherUrlWithoutIcon).toString(),
    //                         [model.MimeType]: model.MimeData,
    //                         "application/x-orgkdeplasmataskmanager_taskbuttonitem": model.MimeData,
    //                     };
    //                     dragHelper.Drag.active = dragHandler.active;
    //                 });
    //             } else {
    //                 setRequestedInhibitDnd(false);
    //                 dragHelper.Drag.active = false;
    //                 dragHelper.Drag.imageSource = "";
    //             }
    //         }
    //     }
    // }

    // Fade animation version
    // KSvg.FrameSvgItem {
    //     id: frame

    //     anchors {
    //         fill: parent

    //         topMargin: (!tasksRoot.vertical && taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
    //         bottomMargin: (!tasksRoot.vertical && taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
    //         leftMargin: ((inPopup || tasksRoot.vertical) && taskList.columns > 1) ? LayoutMetrics.iconMargin : 0
    //         rightMargin: ((inPopup || tasksRoot.vertical) && taskList.columns > 1) ? LayoutMetrics.iconMargin : 0
    //     }

    //     // Add opacity property that responds to hover state
    //     opacity: isHovered ? 1.0 : 0.0

    //     // Add fade animation
    //     Behavior on opacity {
    //         NumberAnimation {
    //             duration: PlasmaCore.Units.shortDuration
    //             easing.type: Easing.InOutQuad
    //         }
    //     }

    //     imagePath: "widgets/tasks"
    //     property bool isHovered: task.highlighted && Plasmoid.configuration.taskHoverEffect
    //     property string basePrefix: "normal"
    //     prefix: isHovered ? TaskTools.taskPrefixHovered(basePrefix, Plasmoid.location) : TaskTools.taskPrefix(basePrefix, Plasmoid.location)

    //     // Avoid repositioning delegate item after dragFinished
    //     DragHandler {
    //         id: dragHandler
    //         grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType

    //         function setRequestedInhibitDnd(value: bool): void {
    //             // This is modifying the value in the panel containment that
    //             // inhibits accepting drag and drop, so that we don't accidentally
    //             // drop the task on this panel.
    //             let item = this;
    //             while (item.parent) {
    //                 item = item.parent;
    //                 if (item.appletRequestsInhibitDnD !== undefined) {
    //                     item.appletRequestsInhibitDnD = value
    //                 }
    //             }
    //         }

    //         onActiveChanged: {
    //             if (active) {
    //                 icon.grabToImage(result => {
    //                     if (!dragHandler.active) {
    //                         // BUG 466675 grabToImage is async, so avoid updating dragSource when active is false
    //                         return;
    //                     }
    //                     setRequestedInhibitDnd(true);
    //                     tasksRoot.dragSource = task;
    //                     dragHelper.Drag.imageSource = result.url;
    //                     dragHelper.Drag.mimeData = {
    //                         "text/x-orgkdeplasmataskmanager_taskurl": backend.tryDecodeApplicationsUrl(model.LauncherUrlWithoutIcon).toString(),
    //                         [model.MimeType]: model.MimeData,
    //                         "application/x-orgkdeplasmataskmanager_taskbuttonitem": model.MimeData,
    //                     };
    //                     dragHelper.Drag.active = dragHandler.active;
    //                 });
    //             } else {
    //                 setRequestedInhibitDnd(false);
    //                 dragHelper.Drag.active = false;
    //                 dragHelper.Drag.imageSource = "";
    //             }
    //         }
    //     }
    // }

    Item {
        id: frameContainer
        anchors.fill: parent

        // // Base (non-hovered) frame
        // KSvg.FrameSvgItem {
        //     id: baseFrame
        //     anchors {
        //         fill: parent
        //         topMargin: (!tasksRoot.vertical && taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
        //         bottomMargin: (!tasksRoot.vertical && taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
        //         leftMargin: ((inPopup || tasksRoot.vertical) && taskList.columns > 1) ? LayoutMetrics.iconMargin : 0
        //         rightMargin: ((inPopup || tasksRoot.vertical) && taskList.columns > 1) ? LayoutMetrics.iconMargin : 0
        //     }
        //     imagePath: "widgets/tasks"
        //     property string basePrefix: "normal"
        //     prefix: TaskTools.taskPrefix(basePrefix, Plasmoid.location)
        //     opacity: task.highlighted && Plasmoid.configuration.taskHoverEffect && !(model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent)) ? 0 : 1

        //     Behavior on opacity {
        //         NumberAnimation {
        //             duration: 180
        //             easing.type: Easing.Out
        //         }
        //     }
        // }

        // // Hovered frame
        // KSvg.FrameSvgItem {
        //     id: hoveredFrame
        //     anchors {
        //         fill: parent
        //         topMargin: (!tasksRoot.vertical && taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
        //         bottomMargin: (!tasksRoot.vertical && taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
        //         leftMargin: ((inPopup || tasksRoot.vertical) && taskList.columns > 1) ? LayoutMetrics.iconMargin : 0
        //         rightMargin: ((inPopup || tasksRoot.vertical) && taskList.columns > 1) ? LayoutMetrics.iconMargin : 0
        //     }
        //     imagePath: "widgets/tasks"
        //     property string basePrefix: "normal"
        //     prefix: TaskTools.taskPrefixHovered(basePrefix, Plasmoid.location)
        //     opacity: task.highlighted && Plasmoid.configuration.taskHoverEffect && !model.IsLauncher && !(model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent))? 1 : 0

        //     Behavior on opacity {
        //         NumberAnimation {
        //             duration: 200
        //             easing.type: Easing.Out
        //         }
        //     }

        //     // Add brightness effect when item is active and hovered
        //     layer.enabled: true
        //     layer.effect: MultiEffect {
        //         brightness: task.highlighted && Plasmoid.configuration.taskHoverEffect && !model.IsLauncher && !(model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent)) && model.IsActive ? 0.8 : 0
        //         // contrast: task.highlighted && model.IsActive ? 0.16 : 0
        //         // saturation: task.highlighted ? 0.5 : 0

        //         Behavior on brightness {
        //             NumberAnimation {
        //                 duration: 200
        //                 easing.type: Easing.Out
        //             }
        //         }

        //         // Behavior on contrast {
        //         //     NumberAnimation {
        //         //         duration: 180
        //         //         easing.type: Easing.InOutQuad
        //         //     }
        //         // }

        //         // Behavior on saturation {
        //         //     NumberAnimation {
        //         //         duration: PlasmaCore.Units.shortDuration
        //         //         easing.type: Easing.InOutQuad
        //         //     }
        //         // }
        //     }
        // }

        // Drag handler
        DragHandler {
            id: dragHandler
            grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType

            function setRequestedInhibitDnd(value: bool): void {
                let item = this;
                while (item.parent) {
                    item = item.parent;
                    if (item.appletRequestsInhibitDnD !== undefined) {
                        item.appletRequestsInhibitDnD = value
                    }
                }
            }

            onActiveChanged: {
                if (active) {
                    icon.grabToImage(result => {
                        if (!dragHandler.active) {
                            return;
                        }
                        setRequestedInhibitDnd(true);
                        tasksRoot.dragSource = task;
                        dragHelper.Drag.imageSource = result.url;
                        dragHelper.Drag.mimeData = {
                            "text/x-orgkdeplasmataskmanager_taskurl": backend.tryDecodeApplicationsUrl(model.LauncherUrlWithoutIcon).toString(),
                            [model.MimeType]: model.MimeData,
                            "application/x-orgkdeplasmataskmanager_taskbuttonitem": model.MimeData,
                        };
                        dragHelper.Drag.active = dragHandler.active;
                    });
                } else {
                    setRequestedInhibitDnd(false);
                    dragHelper.Drag.active = false;
                    dragHelper.Drag.imageSource = "";
                }
            }
        }
    }

    Loader {
        id: taskProgressOverlayLoader

        // anchors.fill: baseFrame //frame // Requires new task progress overlay implementation
        asynchronous: true
        active: model.IsWindow && task.smartLauncherItem && task.smartLauncherItem.progressVisible
        visible: false

        source: "TaskProgressOverlay.qml"
    }

    // Timer for Creating delay
    Timer {
        id: timer
    }
    function delay(delayTime,cb) {
        timer.interval = delayTime;
        timer.repeat = false;
        timer.triggered.connect(cb);
        timer.start();
    }

    Loader {
    id: iconBox

    anchors {
        left: parent.left
        leftMargin: adjustMargin(true, parent.width, taskFrame.margins.left)
        top: parent.top
        topMargin: adjustMargin(false, parent.height, taskFrame.margins.top)
    }

    width: task.inPopup ? Math.max(Kirigami.Units.iconSizes.sizeForLabels, Kirigami.Units.iconSizes.medium) : Math.min(task.parent?.minimumWidth ?? 0, task.height)
    height: task.inPopup ? width : (parent.height - adjustMargin(false, parent.height, taskFrame.margins.top)
                - adjustMargin(false, parent.height, taskFrame.margins.bottom))

    asynchronous: true
    active: height >= Kirigami.Units.iconSizes.small
            && task.smartLauncherItem && task.smartLauncherItem.countVisible
    source: "TaskBadgeOverlay.qml"

    function adjustMargin(isVertical: bool, size: real, margin: real): real {
        if (!size) {
            return margin;
        }

        var margins = isVertical ? LayoutMetrics.horizontalMargins() : LayoutMetrics.verticalMargins();

        if ((size - margins) < Kirigami.Units.iconSizes.small) {
            return Math.ceil((margin * (Kirigami.Units.iconSizes.small / size)) / 2);
        }

        return margin;
    }

    Item {
        id: iconContainer
        anchors.fill: parent

        Kirigami.Icon {
            id: icon
            anchors.fill: parent
            enabled: true
            source: model.decoration
            visible: true  // Hide original icon as it will be displayed through Blend

            transform: Translate {
                id: iconTranslate
            }
        }

        // Create a white rectangle for brightness effect
        Rectangle {
            id: brightnessSource
            anchors.fill: parent
            color: "white"
            visible: false  // Hide as it's just a source for the blend
        }

        // Display a custom underline using Rectangle
        Item {
            id: indicatorContainer
            anchors {
                bottom: parent.bottom
                bottomMargin: -3
                horizontalCenter: parent.horizontalCenter
            }
            width: underline.width
            height: underline.height + 8 // Extra space for glow

            // Helper property to identify non-focused but open windows
            readonly property bool isNonFocusedWindow: model.IsWindow && !model.IsMinimized && !model.IsActive &&
                                                    !model.IsDemandingAttention && !model.IsStartup


            // Main indicator
            Rectangle {
                id: underline
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter

                height: 2.5

                // Width logic based on states
                width: {
                    // Don't show for launchers or launching tasks
                    if (model.IsLauncher || model.IsStartup) {
                        return 0;
                    }

                    // Minimized state or non-focused maximized window
                    if (model.IsMinimized || indicatorContainer.isNonFocusedWindow) {
                        // Unfocused maximized windows have a little more width
                        if (indicatorContainer.isNonFocusedWindow) {
                            return height * 5;
                        }

                        // Slightly wider when hovered (for purely minimized)
                        if (task.highlighted) {
                            return height * 5;
                        }

                        // If attention state, show full width
                        // if (model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent)) {
                        //     return height * 5;
                        // }


                        // Dot size when not hovered
                        return height * 1.2;
                    }

                    // Attention state or Active state (maximized)
                    if (model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent) || model.IsActive) {
                        // 85% of icon width
                        return icon.width * 1.0;
                    }

                    // Default size
                    return height;
                }

                // Rounded corners for dot appearance
                // radius: height / 2
                topLeftRadius: 100
                topRightRadius: 100
                bottomLeftRadius: model.IsMinimized ? task.highlighted ? 0 : 100 : 0
                bottomRightRadius: model.IsMinimized ? task.highlighted ? 0 : 100 : 0


                // Color logic
                color: {
                    // Amber color for attention state
                    if (model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent)) {
                        return "#FB923C";
                    }
                    // White for other states
                    return "white";
                }

                // Opacity logic
                opacity: {
                    // Don't show for launchers or launching tasks
                    if (model.IsLauncher || model.IsStartup) {
                        return 0;
                    }

                    // Attention state
                    if (model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent)) {
                        return task.highlighted ? 1.0 : 1.0; // Was 1.0 : 0.85
                    }

                    // Minimized state or non-focused maximized window
                    if (model.IsMinimized || indicatorContainer.isNonFocusedWindow) {
                        // Lit opacity (0.9) on hover (regardless of state) but lower opacity for unfocused maximized windows (0.35 || same as active) and a little more (for the dot) for purely minimized windows (0.7)
                        // return task.highlighted ? 0.9 : indicatorContainer.isNonFocusedWindow ? 0.35 : 0.7;


                        return task.highlighted ? 0.9 : indicatorContainer.isNonFocusedWindow ? 0.5 : 0.7;
                    }

                    // Active state (maximized)
                    if (model.IsActive) {
                        return task.highlighted ? 0.9 : 0.5;
                    }

                    // Default opacity
                    return 0.3;
                }

                // Animations
                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                }

                // Only show for appropriate states
                visible: !(model.IsLauncher || model.IsStartup)

                layer.enabled: true
                layer.effect: Glow {
                    radius: 16
                    samples: 16
                    color: underline.color
                    source: underline
                    spread: 0.45
                }
            }
        }

        // Brightness effect using Blend
        Blend {
            id: brightnessEffect
            anchors.fill: parent
            source: icon
            foregroundSource: brightnessSource
            mode: "screen"  // Screen blend mode for brightness
            opacity: task.highlighted && ((model.IsDemandingAttention ||
                   (task.smartLauncherItem && task.smartLauncherItem.urgent)) ||
                   model.IsLauncher) ? 0.28 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: PlasmaCore.Units.shortDuration
                    easing.type: Easing.InOutQuad
                }
            }
        }

        // Create a black rectangle for contrast effect
        Rectangle {
            id: contrastSource
            anchors.fill: parent
            color: "black"
            visible: false  // Hide as it's just a source for the blend
        }

        // Contrast effect using Blend
        Blend {
            id: contrastEffect
            anchors.fill: brightnessEffect
            source: brightnessEffect
            foregroundSource: contrastSource
            mode: "overlay"  // Overlay blend mode for contrast
            opacity: task.highlighted && ((model.IsDemandingAttention ||
                   (task.smartLauncherItem && task.smartLauncherItem.urgent)) ||
                   model.IsLauncher) ? 0.16 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: PlasmaCore.Units.shortDuration
                    easing.type: Easing.InOutQuad
                }
            }
        }

        property bool isInUpPhase: false

        // Startup bounce animation
        SequentialAnimation {
            id: bounceAnimation
            loops: Animation.Infinite
            alwaysRunToEnd: true

             // Up phase
            ParallelAnimation {
                ScriptAction {
                    script: iconContainer.isInUpPhase = true
                }
                NumberAnimation {
                    target: iconTranslate
                    property: "y"
                    from: 0
                    to: -6
                    duration: 300
                    easing.type: Easing.OutQuad
                }
            }

            // Down phase
            ParallelAnimation {
                ScriptAction {
                    script: iconContainer.isInUpPhase = false
                }
                NumberAnimation {
                    target: iconTranslate
                    property: "y"
                    from: -6
                    to: 0
                    duration: 300
                    easing.type: Easing.InQuad
                }
            }
        }
    }

    states: [
        State {
            name: "standalone"
            when: !label.visible && task.parent

            AnchorChanges {
                target: iconBox
                anchors.left: undefined
                anchors.horizontalCenter: parent.horizontalCenter
            }

            PropertyChanges {
                target: iconBox
                anchors.leftMargin: 0
                width: Math.min(task.parent.minimumWidth, tasks.height)
                    - adjustMargin(true, task.width, taskFrame.margins.left)
                    - adjustMargin(true, task.width, taskFrame.margins.right)
            }
        }
    ]
}

    PlasmaComponents3.Label {
        id: label

        visible: (inPopup || !iconsOnly && !model.IsLauncher
            && (parent.width - iconBox.height - Kirigami.Units.smallSpacing) >= LayoutMetrics.spaceRequiredToShowText())

        anchors {
            fill: parent
            leftMargin: taskFrame.margins.left + iconBox.width + LayoutMetrics.labelMargin
            topMargin: taskFrame.margins.top
            rightMargin: taskFrame.margins.right + (audioStreamIcon !== null && audioStreamIcon.visible ? (audioStreamIcon.width + LayoutMetrics.labelMargin) : 0)
            bottomMargin: taskFrame.margins.bottom
        }

        wrapMode: (maximumLineCount === 1) ? Text.NoWrap : Text.Wrap
        elide: Text.ElideRight
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
        maximumLineCount: Plasmoid.configuration.maxTextLines || undefined

        Accessible.ignored: true

        // use State to avoid unnecessary re-evaluation when the label is invisible
        states: State {
            name: "labelVisible"
            when: label.visible

            PropertyChanges {
                target: label
                text: model.display
            }
        }
    }

    states: [
        State {
            name: "launcher"
            when: model.IsLauncher

            // Not needed due to custom task indicators
            // PropertyChanges {
            //     target: baseFrame
            //     basePrefix: ""
            // }
        },
        State {
            name: "attention"
            when: model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent)

            // PropertyChanges {
            //     target: baseFrame
            //     basePrefix: "attention"
            // }
        },
        State {
            name: "minimized"
            when: model.IsMinimized

            // PropertyChanges {
            //     target: baseFrame
            //     basePrefix: "minimized"
            // }
        },
        State {
            name: "active"
            when: model.IsActive

            // PropertyChanges {
            //     target: baseFrame
            //     basePrefix: "focus"
            // }
        },
        State {
            name: 'launching'
            when: model.IsStartup
        }
    ]


    Component.onCompleted: {
        if (!inPopup && model.IsWindow) {
            const component = Qt.createComponent("GroupExpanderOverlay.qml");
            component.createObject(task);
            component.destroy();
            updateAudioStreams({delay: false});
        }

        if (!inPopup && !model.IsWindow) {
            taskInitComponent.createObject(task);
        }
        completed = true;
    }
    Component.onDestruction: {
        if (moveAnim.running) {
            (task.parent as TaskList).animationsRunning -= 1;
        }
    }
}
