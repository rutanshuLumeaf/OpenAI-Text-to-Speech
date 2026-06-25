# OpenAI Text-to-Speech Flutter Demo

This is a small Flutter demo app for testing OpenAI text-to-speech locally. It lets you type text, stream generated MP3 audio from the OpenAI speech API, and play the streamed audio immediately inside the app.

The reusable service class is here:

```text
lib/services/openai_tts_service.dart
```

## How Speech Is Generated

This app uses Speech API response streaming. It does not save an MP3 file and does not wait for the full response before starting playback.

1. You type text into the text field.
2. When you tap **Generate Speech**, the app calls `OpenAiTtsService.streamSpeech`.
3. The service reads `OPENAI_API_KEY` from the `.env` file using `flutter_dotenv`.
4. The service sends a `POST` request to:

```text
https://api.openai.com/v1/audio/speech
```

5. The request body tells OpenAI which model, voice, audio format, speed, and input text to use.
6. OpenAI returns binary audio chunks, not JSON.
7. Before the first chunk arrives, the screen starts a tiny local HTTP stream with `LiveTtsAudioServer`.
8. `just_audio` plays that local `127.0.0.1` stream URL.
9. As OpenAI chunks arrive, the screen feeds them into the local stream.
10. Playback starts automatically as soon as the audio decoder has enough streamed MP3 data.
11. When the OpenAI stream finishes, the local audio stream closes.
12. The screen shows first audio data time, total stream completion time, and AI speaking start/end times.

So the important idea is:

```text
Text -> OpenAI API -> streamed MP3 chunks -> live just_audio playback
```

## Is This Streaming?

Yes. This demo uses streamed audio from the Speech API.

That means:

- Playback starts automatically when the first audio chunk arrives.
- You do not need to tap Play after generating speech.
- Long text can begin speaking before the entire response is finished.
- The audio is not saved to disk; it is played once from the stream.

The app also measures timing with a `Stopwatch`. The timer starts when you tap **Generate Speech**. It records one time when the first audio data arrives, and another time when the full audio stream has finished.

The first audio data time is not always exactly the same as the first audible sound. The device audio decoder may need more than one MP3 chunk before it can produce sound. To reduce that delay, the app starts the audio player before the first network chunk arrives, so the player is already waiting for streamed data.

This is still not the same as the OpenAI Realtime API. The Speech API streaming path is good when you already have text and want generated speech to begin sooner. The Realtime API is better for full live voice conversations where audio input, model reasoning, and audio output all happen over a continuous session.

## Speaking Start and End Events

The app also tracks when the AI actually starts and ends speaking.

This is handled through the helper event bus files:

- `lib/helper/event_bus.dart`
- `lib/helper/events.dart`
- `lib/helper/subscription_helper.dart`
- `lib/helper/tts_speech_status_helper.dart`

The screen listens to `just_audio` player state changes. When the player becomes `ready` and `playing`, it fires:

```dart
AiSpeakingStartedEvent
```

When playback reaches `completed`, or when Stop / Reset is tapped after speaking has started, it fires:

```dart
AiSpeakingEndedEvent
```

`TtsSpeechStatusHelper` uses `SubscriptionHelper` to subscribe to these events and expose them as `ValueNotifier` fields for the UI:

```dart
speakingStarted
speakingEnded
```

The UI shows both fields with clock time and elapsed time after tapping **Generate Speech**.

## Current TTS Settings

The default settings are centralized in `OpenAiTtsService`, so they are easy to change later:

```dart
static const String defaultModel = 'tts-1';
static const String defaultVoice = 'coral';
static const String defaultResponseFormat = 'mp3';
static const double defaultSpeed = 1.0;
```

These values are passed in the API request body:

```json
{
  "model": "tts-1",
  "voice": "coral",
  "input": "Text typed by the user",
  "response_format": "mp3",
  "speed": 1.0
}
```

## Main Files

- `lib/main.dart` loads `.env` and starts the app.
- `lib/screens/tts_demo_screen.dart` contains the demo UI and audio controls.
- `lib/services/openai_tts_service.dart` contains the reusable OpenAI TTS helper.
- `lib/audio/live_tts_audio_server.dart` creates the local audio stream used by `just_audio`.
- `lib/helper/events.dart` defines AI speaking start/end events.
- `lib/helper/tts_speech_status_helper.dart` subscribes to speaking events and exposes UI state.

The UI does not call the API directly inside `build`. It calls the service from an async method, then updates small `ValueNotifier` objects for loading, error, and timing state.

The streaming path uses:

- `http.Request` and `client.send(...)` to receive streamed response chunks.
- `LiveTtsAudioServer`, a tiny localhost HTTP server, to provide progressive audio to `just_audio`.
- `eventBus.fire(...)` to publish AI speaking start/end events.

## Environment File

Create a `.env` file in the project root:

```env
OPENAI_API_KEY=sk-...
```

The `.env` file is loaded in `main.dart`:

```dart
await dotenv.load(fileName: '.env');
```

## Security Note

This project is only for local demo/testing.

Do not ship an OpenAI API key inside a production mobile app. A real production app should call your own backend, Firebase Cloud Function, or another secure proxy. That backend can keep the API key private and call OpenAI on behalf of the app.

## Packages Used

- `flutter_dotenv` loads the local `.env` file.
- `http` sends the OpenAI API request.
- `just_audio` plays the streamed audio.

## Run The App

From the project root:

```bash
flutter pub get
flutter run
```

## Android and iOS Notes

No microphone permission is needed because the app does not record audio.

No special storage permission is needed because the generated audio is not saved to disk.

Internet access is required because the app calls the OpenAI API.
