# Arkad Style Guide

Arkad is a personal finance tracker built around the idea of **“the ledger in the garden”**: organic, warm, soft surfaces hold precise financial data. The visual system should feel calm, intelligent, optimistic, and personal without becoming playful or imprecise.

This guide describes the current web experience and provides translation guidance for Flutter and React Native.

## Brand personality

- Calm and reassuring, never loud or sales-heavy.
- Organic softness paired with financial precision.
- Personal and conversational, like a thoughtful financial companion.
- Warm, modern, and lightly editorial.
- Details should feel intentional: generous spacing, quiet borders, strong hierarchy.

Avoid:

- Generic banking blue gradients.
- Dense spreadsheet-like layouts.
- Excessive bright colors.
- Sharp rectangular cards.
- Monospace type for general copy.
- Heavy shadows or high-contrast borders everywhere.

## Color system

Use the following colors as the source of truth. The web implementation exposes many of these as Tailwind names.

| Token | Hex | Usage |
|---|---|---|
| `cream` | `#F4F0E6` | Main page background, input backgrounds, soft surfaces |
| `paper` | `#FCFBF7` | Cards, sidebar, dialogs, elevated surfaces |
| `ink` | `#24362D` | Primary text, headings, icons |
| `dark-green` | `#244F3A` | Primary buttons, balance blob, income states, selected navigation |
| `sage` | `#B4C6AC` | Secondary accent, decorative elements |
| `sage-tint` | `#E3EBDF` | Secondary cards, category pills, assistant surfaces |
| `pastel-yellow` | `#F5D66B` | Primary accent, positive highlights, logo mark, balance accents |
| `clay` | `#C87865` | Expense/negative states and destructive actions only |

### Color rules

- Use `cream` as the dominant canvas color.
- Use `paper` for content containers so cards are only slightly lighter than the page.
- Use `dark-green` sparingly but decisively for primary actions and key financial emphasis.
- Use `pastel-yellow` for optimism and attention, not for long text.
- Reserve `clay` for expense amounts, delete actions, and negative states. It should never become the primary brand color.
- Body text may use reduced-opacity ink equivalents (`ink/60`, `ink/50`, `ink/40`) for hierarchy.
- Do not use pure black. Use `ink`.
- On `dark-green`, use `paper` or white for body text and `pastel-yellow` for emphasis.

## Typography

Arkad uses three typefaces with strict roles:

### Fraunces

Display and editorial typeface.

Use for:

- Page headings.
- Hero headlines.
- Card titles.
- Large balance numbers when they are not financial data.
- Brand wordmark.

Typical weights: 500, 600, 700.

### Manrope

Primary UI and body typeface.

Use for:

- Navigation.
- Buttons.
- Labels.
- Descriptions.
- Form fields.
- Supporting copy.

Typical weights: 400, 500, 600, 700, 800.

### DM Mono

Precision typeface.

Use only for:

- Currency figures.
- Transaction amounts.
- Dates when presented as ledger data.
- API keys and model slugs.
- Financial inputs.
- Small data labels where alignment matters.

Do not use it for headings, navigation, or paragraphs.

### Type scale

- Hero heading: 56–72px desktop, 48–56px mobile, Fraunces 600, line height around 0.98.
- Page heading: 36–48px, Fraunces 600/700.
- Card heading: 22–28px, Fraunces 600/700.
- Large balance: 48–60px, DM Mono 700.
- Body: 14–18px, Manrope 400/500, line height 1.6–2.
- Button: 13–14px, Manrope 700.
- Eyebrow: 10px, Manrope 800, uppercase, letter spacing around 0.2em.
- Metadata: 11–12px, Manrope 500 or DM Mono when numeric.

## Shape language

Arkad is heavily rounded and intentionally soft.

- Cards: 24–30px radius.
- Large hero cards/blob: 32px or more.
- Buttons: full pill radius.
- Inputs: 16–18px radius.
- Small icon tiles: 12–16px radius.
- Avatars: circular or rounded-square, depending on context.
- Category pills: full pill radius.

Avoid sharp corners unless they are part of an icon or a native control that cannot be styled.

### Organic balance blob

The dashboard balance is presented inside a dark green organic blob.

- Use `dark-green` as the base.
- Use a subtle, slow morphing border radius animation.
- Keep the balance number large, bold, white, and high contrast.
- Use a restrained pastel-yellow accent for the percentage change.
- Add only subtle decorative rings or shapes.
- Never allow decorative elements behind the balance text to reduce readability.

## Layout

### Desktop app shell

- Full-height left sidebar: approximately 266px wide.
- Sidebar background: `paper`.
- Main canvas: `cream`.
- Sidebar has a thin low-contrast divider.
- Content has 48px-ish horizontal padding on large screens.
- Content max width is approximately 1400px.
- Sidebar navigation is vertically anchored with assistant promotion and account controls toward the bottom.

### Mobile shell

- Sidebar becomes a slide-in drawer.
- A menu button appears in the top-left header.
- A dimmed backdrop closes the drawer.
- Main content uses 20px horizontal padding.
- Dashboard grids collapse into a single column.
- Chat drawer becomes full width or nearly full width.
- All primary actions remain reachable without horizontal scrolling.

### Landing page

- Header uses a centered max-width container.
- Logo sits left; login and primary signup action sit right.
- Hero uses a two-column desktop layout and a single-column mobile layout.
- The right side contains an organic dark-green product preview with a small yellow assistant card.
- Lower feature strip uses a paper background and three concise benefit columns.

## Navigation

Sidebar navigation items are pill-shaped rows.

### Inactive state

- Transparent or paper background.
- Muted ink text.
- Dark-green hover text.
- Sage-tint hover background.

### Active state

- Dark-green background.
- Paper text.
- Slight soft shadow.
- Icon and label remain visually balanced.

The account overflow menu should be anchored to the account row and contain:

- Change photo.
- Open settings.
- Log out, using clay for the destructive action.

## Buttons

### Primary button

- Dark-green fill.
- Paper text.
- Optional pastel-yellow icon or badge.
- Full pill shape.
- Small soft shadow.
- On hover/press, lift slightly or darken subtly.

### Secondary button

- Paper fill or transparent cream fill.
- Low-contrast ink border.
- Muted ink text.
- Full pill shape.

### Destructive action

- Use clay text or a very soft clay-tint surface.
- Never use a bright red alert treatment for normal delete controls.
- Destructive actions should still be clearly identifiable and require confirmation when deleting meaningful data.

## Cards and surfaces

Cards use:

- `paper` background.
- 24–30px corner radius.
- Very subtle ink border at roughly 10% opacity.
- Soft, low-elevation shadow.
- 24–32px internal padding depending on card size.

Cards should not be overly boxed in. Use whitespace and typography to create grouping before adding dividers.

## Dashboard components

### Balance card

Show:

- Eyebrow: “Total balance”.
- Large DM Mono currency value.
- Month-over-month percentage.
- Short reassuring sentence.
- Optional small decorative status avatars.

### Stat cards

Each stat card contains:

- Small rounded icon tile.
- Label.
- Large DM Mono amount.
- Percentage comparison.

Income uses dark-green/sage. Expenses use clay sparingly.

### Cash flow chart

- Minimal 7-day bar chart.
- Dark-green bars represent income.
- Pastel-yellow bars represent expenses.
- Rounded bar tops.
- Quiet baseline and small DM Mono day labels.
- Include a small legend.

### Transaction row

Each row should contain:

- Category icon inside a rounded tile.
- Merchant name in bold Manrope.
- Category and date as muted metadata.
- Amount aligned to the right in DM Mono.
- Income uses a plus sign and dark-green.
- Expense uses a minus sign and ink or clay depending on emphasis.
- Row is tappable/clickable and opens the edit modal.

Recommended category icon mapping:

- Income: arrow-down-left or wallet.
- Groceries: shopping basket.
- Dining: utensils.
- Subscriptions: music or repeat.
- Transport: car.
- Housing: home or wallet.
- General: credit card.

## Forms and modals

### Inputs

- Cream background.
- Low-contrast ink border.
- 16–18px radius.
- 12–14px vertical padding.
- Dark-green focus border/ring.
- Placeholder text at low ink opacity.
- Financial values use DM Mono.

### Transaction modal

The same modal handles create and edit states.

Fields:

- Merchant/source.
- Amount.
- Income or expense type.
- Category.

For income, show the income category list. For expenses, show the expense category list. Custom categories created in Transactions should be immediately available in this form.

The modal also supports deleting an existing transaction with a clay destructive action.

### Change photo modal

- Centered paper dialog over a blurred/dimmed backdrop.
- Large rounded avatar preview.
- Image picker control styled as a secondary button.
- Primary save action.
- Close icon in the top-right.

## Category management

The Transactions view includes a category management section.

- Use an Expense/Income segmented control.
- Show existing categories as sage-tint pills.
- Provide a text input and Add button.
- New category names should be validated as non-empty and persisted locally.
- Category management should feel lightweight, not like an administrative settings page.

## Onboarding

The landing page “Get started” and Google signup CTAs open onboarding.

Onboarding is a calm, three-step flow:

1. Display name.
2. Primary financial goal.
3. Typical monthly income, optional.

### Onboarding presentation

- Keep the page on the cream background.
- Use a dark-green information panel on desktop.
- Use a large Fraunces question heading.
- Show a small step indicator.
- Use one focused question per screen.
- Provide Back, Continue, and Skip for now.
- Final action is labeled “Enter Arkad”.
- On mobile, hide the decorative information panel and keep the form full width.

Onboarding data is local-only and should be editable later in Settings.

## Settings

Settings should contain two sections:

### Personal basics

- Display name.
- Financial goal.
- Typical monthly income.
- Save personal info action.

### OpenRouter connection

- BYOK API key field, masked.
- Model slug field.
- Clear/save actions.
- Explain that the key remains in the browser and calls OpenRouter directly.

Include data controls separately, with clear all data using the clay destructive style.

## Chat drawer

- Opens from the floating “Chat with Arkad” button, sidebar CTA, or header action.
- Slides in from the right on desktop.
- Full width on smaller screens.
- Paper background with a low-contrast header divider.
- Arkad avatar: dark-green circle with pastel-yellow icon.
- Agent messages: sage-tint bubble, rounded with a slightly tighter top-left corner.
- User messages: dark-green bubble with paper text, tighter top-right corner.
- Composer sits at the bottom with a cream input and dark-green send button.
- Always make BYOK status explicit. Never imply the AI is active without a configured key.

## Motion

Motion should be slow, subtle, and purposeful.

- Balance blob morph: 10–14 seconds, ease-in-out, infinite.
- Button hover/press: 150–220ms.
- Drawer: 250–350ms ease-out.
- Modal backdrop: quick fade with slight blur.
- Avoid bouncy spring motion for finance-related data.
- Respect reduced-motion preferences.

## Icons

Use Lucide-style outline icons with consistent stroke weight around 2px.

- Icons are supportive, never decorative clutter.
- Default icon size: 16–19px.
- Navigation icons: around 18px.
- Hero or assistant icons: 20–22px.
- Use dark-green, ink opacity, sage, pastel-yellow, or clay according to semantic state.

## Accessibility

- Maintain readable contrast, especially on the dark-green blob.
- Do not communicate income/expense by color alone; include plus/minus signs and labels.
- Every icon-only button needs an accessible label.
- Dialogs need a clear close action and should trap focus on native platforms.
- Inputs need visible labels or accessible labels.
- Tap targets should be at least 44px on mobile.
- Support keyboard focus states on web and screen-reader labels on native.
- Respect reduced motion.

## React Native / Flutter translation

### React Native

- Map `paper` and `cream` to shared color constants.
- Use `@expo-google-fonts/fraunces`, `@expo-google-fonts/manrope`, and a DM Mono-compatible font, or package equivalent font files locally.
- Use `Pressable` for buttons and rows with pressed-state opacity/scale kept subtle.
- Use `Modal` with a dimmed backdrop for dialogs.
- Use `Animated` for the balance blob and drawer transitions.
- Use `FlatList` for transactions.
- Use `AsyncStorage` for versioned local data keys.
- Use `SafeAreaView` and a bottom-sheet/drawer pattern for mobile navigation.

### Flutter

- Define `ColorScheme` extensions for the Arkad tokens.
- Bundle Fraunces, Manrope, and DM Mono through `pubspec.yaml`.
- Use `ThemeData` for text styles and rounded `ShapeBorder`s.
- Use `showModalBottomSheet` or a dialog for transaction editing and photo changes.
- Use `NavigationRail` or a custom drawer for larger screens and `NavigationBar`/drawer for phones.
- Use `AnimatedContainer` or `TweenAnimationBuilder` for the organic balance shape.
- Use `ListView.builder` for transaction rows.
- Use `shared_preferences` or a local database for versioned local persistence.

## Persistence keys

The current web implementation uses browser-local persistence:

- `arkad:transactions:v1`
- `arkad:profile:v1`
- `arkad:income-categories:v1`
- `arkad:expense-categories:v1`

Native implementations should preserve the versioned-key approach so migrations can be added without losing user data.
