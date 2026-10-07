import QtQuick

Item {
    id: root

    property var barWindow: null
    property var dropdownController: null
    property var dropdown: null
    property bool hovered: false
    readonly property color pillColor: hovered || (dropdown && dropdown.visible) ? "#343434" : "#303030"
    default property alias pillContents: pill.data

    // The bar anchors each widget to its right neighbour, so extra width only
    // pushes earlier items. No layout pass or second animation is involved.
    // The compact pill and popup's origin both stay at this slot's right edge.
    implicitWidth: dropdown && dropdown.visible ? dropdown.animatedWidth : 33
    implicitHeight: 33

    function toggleDropdown() {
        if (dropdownController)
            dropdownController.toggle(dropdown);
        else if (dropdown)
            dropdown.togglePopup();
    }

    data: [
        Rectangle {
            id: pill
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 33
            height: 33
            radius: height / 2
            color: root.pillColor
            visible: !root.dropdown || !root.dropdown.visible
            Behavior on color { ColorAnimation { duration: 150 } }
        },
        Connections {
            target: root.dropdown
            function onCloseFinished() {
                if (root.dropdownController)
                    root.dropdownController.closed(root.dropdown);
            }
        }
    ]
}
