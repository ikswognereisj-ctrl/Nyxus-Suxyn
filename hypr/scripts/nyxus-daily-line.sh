#!/usr/bin/env bash
# NYXUS easter egg - a different cryptic line on the lock screen each day.
# Deterministic: day-of-year picks the line, so it changes at midnight.
LINES=(
# ── THE RULE, learned the hard way on 2026-08-06 ─────────────────────────
# NOTHING HERE MAY READ AS A SYSTEM STATE. The list this replaces contained
#
#     "you were never locked out · only early"
#
# and the owner met it on his own lock screen, read it as the machine telling
# him he was locked out with time left to wait, and reported a lockout bug with
# a fake countdown. There was no countdown. There is no faillock policy in this
# build at all — which is exactly why his password worked immediately while the
# screen appeared to say it would not.
#
# A lock screen is the one surface where a user cannot check anything else. If
# it says something ambiguous, the ambiguity IS the bug. So: no line may mention
# being locked, waiting, trying again, attempts, time remaining, access, denial,
# permission, or errors. Atmosphere only, and nothing that could be mistaken for
# the machine talking about itself.
#
# The old list was also the forked build's voice, not this one's — "alien neon
# online", "the void stares back", "the anomaly the system could not patch",
# "ghosts in the machine". Suxyn is a daily driver with a rose and a galaxy
# sweep, not a horror build.
"the sweep runs teal to plum · and back again"
"deep glass · lit only at the edges"
"a rose is mostly shadow · that is the point"
"every accent here is a ramp · never a flat fill"
"light does the work · not cloudiness"
"the horizon is a light source"
"colour lives in the border · never behind the text"
"built by hand · one pane at a time"
"quiet machine · sharp edges"
"the seam glows because something is on the other side"
"still until you arrive"
"amber sparks · never a field of gold"
"midnight has a hue · and it is blue"
"the petals keep their own light"
"nothing here is a placeholder"
"frost on glass · warmth underneath"
"one material · every surface"
"the dark is not empty · it is deep"
)
IDX=$(( $(date +%-j) % ${#LINES[@]} ))
echo "${LINES[$IDX]}"
