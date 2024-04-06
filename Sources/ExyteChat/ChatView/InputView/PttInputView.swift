//
//  SwiftUIView.swift
//
//
//  Created by beswarm on 19/2/2024.
//

import SwiftUI
import ExyteMediaPicker

struct PttInputView: View {
    
    @Environment(\.chatTheme) private var theme
    @Environment(\.mediaPickerTheme) private var pickerTheme
    
    @ObservedObject var viewModel: InputViewModel
    var inputFieldId: UUID
    var style: InputViewStyle
    var messageUseMarkdown: Bool
    var hideRecorderUpButton: Bool = true
    var holdToRecord: Bool = true
    var textAndAudioOnly: Bool = true // only audio and text, photo, camera out
    
    @StateObject var recordingPlayer = RecordingPlayer()
    
    private var onAction: (InputViewAction) -> Void {
        viewModel.inputViewAction()
    }
    
    private var state: InputViewState {
        viewModel.state
    }
    
    @State private var overlaySize: CGSize = .zero
    
    @State var emptyDefaultToAudio: Bool = true
    
    @State private var recordButtonFrame: CGRect = .zero
    @State private var lockRecordFrame: CGRect = .zero
    @State private var deleteRecordFrame: CGRect = .zero
    
    @State private var dragStart: Date?
    @State private var tapDelayTimer: Timer?
    @State private var cancelGesture = false
    let tapDelay = 0.2
    
    var body: some View {
        VStack {
            viewOnTop
            HStack(alignment: .bottom, spacing: 0) {
                HStack(alignment: .bottom, spacing: 0) {
                    leftView
                    middleView
                    rightView
                }
                .frame(height: 48)
                .background {
                    RoundedRectangle(cornerRadius: 18)
                    //                        .fill(fieldBackgroundColor)
                        .fill(viewModel.state == .isRecordingHold ? Color.clear : fieldBackgroundColor )
                    //                        .fill(.blue)
                }
                .foregroundColor(.black)
                //                .background(Color.blue)
                .cornerRadius(10)
                .padding(.trailing, 3)
                
                rigthOutsideButton
            }
            
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(backgroundColor)
        .onAppear {
            viewModel.recordingPlayer = recordingPlayer
        }
    }
    
    @ViewBuilder
    var leftView: some View {
        
        if [.isRecordingTap, .isRecordingHold, .hasRecording, .playingRecording, .pausedRecording].contains(state) {
            Group {
                if textAndAudioOnly {
                    Button {
                        onAction(.deleteRecord)
                    } label: {
                        theme.images.recordAudio.deleteRecord
                        //                        .viewSize(24)
                        //                        .padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 0))
                    }
                    .frameGetter($deleteRecordFrame)
                } else {
                    deleteRecordButton
                }
            }
            .viewSize(24)
            .padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 0))
        } else {
            Group {
                if textAndAudioOnly {
                    Color.clear
                        .frame(width: 8, height: 1)
                } else {
                    switch style {
                    case .message:
                        attachButton
                    case .signature:
                        if viewModel.mediaPickerMode == .cameraSelection {
                            addButton
                        } else {
                            Color.clear
                            //                                .frame(width: 12, height: 1)
                        }
                    }
                }
            }
            .viewSize(4)
            .padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 0))
        }
    }
    
    @ViewBuilder
    var middleView: some View {
        Group {
            switch state {
            case .hasRecording, .playingRecording, .pausedRecording :
                recordWaveform
            case .isRecordingTap:
                recordingInProgress
//            case .isRecordingHold:
//                swipeToCancel
            default:
                if emptyDefaultToAudio {
                    pushToTalk
                } else {
                    TextInputView(text: $viewModel.attachments.text, inputFieldId: inputFieldId, style: style)
                }
            }
        }
        .frame(minHeight: 48)
    }
    
    @ViewBuilder
    var rightView: some View {
        VStack(alignment:.trailing) {
//            Spacer()
            Group {
                switch state {
                case .waitingForRecordingPermission:
                    if case .message = style {
                        Color.clear
                        //                        .frame(width: 8, height: 1)
                        //                        .padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 12))
                        //                    cameraButton
                    }
                case .isRecordingHold, .isRecordingTap:
                    recordDurationInProcess
                case .hasRecording:
                    recordDuration
                case .playingRecording, .pausedRecording:
                    recordDurationLeft
                default:
                    //                Color.clear.frame(width: 8, height: 1)
                    Button {
                        withAnimation {
                            emptyDefaultToAudio.toggle()
                        }
                    }  label: {
                        Image(systemName: emptyDefaultToAudio ?  "wave.3.left.circle": "keyboard" )
                            .viewSize(18)
                        //                        .viewSize(48)
                    }
                }
            }
            //        .frame(minHeight: 48)
//            .padding(.trailing)
        }
        .frame(width: 48, height: 48)
    }
    
    @ViewBuilder
    var rigthOutsideButton: some View {
        ZStack {
            if [.isRecordingTap, .isRecordingHold].contains(state) {
                RecordIndicator()
                    .viewSize(80)
                    .foregroundColor(theme.colors.sendButtonBackground)
            }
            Group {
                if state.canSend {
                    sendButton
                } else {
                    recordButton
                        .highPriorityGesture(dragGesture())
                }
            }
            .compositingGroup()
            .overlay(alignment: .top) {
                if hideRecorderUpButton {
                    EmptyView()
                } else {
                    Group {
                        if state == .isRecordingTap {
                            stopRecordButton
                        } else if state == .isRecordingHold {
                            lockRecordButton
                        }
                    }
                    .sizeGetter($overlaySize)
                    // hardcode 28 for now because sizeGetter returns 0 somehow
                    .offset(y: (state == .isRecordingTap ? -28 : -overlaySize.height) - 24)
                }
            }
        }
        .viewSize(48)
    }
    
    @ViewBuilder
    var viewOnTop: some View {
        if let message = viewModel.attachments.replyMessage {
            VStack(spacing: 8) {
                Rectangle()
                    .foregroundColor(theme.colors.friendMessage)
                    .frame(height: 2)
                
                HStack {
                    theme.images.reply.replyToMessage
                    Capsule()
                        .foregroundColor(theme.colors.myMessage)
                        .frame(width: 2)
                    VStack(alignment: .leading) {
                        Text("Reply to \(message.user.name)")
                            .font(.caption2)
                            .foregroundColor(theme.colors.buttonBackground)
                        if !message.text.isEmpty {
                            textView(message.text)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundColor(theme.colors.textLightContext)
                        }
                    }
                    .padding(.vertical, 2)
                    
                    Spacer()
                    
                    if let first = message.attachments.first {
                        AsyncImageView(url: first.thumbnail)
                            .viewSize(30)
                            .cornerRadius(4)
                            .padding(.trailing, 16)
                    }
                    
                    if let _ = message.recording {
                        theme.images.inputView.microphone
                            .renderingMode(.template)
                            .foregroundColor(theme.colors.buttonBackground)
                    }
                    
                    theme.images.reply.cancelReply
                        .onTapGesture {
                            viewModel.attachments.replyMessage = nil
                        }
                }
                .padding(.horizontal, 26)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    func textView(_ text: String) -> some View {
        if messageUseMarkdown,
           let attributed = try? AttributedString(markdown: text) {
            Text(attributed)
        } else {
            Text(text)
        }
    }
    
    var attachButton: some View {
        Button {
            onAction(.photo)
        } label: {
            theme.images.inputView.attach
                .viewSize(24)
                .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
        }
    }
    
    var addButton: some View {
        Button {
            onAction(.add)
        } label: {
            theme.images.inputView.add
                .circleBackground(theme.colors.addButtonBackground)
//                .viewSize(24)
//                .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
        }
    }
    
    var cameraButton: some View {
        Button {
            onAction(.camera)
        } label: {
            theme.images.inputView.attachCamera
                .viewSize(24)
                .padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 12))
        }
    }
    
    var sendButton: some View {
        Button {
            onAction(.send)
        } label: {
            theme.images.inputView.arrowSend
                .viewSize(48)
                .circleBackground(theme.colors.sendButtonBackground)
        }
    }
    
    var recordButton: some View {
        theme.images.inputView.microphone
            .viewSize(48)
            .circleBackground(theme.colors.sendButtonBackground)
            .frameGetter($recordButtonFrame)
    }
    
    var deleteRecordButton: some View {
        Button {
            onAction(.deleteRecord)
        } label: {
            theme.images.recordAudio.deleteRecord
//                .viewSize(24)
//                .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
//                .padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 0))
        }
        .frameGetter($deleteRecordFrame)
    }
    
    var stopRecordButton: some View {
        Button {
            onAction(.stopRecordAudio)
        } label: {
            theme.images.recordAudio.stopRecord
                .viewSize(28)
                .background(
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.4), radius: 1)
                )
        }
    }
    
    var lockRecordButton: some View {
        Button {
            onAction(.recordAudioLock)
        } label: {
            VStack(spacing: 20) {
                theme.images.recordAudio.lockRecord
                theme.images.recordAudio.sendRecord
            }
            .frame(width: 28)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.4), radius: 1)
            )
        }
        .frameGetter($lockRecordFrame)
    }
    
    var swipeToCancel: some View {
        HStack {
            Spacer()
            Button {
                onAction(.deleteRecord)
            } label: {
                HStack {
                    theme.images.recordAudio.cancelRecord
                    Text("Cancel")
                        .font(.footnote)
                        .foregroundColor(theme.colors.textLightContext)
                }
            }
            Spacer()
        }
    }
    
    var recordingInProgress: some View {
        HStack {
            Spacer()
            Text("Recording...")
                .font(.footnote)
                .foregroundColor(theme.colors.textLightContext)
            Spacer()
        }
    }
    
    var recordDurationInProcess: some View {
        HStack(spacing: 1) {
            Circle()
                .foregroundColor(theme.colors.recordDot)
                .viewSize(6)
            recordDuration
        }
    }
    
    var recordDuration: some View {
        Text(DateFormatter.timeString(Int(viewModel.attachments.recording?.duration ?? 0)))
            .multilineTextAlignment(.center)
            .foregroundColor(theme.colors.textLightContext)
            .opacity(0.6)
            .font(.caption2)
            .frame(maxWidth: .infinity, alignment: .center)
//            .monospacedDigit()
//            .padding(.trailing, 12)
    }
    
    var recordDurationLeft: some View {
        Text(DateFormatter.timeString(Int(recordingPlayer.secondsLeft)))
            .multilineTextAlignment(.center)
            .foregroundColor(theme.colors.textLightContext)
            .opacity(0.6)
            .font(.caption2)
            .frame(maxWidth: .infinity, alignment: .center)
//            .monospacedDigit()
//            .padding(.trailing, 12)
    }
    
    var playRecordButton: some View {
        Button {
            onAction(.playRecord)
        } label: {
            theme.images.recordAudio.playRecord
        }
    }
    
    var pauseRecordButton: some View {
        Button {
            onAction(.pauseRecord)
        } label: {
            theme.images.recordAudio.pauseRecord
        }
    }
    
    @ViewBuilder
    var recordWaveform: some View {
        if let samples = viewModel.attachments.recording?.waveformSamples {
            HStack(spacing: 8) {
                Group {
                    if state == .hasRecording || state == .pausedRecording {
                        playRecordButton
                    } else if state == .playingRecording {
                        pauseRecordButton
                    }
                }
                .frame(width: 20)
                
                RecordWaveformPlaying(samples: samples, progress: recordingPlayer.progress, color: theme.colors.textLightContext, addExtraDots: true)
            }
            .padding(.horizontal, 8)
        }
    }
    
    @ViewBuilder
    var pushToTalk: some View {
        HStack {
            Spacer()
            if (viewModel.state == .isRecordingHold ) {
                SoundWaveView(strokeColor: theme.colors.recordDot)
            } else {
                if viewModel.permissionDenied {
                    Text("Record Permission denied")
                        .foregroundStyle(.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                } else {
                    Text("Push To Talk")
                }
            }
            Spacer()
        }
        .gesture(
            DragGesture(minimumDistance: 0.0)
                .onChanged{ _ in
                    print("holdToRecordStart")
                    self.holdToRecordStart()
                }
                .onEnded { _ in
                    self.holdToRecordEnd()
                    print("end")
                }
        )
    }
    
    var fieldBackgroundColor: Color {
        switch style {
        case .message:
            return theme.colors.inputLightContextBackground
        case .signature:
            return theme.colors.inputDarkContextBackground
        }
    }
    
    var backgroundColor: Color {
        switch style {
        case .message:
            return theme.colors.mainBackground
        case .signature:
            return pickerTheme.main.albumSelectionBackground
        }
    }
    
    func holdToRecordStart() {
        if !emptyDefaultToAudio {
            emptyDefaultToAudio.toggle()
        }
        if dragStart != nil {
            return
        }
        self.dragStart = Date()
        self.onAction(.recordAudioHold)
    }
        
    func holdToRecordEnd() {
        if let dragStart = dragStart, Date().timeIntervalSince(dragStart) < 1.0 {
            onAction(.deleteRecord)
        } else {
            self.onAction(.stopRecordAudio)
        }
        self.dragStart = nil
    }

    
    func dragGesture() -> some Gesture {
        DragGesture(minimumDistance: 0.0, coordinateSpace: .global)
            .onChanged { value in
                if holdToRecord  {
                    self.holdToRecordStart()
                    return
                }

                
                if dragStart == nil {
                    dragStart = Date()
                    cancelGesture = false
                    tapDelayTimer = Timer.scheduledTimer(withTimeInterval: tapDelay, repeats: false) { _ in
                        if state != .isRecordingTap, state != .waitingForRecordingPermission {
                            self.onAction(.recordAudioHold)
                        }
                    }
                }
                
                if !self.hideRecorderUpButton {
                    if value.location.y < lockRecordFrame.minY,
                       value.location.x > recordButtonFrame.minX {
                        cancelGesture = true
                        onAction(.recordAudioLock)
                    }
                    
                    if value.location.x < UIScreen.main.bounds.width/2,
                       value.location.y > recordButtonFrame.minY {
                        cancelGesture = true
                        onAction(.deleteRecord)
                    }
                }
            }
            .onEnded() { value in
                if holdToRecord {
                    self.holdToRecordEnd()
                    return
                }
                
                if !cancelGesture {
                    tapDelayTimer = nil
                    if recordButtonFrame.contains(value.location) {
                        if let dragStart = dragStart, Date().timeIntervalSince(dragStart) < tapDelay {
                            onAction(.recordAudioTap)
                        } else if state != .waitingForRecordingPermission {
                            onAction(.send)
                        }
                    }
                    else if lockRecordFrame.contains(value.location) {
                        onAction(.recordAudioLock)
                    }
                    else if deleteRecordFrame.contains(value.location) {
                        onAction(.deleteRecord)
                    } else {
                        onAction(.send)
                    }
                }
                                
            
                dragStart = nil
            }
    }
}


struct Wave: Shape {
    // allow SwiftUI to animate the wave phase
    var animatableData: Double {
        get { phase }
        set { self.phase = newValue }
    }

    // how high our waves should be
    var strength: Double

    // how frequent our waves should be
    var frequency: Double

    // how much to offset our waves horizontally
    var phase: Double

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath()

        // calculate some important values up front
        let width = Double(rect.width)
        let height = Double(rect.height)
        let midWidth = width / 2
        let midHeight = height / 2
        let oneOverMidWidth = 1 / midWidth

        // split our total width up based on the frequency
        let wavelength = width / frequency

        // start at the left center
        path.move(to: CGPoint(x: 0, y: midHeight))

        // now count across individual horizontal points one by one
        for x in stride(from: 0, through: width, by: 1) {
            // find our current position relative to the wavelength
            let relativeX = x / wavelength

            // find how far we are from the horizontal center
            let distanceFromMidWidth = x - midWidth

            // bring that into the range of -1 to 1
            let normalDistance = oneOverMidWidth * distanceFromMidWidth

            let parabola = -(normalDistance * normalDistance) + 1

            // calculate the sine of that position, adding our phase offset
            let sine = sin(relativeX + phase)

            // multiply that sine by our strength to determine final offset, then move it down to the middle of our view
            let y = parabola * strength * sine + midHeight

            // add a line to here
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return Path(path.cgPath)
    }
}

struct SoundWaveView: View {
    @State private var phase = 0.0
    var strokeColor: Color = .red

    var body: some View {
        ZStack {
            ForEach(0..<1) { i in
                Wave(strength: 30, frequency: 60, phase: self.phase)
//                    .stroke(Color.blue.opacity(Double(i) / 10), lineWidth: 5)
                    .stroke(self.strokeColor, lineWidth: 5)
                    .offset(x: CGFloat(i) * 10)
                    .padding(.vertical)
            }
        }
//        .background(Color.blue)
//        .edgesIgnoringSafeArea(.all)
        .onAppear {
            withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                self.phase = .pi * 2
            }
        }
    }
}
