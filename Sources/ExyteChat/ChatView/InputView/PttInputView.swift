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
            HStack(alignment: .bottom, spacing: 10) {
                HStack(alignment: .bottom, spacing: 0) {
                    leftView
                    middleView
                    rightView
                }
                .frame(height: 48)
                .background {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(fieldBackgroundColor)
//                        .fill(.blue)
                }
                .foregroundColor(.black)
//                .background(Color.blue)
                .cornerRadius(10)

                
                
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
            if textAndAudioOnly {
                Button {
                    onAction(.deleteRecord)
                } label: {
                    theme.images.recordAudio.deleteRecord
                        .viewSize(24)
                        .padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 0))
                }
                .frameGetter($deleteRecordFrame)
            } else {
                deleteRecordButton
            }
        } else {
            if textAndAudioOnly {
                Color.clear.frame(width: 12, height: 1)
            } else {
                switch style {
                case .message:
                    attachButton
                case .signature:
                    if viewModel.mediaPickerMode == .cameraSelection {
                        addButton
                    } else {
                        Color.clear.frame(width: 12, height: 1)
                    }
                }
            }
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
                    HStack {
                        Spacer()
                        Text("Push To Talk")
                        Spacer()
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0.0)
                            .onChanged{ _ in
                                self.holdToRecordStart()
                            }
                            .onEnded { _ in
                                self.holdToRecordEnd()
                                print("end")
                            }
                        )
                } else {
                    TextInputView(text: $viewModel.attachments.text, inputFieldId: inputFieldId, style: style)
                }
            }
        }
        .frame(minHeight: 48)
    }
    
    @ViewBuilder
    var rightView: some View {
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
                        .viewSize(48)
                }
            }
        }
//        .frame(minHeight: 48)
        .frame(height: 48)
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
                .viewSize(24)
                .circleBackground(theme.colors.addButtonBackground)
                .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
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
                .viewSize(24)
                .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
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
        HStack {
            Circle()
                .foregroundColor(theme.colors.recordDot)
                .viewSize(6)
            recordDuration
        }
    }
    
    var recordDuration: some View {
        Text(DateFormatter.timeString(Int(viewModel.attachments.recording?.duration ?? 0)))
            .foregroundColor(theme.colors.textLightContext)
            .opacity(0.6)
            .font(.caption2)
            .monospacedDigit()
            .padding(.trailing, 12)
    }
    
    var recordDurationLeft: some View {
        Text(DateFormatter.timeString(Int(recordingPlayer.secondsLeft)))
            .foregroundColor(theme.colors.textLightContext)
            .opacity(0.6)
            .font(.caption2)
            .monospacedDigit()
            .padding(.trailing, 12)
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
//        HStack {
//            Spacer()
//            Button {
//                onAction(.deleteRecord)
//            } label: {
//                HStack {
//                    theme.images.recordAudio.cancelRecord
//                    Text("Cancel")
//                        .font(.footnote)
//                        .foregroundColor(theme.colors.textLightContext)
//                }
//            }
//            Spacer()
//        }
        
        HStack {
            Spacer()
            
            Text("Push To Talk")
            Spacer()
        }
        .foregroundColor(.white)
        .background(Color.blue)
        .cornerRadius(10)
        .frame(height: 48)
        
        .gesture(
            LongPressGesture(minimumDuration: 0.01)
                .onChanged{ _ in
                    viewModel.state = .isRecordingHold
                }
                .onEnded { _ in
                    viewModel.state = .empty
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




