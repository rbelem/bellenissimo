# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Home bakers (amateur to avid) and small-batch professional bakers. Amateurs open it to follow and adapt found recipes without doing conversion math in their head. Pros open it to scale production batches precisely (grams, yields, pan changes). Both use it mid-bake: flour on hands, screen at arm's length, one hand busy.

## Product Purpose

A recipes app for cakes, breads, and pies whose core is a correct scaling engine: kitchen units, density bridges, yield-dimension scaling (count / total grams), pan-volume scaling, ingredient rounding roles, blends, and substitutions. Success is a baker trusting every recomputed quantity at the moment of scaling.

## Positioning

Correctness of the scaling engine — unit bridging, single-rounding semantics, pan-volume and derivative-tree math — is the mechanism a photo-feed recipe app could not truthfully copy.

## Operating Context

Used mid-bake in a kitchen: interruptions frequent, one hand messy, quantities read at a glance from a distance. Also used in prep planning: scaling a recipe to a pan or batch size before starting. Recipes arrive by import (schema.org JSON-LD, planned) or manual entry (planned); seeded cup-weight approximations exist and users may override them.

## Capabilities and Constraints

- Engine (packages/core, pure Dart, 100% line-coverage gate): units, conversions, seeds, yield scaling, single-rounding rule, pans, recipe trees, layered cakes, replacements, blends, substitutions, JSON-LD import.
- Recipes are immutable; scaling returns new instances; derivatives link via parentId.
- Seeds are approximations by design; the UI must let users override them.
- App shell: Flutter; desktop dev runs in a phone-shaped 390×844 window; Android + iOS store targets; persistence not yet built (seed data hardcoded).
- The engine never infers times; timestamps are caller-set data.

## Brand Commitments

Name: bellenissimos (lowercase in the app title). No logo, palette, or typography commitments exist yet.

## Evidence on Hand

Seeded recipes in apps/app/lib/seed_recipes.dart (butter cookies, sandwich loaf, egg-free derivative demonstrating family links). No testimonials, press, or marketing claims exist; none may be fabricated.

## Product Principles

1. Numbers first: every screen makes quantities legible and trustworthy before decoration.
2. Glanceable mid-bake: the next quantity is readable in one look, at arm's length, one-handed.
3. Precision without intimidation: pro-grade math served so an amateur never feels lectured.
4. The engine is the product: UI exists to make scaling visible and trustworthy.
5. User override always: approximations are offered, never imposed.

## Accessibility & Inclusion

Mid-bake use implies large type for at-a-distance reading, high contrast under kitchen lighting, and reachable one-handed targets. No formal standard recorded yet.
