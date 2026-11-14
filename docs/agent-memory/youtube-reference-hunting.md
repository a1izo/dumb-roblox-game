---
name: youtube-reference-hunting
description: Finding and frame-sheeting a reference scene on YouTube in the built-in browser pane when its search page will not draw (2026-11-14, RoleAce); where L's line and L's crouch really are in the anime
metadata:
  type: reference
---

The built-in browser pane, while hidden, draws YouTube **watch pages** but leaves the **search results page** blank (an
empty body, `get_page_text` returns nothing, even after the cookie dialog). What works:

- **Search from any youtube.com page** with `fetch('/results?search_query=' + encodeURIComponent(q) + '&hl=en')`,
  reading the HTML text: the hits are `"videoRenderer":{"videoId":"<11 chars>"` followed by
  `"title":{"runs":[{"text":"..."`. Decline cookies at the first dialog (the "Reject" button).
- **Contact sheet** (the method of [[cutscene-pipeline]]): a fixed canvas over the page, then for each time seek
  `video.currentTime`, wait for `seeked` plus 350 to 450 ms, `drawImage`, label it. **Wait about 1.5 s after the script
  returns before the screenshot**: a screenshot taken while it still draws shows only the first frames. At most 9 frames
  of 340x191 or 16 of 255x143 fit the 800x600 pane. An ad: `v.muted = true; v.play()` and poll `.ad-showing`.
- A page's `javascript_tool` calls forget the helper after a navigation: define it again on each watch page.

**Where Ace's source is** (RoleAce, 2026-11-14): the line "I had to test this just in case ... without having to be there in
person" is spoken by L through a voice changer over his logo (episode 2 "Confrontation", transcript on the Death Note
wiki); he is not shown. L crouched in the armchair, tea poured, the cup lifted by its rim between finger and thumb,
wide eyes, the sharp look to the lens: episode 6 "Unraveling", clip `zoJ8QI26Jt4` (82 s). The sweets (a morsel pinched
at the lips, a sugar cube dropped in tea, a cup held by the rim, the arms resting on the knees): the compilation
`WzC8DdTKp0Q` (152 s). The notes are in `art/refs/cinema/RoleAce.toml`.
