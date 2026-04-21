---
name: angular-component
description: Create modern Angular standalone components following v20+ best practices. Use for building UI components with signal-based inputs/outputs, OnPush change detection, host bindings, content projection, and lifecycle hooks. Triggers on component creation, refactoring class-based inputs to signals, adding host bindings, or implementing accessible interactive components.
---

# Angular Component

Create standalone components for Angular v20+. Components are standalone by default—do NOT set `standalone: true`.

## Component Structure

```typescript
import { Component, ChangeDetectionStrategy, input, output, computed } from '@angular/core';

@Component({
  selector: 'app-user-card',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: {
    'class': 'user-card',
    '[class.active]': 'isActive()',
    '(click)': 'handleClick()',
  },
  template: `
    <img [src]="avatarUrl()" [alt]="name() + ' avatar'" />
    <h2>{{ name() }}</h2>
    @if (showEmail()) {
      <p>{{ email() }}</p>
    }
  `,
  styles: `
    :host { display: block; }
    :host.active { border: 2px solid blue; }
  `,
})
export class UserCard {
  name = input.required<string>();
  email = input<string>('');
  showEmail = input(false);
  isActive = input(false, { transform: booleanAttribute });
  avatarUrl = computed(() => `https://api.example.com/avatar/${this.name()}`);
  selected = output<string>();

  handleClick() {
    this.selected.emit(this.name());
  }
}
```

## Signal Inputs

```typescript
name = input.required<string>();          // Required
count = input(0);                          // Optional with default
label = input<string>();                   // Optional, undefined allowed
size = input('medium', { alias: 'buttonSize' });
disabled = input(false, { transform: booleanAttribute });
value = input(0, { transform: numberAttribute });
```

## Signal Outputs

```typescript
clicked = output<void>();
selected = output<Item>();
valueChange = output<number>({ alias: 'change' });
```

## Host Bindings

Use the `host` object in `@Component` — do NOT use `@HostBinding` or `@HostListener` decorators.

```typescript
host: {
  'role': 'button',
  '[class.primary]': 'variant() === "primary"',
  '[class.disabled]': 'disabled()',
  '[attr.aria-disabled]': 'disabled()',
  '[attr.tabindex]': 'disabled() ? -1 : 0',
  '(click)': 'onClick($event)',
  '(keydown.enter)': 'onClick($event)',
}
```

## Template Syntax

Use native control flow — do NOT use `*ngIf`, `*ngFor`, `*ngSwitch`.

```html
@if (isLoading()) {
  <app-spinner />
} @else if (error()) {
  <app-error [message]="error()" />
} @else {
  <app-content [data]="data()" />
}

@for (item of items(); track item.id) {
  <app-item [item]="item" />
} @empty {
  <p>No items found</p>
}
```

## Class and Style Bindings

Do NOT use `ngClass` or `ngStyle`. Use direct bindings:

```html
<div [class.active]="isActive()">Single class</div>
<div [style.color]="textColor()">Styled text</div>
<div [style.width.px]="width()">With unit</div>
```

## Accessibility Requirements

Components MUST:
- Pass AXE accessibility checks
- Meet WCAG AA standards
- Include proper ARIA attributes for interactive elements
- Support keyboard navigation
- Maintain visible focus indicators

For detailed patterns, see [references/component-patterns.md](references/component-patterns.md).
