import QtQuick
import QtMultimedia

// Plays a camera stream (MJPEG or HLS) with QtMultimedia. Loaded through a
// Loader so the card still works with snapshots when QtMultimedia is missing.
Item {
    id: root

    property string source: ""
    property bool playing: false
    property bool gotFrame: false

    signal failed(string message)
    signal ended

    onSourceChanged: gotFrame = false
    onPlayingChanged: {
        if (!playing) {
            player.stop();
            gotFrame = false;
        }
    }

    MediaPlayer {
        id: player
        source: root.playing ? root.source : ""
        videoOutput: output
        onSourceChanged: {
            if (String(source) !== "")
                play();
        }
        onErrorOccurred: (error, errorString) => root.failed(errorString)
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia)
                root.ended();
        }
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    Connections {
        target: output.videoSink
        function onVideoFrameChanged() {
            if (!root.gotFrame)
                root.gotFrame = true;
        }
    }
}
