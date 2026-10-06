# Font credits

Death's Gambit's lettering (`art/scripts/ui/fonts.py`) is drawn from two fonts from
[Fontshare](https://www.fontshare.com), published by the Indian Type Foundry under the ITF Free Font
License (commercial use, games included; the font files may not be redistributed or modified).

| Face | Drawn from | Designer |
|---|---|---|
| Title | Aktura Regular | Gaetan Baehr |
| Head, Semi, RnLight, RnMedium | Melodrama Bold, Semibold, Light, Medium | Shaily Patel |

**The font files are not in this repository.** Download Aktura and Melodrama from fontshare.com and
unzip them into `art/fonts/fontshare/` (the folder is in `.gitignore`), so that these files exist:

- `art/fonts/fontshare/Aktura_Complete/Fonts/WEB/fonts/Aktura-Regular.ttf`
- `art/fonts/fontshare/Melodrama_Complete/Fonts/WEB/fonts/Melodrama-{Light,Medium,Semibold,Bold}.ttf`

What is committed is the images the script draws from them (`art/export/textures/Ui<Face>1.png`) and the
glyph metrics (`src/shared/UI/GlyphFonts.luau`).

Roblox's own Montserrat (SIL Open Font License) is used for small text, typing and chat.
