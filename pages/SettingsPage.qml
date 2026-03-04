import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI

Page {
    property var animWindowRef
    padding: 20
    background: Rectangle { color: "transparent" }

    ColumnLayout {
        spacing: 10

        EButton {
            text: theme.isDark ? "浅色" : "深色"
            iconCharacter: theme.isDark ? "\uf185" : "\uf186"
            iconRotateOnClick: true
            onClicked: theme.toggleTheme()
        }
    }

    Connections {
        target: animWindowRef
        function onAnimDurationChanged() { animSlider.value = animWindowRef.animDuration }
    }
}
