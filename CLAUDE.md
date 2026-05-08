# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

UniMarket is a SwiftUI-based iOS marketplace app for university students (restricted to `@uniandes.edu.co` emails). It features AI-powered style assistance, real-time chat, offline-first sync, and on-device CoreML clothing analysis.

## Build & Run

**Open in Xcode:**
```bash
open UniMarket-Swift/UniMarket-Swift.xcodeproj
```

**Build via CLI:**
```bash
xcodebuild -project UniMarket-Swift/UniMarket-Swift.xcodeproj \
           -scheme UniMarket-Swift \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           build
```

**Required configuration:** `UniMarket-Swift/Config.xcconfig` must exist with:
```
OpenRouterAPI = sk-or-v1-<key>
```
This file is gitignored. Copy from a team member or the project template.

**Dependencies:** SPM packages (Firebase, Kingfisher, OpenRouter) are managed entirely via Xcode — no `Package.swift` to edit manually. Run build once to resolve.

**Targets iOS 18+, requires Xcode 15+.**

## Architecture

### Global Stores (State Holders)

Three singleton `@EnvironmentObject`s are initialized at app launch and injected from `RootView` down the entire view tree:

- **`SessionManager`** — Auth state, current user profile, `isLoggedIn` gate
- **`ProductStore`** — Live Firestore product listener, Kingfisher prefetching, recommendations cache
- **`ChatStore`** — Firestore conversation listener, unread counts, offline message queue

These stores own all Firestore real-time listeners. ViewModels read from stores; they do not start their own listeners.

### ViewModels

All 16 ViewModels are `@MainActor ObservableObject`. One per screen. They receive stores via dependency injection in their initializers and call stateless Services for mutations.

### Services

Stateless singletons accessed via `static let shared`. They do not hold observable state — only perform async operations and return results. Services call Firestore/Firebase/OpenRouter directly.

### Offline Sync

Four `Pending*Syncer` singletons queue writes when offline and drain queues on reconnection via `NetworkMonitor` (NWPathMonitor):

- `PendingListingsSyncer`
- `PendingChatMessagesSyncer`
- `PendingFavoritesSyncer`
- `PendingListingMutationsSyncer`

UI shows optimistic updates immediately; syncers handle eventual consistency silently.

### Caching Layers

- **LRU in-memory caches** for recommendations scores, OpenRouter-generated eco messages, and user profiles (see `RecommendationsLRUCache`, `ProfileInsightsLRU`, `UserProfileCache`)
- **`ChatPhotoAnalysisCache`** memoizes CoreML inference by image hash
- **Kingfisher** handles image memory + disk caching and prefetching automatically
- **`AIStylistConversationFileStore`** persists AI chat history to disk as JSON per user

### Analytics

Strongly-typed event system — always use the `AnalyticsEvent` enum, never pass raw strings:

```swift
AnalyticsService.shared.log(.productViewed(id: product.id, surface: "browse"))
```

`AnalyticsValue` (string/int/double/bool) serializes to Firebase. Debug builds print all events to console. New events go in the `AnalyticsEvent` enum.

### AI / LLM Integration

`OpenRouterService` calls the OpenRouter API (key from `Config.xcconfig` build setting `OpenRouterAPI`). Used for:
- AI Stylist chat (`AIStylistChatViewModel`)
- Eco-friendly recommendation messages on seller profiles
- Impact insight generation

### On-Device ML

`CoreMLAnalysisFacade` wraps `MobileNetV2.mlmodel` for clothing category/color detection during listing creation (`ClothingAnalysisView`). Results are cached by image hash.

## Key Data Flow

```
Firestore ──► Stores (live listeners)
                  │
                  ▼
            ViewModels (@MainActor)
                  │
                  ▼
              SwiftUI Views
                  │
             user action
                  │
                  ▼
            ViewModel calls Service
                  │
              ┌───┴──────────┐
         online │          offline │
                ▼                  ▼
          Firestore         PendingSyncer queue
                                   │
                            syncs when online
```

## Firestore Collections

- `listings` — products, ordered by `createdAt` descending
- `users` — profiles, `savedItems` array, XP, ratings, profile pictures
- `conversations` — chat threads with shallow product/user snapshots embedded for query efficiency

## Important Conventions

- **Concurrency:** Use `async let` for parallel Firestore reads. Use `withThrowingTaskGroup` for parallel uploads. All UI mutations go through `@MainActor`.
- **New features:** Follow Store → ViewModel → View layering. Mutations go through a Service; never write to Firestore directly from a ViewModel.
- **New analytics events:** Add a case to `AnalyticsEvent` enum with associated values; log it in the ViewModel at the appropriate interaction point.
- **New caches:** Use the existing LRU implementation pattern (capacity-bounded, evict LRU on overflow).
- **Auth gate:** `SessionManager.isLoggedIn` controls root navigation. Email must be `@uniandes.edu.co` and verified.
