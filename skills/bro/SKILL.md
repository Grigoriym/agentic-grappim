---
name: bro
description: Restate your last message in plain language. Use when the user asks for a simpler explanation, says "bro", "in plain English", "explain like a human", "no jargon", or otherwise signals the previous answer was too dense or too technical.
---

# bro

Restate your immediately preceding message. Same content, plain language.

## What to do

1. Take your last message as the only source. Do not add new information, new caveats, or new recommendations.
2. Strip every piece of jargon. If a technical term is unavoidable, name the thing in ordinary words instead of defining the term.
3. Cut everything that was not load-bearing: hedges, disclaimers, restated context, meta-commentary about the answer itself.
4. Say it the way you would say it out loud to a colleague standing next to you.

## Format

- Plain prose. A few short sentences.
- No headers, no bold, no bullet lists unless the original was genuinely a list of separate items — then keep it to short lines.
- Shorter than the original. Usually much shorter.
- Keep file paths, commands, and identifiers exact — those are facts, not jargon.

## Do not

- Do not apologize for the previous message or comment on it being unclear.
- Do not open with a preamble ("Sure", "In short", "Basically").
- Do not soften a conclusion that was stated firmly, or firm up one that was uncertain. If something was genuinely unknown, say you don't know.
- Do not drop a caveat that changes what the user should actually do — say it in plain words instead.

## Example

Before:
> The regression stems from a race condition in the connection pool's lazy initialization path; under concurrent first-use the singleton guard is non-atomic, so two pools get instantiated and the second one shadows the first, leaving orphaned sockets that eventually exhaust the file descriptor limit.

After:
> Two database connection pools get created instead of one when several requests hit at startup at the same time. The extra pool's connections are never closed, and eventually the process runs out of them.
