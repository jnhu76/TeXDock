# Fonts layer

`Dockerfile-full-2` owns font behavior:

- fontconfig Windows-name compatibility aliases
- optional private `fonts.zip` import
- font cache refresh
- public font smoke test
- private Windows font smoke test when `fonts.zip` exists

## Private fonts

Put private fonts here:

```text
docs/fonts/private/fonts.zip
```

The zip may contain nested directories. The importer copies only font files:

- `.ttf`
- `.ttc`
- `.otf`
- `.otc`

Do not commit `fonts.zip`.
