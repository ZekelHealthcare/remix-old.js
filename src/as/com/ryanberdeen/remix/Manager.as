package com.ryanberdeen.remix {
    public class Manager {
        private var tracks:Array;
        private var setStatus:Function;

        private function init(apiKey:String, editor:Object):void {
            positionUpdateTimer = new Timer(10);
            positionUpdateTimer.addEventListener('timer', positionUpdateTimerHandler);
            ExternalInterface.addCallback('setRemixString', setRemixString);
            callJs('init');
        }

        private function clearStatus():void {
            setStatus('');
        }

        private function resetAnalysis():void {
            bars = null;
            beats = null;
            playButton.enabled = false;
            remixButton.enabled = false;

            sound = null;
            samples = null;

            resetPlayer();
        }

        private function chooseFile():void {
            setStatus('Choose file');

            resetAnalysis();
            trackLoader = new TrackLoader(trackApi);
            trackLoader.alwaysUpload = !calculateMd5checkBox.selected;
            trackLoader.addEventListener(TrackLoaderEvent.LOADING_SOUND, loadingSoundHandler);
            trackLoader.addEventListener(TrackLoaderEvent.SOUND_LOADED, soundLoadedHandler);
            trackLoader.addEventListener(TrackLoaderEvent.CALCULATING_MD5, calculatingMd5Handler);
            trackLoader.md5Calculator.addEventListener(ProgressEvent.PROGRESS, md5ProgressHandler);
            trackLoader.addEventListener(TrackLoaderEvent.MD5_CALCULATED, md5CalculatedHandler);
            trackLoader.addEventListener(TrackLoaderEvent.CHECKING_ANALYSIS, checkingAnalysisHandler);
            trackLoader.addEventListener(TrackLoaderEvent.UPLOADING_FILE, uploadingFileHandler);
            trackLoader.fileReference.addEventListener(ProgressEvent.PROGRESS, uploadProgressHandler);
            trackLoader.addEventListener(TrackLoaderEvent.FILE_UPLOADED, fileUploadedHandler);
            trackLoader.addEventListener(TrackLoaderEvent.LOADING_ANALYSIS, loadingAnalysisHandler);
            trackLoader.analysisLoader.addEventListener(AnalysisEvent.ERROR, analysisErrorHandler);
            trackLoader.analysisLoader.addEventListener(AnalysisEvent.COMPLETE, analysisCompleteHandler);
            trackLoader.analysisLoader.addEventListener(Event.COMPLETE, analysisLoaderCompleteHandler);
            trackLoader.analysisLoader.addEventListener(EchoNestErrorEvent.ECHO_NEST_ERROR, echoNestErrorEventHandler);
            trackLoader.analysisLoader.addEventListener(IOErrorEvent.IO_ERROR, errorEventHandler);
            trackLoader.analysisLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, errorEventHandler);

            trackLoader.load();
        }

        private function loadingSoundHandler(e:TrackLoaderEvent):void {
            setStatus('Load sound', true);
        }

        private function soundLoadedHandler(e:TrackLoaderEvent):void {
            clearStatus();
            sound = trackLoader.sound;
        }

        private function calculatingMd5Handler(e:TrackLoaderEvent):void {
            setStatus('Calculate MD5');
        }

        private function md5ProgressHandler(e:ProgressEvent):void {
            progressBar.setProgress(e.bytesLoaded, e.bytesTotal);
        }

        private function md5CalculatedHandler(e:TrackLoaderEvent):void {
            clearStatus();
        }

        private function checkingAnalysisHandler(e:TrackLoaderEvent):void {
            setStatus('Check for analysis', true);
        }

        private function uploadingFileHandler(e:TrackLoaderEvent):void {
            setStatus('Upload');
        }

        private function uploadProgressHandler(e:ProgressEvent):void {
            progressBar.setProgress(e.bytesLoaded, e.bytesTotal);
        }

        private function fileUploadedHandler(e:TrackLoaderEvent):void {
            clearStatus();
        }

        private function loadingAnalysisHandler(e:TrackLoaderEvent):void {
            setStatus('Wait for analysis', true);
        }

        private function analysisErrorHandler(e:Event):void {
            // TODO
        }

        private function analysisCompleteHandler(e:Event):void {
            setStatus('Download analysis', true);
        }

        private function analysisLoaderCompleteHandler(e:Event):void {
            clearStatus();

            bars = trackLoader.analysisLoader.analysis.bars;
            beats = trackLoader.analysisLoader.analysis.beats;

            callJs('setAnalysis', trackLoader.analysisLoader.analysis);
            clearStatus();
            remixButton.enabled = true;
            preparePlayer();
        }

        private function echoNestErrorEventHandler(error:EchoNestErrorEvent):void {
            // TODO
            clearStatus();
        }

        private function errorEventHandler(e:Event):void {
            // TODO
        }

        private function errorHandler(e:Error):void {
            // TODO
        }

        private function resetPlayer():void {
            if (remixPlayer != null) {
                remixPlayer.stop();

                remixPlayer = null;
            }
            playButton.label = "Play";
            playing = false;
            callJs('setProgress', 0);
            positionUpdateTimer.stop();
        }

        private function preparePlayer():void {
            resetPlayer();

            remixPlayer = new SampleSourcePlayer();
            remixPlayer.addEventListener(Event.SOUND_COMPLETE, playerSoundCompleteHandler);
            if (samples) {
                remixPlayer.sampleSource = discontinuousRemix(samples);
                enablePlayer();
            }
        }

        private function enablePlayer():void {
            playButton.enabled = true;
            playButton.label = "Play";
        }

        private function playerSoundCompleteHandler(e:Event):void {
            positionUpdateTimer.stop();
            preparePlayer();
        }

        private function discontinuousRemix(sampleRanges:Array):ISampleSource {
            var sampleSource:DiscontinuousSampleSource = new DiscontinuousSampleSource();

            sampleSource.sampleRanges = sampleRanges;
            sampleSource.sampleSource = new SoundSampleSource(sound);

            return sampleSource;
        }

        private function togglePlayPause():void {
            if (!playing) {
                play();
            }
            else {
                pause();
            }
        }

        private function play():void {
            try {
                remixPlayer.start();
                positionUpdateTimer.start();
                playButton.label = "Pause";
                playing = true;
            }
            catch(e:Error) {
                errorHandler(e);
            }
        }

        private function pause():void {
            remixPlayer.stop();
            positionUpdateTimer.stop();
            playButton.label = "Play";
            playing = false;
        }

        private function positionUpdateTimerHandler(e:Event):void {
            callJs('setProgress', remixPlayer.sourcePosition / (sound.length * 44.1))
        }

        private function callJs(fn:String, ...args):* {
            args.unshift('Remix.__' + fn);
            return ExternalInterface.call.apply(ExternalInterface, args);
        }

        private function remixButtonHandler():void {
            preparePlayer();
            callJs('remix');
        }

        private function setRemixString(string:String):void {
            setRemixArray(string.split(','));
        }

        private function setRemixArray(array:Array):void {
            var result:Array = [];
            for (var i:int = 0; i < array.length - 1; i++) {
                result.push(new SampleRange(Math.round(Number(array[i]) * 44100), Math.round(Number(array[++i]) * 44100)));
            }

            setRemix(result);
        }

        private function setRemix(sampleRanges:Array):void {
            samples = sampleRanges;
            remixPlayer.sampleSource = discontinuousRemix(sampleRanges);
            preparePlayer();
            play();
        }
    }
}