# Mnemo — MVP Product Specification

## 1. Product summary

Mnemo is a collaborative web app for learning through mnemonic devices. Users organize learning material into shared **spaces**, create editable **cards**, and test themselves with a progressive flip-card experience that reveals additional fields in phases.

The initial example use case is learning Farsi vocabulary, but the product must support any subject where learners want to associate multiple pieces of information—for example, a word, pronunciation, translation, image, cue, or memory story.

## 2. MVP goals

- Let a user create an account, sign in, and manage their profile.
- Let a user create and manage learning spaces for separate journeys.
- Let users invite collaborators to a space with an invite code.
- Let everyone in a space view, create, edit, and delete its cards.
- Let a space define the titles and number of fields used by its cards.
- Let a learner study cards in a multi-phase flip-card session.
- Keep the experience simple enough that a user can create a space and study their first card within a few minutes.

## 3. Non-goals for the MVP

The first release will not include payments, public discovery, formal instructor/student roles, automated mnemonic generation, spaced-repetition scheduling, detailed analytics, native mobile apps, or offline support. The data model should leave room for these features later.

## 4. Users and permissions

### User

A user can:

- Register with email and password.
- Sign in, sign out, and reset their password.
- Edit basic profile information such as display name.
- Create, rename, archive, and delete spaces they own.
- Leave spaces they joined.
- View and study all spaces they belong to.

### Space owner

The owner has all member permissions plus the ability to:

- Edit the space name, description, and card field definitions.
- Generate, regenerate, and disable invite codes.
- Remove members.
- Transfer ownership only if this is easy to support safely; otherwise defer it and document that ownership transfer is not available in MVP.

### Space member

A member can:

- View all cards and card fields in the space.
- Create, edit, and delete any card in the space.
- Study the space.
- See the names of other members.

All card edits are shared immediately with the space. MVP does not require per-card ownership, approval workflows, or edit history.

## 5. Core concepts

### Space

A space is an independent learning journey, such as “Farsi Vocabulary” or “Organic Chemistry”. It contains:

- Name
- Optional description
- Owner
- Members
- Card field definitions
- Cards
- Invite settings
- Created and updated timestamps

Each space has one active invite code at a time. Invite codes should be sufficiently hard to guess and can be regenerated or disabled by the owner.

### Card field

A field is a user-defined part of a card. Each field has:

- Title, such as “Farsi”, “Pronunciation”, “English”, or “Mnemonic”
- Stable ordering within the space
- Required/optional status

To keep the MVP flexible without making the editor complicated, fields are text-only. A space should support at least 2 and up to 8 fields. The owner can add, rename, reorder, or remove fields. Removing a field requires confirmation and removes that field’s value from every card in the space.

The space owner chooses which field is shown first in study mode. The study flow then reveals the remaining fields in their configured order.

### Card

A card is a set of values, one per field definition. Cards are available to every member of the space and can be edited by any member.

Cards should have:

- A unique ID
- Space ID
- Values keyed to field IDs
- Created by and last edited by user IDs
- Created and updated timestamps

## 6. Primary user journeys

### First-time setup

1. User lands on a short explanation of Mnemo and chooses Sign up or Log in.
2. After registration, the user sees an empty dashboard with a clear “Create space” action.
3. User names the space and defines its fields, with a useful starter example such as “Term”, “Pronunciation”, “Meaning”, and “Mnemonic”.
4. User arrives at the space and can add the first card immediately.

### Create and join a space

1. Owner opens the space settings and selects “Invite members”.
2. App shows the current invite code and a copy action.
3. Another authenticated user selects “Join space”, enters the code, and confirms.
4. On success, the new member is taken to the space and the owner sees the updated member list.
5. Invalid, expired/disabled, or already-used codes show a clear error. MVP invite codes may be reusable until disabled or regenerated.

### Create and edit a card

1. A member selects “Add card”.
2. The app renders the space’s field titles as labels.
3. The member enters values and saves.
4. The card appears in the shared card list.
5. Any member can open the card, edit its values, or delete it after confirmation.

### Study cards

1. A member selects “Study” from a space.
2. The app starts a session using cards from that space, initially in a simple deterministic order or shuffled order selected by the product team.
3. The first card shows only the configured starting field.
4. The learner clicks/taps “Reveal next” to show the next field.
5. Each reveal is a visible phase change until all fields are shown.
6. The learner can move to the next card, go back, restart, or exit to the space.
7. At the final phase, the learner can mark the card as “Got it” or “Need practice”. MVP stores this only as session feedback; it does not schedule future reviews.

## 7. Functional requirements

### Authentication and account management

- Email/password registration with validation.
- Login and logout.
- Password reset flow.
- Protected application routes for authenticated users.
- Display name shown in member lists and edit metadata.
- Clear handling for duplicate email, invalid credentials, and expired reset links.

### Dashboard

- List spaces the user owns or belongs to.
- Show space name, member count, card count, and last updated time.
- Actions: create space, join space, open space.
- Empty state explaining how to create or join a space.

### Space management

- Create, rename, archive, and delete a space.
- View space overview, card list, study action, and member list.
- Edit description and field definitions in settings.
- Confirm destructive actions.
- Archived spaces are hidden from the default dashboard but are recoverable by the owner if recovery is implemented; otherwise archive can be deferred until after the core MVP.

### Cards

- Responsive card list with search/filter by text across all fields.
- Add, edit, and delete cards.
- Autosize or multiline text inputs for longer mnemonic stories.
- Show who last edited a card and when.
- Empty state when no cards exist.
- Prevent saving a card with missing required fields.

### Study mode

- Focused, distraction-light layout for one card at a time.
- Phase indicator, such as “2 of 4 fields revealed”.
- Reveal one field at a time in configured order.
- Controls for next card, previous card, restart, and exit.
- Shuffle option is desirable, but can be omitted from the first implementation if it slows delivery.
- Preserve the user’s current session state if they refresh, where practical; otherwise exit gracefully without corrupting data.

### Sharing and membership

- Owner can view and copy an invite code.
- Owner can regenerate or disable the code.
- Authenticated users can join by code.
- Members can see the member list.
- Owner can remove members.
- A removed member immediately loses access to the space and its cards.

## 8. Suggested screens

- Landing page
- Sign up
- Log in
- Password reset/request and completion screens
- Dashboard
- Create space
- Space overview/card list
- Card create/edit form
- Study mode
- Space settings: general, fields, members, invite code
- User profile/settings

The UI should be responsive for desktop and mobile browsers, use keyboard-accessible controls, provide visible focus states, and maintain readable contrast. The study screen should prioritize the current card over navigation chrome.

## 9. Data model (logical)

Suggested entities:

- `users`: id, email, password/auth provider reference, display name, created_at, updated_at
- `spaces`: id, owner_id, name, description, status, starting_field_id, invite_code_hash, invite_enabled, created_at, updated_at
- `space_members`: space_id, user_id, role, joined_at
- `field_definitions`: id, space_id, title, position, is_required, created_at, updated_at
- `cards`: id, space_id, created_by, last_edited_by, created_at, updated_at
- `card_values`: card_id, field_id, value, updated_at
- `study_sessions` (optional MVP entity): id, user_id, space_id, started_at, completed_at
- `study_results` (optional MVP entity): session_id, card_id, result, revealed_field_count

Use authorization checks at the API/database layer, not only in the UI. Invite codes should be stored hashed where possible, and raw codes should not appear in logs.

## 10. API/product behavior notes

- Every space and card request must verify that the current user is a member of the relevant space.
- Only the owner can change field definitions and invite settings.
- Field IDs, not field titles, should identify values so renaming a field does not lose card data.
- Mutations should return the updated resource or enough data for the UI to update without a full reload.
- Concurrent edits are out of scope for MVP; last successful save wins.
- Deleting a space should delete or safely detach its members, fields, cards, and values according to the chosen database cascade policy.

## 11. Acceptance criteria

The MVP is ready for internal use when:

- A new user can register, log in, create a space, define fields, add cards, and study them end to end.
- A second user can join a space through an invite code and immediately view, edit, add, delete, and study shared cards.
- The owner can rename fields and the new titles appear consistently in card forms, card views, and study mode.
- The study flow reveals exactly one additional field per phase and clearly indicates completion.
- Unauthorized users cannot access a space by guessing IDs or calling APIs directly.
- Invalid forms and destructive actions have clear validation and confirmation states.
- The core experience works on current desktop and mobile browsers.
- Basic automated tests cover authentication guards, membership authorization, invite-code joining, field/card CRUD, and study-phase progression.

## 12. Open decisions to resolve before implementation

1. Authentication provider and hosting/database stack.
2. Whether spaces can be deleted in MVP or only archived.
3. Whether invite codes are reusable, expire, or require owner approval.
4. Whether study sessions are shuffled by default.
5. Whether the owner can transfer ownership.
6. Whether card fields should support Markdown or remain plain text.
7. Whether “Got it / Need practice” should be persisted now or deferred until spaced repetition is designed.

Recommended defaults for a first build: reusable codes that the owner can regenerate, plain text fields, shuffled study sessions with a restart control, persisted card feedback only if it is inexpensive, and no ownership transfer until a clear need appears.

## 13. Post-MVP directions

- Spaced repetition and per-card scheduling.
- Mnemonic suggestions generated from card content.
- Images, audio, pronunciation playback, and richer field types.
- Personal progress and shared-space activity history.
- Comments, reactions, and edit history on cards.
- Public/read-only sharing links.
- Import/export via CSV and common flashcard formats.
- Notifications for invitations and space activity.
- Fine-grained roles and permissions.

