# SlotSpy Version Tracker

## Current State
- **pubspec version:** 1.0.0+69
- **TestFlight build:** 69
- **Last delivery:** fb2e17c4-9d11-44c7-930a-0a0c51af5649 (2026-04-17)

## Process
1. **BEFORE any upload:** check pubspec vs TestFlight build — they must match
2. **AFTER any upload:** record delivery UUID + date in this file
3. **NEVER bump pubspec without also updating this file**

## How to Check TestFlight Build Number
App Store Connect → SlotSpy → TestFlight tab → builds list shows build numbers.

## Build History

| Version | Build | Delivery UUID | Date | Notes |
|---------|-------|---------------|------|-------|
| 1.0.0 | 69 | fb2e17c4-9d11-44c7-930a-0a0c51af5649 | 2026-04-17 | Push service: raw APNs via UNUserNotificationCenter + method channel; BackendService: fetch gyms/slots/watches from custom backend; Settings screen: backend URL + test connection |
| 1.0.0 | 68 | 1e77c1ae-e257-4df9-b464-f063229f3f9b | 2026-04-16 | Add custom backend toggle in Settings; RpdeService supports backendUrl; SettingsProvider stores backend_url + use_custom_backend |
| 1.0.0 | 59 | 8cef45b9-210b-47a0-81bb-bd5060e9bdbf | 2026-04-16 | Loading overlay progress: pages loaded/total + gyms found + linear progress bar while fetching session-series |
| 1.0.0 | 58 | bae4cba1-7785-44e8-b3f8-2c31bf07c175 | 2026-04-16 | Fixed parallel fetch: sequential page URL discovery then bounded concurrent fetch in batches of 4 |
| 1.0.0 | 57 | 4b89a3a3-b114-4029-bf6a-4a70d326ead6 | 2026-04-16 | Memory-efficient parallel fetch: process each page immediately on arrival, don't accumulate all raw items in memory |
| 1.0.0 | 52 | 701d82ad-a487-4cbe-a498-f26274c8b615 | 2026-04-15 | Auto-advance on all stepper steps |
| 1.0.0 | 51 | 6d127b9d-1ef1-4f37-a032-a5c8ffe7177f | 2026-04-15 | Isolated _SessionStepContent widget |
| 1.0.0 | 10 | 6aece70b-acae-4add-bb47-8b1895f2b794 | 2026-04-15 | Gym step auto-advance |
| 1.0.0 | 9 | 2f41b302-9cba-4134-9441-aedb89860ad4 | 2026-04-15 | Session step loading spinner |
| 1.0.0 | 1 | 77936db8-7edd-4ce0-9a30-12f3f2fc5cdd | 2026-04-15 | First TestFlight release |
