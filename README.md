# ExcuseMaster

AI-powered excuse generator for iOS. Pick a situation, category, and tone — get 3 tailored, copy-paste-ready excuses with reasoning and persuasion mechanics. Powered by x.ai's Grok API.

## Features

- **Generate** — Describe your situation, choose a category (Work, Social, Family, Health, Chores, Other) and tone (Funny, Believable/Professional, Dramatic, Short & Sweet). Get 3 excuses with "Why it works" explanations and the persuasion mechanics used.
- **History** — All generated excuses saved locally with search, swipe-to-copy, swipe-to-share, and swipe-to-delete.
- **Settings** — Secure API key entry, model selection (Grok 3 Mini / Grok 4.1 Fast Reasoning), and connection testing.

## Requirements

- Xcode 15+
- iOS 26.0+
- An [x.ai API key](https://x.ai)

## Setup

1. Clone the repo:
   ```
   git clone https://github.com/iliarafa/excuseMaster.git
   ```
2. Open `ExcuseMaster.xcodeproj` in Xcode.
3. Build and run on a simulator or device.
4. Go to the **Settings** tab and enter your x.ai API key.
5. Use **Test Connection** to verify, then start generating.

## Architecture

| File | Role |
|------|------|
| `ExcuseMasterApp.swift` | App entry point |
| `ContentView.swift` | All UI across 3 tabs, data models, and enums |
| `ExcuseGeneratorService.swift` | x.ai API client, networking, and response parsing |

No external dependencies. Pure SwiftUI with `URLSession` for networking.

## How It Works

Excuses are generated using a system prompt built around 7 persuasion mechanics:

1. **Plausibility Anchor** — common, hard-to-disprove situations
2. **Specificity Balance** — 1–2 vivid but flexible details
3. **Future-Oriented Close** — meaningful future commitment
4. **Emotional Layer** — empathy and sincere regret
5. **Risk Mitigation** — avoids dramatic, easily verifiable lies
6. **Relationship Tuning** — tone matched to the relationship
7. **Brevity & Natural Flow** — short, conversational, text-friendly

## License

MIT
