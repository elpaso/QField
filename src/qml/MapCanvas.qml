/***************************************************************************
                            MapCanvas.qml
                              -------------------
              begin                : 10.12.2014
              copyright            : (C) 2014 by Matthias Kuhn
              email                : matthias (at) opengis.ch
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

import QtQuick 2.0
import QtQuick.Controls 1.2
import QtQml 2.2
import org.qgis 1.0

Item {
  id: mapArea
  property alias mapSettings: mapCanvasWrapper.mapSettings
  property alias isRendering: mapCanvasWrapper.isRendering
  property alias incrementalRendering: mapCanvasWrapper.incrementalRendering

  signal clicked(var mouse)

  /**
   * Freezes the map canvas refreshes.
   *
   * In case of repeated geometry changes (animated resizes, pinch, pan...)
   * triggering refreshes all the time can cause severe performance impacts.
   *
   * If freeze is called, an internal counter is incremented and only when the
   * counter is 0, refreshes will happen.
   * It is therefore important to call freeze() and unfreeze() exactly the same
   * number of times.
   */
  function freeze(id) {
    mapCanvasWrapper.__freezecount[id] = true
    mapCanvasWrapper.freeze = true
  }

  function unfreeze(id) {
    delete mapCanvasWrapper.__freezecount[id]
    mapCanvasWrapper.freeze = Object.keys(mapCanvasWrapper.__freezecount).length !== 0
  }

  MapCanvasMap {
    id: mapCanvasWrapper

    anchors.fill: parent

    property var __freezecount: ({})

    freeze: false
  }

  PinchArea {
    id: pinchArea

    anchors.fill: parent

    onPinchStarted: {
      freeze('pinch')
    }

    onPinchUpdated: {
      mapCanvasWrapper.zoom( pinch.center, pinch.previousScale / pinch.scale )
      mapCanvasWrapper.pan( pinch.center, pinch.previousCenter )
    }

    onPinchFinished: {
      unfreeze('pinch')
      mapCanvasWrapper.refresh()
    }

    MouseArea {
      id: mouseArea

      property point __initialPosition
      property point __lastPosition

      anchors.fill : parent

      onDoubleClicked: {
        clickedTimer.stop()
        var center = Qt.point( mouse.x, mouse.y )
        mapCanvasWrapper.zoom( center, 0.8 )
        // mapCanvasWrapper.pan( pinch.center, pinch.previousCenter )
      }

      onClicked: {
        if ( mouse.button === Qt.RightButton )
        {
          var center = Qt.point( mouse.x, mouse.y )
          mapCanvasWrapper.zoom( center, 1.2 )
        }
        else
        {
          var distance = Math.abs( mouse.x - __initialPosition.x ) + Math.abs( mouse.y - __initialPosition.y )

          if ( distance < 5 * dp)
          {
            if (!clickedTimer.running) {
              props.mouse = mouse
              clickedTimer.restart()
            }
          }
        }
      }

      onPressed: {
        __lastPosition = Qt.point( mouse.x, mouse.y)
        __initialPosition = __lastPosition
        freeze('pan')
      }

      onReleased: {
        unfreeze('pan')
      }

      onPositionChanged: {
        var currentPosition = Qt.point( mouse.x, mouse.y )
        mapCanvasWrapper.pan( currentPosition, __lastPosition )
        __lastPosition = currentPosition
      }

      onCanceled: {
        unfreezePanTimer.start()
      }

      onWheel: {
        mapCanvasWrapper.zoom( Qt.point( wheel.x, wheel.y ), Math.pow( 0.8, wheel.angleDelta.y / 60 ) )
      }

      Timer {
        id: clickedTimer
        interval: 250
        onTriggered: mapArea.clicked( props.mouse )
      }

      Timer {
        id: unfreezePanTimer
        interval: 500;
        running: false;
        repeat: false
        onTriggered: unfreeze('pan')
      }

      QtObject {
        id: props
        property var mouse
      }
    }
  }
}
