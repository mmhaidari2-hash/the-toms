# Image regeneration list (quality audit, Oct 2026)

Style target: the existing place paintings, which are warm painterly gouache/oil illustrations of London scenes with soft light and visible brushwork. Not photographic, not flat vector. Portraits are painted head-and-shoulders on a soft warm background.

## Must do
1. **sara.webp** (portrait). The current one is an interim flat PIL drawing and the only flat portrait among 54.
   Prompt: "Painted head-and-shoulders portrait of Sara, a warm Iranian-British woman in her early 30s who works as a nursery practitioner in Hackney. Dark wavy hair loosely tied back, kind smile, mustard cardigan over a teal top, lanyard. Gouache/oil painterly style matching a children's-book London series, soft warm cream background, visible brush texture, square crop."
   When done, run `bash /workspace/stage/finish_sara.sh <image>`.

## Nice to have
2. **museum** and **cinema** map spots have no painting of their own. Their icons are cropped from map.webp.
   - museum: "Painterly illustration of the grand entrance hall of a London museum, dinosaur skeleton, families, warm daylight, gouache style."
   - cinema: "Painterly illustration of a small independent London cinema foyer at evening, popcorn counter, film posters, warm lamps, gouache style."
3. **driving.webp** and **bigsupermarket.webp** are slightly brighter and more photographic than the rest. Regenerate with the same scene and "painterly gouache, warm muted palette, visible brushwork".

## Cleanup
4. The 50 SVG cartoon avatars in `assets/avatars/` are not referenced by characters.json, which uses the painted portraits. Candidate for deletion; kept for now.
