# Translating EncounterLab

EncounterLab currently ships in English. English remains the default on every
client, including `deDE`, until a translation for that client locale is added.
Translations are optional and may cover only part of the interface.

## Add a language

1. Create a UTF-8 Lua file in this directory, named after the exact WoW client
   locale, such as `frFR.lua` or `deDE.lua`.
2. Read the canonical English phrase list in `../Locale.lua`. Copy the exact
   English text as the key and put your translation on the right-hand side.
3. Register your table using the pattern below, replacing `LOCALE` with the
   client locale and the example value with translated text.
4. Add `Locales\LOCALE.lua` to `../EncounterLab.toc` immediately after
   `Locale.lua`, before `Persistence.lua`, `Renderer.lua`, `Input.lua`, and
   `Interface.lua`. Every locale file must load before the UI modules.
5. Reload WoW on that locale and check the training window, help, controls,
   abilities, leaderboards, history, chat notices, and diagnostics.

```lua
local _, EL = ...

EL.RegisterLocale("LOCALE", {
    ["Please wait until combat ends."] = "TRANSLATED TEXT",
})
```

This is a documentation example; no additional language is enabled by this
directory. `GetLocale()` selects the client's language automatically. There is
no separate language preference to save, and locale files need no locale guard.
Only entries for the active client locale are displayed.

## Phrase and format rules

- Translate complete phrases. The exact English keys are stable lookup keys;
  do not translate the left-hand side or change its punctuation or whitespace.
- `EL.L["English text"]` reads a plain phrase. `EL.F("English %s format", value)`
  reads and safely formats a translated phrase. Add new English keys to the
  central catalog before using them in source: plain phrases belong in the
  `english` list, and formatted phrases belong in the `formats` list.
- Preserve the number, type, and order of every format argument: `%s` for text,
  `%d` for an integer, `%.1f` for a decimal, and so on. Lua 5.1 does not support
  numbered arguments such as `%2$s`; rearrange the surrounding sentence instead.
- Keep `%%` for a literal percent sign inside a formatted phrase. Plain phrases
  may contain an ordinary `%`. Keep `\n` where a line break is needed.
- Keep WoW color escapes such as `|cffffffff` and `|r` paired, where present.
  Preserve command tokens such as `/el` and runtime binding substitutions.
- Diagnostic codes, simulation identifiers, option keys, saved results, file
  paths, and slash-command names remain language-independent. Translate their
  display labels only. Do not rename an internal identifier to translate it.
- Aim for similar text lengths. Test long labels at the minimum window size,
  on the full-screen arena, and with non-default UI scale. Confirm font glyphs,
  wrapping, button labels, focus notices, and dynamically inserted binding names.

## Fallback and validation

Missing locale files, missing keys, and rejected translations display English.
An unknown English lookup key also displays itself so an omitted catalog entry
cannot leave a blank label. Registration rejects unknown keys, empty or
non-string values, mismatched format arguments, and invalid formatted strings.
Plain text is not parsed as a format string, so words following a percent sign
remain ordinary text. `EL.RegisterLocale(locale, entries)` returns the number of
accepted entries followed by the number of rejected entries. Valid entries in a
partially invalid table still load. The canonical `enUS` catalog cannot be
overridden through the registration API.

`EL.F` protects formatting at runtime as well: if a translated format fails, it
tries the English format. If the call itself has invalid arguments, it returns
the English phrase without raising a Lua error.

Run the source checks from the repository's `work` directory with Lua 5.1:

```text
lua tests/localization_test.lua EncounterLab/
```

These checks verify fallback, registration, and format safety. They do not
replace visual verification inside WoW. This source workflow does not build,
package, install, or synchronize the addon.
