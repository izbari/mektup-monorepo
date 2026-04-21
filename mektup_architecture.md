# Production-Grade AI-Powered Chat Platform

**Architecture & Engineering Specification**
**WhatsApp-Class Messaging with Invisible AI Translation**

- **Document Type:** Technical Architecture
- **Audience:** Engineering Leadership, Solo MVP Developer
- **Scope:** MVP to 10M+ Users
- **Platforms:** iOS, Android (Expo), Web
- **Version:** 1.0
- **Date:** April 2026

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Architecture](#2-system-architecture)
3. [Technology Decisions](#3-technology-decisions)
4. [Data Modeling](#4-data-modeling)
5. [Messaging System](#5-messaging-system)
6. [Local-First Sync Engine](#6-local-first-sync-engine)
7. [AI Integration](#7-ai-integration)
8. [Media System](#8-media-system)
9. [Voice and Video Calls](#9-voice-and-video-calls)
10. [Security and Privacy](#10-security-and-privacy)
11. [Performance](#11-performance)
12. [UI and UX Architecture](#12-ui-and-ux-architecture)
13. [Settings System](#13-settings-system)
14. [Authentication](#14-authentication)
15. [Backup and Restore](#15-backup-and-restore)
16. [Web Architecture](#16-web-architecture)
17. [Subscription and Monetization](#17-subscription-and-monetization)
18. [DevOps and Deployment](#18-devops-and-deployment)
19. [Scalability Roadmap](#19-scalability-roadmap)
20. [Risks and Tradeoffs](#20-risks-and-tradeoffs)
21. [Failure Modes and Data Integrity](#21-failure-modes-and-data-integrity)
22. [Feature Parity Checklist](#22-feature-parity-checklist)
23. [Conclusion](#23-conclusion)

---

## 1. Executive Summary

This document specifies the end-to-end architecture of a production-grade, horizontally scalable chat application that replicates the full feature set of WhatsApp and extends it with an **invisible AI translation layer**, a **voice-AI pipeline** (speech recognition, machine translation, speech synthesis), and **higher-order assistive features** (smart replies, tone rewriting, summarization).

The architecture is **local-first, event-sourced, and transport-agnostic**. The client is the source of truth for the user's interactive state; the server is a durable, ordered, replicated log that devices converge on. This model is the only architecture that simultaneously satisfies WhatsApp-class latency, robust offline behavior, multi-device consistency, and solo-developer operability at MVP — while allowing graceful migration to a custom backend at scale.

### Summary of Irrevocable Decisions

- **Client framework:** Expo (React Native) with the New Architecture (Fabric + TurboModules) as baseline.
- **Backend at MVP:** Supabase (Postgres, Realtime, Storage, Edge Functions). Migration plan defined.
- **Backend at scale:** Self-hosted Postgres (sharded) with Elixir Phoenix Channels; Cloudflare R2 for media; NATS JetStream as an event bus.
- **Local database:** WatermelonDB on top of SQLite. Final choice, justified in the Technology Decisions section.
- **Sync model:** Event-sourced log with a server-assigned per-chat sequence number (`chat_seq`), combined with Last-Writer-Wins with semantic guards. CRDTs rejected with justification.
- **Transport:** WebSocket, with HTTP REST fallback.
- **End-to-end encryption:** Signal Protocol (X3DH + Double Ratchet) with Sender Keys for groups.
- **Media:** S3-compatible object store behind a CDN, with resumable uploads and per-attachment AES-GCM encryption.
- **Calling:** WebRTC, LiveKit SFU, coturn TURN relays.
- **Web:** Same business-logic package (`@app/core`) compiled for browser; WASM SQLite + OPFS for local storage.

---

## 2. System Architecture

### 2.1 High-Level Topology

The platform is organized as three concentric layers around an ordered, append-only event log that is the canonical source of truth for all durable state.

- **Edge (clients).** iOS, Android (both on Expo), and Web. Each device keeps a complete local replica of the user's authored and received events. All user actions first mutate the local replica; network transport is a best-effort side channel.
- **Realtime fabric.** A stateful WebSocket fleet terminates client connections, authenticates devices, fans out events, and persists them into the log.
- **Durable core.** Postgres (sharded by chat) is the system of record for events, users, chats, devices, and subscriptions. Object storage holds media ciphertext. A small Redis layer caches presence, typing, and delivery state.

The AI layer (translation, speech, smart replies) is a set of stateless microservices fronted by an **AI Gateway** which enforces quotas, signs provider URLs, and never sees plaintext message content beyond what the client temporarily supplies for a single request.

### 2.2 Logical Architecture Diagram

```
Clients (iOS / Android / Web)
  ↓ WebSocket (primary) · HTTPS REST (fallback)
Edge Load Balancer (TLS, WS, HTTP/2)
  ↓
Realtime Fabric (WebSocket fleet) · REST / Edge Functions
  ↓
Event Router (NATS JetStream at scale; Postgres LISTEN/NOTIFY at MVP)
  ↓
Postgres Cluster (sharded by chat) · Object Storage (R2/S3 + CDN)

Parallel planes:
  • AI Gateway → Translation, ASR, TTS, Smart Replies, Summarization
  • Calling plane → coturn (TURN), LiveKit (SFU)
  • Observability → OpenTelemetry, Prometheus, Loki, Sentry
```

### 2.3 Client-Heavy, Backend-Light Strategy

The defining architectural commitment is that the **client is authoritative for UX-critical state**. Concretely:

- A sent message appears in the UI before the server acknowledges it. The server ack upgrades the delivery tick, not the message itself.
- Search, pagination, filtering, and chat-list grouping run against the local database. The server is never in the UI's critical path after first boot.
- Chat-list ordering, unread counts, and presence are derived client-side from the local event log, not pulled from the server.
- The server's job is reduced to: authenticate, order, persist, fan out, deliver ciphertext. It does not interpret message content.

**The result:** p99 UI latency is bounded by local disk I/O (single-digit milliseconds), offline is a first-class mode rather than a degraded one, and the server is stateless per request beyond the WebSocket session.

### 2.4 Offline-First Event System

Every user-visible mutation is modeled as an **operation**: send message, edit message, delete message, react, mark delivered, mark read, typing start, create chat, add member, and so on.

Every operation carries a client-generated unique identifier (**UUIDv7**, which is both globally unique and time-ordered), the author device identifier, a Lamport timestamp for local ordering, a wall-clock timestamp for display only, and a type-specific payload.

When the user performs an action, the operation is written to local storage together with its derived projection (the message row, the reaction, etc.) in a single transaction, and then enqueued into the **operation queue**. A background worker drains the queue against the server. Crashes, process kills, and network failures are all survived because the queue is durable.

### 2.5 Multi-Device Sync Model

A user can have up to **8 active devices** at once, mirroring WhatsApp's recent limit. Devices are peers — there is no primary device. Each device has its own identity key, connects independently to the realtime fabric, receives a copy of every event for chats the user is a member of, and maintains an independent per-chat cursor.

Messages sent from one device are echoed back to that same device via the event log (not via the optimistic local path), which makes every device's view of a chat eventually identical by construction. This is the same model Signal and modern WhatsApp multi-device use.

### 2.6 Realtime Infrastructure

| Concern | MVP (Supabase) | At scale |
|---|---|---|
| Transport | Supabase Realtime over WebSocket (Phoenix Channels) | Phoenix Channels (Elixir) or custom Go with NATS JetStream backplane |
| Ordering | Postgres logical replication | Append-only log in sharded Postgres with a per-chat sequence function |
| Fan-out | Realtime broadcasts inserts to subscribed devices | Dedicated fan-out service reads the log and pushes to device sessions |
| Presence / typing | Supabase Realtime presence channels | Redis pub/sub with TTL-backed keys |
| Push notifications | Edge function relays to APNs and FCM | Dedicated push service |

**WebSocket is mandatory, not optional.** Long-polling is only used as a degraded fallback on hostile networks (captive portals, restrictive corporate proxies).

---

## 3. Technology Decisions

### 3.1 Backend: Supabase vs. Firebase vs. Custom

| Criterion | Supabase | Firebase | Custom (Go / Elixir) |
|---|---|---|---|
| Data model | Relational (Postgres) | Document (Firestore) | Any; we chose Postgres |
| Realtime | Phoenix Channels over WebSocket | Firestore listeners | Phoenix Channels or NATS |
| Auth | GoTrue (phone, email, OAuth) | Firebase Auth | Ory / Keycloak / custom |
| Storage | S3-compatible | Cloud Storage | R2 / S3 |
| Vendor lock-in | Low (Postgres underneath) | High (proprietary) | None |
| Cost at MVP | Very low | Very low | High operational overhead |
| Cost at 10M MAU | Becomes expensive | Very expensive | Lowest per-message |
| Query power | Full SQL | Limited (no joins, strict index caps) | Full SQL |
| Exit migration | Trivial (standard Postgres dump) | Painful (proprietary formats) | N/A |

> **Decision: Supabase at MVP, custom Elixir/Go at scale**
>
> For the first 0–500k monthly active users, a solo developer cannot run a multi-region stack of Postgres, realtime, auth, and storage services without drowning in operations work. Supabase collapses all of these into a single managed product while keeping the door open — because it is built on open-source components and the data layer is standard Postgres.
>
> Once the platform exceeds roughly one million monthly users, or when Supabase costs exceed a few thousand dollars per month, we migrate to self-hosted Postgres (sharded by chat) with Elixir Phoenix Channels for realtime (same protocol, so clients are unchanged), dedicated auth, and Cloudflare R2 for storage. The migration path is planned at day one, which is why Firebase is rejected: leaving Firestore requires rewriting every query in the product.

### 3.2 Local Database: Final Decision

| Criterion | Raw SQLite | Realm | WatermelonDB |
|---|---|---|---|
| Storage engine | SQLite | Proprietary object store | SQLite under the hood |
| Expo compatibility | Excellent | Poor (requires native fork per RN version) | Good (config plugin for Dev Client) |
| Query performance | Excellent if indexed | Good, but object-oriented queries hide cost | Excellent; lazy observables prevent full reads |
| Reactivity | None native (hand-rolled) | Live objects (auto-update) | Observables that integrate with React |
| Sync support | None — write it yourself | Realm Sync (locks you to Atlas) | Built-in pull/push protocol, backend-agnostic |
| Memory footprint | Lowest | Highest (keeps hot objects mapped) | Low (lazy record loading by default) |
| Web support | WA-SQLite with OPFS | Realm Web is read-only | WA-SQLite adapter |
| Migration tooling | Manual SQL | Schema migrations | Migration DSL |
| License | Public domain | Apache 2.0 (Sync is paid) | MIT |

> **Local Database Final Choice: WatermelonDB**
>
> WatermelonDB is the correct answer for this workload, and the other options are measurably inferior.
>
> **It is SQLite underneath.** We inherit SQLite's two-decade stability, durability, and query planner without reimplementing any of it. On the web side, a WASM SQLite adapter gives us the same ergonomics in the browser.
>
> **Lazy loading is the default.** A chat screen with 100,000 messages does not load 100,000 rows. It observes a bounded query ("give me the last 50 messages in this chat by server sequence") and only those 50 records are materialized. This is the single biggest win over raw SQLite, where the developer has to hand-wire this behavior.
>
> **Observables integrate cleanly with React.** The UI layer subscribes to a query, and WatermelonDB emits a minimal diff when underlying rows change. Combined with a virtualized list, the result is WhatsApp-grade scroll performance with no manual invalidation code.
>
> **Built-in sync protocol.** The library ships with exactly the primitives our sync engine needs: push local operations, pull remote operations since a cursor, apply in a single transaction. We do not reinvent delta sync.
>
> **Why Realm is rejected.** Realm requires a native module tightly coupled to the React Native version. Every Expo SDK upgrade becomes a landmine. Realm Sync is a commercial offering locked to MongoDB Atlas, which defeats the "backend is not a hard dependency" principle.
>
> **Why raw SQLite is rejected.** Every feature WatermelonDB provides (lazy observables, reactive queries, sync, migrations, typed models) would have to be reimplemented by the developer. A chat app is the wrong project on which to also write a reactive ORM.

### 3.3 Client Framework and Tooling

- **Expo managed workflow** is sufficient until WatermelonDB requires its config plugin and native module. At that point the project switches to **Expo Dev Client** with continuous native generation (the `ios/` and `android/` folders are never hand-edited). This retains Expo's over-the-air updates and build infrastructure while unlocking any native module.
- **TypeScript** in strict mode everywhere.
- **Zustand** for ephemeral UI state; WatermelonDB observables for durable state. No Redux.
- **Tamagui** for styling, producing native styles on mobile and CSS on web with shared design tokens.
- **React Navigation** on mobile, **TanStack Router** on web.
- **Vitest** for core logic, **Detox** for end-to-end tests on mobile, **Playwright** for web.

---

## 4. Data Modeling

### 4.1 Design Principles

1. **UUIDv7 everywhere.** Globally unique, time-ordered, usable both as a primary key and a natural sort cursor. Avoids the hot-write shard caused by monotonically increasing integer keys.
2. **No hard deletes.** All deletions are tombstones (a `deleted_at` timestamp), which is required for event replay and multi-device convergence.
3. **Server-assigned per-chat sequence number.** The server atomically assigns a strictly increasing sequence number (`chat_seq`) to each event within a chat. This is the only value clients trust for ordering.
4. **Server does not see plaintext.** Message bodies, reaction metadata, and media are all stored as ciphertext. The server handles only opaque bytes plus the minimum metadata needed for routing and ordering.

### 4.2 Core Server Entities

The server persists the following entities. Only the conceptually essential columns are listed.

| Entity | Purpose and essential fields |
|---|---|
| **Users** | Identity and profile. Phone (E.164), optional email, display name, avatar, native language, privacy settings. |
| **Devices** | One row per trusted device per user. Platform, device name, public identity key, signed pre-key with signature, push token, registration time, revocation time. |
| **One-time prekeys** | Pool of Signal one-time prekeys per device, consumed during key exchange. |
| **Chats** | Metadata for a conversation: type (direct, group, broadcast), title, avatar, creator, last event pointer, optional chat-level language override. |
| **Chat members** | Membership rows linking users to chats. Role (owner, admin, member), join and leave times, mute-until, last-read sequence. |
| **Events** | The append-only log. Each event has an id, a chat id, a server-assigned sequence number, a sender, an event type, optional parent event (for edits, reactions, deletes), ciphertext, wall-clock time, server time. Hash-partitioned by chat id. |
| **Messages** | Projection derived from events of type `message.send`. Holds denormalized fields the server does not need but which simplify reads (ciphertext body, media reference, reply reference, edit/delete markers, original-language hint). |
| **Message receipts** | One row per (message, user, device, state) where state is delivered, read, or played. Drives the tick system. |
| **Reactions** | One row per (message, user, emoji). Added and removed as events. |
| **Attachments** | Metadata for each media upload. Mime type, byte size, dimensions, duration, storage key, thumbnail key, per-recipient-wrapped content key, SHA-256 integrity hash. |
| **Calls** | Call start and end times, type (audio / video), SFU room identifier, end reason. |
| **Call participants** | Join/leave times per user per call. |
| **Sessions** | Refresh-token handles for device authentication, with hashed tokens, expiration, last-seen IP and user agent. |
| **Subscriptions** | Tier, status, billing provider, period end, AI usage quotas and consumption counters. |
| **Backups** | Pointer records describing user-owned encrypted cloud backups; stores only key-derivation parameters and manifest references, never plaintext. |

### 4.3 Local (Client) Entities

The local database is leaner than the server. It holds the UI-queryable subset plus two sync-specific tables.

| Entity | Purpose |
|---|---|
| **Chats** | Denormalized per-chat header: title, avatar, last event timestamp, unread count, mute-until, pinned and archived flags, chat-level language override. |
| **Messages** | Decrypted message rows. Includes the plaintext body, the translated body (when applicable), a status enum (sending, sent, delivered, read, failed), star flag, edit/delete markers. |
| **Attachments** | Local upload/download progress plus decrypted local file path. |
| **Reactions** | Same shape as server: (message, user, emoji). |
| **Members** | Per-chat user list, with last-read sequence. |
| **Users** | Cache of contacts, including blocked flag and last-seen time. |
| **Operation queue** | Durable outbox of pending operations with attempts count, next retry time, and state (pending, in-flight, acked, dead). |
| **Sync cursors** | Per-chat last applied sequence and last pulled time. Advanced only inside the same transaction that applies events. |
| **Calls** | Local call history projection. |

### 4.4 Index Strategy

| Query | Index | Rationale |
|---|---|---|
| Load latest N messages in a chat | `(chat_id, sequence descending)` | The chat screen's hot path |
| Chat list by recent activity | `(last_event_timestamp descending)` | The home screen's hot path |
| Unread count per chat | `(chat_id, status)` | Filtered count on unread rows |
| Global text search | SQLite FTS5 virtual table on body | Local full-text search |
| Deduplicate event on ingest | `unique (chat_id, event_id)` | Idempotency guard |
| Receipts for a message | `(message_id)` | Drives tick rendering |
| Active devices for a user | partial index on non-revoked devices | Very small, hot-read |
| Contact lookup by phone number | `unique on phone` | Contact discovery |
| Starred messages | partial index where `starred = true` | Starred screen |

### 4.5 Partitioning Strategy

The event table is **hash-partitioned by chat id** into 64 partitions at MVP. Hashing keeps data evenly distributed; a time-range partitioning scheme would create a hot tail partition. The message, receipt, and reaction tables share the same partitioning key, keeping joins colocated.

Beyond about 100 million events, partitions are further split by `(chat_id, server_time)` range for cold-archive tiering: events older than eighteen months move to cheap storage, and block-range (BRIN) indexes replace standard B-trees for archival partitions.

### 4.6 Multi-Device Consistency Guarantees

1. **Per-chat total order** across all devices, by server-assigned sequence.
2. **At-least-once delivery** to every non-revoked device, with idempotent application guaranteed by the unique event id.
3. **Causal consistency within a chat:** if a device has seen an event that references a parent, it must have already seen the parent. This is enforced by refusing to apply an event whose parent is missing, and pulling the gap before proceeding.
4. **Read-your-writes:** after a local write commits, every subsequent read on the same device returns it, regardless of sync state.

---

## 5. Messaging System

### 5.1 Message Lifecycle

A message traverses up to nine states. Each transition is observable and has a corresponding UI affordance.

| # | State | Meaning and trigger |
|---|---|---|
| 1 | Composing | User is typing. Local draft, not yet an operation. |
| 2 | Queued | User tapped Send. Operation inserted in queue, message row inserted with `status = sending`. UI shows a clock icon. |
| 3 | In flight | Worker has picked up the op and sent it over the socket. |
| 4 | Sent | Server acknowledged: event persisted with an assigned sequence number. UI shows a single tick. |
| 5 | Delivered | Server reports that at least one recipient device received the event. UI shows double gray ticks. |
| 6 | Read | At least one recipient device marked the message read. UI shows double blue ticks. |
| 7 | Played | Voice messages only. Recipient listened to the audio. Microphone icon turns blue. |
| 8 | Edited | Author sent a subsequent edit event. UI shows "edited" label. |
| 9 | Deleted | Delete event applied. UI shows "This message was deleted." |

### 5.2 Send Path

When the user taps Send, the client performs a single local transaction that does three things atomically: it inserts the optimistic message row with status `sending`, it enqueues an outgoing operation in the durable queue, and it wakes the sync worker. The user sees the message instantly.

The worker then encrypts the payload per recipient device using the Signal session state, sends it to the server, and waits for the acknowledgement. The server returns the server-assigned sequence number, which the client writes back into the message row and simultaneously transitions the status to `sent`. **Crucially, the transaction that removes the op from the queue and updates the message status is the same one;** there is no intermediate state where the op has been removed but the status has not been updated.

If the process is killed between any of these steps, durability holds: either the op is still in the queue (and will be retried) or it has been fully applied.

### 5.3 Delivery Guarantees

| Guarantee | Mechanism |
|---|---|
| At-least-once to the server | The op stays in the queue until the server returns an acknowledgement. Crash-safe. |
| Exactly-once application | The server deduplicates on a unique index over `(chat_id, event_id)`. Retries are transparent. |
| At-least-once to recipient devices | Each connected device's socket session acknowledges each event. Unacked events are resent on reconnect via the cursor pull. |
| Exactly-once client apply | The client deduplicates on a local unique index over the remote event id. |
| Per-chat ordering | Readers sort by the server-assigned sequence number. Gaps are detected and filled by a range pull. |

### 5.4 Retry and Backoff

The worker retries failed operations with **exponential backoff and full jitter**: after the n-th failure, the next attempt is scheduled at a random point in the interval `[0, min(30s, 2^n · 0.5s)]`. After ten failed attempts, the operation is marked `dead` and the UI surfaces a "tap to retry" affordance that resets the attempt counter.

Retryable errors include network failures, 5xx responses, and 429 rate limits (the client honors the `Retry-After` header). Non-retryable errors — such as an invalid signature or "you were blocked by the recipient" — transition the op directly to `dead`.

### 5.5 Deduplication

Three independent layers of deduplication guarantee at-most-once visible effect:

1. The client never enqueues the same operation id twice.
2. The server enforces uniqueness on `(chat_id, event_id)`; duplicate inserts return the original sequence number, so retries are transparent.
3. The recipient client ignores events whose remote id already exists in its local messages table.

### 5.6 Ordering

The system guarantees **total order per chat**. Global total order is neither promised nor needed — two events in different chats have no causal relationship visible to the user.

Within a chat, order is exclusively the server-assigned sequence number. The server assigns it inside an advisory lock per chat (using the chat id as the lock key) plus a unique-violation guard against reinsertion. This serializes writes only within a single chat, giving high cross-chat concurrency.

### 5.7 Read Receipts

Three granularities, all user-configurable:

- **Delivered:** emitted when the event lands on a recipient device. Batched and debounced by 200 milliseconds. Not privacy-sensitive and cannot be disabled.
- **Read:** emitted when the recipient has the chat screen focused and the message is visible in the viewport. Batched and debounced by 400 milliseconds. If the user disables read receipts, the server enforces symmetry: that user also stops seeing the read state of others.
- **Played:** voice messages only, emitted when playback passes 90% of the audio duration or the user replays the message within the same session.

For direct chats, a tick goes blue when any of the recipient's devices reads. For groups, the read indicator requires all non-muted members to have read.

### 5.8 Typing Indicators

Typing indicators are **ephemeral and never persisted**. They travel over a separate presence channel. The client emits a typing start on the first keystroke, refreshes it every three seconds while typing continues, and emits typing stop five seconds after the last keystroke or immediately on send. Recipients display the indicator with a five-second auto-decay if no refresh arrives.

---

## 6. Local-First Sync Engine

### 6.1 Invariants

> **Sync Engine Invariants**
>
> 1. Local writes never block on the network.
> 2. Every durable mutation is an event with a globally unique, time-ordered identifier.
> 3. The server assigns the authoritative per-chat sequence number.
> 4. Clients maintain a per-chat cursor. Sync is "pull everything above my cursor, push everything in my queue."
> 5. All operations are idempotent by virtue of their event id.
> 6. The local database is the source of truth for the UI; the server is the source of truth for cross-device convergence.

### 6.2 Event Sourcing Model

The server's `events` table is the full write log. **Projection tables** (messages, reactions, receipts) are cached views, computed by applying events. Rebuilding a projection from the event log is a supported administrative operation; this is what makes backups, restores, and re-bootstrapping safe.

The event types currently modeled are: `message.send`, `message.edit`, `message.delete`, `reaction.add`, `reaction.remove`, `chat.create`, `chat.add_member`/`remove_member`, `chat.update_metadata`, `delivery_receipt`, `read_receipt`, `call.start`, and `call.end`. Each type has a strictly typed payload; projection handlers are pure functions of the previous state and the incoming event, which is what makes replay safe.

### 6.3 Operation Queue

The local operation queue is the durable per-device outbox. A single background worker drains it, processing one operation per chat at a time but handling multiple chats in parallel. For each operation it:

1. Marks the operation `in_flight`.
2. Calls the server, which responds with an acknowledgement (containing the event id, assigned sequence number, and server timestamp) or an error.
3. On acknowledgement, in a single local transaction, applies the ack to the corresponding message row (updating its sequence number, server timestamp, and status) and removes the operation from the queue.
4. On a retryable error, increments the attempt counter and schedules a next retry with jittered exponential backoff.
5. On a non-retryable error, marks the operation `dead` and surfaces a user-visible failure indicator.

### 6.4 Conflict Resolution

> **Decision: Last-Writer-Wins with semantic guards. CRDTs rejected.**

The system uses **Last-Writer-Wins**, scoped and guarded:

- "Writer" is defined as the event with the larger server-assigned sequence number. Because the server assigns the sequence, "last" is unambiguous across devices without needing clock synchronization.
- For **message edits**, the edit with the highest sequence wins; earlier edits remain in the event log as history but are not displayed.
- For **deletes**, a delete always wins over any concurrent edit, regardless of sequence (delete is absorbing).
- For **reactions**, the operation model is set semantics: add and remove per (user, emoji) pair. The last operation per key wins. This is a trivially-conflict-free grow-only set with tombstones — a degenerate CRDT we get for free.

**Why not full CRDTs (Automerge, Yjs)?** Messaging is append-dominant with point mutations; it is not collaborative text editing. The overwhelming majority of operations (send, react, ack) are additions, which are inherently conflict-free. The rare in-place mutations (edit, delete) are semantically owner-only — only the author may edit or delete-for-all — which eliminates 95% of possible conflicts by construction. Full CRDT libraries impose three-to-tenfold storage overhead per message, non-trivial merge cost on every incoming event, complex garbage collection for history compaction, and an unfamiliar programming model that slows feature velocity for a solo developer.

Last-Writer-Wins over a server-assigned sequence number gives the same convergence guarantees for our operation set with none of this overhead. It is the same reason Signal, WhatsApp, and Telegram do not use Automerge.

### 6.5 Per-Chat Sync States

| State | Meaning and transitions |
|---|---|
| **Bootstrap** | First time this device sees this chat. Initial snapshot plus cursor. |
| **Catching up** | Cursor lags the server head. Pulling events in pages of 200. |
| **Live** | Cursor equals the server head. Events arrive as they happen over the socket. |
| **Degraded** | WebSocket disconnected. The op queue continues locally; pulls resume on reconnection. |
| **Gap** | A missing sequence number was detected. Issue a range fetch. |
| **Error** | Unrecoverable condition (for example, chat no longer accessible). Surface to UI. |

### 6.6 Delta Sync Protocol

The protocol has three operations. The client **pushes** a batch of local operations; the server returns acknowledgements for each. The client **pulls** events above its per-chat cursor, with the server returning up to a bounded number of events along with a `has_more` flag and the next cursor. The client **subscribes** over the WebSocket with its current cursors; the server then pushes events as they are persisted.

**Gap detection.** When the client is in the live state and receives an event with sequence `N+2` while its cursor is at `N`, it enters gap state, fetches the range `(N, N+2]`, applies it in order, and returns to live.

### 6.7 Reconciliation After Reconnect

On reconnection, the client reauthenticates the device and subscribes with its current cursors. The server responds with a sync hint giving the current head sequence for each chat. If the gap is small (say, fewer than 50 events), the client relies on fan-out replay and the events simply stream in. If the gap is large, the client issues range pulls and catches up in bounded pages.

Throughout catch-up, the client continues to render from its local database; new events simply append. The op queue resumes draining in parallel. Any operation whose acknowledgement was lost during the disconnect is retried; the server's deduplication index makes this safe.

### 6.8 Adversarial Edge Cases

| Scenario | Behavior |
|---|---|
| Duplicate message (retry after lost acknowledgement) | The server deduplicates on event id and returns the original sequence. The client deduplicates on its local unique index. The user sees exactly one message. |
| Cross-device ordering | Clients sort by server sequence. Even if device wall clocks are hours apart, the chat renders identically on all devices. |
| Clock drift | Never used for ordering. Wall-clock timestamp is shown only when its deviation from the server time is below two minutes; otherwise the server time is displayed, preventing obviously wrong dates. |
| Offline edit of an un-sent message | The edit is coalesced with the pending send: the outgoing send uses the final body. No separate edit event is emitted. |
| Offline delete of an un-sent message | The send op is removed from the queue and the message row is hard-deleted locally. No event is ever emitted. |
| Offline edit of a sent message | The edit op is enqueued normally and becomes a regular edit event on reconnection. |
| App killed mid-sync | The op queue is durable and the worker resumes on restart. A pull cursor is advanced only after the transaction commits, so a half-applied pull is replayed, not skipped. |
| Partial page failure on pull | Pulls are per chat; a 5xx on one chat does not stop others. Retried with backoff. |
| Device revoked during drain | The server returns a device-revoked error. The client wipes local cipher state and triggers the re-pair flow; the queue is preserved and retried once the device is re-paired. |
| Clock goes backwards | UUIDv7 generation enforces monotonicity via a per-process counter, so event ids remain unique even under clock moves. |

### 6.9 Idempotency and Replay Safety

Every mutating primitive — client operation, server event application, client event projection — is idempotent:

- Applying the same operation twice produces the same state as applying it once.
- Replaying a full event stream from scratch produces identical projections, because projection handlers are pure functions and deletes are tombstones.
- Re-bootstrapping a device is equivalent to restoring from the log; the only difference is that ephemeral state (typing, presence) is not replayed.

### 6.10 Position on the CAP Spectrum

The system is **AP with eventual consistency, tending toward strong consistency within a single chat**. Clients always accept writes (queuing them locally). Servers accept writes whenever the chat's primary shard is reachable. Within a chat, writes against the shard are linearizable (advisory lock plus unique index); reads from the client accept causal consistency from the local replica, and linearizable reads are available on demand directly from the primary when required.

---

## 7. AI Integration

### 7.1 The E2EE / Server-Side-AI Tradeoff

> **Critical Tradeoff**
>
> End-to-end encryption means the server cannot read plaintext. Therefore **all AI processing that requires plaintext runs on the device** — on the author's device for outgoing content and on the recipient's device for incoming content — never on our servers. The AI Gateway is a proxy to providers that the client talks to directly via short-lived signed URLs, so the provider sees plaintext temporarily but our servers do not store it.
>
> This is the only architecture consistent with Signal-model E2EE. WhatsApp, Signal, and iMessage all make the same choice for on-device AI features.

### 7.2 Invisible Translation

Translation is performed by the **recipient device, per recipient, per target language**. This is the only way to support a 3-person group where members speak, say, Japanese, Turkish, and French and everyone sees the conversation in their own language.

The flow is simple: when a message arrives, the recipient decrypts it, reads the embedded original-language hint, compares it against the user's preferred language (or the chat-level override), and — if they differ — calls the translation service via the gateway. The translated body is stored locally alongside the original. The UI shows the translation by default with a long-press "show original" toggle.

Key properties:

- The author's native language travels inside the encrypted payload; the server never sees it.
- A **per-chat language override** lets users pin a chat to stay in the original language (useful when practicing a foreign language). This is a local preference, not synced.
- Every translated message offers a long-press "show original" action.
- The client maintains a local LRU cache keyed by `(body_hash, source_language, destination_language)`. Repeated common phrases are free to translate.

### 7.3 Voice AI Pipeline

The voice pipeline is **end-to-end on-device**. On the sender side, audio is recorded (Opus at 32 kbps, mono), optionally trimmed by a local voice activity detector, and uploaded as an encrypted attachment. On the recipient side, the behavior depends on the user's voice AI setting:

- **Play original.** Default; the audio is simply played.
- **Subtitles only.** The audio is transcribed (ASR), the transcript is translated into the user's language, and the original audio plays while the translated text is shown as a caption.
- **Dubbed TTS.** The audio is transcribed, translated, and resynthesized via text-to-speech into the user's language. The synthesized audio replaces the original in playback.

**Tone and speed preservation.** The TTS input carries prosody hints derived from ASR-estimated speaking rate and pitch contour deciles. This is imperfect but measurably better than default TTS. **Voice-preserving TTS** (speaker-cloning) is gated behind the Pro tier and requires an explicit consent prompt from the original speaker, in line with emerging voice-likeness regulations.

### 7.4 Provider Abstraction and the AI Gateway

All AI calls pass through a single **abstract provider interface**, so underlying providers (OpenAI, DeepL, ElevenLabs, Whisper, and alternatives) are swappable without touching feature code. A fallback chain exists for each capability: primary, secondary, on-device fallback.

The server-side **AI Gateway** is the only backend component that touches AI providers. Its responsibilities are:

- **Signing:** issues short-lived URLs that authorize a specific device to call a specific provider endpoint within a specific budget.
- **Accounting:** atomically decrements the user's usage quota before routing.
- **Fallback routing:** if the primary provider is over quota or unavailable, rewrites the signed URL to the next provider in the chain.
- **Redaction:** strips provider API keys from any client-bound response.
- **Rate limiting:** enforces per-user and per-device caps.
- **Never logs plaintext:** logs only size, duration, and hash metadata.

### 7.5 Cost Optimization

| Technique | Impact |
|---|---|
| Client-side LRU cache | Repeated translations ("ok", "thanks") are free. Measured hit rates of 38–55% on realistic corpora. |
| Server-side content-hash dedup | Multiple users receiving the same forwarded message translate once; cached keyed by `(body_hash, language_pair)`. |
| Batching | The client translates a page of messages in a single provider call. Cuts 70–85% of sync-after-reconnect cost. |
| Length-based routing | Short messages go to a cheap model or on-device MLKit; medium to a mid-tier LLM; long to a top-tier LLM. |
| Lazy translation | Messages in chats the user has not opened in seven days are not translated until the chat is opened. |
| TTS pre-warm cache | On first decode, cache keyed by `(text, voice, speed)`; replay is free. |
| Quota enforcement | Free tier strictly limited; Pro tier bypasses cheap-model routing for quality. |

### 7.6 Latency Strategies

The target user-facing latency budget is: **translation appears within 400 milliseconds on Wi-Fi and 900 milliseconds on LTE**. This is below the "feels instant" perceptual threshold.

Techniques used to meet this budget:

- **Optimistic render.** Show the original immediately; swap in the translation when it arrives. The UI never blocks.
- **Streaming.** For long messages, the gateway streams the translated tokens as they are produced; users see words appearing.
- **Prefetch.** As the user scrolls into a chat, the next fifty messages are translated ahead of the scroll position.
- **On-device fallback.** For common language pairs (English with Spanish, French, Portuguese, Japanese, Turkish), shipped MLKit/ONNX models provide offline, zero-latency translation of short messages.

### 7.7 Smart Replies, Tone Rewriting, Summarization

- **Smart replies** are generated from the most recent ten messages in a chat. Three short suggestions are produced. The cache key is the chat-state hash; it is invalidated on any new event.
- **Tone rewriting** is invoked from the compose bar, with choices like "more formal", "friendlier", "shorter", or "apologetic". Edits apply to the draft only; no server state is involved.
- **Summarization** is invoked from the chat's menu as "Summarize unread". The client decrypts the unread range, sends it to the LLM, and renders a transient bubble at the top of the chat. The summary is not a message and is not persisted.

---

## 8. Media System

### 8.1 Requirements

The media system handles images, videos, documents, audio, voice, stickers, and GIFs, with a **2 GB cap per attachment**. Every attachment is encrypted end-to-end with **AES-256-GCM** using a random per-attachment content key; that key is wrapped per recipient device using the Signal-session key to that device and carried inside the encrypted message payload. Uploads are resumable (tus-like), downloads are progressive (thumbnail → low-resolution → full), and origin storage sits behind a CDN with a target cache-hit ratio above 95%.

### 8.2 Upload Pipeline

When the user attaches media, the client generates a random content key and a SHA-256 hash of the plaintext for integrity checking. It then encrypts the blob in 4 MB chunks using AES-GCM, with per-chunk nonces derived from the content key and the chunk index; the encrypted chunks are concatenated into the upload object.

The client initiates a multipart upload against the storage service, uploads chunks in parallel (up to four concurrent), and persists the byte offset after each acknowledged chunk. If the process is killed mid-upload, it resumes from the last acknowledged offset. When all chunks are in, the client tells the server to finalize and the server writes the attachment metadata row. The content key is then wrapped per recipient device and carried in the outgoing message payload.

### 8.3 Download and Progressive Loading

On event arrival, the message carries the attachment id and the wrapped content key. The client unwraps the key locally, fetches a signed CDN URL, and begins downloading.

For images and video, the small encrypted thumbnail (typically 20–30 KB) is fetched and decrypted first so a blurred preview appears immediately. Full-resolution assets download in the background when the user is viewing the chat, and are deferred for other chats unless the user's media auto-download preferences explicitly permit.

### 8.4 CDN and Storage Lifecycle

| Layer | Strategy |
|---|---|
| Origin | Supabase Storage at MVP; Cloudflare R2 (zero egress cost) or S3 with CloudFront at scale. |
| CDN | Cloudflare in front of R2 for global caching; signed URLs scoped to an attachment and a device. |
| Encryption at rest | Objects are stored as opaque bytes; the application's AES-GCM provides content-level security. The platform's server-side encryption is still enabled for defense in depth. |
| Lifecycle | Media older than 90 days with no starred references is transitioned to infrequent-access storage. Media from delete-for-all messages is purged within 24 hours. |
| Deduplication | Ciphertext hash deduplicated at the storage layer — the same forwarded meme from many users is physically stored once. |

### 8.5 Thumbnails, Blurhash, and Voice Waveforms

- **Images.** A 320-pixel JPEG thumbnail and a BlurHash string are generated on the device before upload. Both travel encrypted.
- **Videos.** A poster frame is extracted (same pipeline as images) along with an estimated duration. Short clips get an HLS variant generated locally.
- **Voice messages.** A 128-bucket amplitude array is computed on the device for the waveform display; it travels as encrypted metadata.

---

## 9. Voice and Video Calls

### 9.1 Architecture

Calls use **WebRTC in a hybrid peer-to-peer plus SFU model**. One-to-one calls go peer-to-peer, falling back to a TURN relay when direct connections fail. Group calls are routed through a **LiveKit Selective Forwarding Unit (SFU)**: each participant uploads one stream to the SFU, which forwards it to all other participants. This handles 50+ participants per room. A multipoint control unit (MCU) is deliberately not used; the cost and latency tradeoff is not worthwhile for the target user experience.

### 9.2 Signaling

Signaling piggybacks on the existing WebSocket fabric via a dedicated namespace per call. The handshake is the standard WebRTC exchange — offer, answer, ICE candidates — relayed through the signaling channel. Signaling payloads are never persisted in the event log; they are ephemeral. Call start and end events (without SDP) are persisted as chat events so call history is part of the chat.

### 9.3 TURN and STUN

STUN reflexion uses public servers plus our own. **TURN relays** run as a coturn fleet behind Anycast IPs, accepting TLS on port 5349 and UDP on port 3478, and additionally port 443 for restrictive networks. TURN is mandatory for symmetric-NAT and carrier-NAT mobile clients, which are roughly 20–30% of traffic in practice.

TURN credentials are HMAC-derived from a shared secret with a 10-minute time-to-live, issued by the signaling service when a call starts. There are no long-lived TURN accounts. TURN is colocated with the SFU so relayed traffic never leaves the datacenter twice, which dramatically reduces egress cost.

### 9.4 SFU Scaling

Each LiveKit node runs per region and autoscales by CPU utilization and participant count, targeting less than 40% CPU at steady state. Clients publish three simulcast encodings (low, medium, high) and the SFU subscribes each recipient to the appropriate layer for their available downlink; this is what makes 20-participant video on LTE workable.

One-to-one calls are end-to-end encrypted via DTLS-SRTP between peers. Group calls are transport-encrypted at the SFU boundary at MVP; a sender-keys-style construction for group-call E2EE is a v2 feature with explicit transparent documentation in the interim.

### 9.5 Capacity Targets

| Metric | Per-node target | Fleet scaling |
|---|---|---|
| TURN relay throughput | 1 Gbps per node | Horizontal; Anycast ensures locality |
| SFU participant streams | 500 concurrent streams | Horizontal; sticky room-to-node |
| Concurrent calls | 2000 per signaling node | Signaling is stateless beyond the socket |
| Max participants per call | 50 at MVP, 100+ at scale | SFU CPU-bound above about eight active speakers |

---

## 10. Security and Privacy

### 10.1 Threat Model

| Adversary | Capability and mitigation |
|---|---|
| Passive network observer | Can see all traffic. Mitigated by TLS 1.3 end-to-end. |
| Our own server | Has ciphertext and metadata but cannot read message plaintext. Metadata minimization is the defense against compromise or legal compulsion. |
| Malicious server-side insider | Same as above, plus audit logging on administrative access; the admin console cannot decrypt messages. |
| Stolen unlocked device | Local database is accessible to the user's OS session. Mitigated by OS-level encryption and an optional in-app biometric lock. |
| Stolen locked device | The database encryption key is stored in a hardware-backed keystore (iOS Keychain, Android StrongBox, or equivalent). |
| Compelled disclosure | We can only produce metadata (chat-member graph, timestamps, IP addresses). We cannot decrypt messages. Backups, if stored in the user's iCloud or Google Drive, require the user's backup password to decrypt. |

### 10.2 End-to-End Encryption

We use the **Signal Protocol** — X3DH for initial key agreement and the Double Ratchet for ongoing communication. Every device in the system is an independent Signal endpoint with its own long-term identity key.

When Alice first messages Bob, Alice fetches Bob's identity key, his signed pre-key, and a one-time pre-key from the server. Four Diffie-Hellman values are computed and hashed into a single shared secret, which initializes the Double Ratchet for the session. Thereafter, each message advances a symmetric chain, and a DH ratchet step occurs at every direction change — giving **forward secrecy** (compromise of today's key does not decrypt yesterday's messages) and **post-compromise security** (one new DH step restores secrecy).

Group messaging uses **Sender Keys**, which avoids pairwise-encrypting the same message to every member for each send. Each member maintains a per-group symmetric chain; the chain key is delivered to each member via their Signal session when the group is formed or membership changes. Membership changes trigger sender-key rotation.

### 10.3 Device Registration and Trust

A new device generates its identity keypair and pre-key bundle locally; private keys never leave the device's keystore. The public half is registered with the server at first login.

For a new device to be trusted for an existing user's chats, it must be linked from an already-trusted device via a QR-code flow. The existing device generates a one-time linking secret, encodes it in a QR code with the server URL and the user id, and the new device scans to register. The existing device then cross-signs the new device's identity key — the server accepts the new device only if the cross-signature is valid. Sender Keys for all existing groups are pushed to the new device over the just-established Signal sessions.

Phone-number login without a pre-existing trusted device — a first device or a restoration after a lost device — requires an OTP and **does not recover message history**. History lives only in encrypted backups or on other trusted devices. This is an explicit, documented privacy contract.

### 10.4 Key Management and Rotation

The **signed pre-key** rotates weekly, with a one-week grace period for the previous key. The client keeps a pool of 100 **one-time pre-keys** on the server and replenishes when the pool dips below 20. The **long-term identity key** is device-scoped and is rotated only via re-linking. **Ratchet keys** rotate per message (symmetric) and per direction change (DH).

### 10.5 Secure Local Storage

On mobile, the local database is encrypted with **SQLCipher (AES-256)**; the database key lives in the OS keystore (iOS Keychain with "after-first-unlock, this device only" access, Android Keystore with StrongBox where available). Private Signal keys are kept in the same keystore, never exported, never included in backups in plaintext. On the web, storage is AES-GCM encrypted via Web Crypto, with the key wrapped by a user-derived key-encryption key.

An optional **app lock** provides a biometric gate on foreground entry; it does not change storage keys, only the UI gate.

### 10.6 Metadata Minimization

The server must hold certain metadata — device keys, the chat-member graph, delivery states, and timestamps — in order to route messages. The server **must not** hold message plaintext, attachment plaintext, or reaction content. Receipts carry only message ids and state values; attachment records carry only ciphertext references and cryptographic handles. Application logging is strictly event-level (user id, device id, action, timestamp, size) and never includes content. A CI lint rule blocks any code change that introduces content-level logging.

---

## 11. Performance

### 11.1 Pagination and List Virtualization

The chat screen observes a WatermelonDB query ordered by sequence descending, with a live limit of 60 materialized rows. The list is rendered by **FlashList** (Shopify's virtualized list component), with item heights pre-measured for text-only messages and cached by message id for media. Upward scrolling loads 60-row pages with a 200-millisecond debounce; downward scrolling is always live via the observable. Switching chats tears down the observer so memory is released.

### 11.2 Background Sync

On iOS, background refresh uses `BGAppRefreshTaskRequest` with a 30-minute minimum interval, reinforced by silent high-priority push to wake the app within a bounded 28-second window for draining the op queue and pulling new events. On Android, WorkManager periodic jobs (15-minute minimum) plus FCM high-priority expedited work provide the same.

A full cold sync of 500 new events is capped at a 2 MB download. Background sync never runs AI translation — translation runs on foreground entry — so the user sees originals first and translations land as they open each chat.

### 11.3 Memory Optimization

| Technique | Detail |
|---|---|
| Virtualized list rendering | FlashList recycles view instances by type; target RAM under 80 MB for a chat with 100,000 local messages. |
| Thumbnail-first media | Full-resolution images are downloaded lazily; memory holds only the two visible full images. |
| Bounded caches | The translation cache uses a bounded LRU, not an ever-growing object. |
| Hermes engine | Mandatory; yields a measurable 30–40% baseline RAM reduction. |
| Turbo modules | WatermelonDB and libsignal expose Turbo Module interfaces where possible, avoiding bridge marshalling cost. |
| Image decoder | The image component uses `expo-image` (libjpeg-turbo plus memory and disk cache). |
| Bounded observables | UI observables have explicit take and distinct operators; no unbounded streams. |

### 11.4 Startup Performance

The target is **under 1.2 seconds** from cold start to the chat list rendered on a mid-tier Android (Pixel 4a class). Work deferred past first paint includes Signal session load, media download workers, and AI warm-up. SQLite is tuned for latency over throughput: WAL mode, `normal` synchronous, 20 MB cache. The Hermes bundle is precompiled and shipped.

### 11.5 Real-World Constraints

| Constraint | Mitigation |
|---|---|
| Flaky networks | All writes local-first; op queue durable; exponential backoff; idempotent retries. |
| High latency | Optimistic UI; speculative execution; batched RPCs; server sequence remains correct. |
| Partial sync failure | Per-chat cursors advance independently; one failing chat does not block others. |
| Tight mobile memory | Lazy queries, virtualized lists, bounded caches, Hermes, lazy records. |
| Low disk space | Storage quota in settings with automatic cleanup of orphan media. |
| Battery sensitivity | Single WebSocket connection with 45-second heartbeat; push-driven in background. |
| Clock drift | Ordering uses server sequence; wall-clock timestamps are suppressed when more than two minutes off. |

---

## 12. UI and UX Architecture

### 12.1 Information Architecture

Top-level tabs are **Chats, Calls, Updates (Status), Communities (v2), and Settings** (as a modal stack reached from Chats). The Chats tab has a search bar at the top, a pinned-chats section, a filter bar (All, Unread, Groups, @Mentions), and archived chats in the footer.

### 12.2 Chat Screen Behavior

Consecutive messages from the same sender within a three-minute window collapse into a single bubble group; only the last shows a timestamp and only the first shows the avatar. Day separators are sticky headers inserted between messages that cross a date boundary in the device's time zone. Right-swipe on a bubble pulls it up into the compose bar as a quoted reply. Long-press opens a context sheet with react, reply, forward, copy, star, delete, edit (for the author), info, and show original (for translated messages). The list auto-scrolls to the bottom when a new message arrives if the user is within 120 pixels of the bottom; otherwise a "new messages" pill appears.

### 12.3 Tick System Logic

| Tick | Meaning | UI condition |
|---|---|---|
| Clock | Queued or in flight | Status is `sending` or `in_flight` |
| Single gray | Sent | Status is `sent` |
| Double gray | Delivered | Any delivered receipt exists for any recipient device |
| Double blue | Read | Any read receipt exists (direct chat) or all non-muted members have read (group) |
| Red triangle | Failed | Status is `failed`; tap to retry |

Voice messages additionally show a blue microphone icon when they reach the played state.

### 12.4 Reactions UI

A long-press opens an emoji picker strip showing the six most recent reactions plus a `+` for the full picker. Reactions are aggregated under the message in a pill, such as `♡ 3 ☞ 5`, and tapping the pill opens the list of users who reacted. Tapping the user's own emoji toggles it off.

### 12.5 Presence and Typing

A green "online" dot appears on an avatar when the user's last-active time is within the last 30 seconds and their last-seen privacy setting permits. The typing indicator replaces the last-seen line in the header with "typing...". For groups it reads "Alice and Bob are typing..." for up to two names and falls back to "3 members typing..." beyond that.

### 12.6 Error States

| State | UI |
|---|---|
| Network down | A subtle banner at the top of the screen: "Waiting for network..." Does not block typing or sending. |
| Reconnecting | A small "Connecting..." pill that disappears within 2 seconds of reconnection. |
| Message send failed | Red triangle on the bubble; tap to retry. |
| Upload failed | Red triangle on the media bubble with a retry action. |
| Translation failed | Original is shown with a small subscript "(couldn't translate)"; retries on tap. |
| Call failed or dropped | Toast: "Call ended — connection lost" with a redial button. |
| Auth expired | Full-screen modal: "You've been signed out on this device," linking to re-login. |

---

## 13. Settings System

Settings form a nested tree. Each leaf is either a **local preference** (in which case it is synced across the user's devices via a small `pref.set` event) or an **account-level property** (stored on the user record and propagated to all devices).

### 13.1 Account

- **Phone number.** Change via OTP on both old and new numbers. A migration event links all chats to the new number transparently.
- **Email.** Add and verify via magic link; used as a second-factor or recovery channel.
- **Two-step verification.** A user-set PIN plus an optional recovery email. Required for phone-number changes and backup restores.
- **Request account info.** Generates a downloadable zip of non-message metadata (profile, chat graph, subscription) within 72 hours. Messages are not included; they are end-to-end encrypted and unavailable to us.
- **Delete account.** Triggers a 30-day soft deletion; after the grace period, all server-side rows are removed and media is purged. Messages on recipients' devices are not removed — those are part of others' chat history and are not ours to delete unilaterally.

### 13.2 Privacy

- **Last seen and online.** Everyone, My contacts, My contacts except..., Nobody. Symmetric: hiding yours hides others'.
- **Profile photo, about.** Same granularity as last seen.
- **Status (stories).** Granular visibility list.
- **Read receipts.** On or off; disabling disables them bidirectionally for you.
- **Groups.** Who can add you.
- **Live location.** Default off; per-chat enable with TTL (15 minutes, 1 hour, 8 hours).
- **Blocked contacts.** List with unblock action; blocked users' messages reach the server and are dropped.
- **Disappearing messages (default).** Off, 24 hours, 7 days, or 90 days. Per-chat override available.
- **App lock.** Biometric or PIN gate with timeout.
- **Chat lock.** Hide specific chats behind an extra biometric layer; locked chats bypass default notification previews.
- **Screenshot notifications** (iOS only; Android cannot reliably detect).

### 13.3 Chats

- **Theme:** System, Light, Dark.
- **Wallpaper:** default, solid colors, or user images; per-chat overrides.
- **Font size:** small, medium, large, extra-large.
- **Enter is send** (web and tablet only).
- **Media visibility in device gallery** (default off).
- **Chat backup** (see the backup section).
- **Chat history actions:** export chat, archive all, clear all, delete all.

### 13.4 Notifications

- Global tones for messages, groups, and reactions; call ringtone.
- Message preview on or off.
- High-priority heads-up notifications.
- In-app sounds.
- Per-chat mute durations (8 hours, 1 week, always); custom tone; custom vibration.
- Reaction notifications on or off.

### 13.5 Storage and Data

- **Manage storage:** per-chat storage use; review items over 5 MB and items forwarded many times; bulk delete.
- **Network usage:** bytes by category since install.
- **Media auto-download,** three scenarios (Wi-Fi, cellular, roaming), each with per-type toggles. Defaults: Wi-Fi downloads everything, cellular downloads photos only, roaming downloads nothing.
- **Upload quality:** standard or HD.
- **Data saver:** reduces call bandwidth; limits background sync; disables video autoplay.
- **Proxy:** custom SOCKS5 or HTTP for restricted networks.

### 13.6 Linked Devices

- List of active devices with name, platform, app version, last-active time, and coarse IP geolocation; log out and rename actions.
- Link a new device via QR-code flow.
- Auto-logout after 30 days of inactivity.
- "Trust this device" flag that permits this device to approve future linked devices.

### 13.7 AI Settings

- **Translation.** Global on/off; preferred language; additional languages understood (messages in these are not translated); auto-translate incoming; per-chat overrides; prefer on-device model (saves data and battery at some quality cost).
- **Voice AI.** Auto-transcribe voice notes; translate voice notes (caption, dubbed TTS, or disabled); preserve voice via clone TTS (Pro, with consent from the original speaker); voice assistant (read incoming, dictate outgoing).
- **Smart replies.** On or off; default tone.
- **Summarize long threads.** On or off; minimum unread count to show the summarize button (default 20).
- **Tone rewriter.** Available tones; custom presets.
- **Data sharing with AI providers.** On or off. Off disables all AI features. The consent language is explicit and plain.

### 13.8 Subscription

- Current plan, renewal date, billing provider.
- AI usage with progress bars (translations, ASR seconds, TTS characters).
- Manage subscription (deep-links into App Store, Play, or Stripe portal).
- Restore purchases.
- Upgrade and downgrade flows with the paywall.

### 13.9 Help

- FAQ, contact us, terms, privacy policy.
- App info: version, build, device id for support.
- Send diagnostics: gathers logs with PII stripped; user-triggered only.

---

## 14. Authentication

### 14.1 Primary: Phone OTP

The user enters their phone number in E.164 format. The client requests the server to start the flow; the server sends a six-digit OTP via SMS with a five-minute expiry. On entry, the server verifies and returns an access token, a refresh token, and the user id. The client then registers a new device. Silent-SMS auto-fill is used where available, for a more frictionless flow. Abuse protection rate-limits by phone, IP, and device fingerprint.

### 14.2 Secondary: Email Magic Link

Used for web sign-up in regions where SMS is unreliable or expensive, and as a recovery channel. Always secondary — it cannot alone sign the user in from a new device without also possessing a trusted device or an OTP.

### 14.3 Device Registration

Registration is a single server call carrying the platform, device name, public identity key, signed pre-key (with its signature), a batch of 100 one-time pre-keys, the optional push token, and the app version. The server issues a device id and, on iOS, an attestation challenge (DeviceCheck / App Attest); on Android, Play Integrity is required. This raises the cost of building a bot farm.

### 14.4 Trusted Device Model

A device is **trusted** if at least one other trusted device has cross-signed its identity key. The first device is trusted via phone-number verification alone. Every subsequent device requires a QR-linking handshake with an existing trusted device. Any trusted device may revoke trust of any other device.

### 14.5 Sessions

Access tokens are short-lived (15 minutes) JWTs. Refresh tokens are long-lived (90 days), opaque, rotate on each use, and are one-shot. Refresh tokens are stored hashed on the server; a leak cannot be replayed without the plaintext. Every access token carries the device id; operations from a device id mismatch are rejected.

### 14.6 Session Invalidation

Session invalidation is triggered by logout, administrative revocation from another trusted device, two-step PIN change, or detected suspicious activity (for example, geographic anomaly combined with multiple failed OTPs). All active sessions for a revoked device are terminated immediately via a WebSocket broadcast; the device wipes its local database on receiving the revocation.

### 14.7 Multi-Device Rules

A user may have up to **8 active devices** (a soft cap). Devices automatically expire after 30 days without a socket connection. Adding a ninth device prompts the user to revoke one. Each device has independent authentication but shares the same user id and the same event stream.

---

## 15. Backup and Restore

### 15.1 Requirements

Backups are encrypted at rest with a user-derived key; the provider (iCloud, Google Drive, or our cloud) cannot decrypt them. Backups are incremental, so the full database is not re-uploaded daily. Restoration works after a fresh install, on a new device, and across devices with graceful conflict handling.

### 15.2 Backup Key Derivation

The user sets a backup password (or copies a 64-digit encryption key as a fallback). The server stores a backup salt and the Argon2id parameters (memory 64 MiB, time cost 3, parallelism 2). The backup key is derived with Argon2id and never leaves the device.

> **Privacy Contract**
>
> Without the backup password, the backup is permanently unrecoverable. We cannot help the user recover it — this is the explicit privacy contract.

### 15.3 Backup Contents

A backup consists of a signed, encrypted manifest containing the user's device keys, a schema version, and rowsets for chats, messages, attachments, reactions, members, and cursors. Media files live beside the manifest as one file per attachment, each encrypted with its original content key wrapped by the backup key (so restoration does not require device keys).

The layout alternates full snapshots and incremental deltas. Snapshots are rewritten every 14 days; deltas accumulate between.

### 15.4 Schedule

Backups trigger daily at a user-chosen hour, only when on Wi-Fi and charging (default), and only when the client has been idle for 5 minutes (the user is not actively chatting). Manual "Back up now" is available in settings.

### 15.5 Incremental Backup Algorithm

The client reads the last-backed-up sequence for each chat, writes all events since the cursor into a delta file, appends any new media ciphertext into the media directory, signs the delta with an HMAC of the backup key, and uploads it. If the cumulative delta size exceeds 30% of the last snapshot, the next scheduled backup takes a fresh snapshot and prunes old deltas.

### 15.6 Restore Flows

**Fresh install, same phone number.** After OTP login, the server returns a reference to the user's cloud backup. The client prompts for the backup password, derives the key, downloads and verifies the snapshot, writes the local database in a single transaction, then applies the deltas in order. Media is restored lazily: the first view of each message fetches the storage key from the manifest, downloads, verifies the SHA-256, and decrypts. Any events since the backup are pulled from the server's event log.

**New device alongside an existing trusted device.** The QR-linking flow runs. The new device starts empty and pulls the full event log via normal sync; an existing trusted device may also serve as a peer relay for faster hydration. Media is deferred.

**Fresh install, lost phone number.** The user registers a new phone and recovery email. The two-step PIN plus email OTP authorize account recovery, after which the restore flow above runs.

### 15.7 Conflict Handling

The hard case: a user has been using device A for a week, then restores from a week-old backup onto a fresh device B, which then becomes their primary. Device A and B diverge only in what A did in that week, but those events also live in the server's event log — convergence is automatic via ordinary sync.

True conflicts can only arise for **local-only state that is not synced server-side** — pinned chats, archived flags, per-chat wallpapers. For these the system uses Last-Writer-Wins over device-write time. Occasionally a setting flip is lost; this matches observed WhatsApp behavior and is acceptable.

### 15.8 Integrity

Every backup carries an HMAC (keyed by the backup key) over its contents. Backups are also signed by a device key. Tampering is detected on restore. The version field permits schema upgrades via explicit migration paths. A nightly canary job restores a known fixture and compares hashes end-to-end.

---

## 16. Web Architecture

### 16.1 Shared Business Logic

The business logic — models, sync engine, AI abstraction, Signal wrappers, operation queue, reducers — lives in a single pure TypeScript package `@app/core` with zero platform imports. It runs identically under Node for tests, under React Native for mobile, and under the browser for web. The repository is a pnpm monorepo with apps for mobile and web and shared packages for core, UI (Tamagui), Signal bindings, the database adapter, transport, and the AI client.

### 16.2 Platform Differences

| Concern | Mobile | Web |
|---|---|---|
| Local database | WatermelonDB on SQLite (native) | WatermelonDB on WASM SQLite persisted to OPFS |
| Crypto | libsignal via JSI / TurboModule | libsignal compiled to WASM |
| Push notifications | APNs and FCM | Web Push with VAPID via a Service Worker |
| Media capture | `expo-image-picker`, Camera | File input and `navigator.mediaDevices` |
| Calls | `react-native-webrtc` plus LiveKit RN | Native WebRTC plus LiveKit JS |
| Navigation | React Navigation | TanStack Router |
| Background sync | BGTask and WorkManager | Service Worker wake on push |
| Biometric app lock | `expo-local-authentication` | WebAuthn |

### 16.3 Web-Only Session Model

A web session is a **fully independent device** in the device model, not a mirror of the phone. It has its own identity keypair (generated in-browser, stored in IndexedDB wrapped by a non-exportable Web Crypto key). It follows the same QR-linking flow to gain trust. On logout or 14-day inactivity, the browser wipes its local database.

### 16.4 Session Continuity

There is no "open the chat on phone, see it on web" magic beyond what multi-device sync already provides: every trusted device receives every event. A user opening web sees the same state as mobile because both devices are peers against the same event log.

### 16.5 Multi-Device Behavior

Typing indicators are emitted by the focused device only; multiple focused devices are disambiguated by a five-minute "most-recent-interaction" focus lease. Notifications on device A are suppressed when device B has been active within the last 30 seconds. Read receipts are satisfied when any device marks read. Drafts are local and not synced (matching WhatsApp); voice-note drafts are an exception and resume cross-device via the op queue.

### 16.6 Web Performance Constraints

WASM SQLite is three-to-five times slower than native SQLite. The system mitigates this by batching writes and keeping the full-text search index small: only the last 10,000 messages are locally searchable on web; older matches require server-side search. The OPFS quota varies per browser; we cap local storage at 2 GB and evict oldest-first when near quota. The initial WASM payload is about 1.2 MB gzipped for libsignal and SQLite combined, and is deferred past first paint.

---

## 17. Subscription and Monetization

### 17.1 Tiers

| Feature | Free | Plus ($4.99/mo) | Pro ($14.99/mo) |
|---|---|---|---|
| Core messaging, voice, video | Yes | Yes | Yes |
| Media upload cap | 100 MB | 2 GB | 2 GB |
| AI translations per month | 1,000 | 25,000 | Unlimited |
| ASR seconds per month | 60 | 1,800 | Unlimited |
| TTS characters per month | 0 | 50,000 | Unlimited |
| Summarization | 5 / day | 100 / day | Unlimited |
| Smart replies, tone rewrite | Yes | All tones | All plus custom |
| Voice-preserving TTS (clone) | — | — | Yes (with consent) |
| Cloud backup size | 1 GB | 25 GB | 200 GB |
| Device count | 4 | 8 | 8 |
| Priority support | — | Yes | Yes |

A **Business tier** at $49 per seat per month adds team workspaces, single sign-on, audit logs, and admin analytics.

### 17.2 AI Usage Metering

Usage counters live on the server and are the authoritative source. The AI Gateway increments them atomically before routing to a provider, so an in-flight call cannot exceed its quota. Quotas reset at the subscription period end. Users receive email and in-app warnings at 80% and 100% of quota. When exhausted, AI features degrade gracefully: translation falls back to on-device MLKit where available; ASR and TTS are disabled with a clear upgrade affordance.

### 17.3 Paywall Design

- **Soft paywall** on quota exhaustion: a modal explains what broke and offers a "keep using" upgrade.
- **Feature gates** on Pro-only affordances (voice clone, custom tones) show a lock icon with a tappable upgrade.
- **Trial** for new users: Plus features free for the first seven days with a clear countdown.
- **Promo codes** for partner channels.

### 17.4 Billing Integration

Stripe handles web subscriptions. StoreKit 2 handles iOS with server-side receipt validation via App Store Server Notifications. Play Billing handles Android via Real-Time Developer Notifications. Receipt validation is always server-side; client-side claims are never trusted. An entitlement endpoint returns the authoritative tier for a user, keyed by user id rather than store identity, so a user who upgrades on iOS and logs in on Android keeps their entitlements. On past-due status, 7 days of grace service continue before downgrade to Free.

---

## 18. DevOps and Deployment

### 18.1 Environments

| Environment | Purpose |
|---|---|
| Dev | Every engineer has a personal Supabase project and Dev Client build. AI providers are mocked. |
| Preview | Per-PR ephemeral Supabase branch and EAS preview build; destroyed on merge. |
| Staging | Mirror of production topology with synthetic traffic; canary target. |
| Production | Multi-region (US East, EU West, APAC SE) with auto-failover. |

### 18.2 CI/CD

GitHub Actions runs the pipeline: lint, type-check, unit tests (Vitest, Jest), integration tests against a local Supabase stack, and Detox/Playwright on labeled PRs. On merges to `main`, EAS Build submits iOS and Android builds; the web bundle is built with Vite. Expo EAS Update pushes JS-only over-the-air updates per environment channel. Database migrations are versioned SQL applied via Supabase CLI in CI; every forward migration requires a paired rollback script. Feature flags are evaluated client-side against a `/flags` endpoint with 5-minute caching.

### 18.3 Monitoring

| Signal | Tooling and thresholds |
|---|---|
| App performance | Sentry Performance plus Firebase Performance; alert on p95 cold start above 2 seconds or chat open above 500 ms. |
| Crash rate | Sentry Crashlytics; page on above 0.5% sessions over 15 minutes. |
| Server latency | Prometheus and Grafana; alert on p99 RPC above 800 ms. |
| WebSocket health | Concurrent sessions, reconnect rate, average session duration; alert on reconnect rate above 20% per minute. |
| Delivery success | Percentage of events whose receipt reaches sender within 30 seconds: target above 99.5%. |
| AI cost | USD per hour with a hard circuit-breaker at twice the budget. |
| Sync health | Per-device lag (head minus cursor); alert on p99 lag above 2 minutes. |

### 18.4 Logging and Crash Analytics

Logs are structured JSON sent to Loki. Log content is strictly event-level: user id, device id, action, timestamp, size — never message content, attachment content, phone number, OTP, or token. A CI lint rule blocks any code introducing content-level logging. Trace ids propagate from the WebSocket frame through all backend calls.

Sentry handles crashes, with source maps uploaded by the build pipeline. ANR detection on Android flags main-thread stalls. JS errors carry breadcrumbs from navigation and the last 20 database operations.

### 18.5 Infrastructure as Code

Supabase configuration lives in `supabase/config.toml`; migrations in SQL; Edge Functions in the `supabase/functions` directory. For the scale target, Terraform modules describe Postgres (RDS or Cloud SQL), Kubernetes (EKS or GKE), R2, TURN, LiveKit, and NATS. Secrets are managed in Doppler or AWS Secrets Manager; none live in the repository.

### 18.6 Release Cadence

Mobile releases weekly, on Mondays, with a 20% staged rollout advancing to 100% over 48 hours unless crash-free rate drops. Web deploys continuously. Backend deploys are gated on a 30-minute synthetic-traffic canary in staging.

---

## 19. Scalability Roadmap

### 19.1 Phases

| Phase | Scale | Stack changes | Trigger |
|---|---|---|---|
| **MVP** | 0–50k MAU | Pure Supabase, Cloudflare, Stripe, and AI providers via the gateway. | Launch. |
| **Growth** | 50k–500k | Postgres read replicas; pgBouncer; Redis for presence; R2 for storage; regional coturn fleet. | p95 Supabase latency above 300 ms. |
| **Scale** | 500k–5M | Self-hosted Postgres sharded by chat; Phoenix Channels replacing Supabase Realtime; dedicated push service; LiveKit fleet. | Supabase spend above $10k/mo or p99 fan-out above 1 s. |
| **Enterprise** | 5M–50M+ | NATS JetStream event bus; ScyllaDB for hot events and receipts; Go fan-out service; multi-region active-active; per-region data residency. | Global presence with under 150 ms p95 to users. |

### 19.2 When to Leave Supabase

**Triggers:** monthly spend above $10k, sustained realtime CPU pressure, need for per-shard tenancy or custom egress optimization, or compliance requirements such as HIPAA-grade access controls.

**Migration path** (made feasible by the architectural choices):

- **Database.** Already Postgres. Dump and restore into a self-managed cluster; point the new backend at it.
- **Auth.** Already issuer-signed JWTs; replace GoTrue with Keycloak or a custom service.
- **Realtime.** Same Phoenix Channels protocol; swap hosting from Supabase to self-run. Clients are unchanged.
- **Storage.** S3-compatible; move bucket from Supabase to R2 with a one-time re-key or a proxied-read cutover.
- **Edge Functions.** Rewrite as Go services or Deno Deploy; URLs unchanged.

Every migration step is gradual and reversible by design.

### 19.3 Microservices Split

At the Scale phase the backend splits into services owning their own data stores: **auth, gateway / WebSocket termination, event intake** (assigning sequence numbers), **fan-out, presence, media, AI gateway, billing, push, and calling**. Boundaries follow data ownership; there is no shared database between services.

### 19.4 Capacity Targets at 10M MAU

| Metric | Target |
|---|---|
| Peak concurrent WebSocket sessions | Roughly 2 million. |
| Events ingested per second (peak) | Roughly 400,000. |
| Postgres write QPS | Roughly 250,000 with hash partitioning and sharding. |
| Media egress | Roughly 8 Gbps sustained. |
| TURN relayed call traffic | Roughly 20% of call traffic. |
| Infra cost per MAU per month | Target under $0.15, excluding variable AI cost. |

---

## 20. Risks and Tradeoffs

### 20.1 Technical

| Risk | Impact | Mitigation |
|---|---|---|
| WatermelonDB maintenance | Community-maintained; single-maintainer risk. | We own the fork if required; the DB adapter is abstracted so switching is feasible. |
| Supabase API drift | Realtime API changes could force rewrites. | Phoenix protocol is open; self-hosted Phoenix is a drop-in. |
| Signal protocol complexity | libsignal updates and cross-device ratchet state are subtle. | Version-pin libsignal; protocol tests in CI; canary one account through every release. |
| E2EE plus server-side AI | We cannot centralize AI cost savings. | Aggressive client caching, batching, progressive on-device models. |
| Clock or ordering bugs | Misordered history is user-visible. | Server-assigned sequence; property-based tests on the sync engine; dev-build invariant assertions. |
| WebRTC NAT traversal | 15–20% of calls fail on hostile networks. | TURN everywhere, including TLS/443 and TCP fallbacks. |
| OTA and native mismatch | An EAS Update may push a JS bundle incompatible with installed native. | `expo-updates` runtime-version policy; native changes always ship via the stores. |

### 20.2 Product

| Risk | Impact | Mitigation |
|---|---|---|
| WhatsApp-parity bar | Users defect if any major feature is missing. | Feature-parity checklist as a release gate; each missing feature is tracked. |
| Translation quality | Bad translations are worse than no translations. | Tiered model selection; confidence-gated display; feedback loop informing routing. |
| Cultural appropriateness | Honorifics and formality may be mangled. | Context-aware translation using the last N messages; target-register metadata. |
| Privacy narrative | Users may not understand AI plus E2EE. | Clear on-device messaging; transparency report; third-party audit at scale. |

### 20.3 Cost

| Risk | Impact | Mitigation |
|---|---|---|
| AI cost blowup | Heavy users deplete margin. | Metered quotas; strict Free tier; on-device fallbacks; volume pricing; weekly finops review. |
| Egress (media and calls) | Mobile users generate terabytes of media. | R2 (zero egress); TURN colocated with SFU; CDN caching. |
| SMS OTP cost | Highest per-user auth cost. | Aggressive rate-limiting; retry caps; flash-call / silent-SMS where available. |
| Our-cloud backup storage | iCloud and GDrive are free to the user, but our-cloud backup tier costs us. | Our-cloud backup gated to Pro and above. |

---

## 21. Failure Modes and Data Integrity

### 21.1 Duplicate Message Handling

When an event arrives, the client first checks if the remote id already exists in local messages. If yes, the event is already applied; if the arriving version is newer than the local version, status and sequence are updated. If the remote id is new, the client checks whether the incoming sequence is exactly the expected next sequence; if it is smaller, a rare race is handled without advancing the cursor; if it is larger than expected, a gap is detected, the missing range is pulled, and events are applied in order.

### 21.2 Crash During Sync

Every apply operation commits the projection and the cursor in the same database transaction. If the process dies mid-transaction, the write is rolled back and the next run re-pulls from the cursor — no duplication, no loss. The op queue uses the same pattern: destroying an op after its acknowledgement and updating the corresponding message row are a single transaction. On restart, any op still present is retried, and the server's deduplication guarantees exactly-once application.

### 21.3 App Killed in Background

iOS aggressively terminates background processes after around 30 seconds. Silent push wakes the app for event delivery; the app performs a bounded unit of work (drain the next few ops, pull once) within a 28-second window and returns. Android is more forgiving with foreground services, but most users do not grant them for chat apps, so FCM high-priority push is the primary wakeup. WAL-mode SQLite guarantees the last committed transaction is recoverable even if the OS kills the process mid-apply.

### 21.4 Interrupted Uploads and Downloads

Uploads record bytes sent durably. On resume, the client asks the storage service for the server-confirmed offset and continues from there. Downloads are HTTP-range aware; partially downloaded files on disk have a `.part` suffix and resume via Range requests. A full-file SHA-256 check runs once the file is assembled.

### 21.5 Event Replay Safety

Projection handlers are written as pure functions of `(previous_state, event)`. Each handler for each event type is individually idempotent: `message.send` upserts by remote id; `message.edit` updates body only if the incoming server timestamp is newer than the current edit timestamp; `message.delete` sets the delete marker; `reaction.add` upserts a (message, user, emoji) row; `reaction.remove` removes that row. Replaying the entire event stream from scratch yields identical projections.

### 21.6 Consistency vs. Availability Tradeoffs

| Situation | We choose |
|---|---|
| Client offline, user sends | Availability — op queued, eventually consistent. |
| Primary shard briefly down | Fast failover to standby; a few tens of seconds of blocked writes on that shard. We prefer availability. |
| Cross-region partition | Each region is independently writable; cross-region convergence happens on partition heal. |
| Concurrent edit across user's devices | Last-Writer-Wins on server sequence; earlier edits are archived in the log. |

### 21.7 Dev-Mode Invariant Assertions

In development builds the sync engine asserts invariants on every apply: sequence numbers are strictly increasing (or equal to existing); no remote id appears twice; no message has `sent` status without a positive sequence; reactions cannot be removed before being added. Violations throw in dev and are reported to Sentry with full context in production.

---

## 22. Feature Parity Checklist

| WhatsApp Feature | Status | Notes |
|---|---|---|
| One-to-one messaging | ✅ Yes | Core. |
| Group chats (up to 1024 members) | ✅ Yes | SFU-friendly member counts. |
| Broadcast lists | ✅ Yes | Modeled as a broadcast chat type. |
| Communities | 🔲 v2 | Group-of-groups; deferred. |
| Channels | 🔲 v2 | One-to-many broadcast. |
| Single, double, blue ticks | ✅ Yes | Full tick-state machine. |
| Played tick for voice | ✅ Yes | |
| Message editing (15-minute window) | ✅ Yes | |
| Delete for me and delete for all | ✅ Yes | |
| Forwarding | ✅ Yes | Including "forwarded many times" mark. |
| Starred messages | ✅ Yes | |
| Reactions (any emoji) | ✅ Yes | |
| Replies and quoting | ✅ Yes | |
| Mentions | ✅ Yes | In groups, with notifications. |
| Polls | ✅ Yes | Modeled as a message type. |
| Typing indicators | ✅ Yes | |
| Online and last seen | ✅ Yes | |
| Images, videos, documents | ✅ Yes | |
| Voice messages | ✅ Yes | |
| Stickers and GIFs | ✅ Yes | Including custom packs. |
| Location sharing (static and live) | ✅ Yes | Live location has TTL. |
| Contact sharing | ✅ Yes | |
| Voice and video calls (1:1) | ✅ Yes | |
| Group voice and video calls | ✅ Yes | Up to 50 / 32 at MVP. |
| Status (stories) | ✅ Yes | 24-hour expiry, privacy-controlled. |
| Disappearing messages | ✅ Yes | Per-chat, 24h/7d/90d. |
| View-once media | ✅ Yes | Client refuses re-open. |
| "Keep in chat" for disappearing | ✅ Yes | |
| Global and per-chat search | ✅ Yes | Local FTS; server-side for web. |
| Backup and restore | ✅ Yes | See backup section. |
| Multi-device | ✅ Yes | Up to 8. |
| Web and desktop | ✅ Yes | Standalone, not phone-mirrored. |
| Pinned, archived, muted chats | ✅ Yes | |
| Blocked contacts, report spam | ✅ Yes | |
| End-to-end encryption | ✅ Yes | Signal Protocol. |
| Two-step verification | ✅ Yes | |
| Change number and delete account | ✅ Yes | 30-day grace on delete. |
| Custom notifications per chat | ✅ Yes | |
| Chat themes and wallpapers | ✅ Yes | Global and per-chat. |
| Dark mode | ✅ Yes | System or manual. |
| **Beyond WhatsApp — AI layer** | | |
| Invisible translation | ✅ Yes | Per-recipient, per-language, cached. |
| Voice AI pipeline (ASR + MT + TTS) | ✅ Yes | Opt-in. |
| Smart replies | ✅ Yes | |
| Tone rewriter | ✅ Yes | |
| Conversation summarization | ✅ Yes | |
| Voice-preserving TTS | ✅ Yes | Pro tier, with sender consent. |

---

## 23. Conclusion

This architecture is defensible on three axes.

**It is buildable by one engineer.** Supabase removes the infrastructure tax at MVP. Expo collapses mobile distribution onto a single codebase. WatermelonDB provides a reactive, syncable local store without writing one from scratch. The AI Gateway keeps LLM providers interchangeable.

**It is not a dead end.** Every choice made for operational simplicity has a known escape hatch: Supabase to self-hosted Postgres with Phoenix; Supabase Storage to R2; Edge Functions to Go services. Even WatermelonDB is ultimately SQLite, so the project could run raw SQL directly if it had to.

**It honors the product commitments.** Local-first guarantees UX quality. Signal Protocol guarantees privacy. The server-assigned sequence plus LWW-with-semantic-guards guarantees multi-device convergence without the overhead of full CRDTs. The event log plus idempotent projections means that backup, restore, replay, audit, and re-bootstrap all work by construction rather than as special-cased features.

What remains is execution: build the op queue, the projections, the Signal wrappers, the WatermelonDB schema, the AI gateway, and a disciplined feature-parity rollout. **The shape is correct.**

---

*End of Document*
